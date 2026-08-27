from fastapi import APIRouter

from app.api.routes import (
    admin,
    admin_auth,
    admin_escrow,
    admin_kyc,
    ai,
    auth,
    bank,
    bookings,
    feature_flags,
    health,
    kyc,
    matching,
    marketplace,
    media,
    messages,
    notifications,
    ws, 
    requests,
    reviews,
    trips,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(bank.router)
api_router.include_router(admin_auth.router)
api_router.include_router(admin.router)
api_router.include_router(admin_escrow.router)
api_router.include_router(admin_kyc.router)
api_router.include_router(users.router)
api_router.include_router(trips.router)
api_router.include_router(kyc.router)
api_router.include_router(requests.router)
api_router.include_router(matching.router)
api_router.include_router(bookings.router)
api_router.include_router(marketplace.router)
api_router.include_router(media.router)
api_router.include_router(reviews.router)
api_router.include_router(ai.router)
api_router.include_router(feature_flags.router)
api_router.include_router(messages.router)
api_router.include_router(notifications.router)
api_router.include_router(ws.router) 
