from sqlalchemy.orm import Session

from .models import TouristSpot

SEED_SPOTS = [
    {
        "name": "El Nido",
        "location": "Palawan",
        "description": "Crystal lagoons, limestone cliffs, and island hopping routes.",
        "category": "Beach",
        "latitude": 11.1956,
        "longitude": 119.4075,
        "image_url": "https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?q=80&w=1200&auto=format&fit=crop",
        "rating": 4.9,
    },
    {
        "name": "Mayon Volcano",
        "location": "Albay",
        "description": "Scenic trails and the Philippines' famous perfect cone volcano.",
        "category": "Mountain",
        "latitude": 13.2572,
        "longitude": 123.6859,
        "image_url": "https://images.unsplash.com/photo-1570789210967-2cac24afeb00?q=80&w=1200&auto=format&fit=crop",
        "rating": 4.8,
    },
    {
        "name": "Chocolate Hills",
        "location": "Bohol",
        "description": "Hundreds of rolling hills with a unique dry-season chocolate color.",
        "category": "Nature",
        "latitude": 9.8297,
        "longitude": 124.1397,
        "image_url": "https://images.unsplash.com/photo-1548013146-72479768bada?q=80&w=1200&auto=format&fit=crop",
        "rating": 4.7,
    },
    {
        "name": "Intramuros",
        "location": "Manila",
        "description": "Historic walls, museums, churches, and Spanish-era streets.",
        "category": "Heritage",
        "latitude": 14.5896,
        "longitude": 120.9747,
        "image_url": "https://images.unsplash.com/photo-1570168007204-dfb528c6958f?q=80&w=1200&auto=format&fit=crop",
        "rating": 4.6,
    },
]


def seed_spots(db: Session) -> None:
    if db.query(TouristSpot).count() > 0:
        return
    db.add_all(TouristSpot(**spot) for spot in SEED_SPOTS)
    db.commit()
