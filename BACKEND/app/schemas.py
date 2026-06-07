from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class UserUpdate(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)


class UserOut(BaseModel):
    id: int
    full_name: str
    email: EmailStr
    is_verified: bool
    is_admin: bool

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    token: str
    user: UserOut


class RegisterResponse(BaseModel):
    message: str
    email: EmailStr
    requires_verification: bool = True


class VerifyEmailIn(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)


class ResendVerificationIn(BaseModel):
    email: EmailStr


class ForgotPasswordIn(BaseModel):
    email: EmailStr


class ResetPasswordIn(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)
    new_password: str = Field(min_length=6, max_length=128)


class GoogleSignInIn(BaseModel):
    id_token: str = Field(min_length=20)


class SpotOut(BaseModel):
    id: int
    name: str
    location: str
    description: str
    category: str
    latitude: float
    longitude: float
    image_url: str
    rating: float
    entrance_fee: str
    opening_hours: str
    transport_guide: str
    emergency_info: str
    weather_note: str

    class Config:
        from_attributes = True


class SpotCreate(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    location: str = Field(min_length=2, max_length=160)
    description: str = Field(min_length=5, max_length=2000)
    category: str = Field(min_length=2, max_length=80)
    latitude: float
    longitude: float
    image_url: str = ""
    rating: float = 4.8
    entrance_fee: str = "Check local tourism office"
    opening_hours: str = "Open daily"
    transport_guide: str = "Use local transport or map directions"
    emergency_info: str = "Call 911 for emergencies"
    weather_note: str = "Check weather before traveling"


class ReviewCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=1000)


class ReviewOut(BaseModel):
    id: int
    spot_id: int
    rating: int
    comment: str
    author_name: str
    created_at: datetime


class PhotoCreate(BaseModel):
    image_url: str = Field(min_length=5, max_length=2_500_000)
    caption: str = Field(default="", max_length=220)


class PhotoOut(BaseModel):
    id: int
    spot_id: int
    image_url: str
    caption: str
    author_name: str
    created_at: datetime


class PostCreate(BaseModel):
    body: str = Field(min_length=1, max_length=1000)
    title: str | None = Field(default=None, max_length=160)
    spot_name: str | None = Field(default=None, max_length=160)
    photo_urls: list[str] = Field(default_factory=list, max_length=20)


class PostOut(BaseModel):
    id: int
    title: str
    body: str
    spot_name: str
    author_name: str
    created_at: datetime
    photo_urls: list[str] = Field(default_factory=list)
    like_count: int = 0
    comment_count: int = 0


class CommentCreate(BaseModel):
    body: str = Field(min_length=1, max_length=700)


class CommentOut(BaseModel):
    id: int
    post_id: int
    body: str
    author_name: str
    created_at: datetime


class ItineraryCreate(BaseModel):
    title: str = Field(min_length=2, max_length=180)
    travel_date: str = Field(default="", max_length=40)
    notes: str = Field(default="", max_length=1000)
    spot_id: int | None = None


class ItineraryOut(BaseModel):
    id: int
    title: str
    travel_date: str
    notes: str
    spot_name: str = ""


class BudgetCreate(BaseModel):
    label: str = Field(min_length=2, max_length=180)
    amount: float = Field(ge=0)
    category: str = Field(default="Other", max_length=80)


class BudgetOut(BaseModel):
    id: int
    label: str
    amount: float
    category: str


class ReportCreate(BaseModel):
    reason: str = Field(min_length=2, max_length=180)
    details: str = Field(default="", max_length=1000)
    spot_id: int | None = None


class BadgeOut(BaseModel):
    title: str
    description: str


class SpotStatusIn(BaseModel):
    visited: bool = False
    favorite: bool = False
    want_to_visit: bool = False


class ProfileStats(BaseModel):
    visited: int
    favorites: int
    want_to_visit: int
    posts: int
