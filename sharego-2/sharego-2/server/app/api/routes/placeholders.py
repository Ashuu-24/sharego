from fastapi import APIRouter, HTTPException, status

router = APIRouter(tags=["pending"])


@router.api_route("/escrow", methods=["GET", "POST"])
@router.api_route("/offers", methods=["GET", "POST"])
@router.api_route("/meetups", methods=["GET", "POST"])
@router.api_route("/messages", methods=["GET", "POST"])
async def not_implemented():
    raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="Planned in Sprint 2+")
