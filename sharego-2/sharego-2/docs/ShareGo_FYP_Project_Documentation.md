# Flyro — Final Year Project Documentation
*Mobile Marketplace for Travelers • Feature A: Personal Shopping with Escrow (Simulation) • Feature B: OLX-style Overweight Marketplace (Bargaining Only)*  
**Backend:** FastAPI + Jinja2 Admin + SQLite  
**AI Assistant:** Simple LLM (No RAG, Read-only DB Tools)

**Version:** 1.0  
**Date:** 15 Feb 2026

---

## Document Control
| Item | Value |
|---|---|
| Project Name | Flyro |
| Document Purpose | Explain Flyro product scope, flows, requirements, edge cases, and chosen technologies. Provide implementation points (milestones) without code. |
| Audience | FYP evaluators, supervisor, potential investor-style reviewers, development team |
| Out of Scope | Production hosting, real money payments, real-time airport notifications at scale, and official integrations with airlines/customs authorities (FYP uses simulation/stubs). |

---

## Executive Summary
Flyro is a traveler-first mobile marketplace. It solves two practical problems for Pakistan-focused cross-border travel and airport scenarios:

1) **Personal Shopping & Delivery (Escrow Simulation):** A buyer requests an item from abroad (e.g., iPhone from the US). A traveler coming to Pakistan accepts the job, purchases the item using their own money, and delivers it in Pakistan. The buyer’s payment is held in a simulated escrow, and is released (with traveler commission) only after verified handover.

2) **Overweight Marketplace (OLX-style Classifieds):** A traveler (or any user) can list items for sale from any location (airport, city, etc.) when they cannot carry them (e.g., baggage overweight). Interested users negotiate privately using offer/counter-offer (bargaining), then meet and complete the deal. Flyro does not handle courier/logistics or payments for marketplace deals; it only provides listing, bargaining, and optional meetup confirmation for record.

For the FYP, Flyro runs locally using FastAPI with SQLite, includes a Jinja2 admin panel, and uses a constrained AI assistant (no RAG) that answers only Flyro- and policy-related questions using curated FAQs and read-only database tools.

---

# PRD Touch

## Problem Statement
- International courier and customs charges can make overseas purchases expensive or slow for Pakistan-based buyers.
- Travelers often have unused baggage allowance, but lack a safe and structured way to offer help and earn commission.
- At airports, overweight baggage can cause loss or forced disposal of items; a quick local resale mechanism can save value.

## Goals
- Enable traveler-first jobs: traveler earns commission by purchasing and bringing items to Pakistan (Feature A).
- Provide a classifieds marketplace for quick resale of items from any location using bargaining (Feature B).
- Maintain trust with identity checks, escrow simulation, handover verification, and ratings/reviews.
- Deliver an end-to-end demo-ready system suitable for FYP evaluation without production deployment.

## Non-Goals
- Flyro does not perform or guarantee customs clearance.
- Flyro does not provide courier delivery or shipment tracking for marketplace deals.
- Flyro does not process real payments (escrow is simulated for FYP).
- Flyro does not provide legal advice; it shows advisories and recommends official sources.

## Users and Roles
| Role | Description | Key Actions |
|---|---|---|
| Traveler | Primary target user. Posts trips and accepts shopping jobs; can also use marketplace. | Post trip, accept booking, purchase item, handover, receive escrow release, review |
| Buyer | Requests an overseas item and pays into escrow simulation. | Post request, negotiate, fund escrow, receive item, confirm delivery, review |
| Marketplace Seller | Lists items for sale (often due to overweight). | Create listing, negotiate offers, arrange meetup, mark sold, review |
| Marketplace Buyer | Browses listings and bargains. | Search listings, send offer, negotiate, arrange meetup, review |
| Admin/Ops | FYP demo operator. Approves KYC and can release/refund escrow. | Approve/reject KYC, view timelines, release/refund escrow, moderate listings |

## Key Success Metrics (FYP Demo)
- End-to-end Feature A demo completes: trip + request + booking + pickup/delivery verification + escrow release.
- End-to-end Feature B demo completes: listing + offer/counter + accept + meetup confirmation + mark sold.
- Security: unauthorized users cannot perform booking/offer actions; OTP and rate limits prevent abuse.
- Admin panel shows real state changes with audit logs.

---

# Scope and Functional Requirements

## Feature A — Personal Shopping with Escrow (Simulation)
- Trip posting by traveler (route, date, capacity/space, optional proof).
- Buyer posts item request (product, specs, budget/target price, destination city, time window).
- Matching suggestions (rule-based): route/destination, date window, and capacity constraints.
- Negotiation (in-app chat or external contact; for FYP, basic chat is optional).
- Booking creation: buyer funds simulated escrow; booking transitions follow controlled state machine.
- Traveler acceptance/decline.
- Traveler uploads purchase proof (receipt image).
- Handover verification: pickup and delivery confirmations using OTP/QR, GPS, photos, and seal identifier.
- Admin escrow release/refund actions (simulated wallet ledger).
- Ratings and reviews after completion.

