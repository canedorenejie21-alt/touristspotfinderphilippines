from datetime import datetime

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import func, inspect, text
from sqlalchemy.orm import Session

from .auth import create_token, get_current_user, hash_password, verify_password
from .config import get_settings
from .database import Base, engine, get_db
from .models import (
    BudgetItem,
    EmailVerificationCode,
    ItineraryItem,
    PasswordResetCode,
    PostComment,
    PostLike,
    SpotPhoto,
    SpotReport,
    SpotReview,
    TouristSpot,
    TravelPost,
    User,
    UserSpotStatus,
)
from .schemas import (
    AuthResponse,
    BadgeOut,
    BudgetCreate,
    BudgetOut,
    CommentCreate,
    CommentOut,
    ForgotPasswordIn,
    ItineraryCreate,
    ItineraryOut,
    PhotoCreate,
    PhotoOut,
    PostCreate,
    PostOut,
    ProfileStats,
    RegisterResponse,
    ResendVerificationIn,
    ResetPasswordIn,
    ReportCreate,
    ReviewCreate,
    ReviewOut,
    SpotCreate,
    SpotOut,
    SpotStatusIn,
    UserCreate,
    UserLogin,
    UserOut,
    UserUpdate,
    VerifyEmailIn,
)
from .seed import seed_spots
from .verification import (
    create_and_send_password_reset_code,
    create_and_send_verification_code,
    hash_code,
)

settings = get_settings()
EMAIL_DELIVERY_ERROR = "Email sending failed. Check SMTP variables in the backend host."

app = FastAPI(title="Tourist Spot Finder PH API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.frontend_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(bind=engine)
    ensure_user_columns()
    ensure_tourist_spot_columns()
    db = next(get_db())
    try:
        seed_spots(db)
        apply_admin_emails(db)
    finally:
        db.close()


def ensure_user_columns() -> None:
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("users")}
    with engine.begin() as connection:
        if "is_verified" not in columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN is_verified BOOLEAN NOT NULL DEFAULT FALSE")
            )
        if "is_admin" not in columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE")
            )


def apply_admin_emails(db: Session) -> None:
    if not settings.admin_emails:
        return
    db.query(User).filter(func.lower(User.email).in_(settings.admin_emails)).update(
        {User.is_admin: True},
        synchronize_session=False,
    )
    db.commit()


def ensure_tourist_spot_columns() -> None:
    inspector = inspect(engine)
    if "tourist_spots" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("tourist_spots")}
    additions = {
        "entrance_fee": "VARCHAR(120) NOT NULL DEFAULT 'Check local tourism office'",
        "opening_hours": "VARCHAR(120) NOT NULL DEFAULT 'Open daily'",
        "transport_guide": "TEXT NOT NULL DEFAULT 'Use local transport or map directions'",
        "emergency_info": "TEXT NOT NULL DEFAULT 'Call 911 for emergencies'",
        "weather_note": "VARCHAR(220) NOT NULL DEFAULT 'Check weather before traveling'",
    }
    with engine.begin() as connection:
        for name, ddl in additions.items():
            if name not in columns:
                connection.execute(text(f"ALTER TABLE tourist_spots ADD COLUMN {name} {ddl}"))


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin account required")
    return current_user


