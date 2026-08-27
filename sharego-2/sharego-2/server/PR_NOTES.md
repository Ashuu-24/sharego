# PR Notes - Feature A Booking Actions

## Endpoints implemented/validated
- `POST /bookings/{id}/accept`
- `POST /bookings/{id}/decline`
- `POST /bookings/{id}/pickup/verify`
- `POST /bookings/{id}/delivery/verify`
- `POST /bookings/{id}/cancel`
- `POST /bookings/{id}/expire` (admin-only stub until scheduler wiring)
- `POST /admin/escrow/{id}/release`
- `POST /admin/escrow/{id}/refund`

## OTP generation behavior (QA)
- OTPs are issued during booking creation (`POST /bookings`).
- Storage is hash-only (`bcrypt`): no plaintext OTP persisted.
- Dev-only fields returned for testing:
  - `pickup_otp_dev`
  - `delivery_otp_dev`
- OTPs are single-use and cleared after successful verify.

## Additional checks added
- Waybill format assertion: `^SG-\d{4}-\d{6}$`.
- Ownership/role guards covered:
  - non-traveler cannot accept/decline/pickup
  - non-buyer cannot delivery/verify
  - uninvolved user gets `403` on booking actions
- Cancel/expire flow coverage:
  - initiator cancel while `REQUESTED/HOLD_PLACED`
  - expire stub transition for scheduler parity
- Audit assertions include booking and escrow transitions.

## Marketplace implementation
- Implemented OLX-style marketplace flows (no auction/escrow/courier logic):
  - `POST /market/listings`
  - `GET /market/listings`
  - `GET /market/listings/{id}`
  - `PATCH /market/listings/{id}`
  - `POST|PATCH /market/listings/{id}/mark_sold`
  - `POST /market/listings/{id}/offer`
  - `GET /market/listings/{id}/offers` (participant-only thread view)
  - `POST /market/offers/{id}/counter`
  - `POST /market/offers/{id}/accept`
  - `POST /market/offers/{id}/decline`
  - `POST /market/offers/{id}/withdraw`
  - `POST /market/meetups`
  - `GET /market/meetups/{id}` (participant-only)
  - `POST /market/meetups/{id}/confirm`
- All marketplace response models include a standard `marketplace_disclaimer` field.
- Marketplace errors use unified core envelope via global handlers:
  - shape: `{ "error": { "code": "http_<status>", "message": "...", "details"?: ... } }`
- Listing filters implemented on `GET /market/listings`:
  - `query`
  - `category`
  - near filter by either:
    - `near=lat,lng,radius_km`
    - or `latitude=<lat>&longitude=<lng>&radius_km=<r>`
  - price range:
    - `min`/`max` aliases
    - `min_price`/`max_price` also supported
  - `status` (default `active`)
- Added integration test `tests/test_market_listing_offer_flow.py` covering:
  - listing -> offer -> counter -> accept -> meetup create -> confirm -> mark sold
  - unauthorized actions (403) and invalid transitions (400)
  - explicit non-participant 403 checks for offer thread and meetup read
  - explicit seller-only action 403 checks (counter/decline/accept)
  - listing filter behavior for query/category/near/price/status