## Feature B — Overweight Marketplace (OLX-style Bargaining)
- Listings can be created from **any location** (airport/city/anywhere).
- Listing includes: title, description, category, condition, photos, ask price, location text, optional map coordinates.
- Search and filters: keyword, category, near-me radius, price range, active listings only.
- Bargaining only: offer / counter-offer / accept / decline / withdraw.
- Private offer threads (only seller and the specific buyer see it).
- Optional meetup creation and OTP confirmation (record only).
- Seller can mark listing as sold; listing removed from active feeds.
- Reviews for marketplace deals (optional for FYP).
- Disclaimer displayed: Flyro does not handle delivery, payment, or customs for marketplace deals.

## Identity Verification and KYC
Flyro uses identity verification to reduce fraud. For the FYP, verification is manual (admin approves).

- Pakistan users: CNIC + selfie (manual review).
- Foreign nationals (no Pakistani CNIC): passport + selfie; optionally visa/entry stamp image.
- If a user cannot provide official ID in FYP demo: they are limited to browsing only or sandbox mode (admin-controlled feature flag).
- KYC status: pending, approved, rejected; rejection requires reason notes.

---

# Detailed App Flows and All Outcomes

## Feature A Flow — Personal Shopping (Escrow Simulation)
1. User signs up with email OTP and creates a profile.
2. User submits KYC (CNIC/Passport + selfie). Admin approves or rejects.
3. Traveler posts a Trip (origin airport, destination airport, date, available baggage capacity).
4. Buyer posts a Request (item, specs, target price, weight estimate, destination city, time window).
5. Flyro suggests matches. Buyer contacts traveler and negotiates terms (price, commission, delivery city).
6. Buyer creates Booking and funds simulated escrow (hold). Booking moves to **HOLD_PLACED**.
7. Traveler accepts (or declines). If accepted, Booking moves to **ACCEPTED**.
8. Traveler purchases item using own money and uploads receipt proof.
9. Pickup verification (optional) — system records GPS/photos and seal ID, moves to **PICKUP_OK**.
10. Delivery verification in Pakistan — OTP/QR + seal match + photos/GPS. Booking moves to **DELIVERY_OK**.
11. Admin releases escrow (simulated) to traveler wallet including commission. Booking becomes **RELEASED**.
12. Both parties can leave rating/review.

### Feature A — Possible Outcomes / Edge Cases
| Scenario | Expected System Behavior |
|---|---|
| Traveler declines after HOLD_PLACED | Booking becomes CANCELLED; admin can trigger refund to buyer wallet (sim). |
| Buyer cancels before traveler accepts | If allowed: booking CANCELLED and escrow refunded; cancellation recorded in audit logs. |
| Traveler accepts but fails to deliver | Buyer opens dispute (optional). Admin reviews evidence and refunds/splits as policy. |
| OTP entered wrong multiple times | Rate limit and lockout for that action; log attempt; require admin override in demo if needed. |
| Seal mismatch on delivery | Delivery verification blocked; dispute path recommended. |
| Receipt/proof missing | Booking can proceed, but trust score reduced or admin requires proof via feature flags. |
| KYC rejected | User restricted from creating trips/bookings; can resubmit. |
| Foreign national has passport only | Allowed (manual approval). |
| Missing official ID | Browsing-only or sandbox-restricted. |

## Feature B Flow — Overweight Marketplace (Classifieds)
1. Seller creates a Marketplace Listing from any location with photos, ask price, and location text.
2. Buyers browse/search listings (keyword/category/near-me/price).
3. A buyer sends an Offer (bargain). Seller can counter, accept, or decline.
4. If accepted, parties arrange meetup and payment outside Flyro.
5. Optional: create a Meetup in Flyro with place/time; OTP confirms meetup occurred (record only).
6. Seller marks listing as **SOLD**; removed from active feed.
7. Optional: both leave reviews.

### Feature B — Possible Outcomes / Edge Cases
| Scenario | Expected System Behavior |
|---|---|
| Multiple buyers send offers | Offers remain private per buyer thread; seller chooses one to accept. |
| Buyer withdraws offer | Offer becomes WITHDRAWN; thread still viewable to participants. |
| Seller pauses listing | Listing hidden from active search; can resume later. |
| Listing reported/flagged | Admin can remove/flag; listing removed from public feed. |
| Meetup OTP not confirmed | Deal can still be marked sold; OTP is optional record. |
| Buyer in another city | Allowed; logistics are user-managed and disclaimed. |
| Seller attempts auction | Not supported; no public bids and bargaining-only lifecycle. |

---