@app.post("/auth/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, db: Session = Depends(get_db)) -> RegisterResponse:
    existing = db.query(User).filter(func.lower(User.email) == payload.email.lower()).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email is already registered")
    user = User(
        full_name=payload.full_name.strip(),
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        is_verified=not settings.require_email_verification,
        is_admin=payload.email.lower() in settings.admin_emails,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    if settings.require_email_verification:
        try:
            create_and_send_verification_code(db, user)
        except RuntimeError as exc:
            raise HTTPException(
                status_code=503,
                detail=EMAIL_DELIVERY_ERROR,
            ) from exc
    return RegisterResponse(
        message=(
            "Verification code sent to your email"
            if settings.require_email_verification
            else "Account created successfully"
        ),
        email=user.email,
        requires_verification=settings.require_email_verification,
    )


@app.post("/auth/resend-verification", response_model=RegisterResponse)
def resend_verification(
    payload: ResendVerificationIn,
    db: Session = Depends(get_db),
) -> RegisterResponse:
    user = db.query(User).filter(func.lower(User.email) == payload.email.lower()).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email is not registered")
    if user.is_verified:
        raise HTTPException(status_code=400, detail="Email is already verified")
    try:
        create_and_send_verification_code(db, user)
    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=EMAIL_DELIVERY_ERROR,
        ) from exc
    return RegisterResponse(
        message="Verification code sent to your email",
        email=user.email,
    )


@app.post("/auth/verify-email", response_model=AuthResponse)
def verify_email(payload: VerifyEmailIn, db: Session = Depends(get_db)) -> AuthResponse:
    user = db.query(User).filter(func.lower(User.email) == payload.email.lower()).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email is not registered")
    if user.is_verified:
        return AuthResponse(token=create_token(user.id), user=UserOut.model_validate(user))

    code_row = (
        db.query(EmailVerificationCode)
        .filter(
            EmailVerificationCode.user_id == user.id,
            EmailVerificationCode.used_at.is_(None),
        )
        .order_by(EmailVerificationCode.created_at.desc())
        .first()
    )
    if not code_row or code_row.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Verification code expired")
    if code_row.code_hash != hash_code(payload.code):
        raise HTTPException(status_code=400, detail="Invalid verification code")

    code_row.used_at = datetime.utcnow()
    user.is_verified = True
    db.commit()
    db.refresh(user)
    return AuthResponse(token=create_token(user.id), user=UserOut.model_validate(user))


@app.post("/auth/login", response_model=AuthResponse)
def login(payload: UserLogin, db: Session = Depends(get_db)) -> AuthResponse:
    user = db.query(User).filter(func.lower(User.email) == payload.email.lower()).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if not settings.require_email_verification and not user.is_verified:
        user.is_verified = True
        db.commit()
        db.refresh(user)
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="Please verify your email before logging in")
    return AuthResponse(token=create_token(user.id), user=UserOut.model_validate(user))


@app.post("/auth/forgot-password")
def forgot_password(payload: ForgotPasswordIn, db: Session = Depends(get_db)) -> dict[str, str]:
    user = db.query(User).filter(func.lower(User.email) == payload.email.lower()).first()
    if user:
        try:
            create_and_send_password_reset_code(db, user)
        except RuntimeError as exc:
            raise HTTPException(
                status_code=503,
                detail=EMAIL_DELIVERY_ERROR,
            ) from exc
    return {"message": "If the email exists, a reset code has been sent"}


@app.post("/auth/reset-password")
def reset_password(payload: ResetPasswordIn, db: Session = Depends(get_db)) -> dict[str, str]:
    user = db.query(User).filter(func.lower(User.email) == payload.email.lower()).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email is not registered")
    code_row = (
        db.query(PasswordResetCode)
        .filter(
            PasswordResetCode.user_id == user.id,
            PasswordResetCode.used_at.is_(None),
        )
        .order_by(PasswordResetCode.created_at.desc())
        .first()
    )
    if not code_row or code_row.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Reset code expired")
    if code_row.code_hash != hash_code(payload.code):
        raise HTTPException(status_code=400, detail="Invalid reset code")

    code_row.used_at = datetime.utcnow()
    user.password_hash = hash_password(payload.new_password)
    db.commit()
    return {"message": "Password reset successful"}


@app.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)) -> User:
    return current_user