# Technology and System Components

## Frontend (Mobile)
- Flutter (single app for travelers and buyers; Android-first for FYP).
- Device features: camera upload, optional QR scan, GPS capture.

## Backend
- FastAPI (Python) REST APIs + Jinja2 server-rendered admin panel.
- SQLite database (local file) for FYP.
- SQLModel/SQLAlchemy ORM + Alembic migrations.
- SlowAPI rate limiting.
- Passlib (bcrypt) for OTP/code hashing.
- APScheduler for expiry/cleanup jobs.

## Admin Panel
- Jinja2 templates: dashboard, KYC queue, booking timelines, escrow actions, marketplace moderation, feature flags.
- Admin actions are audited (before/after snapshots).

## AI Assistant
- Simple LLM API with strict system prompt (Flyro-only).
- No RAG: answers only from curated FAQ dict + read-only DB tools + policy_flags lookup + simple calculators.
- Read-only tools: booking status, user trips/requests, marketplace listing search, offers for own listing.
- Safety: refuses contraband/illegal instructions; no legal advice (advisory only).

---

# Implementation Points (Milestones) — Not Code
1. Foundation: finalize migrations, security hardening (OTP hashing, throttles), unified error responses, audit log skeleton.
2. Feature A model completion: requests, bookings, escrow, wallet ledger, handover events; finalize state machine constants.
3. Feature A API readiness: requests CRUD, matching suggestions, booking transitions, handover verification, admin release/refund.
4. Feature B marketplace readiness: listings CRUD + search, offer bargaining lifecycle, meetup record confirmation, mark sold, moderation hooks.
5. Admin MVP: dashboard KPIs, KYC approve/reject, booking timeline, escrow actions, marketplace moderation, feature flags.
6. Media pipeline: upload validation and safe path policy reused across KYC/receipts/handover/listings.
7. Tasks and cleanup: booking/listing expiration sweeps and demo seed scripts.
8. AI assistant: strict prompt + FAQ + read-only tools; no write actions; test refusals and access controls.
9. Testing and demo hardening: end-to-end tests for both features, ownership tests, demo scripts.

---

# Non-Functional Requirements and Security

## Security Controls
- JWT authentication for protected endpoints.
- Role guards for admin operations (KYC approval, escrow release/refund).
- OTP/code hashing using bcrypt; single-use consumption.
- Rate limiting for OTP endpoints and sensitive actions.
- Owner checks: only participants can view/act on their bookings and marketplace offer threads.
- Audit logs for admin mutations and security-sensitive actions.

## Privacy
- Store only necessary identity documents for FYP; private UUID-based filenames.
- Avoid logging raw PII; use request-id and user-id references.

## Performance (FYP scale)
- SQLite WAL mode to reduce lock contention during demos.
- Short DB transactions and retry-on-locked writes.

## Known Limitations (FYP)
- Escrow is simulated; no real payment integration.
- No real-time push notification infra at scale (can be stubbed).
- Customs/airline rules are advisory only.

---

# Appendix A — API Overview (High Level)
| Module | Core Endpoints (examples) | Notes |
|---|---|---|
| Auth | `/auth/register`, `/auth/verify-otp`, `/auth/me` | OTP + JWT |
| KYC | `/kyc/submit`, `/kyc/status`, `/admin/kyc/*` | Manual review |
| Trips | `/trips` (POST/GET) | Traveler trips |
| Requests | `/requests` (POST/GET/PATCH/DELETE) | Buyer requests |
| Matching | `/matching/suggest?tripId=` or `requestId=` | Rule-based |
| Bookings | `/bookings`, `/bookings/{id}/accept`, `/pickup/verify`, `/delivery/verify` | Feature A state machine |
| Escrow (Admin) | `/admin/escrow/{id}/release`, `/refund` | Simulated wallet ledger |
| Marketplace | `/market/listings`, `/market/offers/*`, `/market/meetups/*` | OLX-style bargaining |
| Media | `/media/upload` | Validated uploads |
| Admin UI | `/admin`, `/admin/kyc`, `/admin/bookings`, `/admin/market` | Jinja2 |
| AI | AI microservice `/ai/chat` | No RAG; read-only tools |

---

# Appendix B — State Machines

## Booking Status (Feature A)
- REQUESTED: booking created
- HOLD_PLACED: buyer funded escrow hold (simulation)
- ACCEPTED: traveler accepted job
- PICKUP_OK: pickup verification completed (optional)
- DELIVERY_OK: delivery verification completed
- RELEASED: escrow released to traveler wallet
- CANCELLED/EXPIRED: terminated flows

## Marketplace Offer Status (Feature B)
- SENT: buyer sent offer
- COUNTERED: seller countered
- ACCEPTED: seller accepted
- DECLINED: seller declined
- WITHDRAWN: buyer withdrew offer