@app.put("/me", response_model=UserOut)
def update_me(
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> User:
    current_user.full_name = payload.full_name.strip()
    db.commit()
    db.refresh(current_user)
    return current_user


@app.get("/spots", response_model=list[SpotOut])
def spots(
    q: str = Query(default=""),
    category: str = Query(default=""),
    db: Session = Depends(get_db),
) -> list[TouristSpot]:
    query = db.query(TouristSpot)
    if q:
        pattern = f"%{q.lower()}%"
        query = query.filter(
            func.lower(TouristSpot.name).like(pattern)
            | func.lower(TouristSpot.location).like(pattern)
            | func.lower(TouristSpot.description).like(pattern)
        )
    if category:
        query = query.filter(func.lower(TouristSpot.category) == category.lower())
    return query.order_by(TouristSpot.name).all()


@app.post("/admin/spots", response_model=SpotOut, status_code=status.HTTP_201_CREATED)
def create_spot(
    payload: SpotCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
) -> TouristSpot:
    spot = TouristSpot(**payload.model_dump())
    db.add(spot)
    db.commit()
    db.refresh(spot)
    return spot


@app.get("/spots/{spot_id}/reviews", response_model=list[ReviewOut])
def spot_reviews(spot_id: int, db: Session = Depends(get_db)) -> list[ReviewOut]:
    rows = (
        db.query(SpotReview)
        .filter(SpotReview.spot_id == spot_id)
        .order_by(SpotReview.created_at.desc())
        .all()
    )
    return [
        ReviewOut(
            id=row.id,
            spot_id=row.spot_id,
            rating=row.rating,
            comment=row.comment,
            author_name=row.user.full_name,
            created_at=row.created_at,
        )
        for row in rows
    ]


@app.post("/spots/{spot_id}/reviews", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
def create_review(
    spot_id: int,
    payload: ReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ReviewOut:
    spot = db.get(TouristSpot, spot_id)
    if not spot:
        raise HTTPException(status_code=404, detail="Spot not found")
    review = (
        db.query(SpotReview)
        .filter(SpotReview.user_id == current_user.id, SpotReview.spot_id == spot_id)
        .first()
    )
    if not review:
        review = SpotReview(user_id=current_user.id, spot_id=spot_id)
        db.add(review)
    review.rating = payload.rating
    review.comment = payload.comment.strip()
    db.commit()
    db.refresh(review)
    avg_rating = db.query(func.avg(SpotReview.rating)).filter(SpotReview.spot_id == spot_id).scalar()
    spot.rating = round(float(avg_rating or spot.rating), 1)
    db.commit()
    return ReviewOut(
        id=review.id,
        spot_id=review.spot_id,
        rating=review.rating,
        comment=review.comment,
        author_name=current_user.full_name,
        created_at=review.created_at,
    )


@app.get("/spots/{spot_id}/photos", response_model=list[PhotoOut])
def spot_photos(spot_id: int, db: Session = Depends(get_db)) -> list[PhotoOut]:
    rows = (
        db.query(SpotPhoto)
        .filter(SpotPhoto.spot_id == spot_id)
        .order_by(SpotPhoto.created_at.desc())
        .all()
    )
    return [
        PhotoOut(
            id=row.id,
            spot_id=row.spot_id,
            image_url=row.image_url,
            caption=row.caption,
            author_name=row.user.full_name,
            created_at=row.created_at,
        )
        for row in rows
    ]


@app.post("/spots/{spot_id}/photos", response_model=PhotoOut, status_code=status.HTTP_201_CREATED)
def create_photo(
    spot_id: int,
    payload: PhotoCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PhotoOut:
    if not db.get(TouristSpot, spot_id):
        raise HTTPException(status_code=404, detail="Spot not found")
    photo = SpotPhoto(
        user_id=current_user.id,
        spot_id=spot_id,
        image_url=payload.image_url.strip(),
        caption=payload.caption.strip(),
    )
    db.add(photo)
    db.commit()
    db.refresh(photo)
    return PhotoOut(
        id=photo.id,
        spot_id=photo.spot_id,
        image_url=photo.image_url,
        caption=photo.caption,
        author_name=current_user.full_name,
        created_at=photo.created_at,
    )


@app.get("/spots/trending", response_model=list[SpotOut])
def trending_spots(db: Session = Depends(get_db)) -> list[TouristSpot]:
    review_counts = (
        db.query(SpotReview.spot_id, func.count(SpotReview.id).label("count"))
        .group_by(SpotReview.spot_id)
        .subquery()
    )
    return (
        db.query(TouristSpot)
        .outerjoin(review_counts, TouristSpot.id == review_counts.c.spot_id)
        .order_by(TouristSpot.rating.desc(), func.coalesce(review_counts.c.count, 0).desc())
        .limit(10)
        .all()
    )


def post_to_out(row: TravelPost, db: Session) -> PostOut:
    like_count = db.query(PostLike).filter(PostLike.post_id == row.id).count()
    comment_count = db.query(PostComment).filter(PostComment.post_id == row.id).count()
    return PostOut(
        id=row.id,
        title=row.title,
        body=row.body,
        spot_name=row.spot_name,
        author_name=row.author.full_name,
        created_at=row.created_at,
        like_count=like_count,
        comment_count=comment_count,
    )


@app.get("/posts", response_model=list[PostOut])
def posts(db: Session = Depends(get_db)) -> list[PostOut]:
    rows = db.query(TravelPost).order_by(TravelPost.created_at.desc()).limit(50).all()
    return [post_to_out(row, db) for row in rows]


@app.post("/posts", response_model=PostOut, status_code=status.HTTP_201_CREATED)
def create_post(
    payload: PostCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PostOut:
    title = payload.title.strip() if payload.title else "Traveler Update"
    spot_name = payload.spot_name.strip() if payload.spot_name else ""
    post = TravelPost(
        user_id=current_user.id,
        title=title,
        body=payload.body.strip(),
        spot_name=spot_name,
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return post_to_out(post, db)


@app.post("/posts/{post_id}/like")
def toggle_post_like(
    post_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, int | bool]:
    if not db.get(TravelPost, post_id):
        raise HTTPException(status_code=404, detail="Post not found")
    like = (
        db.query(PostLike)
        .filter(PostLike.post_id == post_id, PostLike.user_id == current_user.id)
        .first()
    )
    liked = like is None
    if like:
        db.delete(like)
    else:
        db.add(PostLike(post_id=post_id, user_id=current_user.id))
    db.commit()
    count = db.query(PostLike).filter(PostLike.post_id == post_id).count()
    return {"liked": liked, "like_count": count}


@app.get("/posts/{post_id}/comments", response_model=list[CommentOut])
def post_comments(post_id: int, db: Session = Depends(get_db)) -> list[CommentOut]:
    rows = (
        db.query(PostComment)
        .filter(PostComment.post_id == post_id)
        .order_by(PostComment.created_at.asc())
        .all()
    )
    return [
        CommentOut(
            id=row.id,
            post_id=row.post_id,
            body=row.body,
            author_name=row.user.full_name,
            created_at=row.created_at,
        )
        for row in rows
    ]


@app.post("/posts/{post_id}/comments", response_model=CommentOut, status_code=status.HTTP_201_CREATED)
def create_post_comment(
    post_id: int,
    payload: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CommentOut:
    if not db.get(TravelPost, post_id):
        raise HTTPException(status_code=404, detail="Post not found")
    comment = PostComment(post_id=post_id, user_id=current_user.id, body=payload.body.strip())
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return CommentOut(
        id=comment.id,
        post_id=comment.post_id,
        body=comment.body,
        author_name=current_user.full_name,
        created_at=comment.created_at,
    )


@app.put("/spots/{spot_id}/status")
def update_spot_status(
    spot_id: int,
    payload: SpotStatusIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, bool]:
    spot = db.get(TouristSpot, spot_id)
    if spot is None:
        raise HTTPException(status_code=404, detail="Spot not found")
    status_row = (
        db.query(UserSpotStatus)
        .filter(UserSpotStatus.user_id == current_user.id, UserSpotStatus.spot_id == spot_id)
        .first()
    )
    if status_row is None:
        status_row = UserSpotStatus(user_id=current_user.id, spot_id=spot_id)
        db.add(status_row)
    status_row.visited = payload.visited
    status_row.favorite = payload.favorite
    status_row.want_to_visit = payload.want_to_visit
    db.commit()
    return {
        "visited": status_row.visited,
        "favorite": status_row.favorite,
        "want_to_visit": status_row.want_to_visit,
    }


@app.get("/spots/{spot_id}/status")
def get_spot_status(
    spot_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, bool]:
    row = (
        db.query(UserSpotStatus)
        .filter(UserSpotStatus.user_id == current_user.id, UserSpotStatus.spot_id == spot_id)
        .first()
    )
    return {
        "visited": bool(row and row.visited),
        "favorite": bool(row and row.favorite),
        "want_to_visit": bool(row and row.want_to_visit),
    }


@app.get("/itinerary", response_model=list[ItineraryOut])
def itinerary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[ItineraryOut]:
    rows = (
        db.query(ItineraryItem)
        .filter(ItineraryItem.user_id == current_user.id)
        .order_by(ItineraryItem.travel_date.asc(), ItineraryItem.created_at.desc())
        .all()
    )
    return [
        ItineraryOut(
            id=row.id,
            title=row.title,
            travel_date=row.travel_date,
            notes=row.notes,
            spot_name=row.spot.name if row.spot else "",
        )
        for row in rows
    ]


@app.post("/itinerary", response_model=ItineraryOut, status_code=status.HTTP_201_CREATED)
def create_itinerary_item(
    payload: ItineraryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ItineraryOut:
    item = ItineraryItem(
        user_id=current_user.id,
        spot_id=payload.spot_id,
        title=payload.title.strip(),
        travel_date=payload.travel_date.strip(),
        notes=payload.notes.strip(),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return ItineraryOut(
        id=item.id,
        title=item.title,
        travel_date=item.travel_date,
        notes=item.notes,
        spot_name=item.spot.name if item.spot else "",
    )


@app.delete("/itinerary/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_itinerary_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    item = db.query(ItineraryItem).filter(ItineraryItem.id == item_id, ItineraryItem.user_id == current_user.id).first()
    if item:
        db.delete(item)
        db.commit()


@app.get("/budget", response_model=list[BudgetOut])
def budget(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[BudgetOut]:
    rows = db.query(BudgetItem).filter(BudgetItem.user_id == current_user.id).order_by(BudgetItem.created_at.desc()).all()
    return [BudgetOut(id=row.id, label=row.label, amount=row.amount, category=row.category) for row in rows]


@app.post("/budget", response_model=BudgetOut, status_code=status.HTTP_201_CREATED)
def create_budget_item(
    payload: BudgetCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BudgetOut:
    item = BudgetItem(
        user_id=current_user.id,
        label=payload.label.strip(),
        amount=payload.amount,
        category=payload.category.strip(),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return BudgetOut(id=item.id, label=item.label, amount=item.amount, category=item.category)


@app.delete("/budget/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_budget_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    item = db.query(BudgetItem).filter(BudgetItem.id == item_id, BudgetItem.user_id == current_user.id).first()
    if item:
        db.delete(item)
        db.commit()


@app.post("/reports", status_code=status.HTTP_201_CREATED)
def create_report(
    payload: ReportCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, str]:
    db.add(
        SpotReport(
            user_id=current_user.id,
            spot_id=payload.spot_id,
            reason=payload.reason.strip(),
            details=payload.details.strip(),
        )
    )
    db.commit()
    return {"message": "Report submitted"}


@app.get("/me/badges", response_model=list[BadgeOut])
def badges(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[BadgeOut]:
    statuses = db.query(UserSpotStatus).filter(UserSpotStatus.user_id == current_user.id).all()
    post_count = db.query(TravelPost).filter(TravelPost.user_id == current_user.id).count()
    review_count = db.query(SpotReview).filter(SpotReview.user_id == current_user.id).count()
    result = [BadgeOut(title="Verified Traveler", description="Verified email account")]
    if sum(1 for row in statuses if row.favorite) >= 3:
        result.append(BadgeOut(title="Wishlist Builder", description="Saved 3 favorite spots"))
    if sum(1 for row in statuses if row.visited) >= 3:
        result.append(BadgeOut(title="Explorer", description="Marked 3 spots as visited"))
    if post_count >= 3:
        result.append(BadgeOut(title="Community Voice", description="Shared 3 travel posts"))
    if review_count >= 3:
        result.append(BadgeOut(title="Helpful Reviewer", description="Reviewed 3 tourist spots"))
    return result


@app.get("/admin/analytics")
def admin_analytics(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
) -> dict[str, int | float]:
    return {
        "users": db.query(User).count(),
        "verified_users": db.query(User).filter(User.is_verified.is_(True)).count(),
        "tourist_spots": db.query(TouristSpot).count(),
        "posts": db.query(TravelPost).count(),
        "reviews": db.query(SpotReview).count(),
        "photos": db.query(SpotPhoto).count(),
        "reports": db.query(SpotReport).count(),
        "average_rating": round(float(db.query(func.avg(TouristSpot.rating)).scalar() or 0), 2),
    }


@app.get("/profile/stats", response_model=ProfileStats)
def profile_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProfileStats:
    rows = db.query(UserSpotStatus).filter(UserSpotStatus.user_id == current_user.id).all()
    post_count = db.query(TravelPost).filter(TravelPost.user_id == current_user.id).count()
    return ProfileStats(
        visited=sum(1 for row in rows if row.visited),
        favorites=sum(1 for row in rows if row.favorite),
        want_to_visit=sum(1 for row in rows if row.want_to_visit),
        posts=post_count,
    )
