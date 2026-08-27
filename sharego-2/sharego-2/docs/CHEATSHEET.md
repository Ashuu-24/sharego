# Flyro — FYP Evaluation Cheatsheet

## 1. Project Overview (Elevator Pitch)

Flyro is a **peer-to-peer mobile marketplace for Pakistan** with two core features:
- **Feature A (Cross-Border Delivery):** Buyers request products from abroad, verified travelers carry them using spare luggage capacity, and simulated escrow protects both parties with OTP-verified handover.
- **Feature B (Local Marketplace):** OLX-style buy/sell with offer bargaining and meetup scheduling — no courier or payment handling by Flyro.

Built with **Flutter (Android) + FastAPI (Python) + SQLite**, with a multi-LLM AI assistant (Gemini, NVIDIA, OpenAI) and a full admin dashboard.

---

## 2. Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Mobile** | Flutter 3.3+ / Dart | Android app (Material Design 3) |
| **State Mgmt** | Riverpod 3.x | Reactive state management |
| **Navigation** | Go Router 17.x | Declarative routing |
| **HTTP Client** | Dio 5.x | API calls with retry logic |
| **Backend** | FastAPI 0.110 / Python | REST API + admin panel |
| **ORM** | SQLModel + SQLAlchemy | Database models & queries |
| **Database** | SQLite (WAL mode) | Persistent storage |
| **Migrations** | Alembic | Schema version control (10 revisions) |
| **Admin Panel** | Jinja2 Templates | Server-rendered HTML dashboard |
| **Auth** | JWT (HS256) + bcrypt OTP | Token-based + one-time passwords |
| **AI** | Gemini 2.5 + NVIDIA gpt-oss-120b + OpenAI gpt-4o-mini | Multi-provider LLM with fallback |
| **Flight Tracking** | AviationStack API | Real-time flight status |
| **Rate Limiting** | SlowAPI | DDoS protection |
| **Theme** | Material 3 (Dark + Light) | Dark/light mode toggle |
| **Refresh Rate** | flutter_displaymode | 120Hz support |

---

## 3. Architecture

```
┌─────────────────────────┐
│   Flutter Mobile App     │
│  (Riverpod + Go Router)  │
│  Dio HTTP → REST API     │
└────────────┬────────────┘
             │ HTTPS / HTTP
┌────────────▼────────────┐
│   FastAPI Backend        │
│  ┌───────┐ ┌──────────┐ │     ┌──────────────────┐
│  │REST   │ │Admin     │ │────▶│ External APIs     │
│  │API    │ │Panel     │ │     │ - Google Gemini   │
│  │(JWT)  │ │(Cookie)  │ │     │ - NVIDIA NIM      │
│  └───┬───┘ └────┬─────┘ │     │ - OpenAI          │
│      │          │        │     │ - AviationStack   │
│  ┌───▼──────────▼─────┐ │     │ - Google OAuth    │
│  │  SQLite (WAL mode)  │ │     │ - SMTP Email      │
│  │  18+ tables         │ │     └──────────────────┘
│  │  Alembic migrations │ │
│  └─────────────────────┘ │
└──────────────────────────┘
```

---

## 4. Feature A — Cross-Border Delivery (Complete Flow)

### Buyer's Journey:
1. **Post Request** → Item name, specs, target price, weight, time window
2. **Browse Travelers** → Filter by route, date, available capacity
3. **Select Traveler** → View profile, reviews, flight details
4. **Create Booking** → Enter item details, delivery address
5. **Escrow Hold** → Simulated payment deducted from wallet
6. **Wait for Acceptance** → Traveler accepts or declines
7. **Track Status** → Traveler posts updates (picked up, at airport, in transit, arrived)
8. **Delivery OTP** → Enter OTP code to confirm delivery + GPS + photos
9. **Escrow Released** → Admin releases funds to traveler
10. **Leave Review** → Rate the traveler (1-5 stars)

### Traveler's Journey:
1. **KYC Verification** → Upload CNIC/Passport + Selfie (admin approves)
2. **Post Trip** → Flight details, route, date, capacity, fee per kg
3. **Admin Approval** → Trip reviewed (pending_review → approved)
4. **Accept Booking** → Review buyer's request, accept or decline
5. **Purchase Item** → Buy the item abroad, upload receipt
6. **Post Status Updates** → Picked up, at airport, in transit, arrived
7. **Pickup OTP** → Verify pickup with OTP + GPS + seal ID
8. **Deliver Item** → Meet buyer, verify with delivery OTP
9. **Get Paid** → Admin releases escrow to wallet (minus commission)
10. **Leave Review** → Rate the buyer

### Booking State Machine:
```
REQUESTED → HOLD_PLACED → ACCEPTED → PICKUP_OK → DELIVERY_OK → RELEASED
                                                                    │
CANCELLED ◄──────────────────────────────────────────────────────────┘
EXPIRED ◄───────────────────────────────────────────────────────────┘
```

---

## 5. Feature B — Local Marketplace (Complete Flow)

### Seller's Journey:
1. **Create Listing** → Title, description, photos, ask price, category, location (GPS)
2. **Receive Offers** → Buyers send price offers with messages
3. **Bargain** → Counter-offer, accept, or decline
4. **Schedule Meetup** → Set place, time with accepted buyer
5. **Meet & Sell** → Confirm meetup with OTP
6. **Mark Sold** → Listing removed from feed
7. **Leave Review** → Rate the buyer

### Buyer's Journey:
1. **Browse Listings** → Search by keyword, category, near-me, price range
2. **Send Offer** → Amount + optional message
3. **Bargain** → Counter-offer thread (private between buyer & seller)
4. **Meetup** → Confirm scheduled meetup
5. **Leave Review** → Rate the seller

### Offer State Machine:
```
SENT → COUNTERED → ACCEPTED / DECLINED / WITHDRAWN
```

---

## 6. Database Tables (18+ Tables)

| # | Table | Key Fields | Purpose |
|---|-------|-----------|---------|
| 1 | **User** | email, password_hash, name, city, kyc_status, rating_avg, roles_csv | User accounts |
| 2 | **OTPEntry** | email, otp_hash, expires_at, attempts, used_at | OTP verification |
| 3 | **OTPThrottle** | email, ip_address | Rate limiting OTPs |
| 4 | **Trip** | user_id, origin/dest airports, date, capacity_kg, fee_pkr, flight_number, status | Traveler trips |
| 5 | **KYCProfile** | user_id, doc_type, doc_url, selfie_url, passport_url, status | Identity verification |
| 6 | **RequestItem** | user_id, product_name, specs_json, target_price, weight_kg | Buyer requests |
| 7 | **Booking** | trip_id, request_id, status, waybill, pickup/delivery_code_hash, seal_id | Feature A bookings |
| 8 | **BookingUpdate** | booking_id, user_id, update_type, note | Status updates timeline |
| 9 | **EscrowTx** | booking_id, amount, currency, status (hold/released/refunded) | Simulated escrow |
| 10 | **WalletEntry** | user_id, delta, balance_after, reason, ref_id | Wallet ledger |
| 11 | **HandoverEvent** | booking_id, type (PICKUP/DELIVERY), gps_lat/lng, photos_paths, seal_id | Verification events |
| 12 | **MarketListing** | seller_id, title, photos_paths, ask_price, location, status | Feature B listings |
| 13 | **MarketOffer** | listing_id, from_user_id, amount, message, status | Offer bargaining |
| 14 | **MarketMeetup** | listing_id, buyer_id, seller_id, place_text, otp_hash | Meetup scheduling |
| 15 | **Message** | sender_id, receiver_id, content, booking_id, listing_id | In-app chat |
| 16 | **Review** | reviewer_id, reviewee_id, target_type, rating, comment | Ratings system |
| 17 | **Dispute** | booking_id, filed_by, reason, status | Dispute tracking |
| 18 | **DisputeEvidence** | dispute_id, uploader_id, file_url | Evidence files |
| 19 | **FeatureFlag** | key, value, cohort | Feature toggles |
| 20 | **AuditLog** | actor, action, entity, before, after, request_id | Audit trail |

---

## 7. API Endpoints Summary

### Auth (6 endpoints)
- `POST /auth/register` — Email + OTP registration
- `POST /auth/register-password` — Email + password registration
- `POST /auth/verify-otp` — OTP verification → JWT token
- `POST /auth/login` — Password login → JWT token
- `POST /auth/google` — Google Sign-In (OAuth 2.0)
- `POST /auth/forgot` — Forgot password (OTP re-issue)

### Users (3 endpoints)
- `GET /users/me` — Current user profile
- `PUT /users/me` — Update profile
- `GET /users/{id}` — Public profile

### Trips (5 endpoints)
- `POST /trips` — Create trip
- `GET /trips` — List trips (mine or public approved)
- `GET /trips/{id}` — Trip details
- `PUT /trips/{id}` — Edit trip
- `GET /trips/{id}/flight-status` — AviationStack tracking

### Requests (4 endpoints)
- `POST /requests` — Create item request
- `GET /requests` — List requests
- `GET /requests/{id}` — Request details
- `DELETE /requests/{id}` — Delete request

### Bookings (8 endpoints)
- `POST /bookings` — Create booking (escrow hold)
- `GET /bookings` — List bookings
- `GET /bookings/{id}` — Booking details
- `POST /bookings/{id}/accept` — Traveler accepts
- `POST /bookings/{id}/decline` — Traveler declines
- `POST /bookings/{id}/cancel` — Buyer cancels
- `POST /bookings/{id}/pickup` — Verify pickup (OTP + GPS)
- `POST /bookings/{id}/delivery` — Verify delivery (OTP + GPS)

### Booking Updates (2 endpoints)
- `POST /bookings/{id}/updates` — Traveler posts status update
- `GET /bookings/{id}/updates` — Get update timeline

### Marketplace (10 endpoints)
- `POST /market/listings` — Create listing
- `GET /market/listings` — Browse/search listings
- `GET /market/listings/{id}` — Listing details
- `PUT /market/listings/{id}` — Edit listing
- `POST /market/listings/{id}/offers` — Send offer
- `GET /market/listings/{id}/offers` — View offer thread
- `POST /market/offers/{id}/counter` — Counter-offer
- `POST /market/offers/{id}/accept` — Accept offer
- `POST /market/listings/{id}/meetup` — Schedule meetup
- `POST /market/listings/{id}/sold` — Mark sold

### KYC (2 endpoints)
- `POST /kyc` — Submit KYC documents
- `GET /kyc/status` — Check KYC status

### Reviews (2 endpoints)
- `POST /reviews` — Submit review
- `GET /reviews` — List reviews for a user

### Messages (2 endpoints)
- `POST /messages` — Send message
- `GET /messages` — List conversations

### AI (1 endpoint)
- `POST /ai/chat` — AI assistant chat

### Media (1 endpoint)
- `POST /media/upload` — Upload file (images only)

### Admin Panel (15+ endpoints)
- Cookie-based web dashboard at `/admin/*`
- KYC approval/rejection, booking management, escrow release/refund
- Marketplace moderation, user management, feature flags, audit logs

---

## 8. Security Measures

| Measure | Implementation |
|---------|---------------|
| **Authentication** | JWT tokens (HS256, 60-min expiry) |
| **Password Hashing** | bcrypt (12 rounds) |
| **OTP Security** | bcrypt-hashed, single-use, 300s TTL, 3 max attempts |
| **Rate Limiting** | SlowAPI: 3 OTP/min, 5 login/min, 10 Google/min, 30 AI/hour |
| **OTP Throttling** | Per email + IP address |
| **CORS** | Configurable allowed origins |
| **Trusted Hosts** | TrustedHostMiddleware (configurable) |
| **Admin Auth** | Cookie-based session with timeout |
| **Access Control** | Owner/role-based guards on all endpoints |
| **Audit Logging** | All mutations logged with actor, before/after snapshots |
| **Request Tracking** | UUID request_id on every HTTP request |
| **Input Validation** | Pydantic schemas on all endpoints |
| **File Validation** | MIME type + extension check on uploads (jpg/png only) |
| **Waybill Format** | Validated pattern: SG-XXXX-XXXXXX |

---

## 9. Admin Panel Features

- **Dashboard** — KPIs overview
- **KYC Queue** — Approve/reject with inline image thumbnails (doc, selfie, passport)
- **Bookings** — Timeline view, detail page, escrow release/refund
- **Trips** — Approve/reject with reason
- **Users** — Make admin, remove admin, delete user
- **Marketplace** — Flag/unflag listings
- **Wallets** — View balances, top-up
- **Audit Logs** — Filter by action, admin, entity; before/after snapshots
- **Feature Flags** — Enable/disable features by cohort

---

## 10. AI Assistant Capabilities

- **Multi-LLM** with automatic fallback: NVIDIA gpt-oss-120b → OpenAI gpt-4o-mini → Gemini 2.5 Flash
- **Travel Safety** — War zones, safe countries, travel advisories, visa info
- **Courier Guidance** — What items can be carried from which countries, customs rules
- **Item Legality** — Risk levels (LOW/MEDIUM/HIGH/PROHIBITED), required documentation
- **Shipping Calculator** — Fee estimates based on weight and route
- **FAQ** — Flyro features, escrow, KYC, marketplace rules
- **DB Tools** — Read-only: show my bookings, my trips, my listings
- **Policy Flags** — Restricted items, customs warnings
- **Rate Limited** — 30 requests/hour per user
- **Safety** — Refuses smuggling, narcotics; no formal legal advice

---

## 11. Key Mobile App Features

- **13+ screens** per feature flow
- **Dark/Light theme** toggle (Material Design 3, ColorScheme.fromSeed)
- **120Hz refresh rate** support (flutter_displaymode)
- **Saved Trips** — Bookmark trips locally (SharedPreferences)
- **AI Chat** — Persistent in-memory history until app closed
- **Google Sign-In** — OAuth 2.0 (optional, alongside email+password)
- **Airport/Airline auto-complete** — From bundled JSON data (400+ airports, 100+ airlines)
- **GPS location** — For handover verification and near-me marketplace search
- **Image upload** — Camera/gallery for KYC, receipts, dispute evidence

---

## 12. Trip Status Machine

```
pending_review → approved (by admin)
               → rejected (by admin, with reason)
```

---

## 13. Key Terminology

| Term | Meaning |
|------|---------|
| **Feature A** | Cross-border personal shopping with escrow simulation |
| **Feature B** | Local OLX-style marketplace with bargaining |
| **Escrow** | Simulated payment hold (not real money — virtual wallet) |
| **KYC** | Know Your Customer — identity verification (CNIC/Passport + Selfie) |
| **Waybill** | Booking reference number (format: SG-XXXX-XXXXXX) |
| **Seal ID** | Physical tamper-proof seal number verified at pickup and delivery |
| **OTP** | One-Time Password — used for auth AND handover verification |
| **Handover** | Physical exchange moment — verified with OTP + GPS + photos |
| **WAL Mode** | SQLite Write-Ahead Logging — enables concurrent reads during writes |
| **Riverpod** | Flutter state management (reactive, compile-safe) |
| **Go Router** | Declarative URL-based navigation for Flutter |
| **JWT** | JSON Web Token — stateless authentication |
| **Alembic** | Python database migration tool (version control for schema) |

---

## 14. Common Evaluation Questions & Answers

### Q: What problem does Flyro solve?
**A:** Pakistan lacks a peer-to-peer platform connecting international travelers with buyers who need products from abroad. Flyro lets travelers earn money from their spare luggage capacity while buyers get products at lower prices than traditional import. The marketplace feature also enables local buy/sell with built-in bargaining.

### Q: Why not use an existing platform like Grabr or PiggyBee?
**A:** Existing platforms don't target Pakistan's market, don't support PKR, and lack features like KYC verification for Pakistani IDs (CNIC), local marketplace, and Urdu-compatible design. Flyro is built specifically for the Pakistan context.

### Q: How do you handle trust between strangers?
**A:** Multiple layers:
1. KYC verification (CNIC/Passport + Selfie, admin-approved)
2. Escrow holds buyer's payment until delivery is confirmed
3. OTP-verified handover (pickup + delivery) with GPS logging and photos
4. Tamper-proof seal ID matching between pickup and delivery
5. Rating & review system after every transaction
6. Dispute system with evidence upload
7. Admin oversight for escrow release/refund

### Q: Is the escrow real money?
**A:** No — it's a simulated escrow for FYP purposes. The wallet uses virtual credits with a ledger system (WalletEntry table). In production, this would integrate with Stripe, JazzCash, or EasyPaisa.

### Q: How does the AI assistant work?
**A:** Multi-provider architecture with automatic fallback:
1. Primary: NVIDIA gpt-oss-120b (120B parameter reasoning model)
2. Fallback: OpenAI gpt-4o-mini
3. Fallback 2: Google Gemini 2.5 Flash

It has a strict system prompt limiting it to Flyro-related questions, travel safety, courier guidance, and item legality. It can read the database (bookings, trips, listings) but cannot write. Rate limited to 30 requests/hour.

### Q: Why SQLite instead of PostgreSQL?
**A:** For FYP scope, SQLite with WAL mode is sufficient — zero configuration, no separate server process, supports concurrent reads. Alembic migrations make it easy to switch to PostgreSQL for production.

### Q: How do you prevent illegal items from being shipped?
**A:** Policy flags system detects restricted items (drugs, weapons, live animals, hazardous materials) and warns users. The AI assistant provides customs guidance per country. Admin can review and flag suspicious listings. KYC verification ensures user identity. However, Flyro is a platform — users are responsible for compliance with customs laws.

### Q: What's your testing strategy?
**A:** Integration tests for critical paths:
- Auth: OTP flow, JWT validation, user creation
- Bookings: Full lifecycle (create → accept → pickup → delivery → release)
- Marketplace: Listing → offer → counter → accept → meetup → sold
- Ownership guards: 403 for unauthorized actions
- Rate limiting: 429 for exceeded limits

### Q: What would you do differently for production?
**A:**
- Real payment integration (Stripe/JazzCash)
- PostgreSQL instead of SQLite
- WebSocket for real-time chat (replace polling)
- Push notifications (Firebase Cloud Messaging)
- Cloud deployment (AWS/GCP)
- Automated KYC (OCR + face matching)
- End-to-end encryption for messages
- ML-based matching algorithm

### Q: How do you handle the admin panel?
**A:** Server-rendered Jinja2 HTML templates with cookie-based authentication. Separate from the REST API. Admin can: approve/reject KYC and trips, manage escrow (release/refund), moderate marketplace, manage users (make admin/delete), view audit logs filtered by admin/action/entity, and toggle feature flags.

### Q: What SDGs does this project align with?
**A:**
- **SDG 8 (Decent Work):** Creates income opportunities for travelers using spare luggage capacity
- **SDG 12 (Responsible Consumption):** Enables sharing economy — optimizes existing travel capacity instead of dedicated shipping

### Q: How does the dark theme work?
**A:** Material Design 3 `ColorScheme.fromSeed()` with `Brightness.dark`. Theme mode is persisted in SharedPreferences. All screens use `Theme.of(context)` instead of hardcoded colors. Toggled in Settings via a `ThemeModeNotifier` (Riverpod).

### Q: How does the booking notification work?
**A:** When a traveler posts a status update (picked_up, at_airport, in_transit, arrived), the server automatically creates an in-app Message to the buyer with the update details. The buyer sees it in their Messages tab.

---

## 15. Project Statistics

| Metric | Count |
|--------|-------|
| **Dart files** | 40+ |
| **Python files** | 30+ |
| **API endpoints** | 50+ |
| **Database tables** | 20 |
| **Alembic migrations** | 10 |
| **Admin templates** | 11 |
| **Mobile screens** | 30+ |
| **Lines of code (server)** | ~5,000 |
| **Lines of code (mobile)** | ~8,000 |

---

## 16. Documents in This Folder

| File | Description |
|------|-------------|
| `Flyro_Final_Report.pdf` | FYP-I signed final report (Dec 2025) |
| `Flyro_Proposal.pdf` | Original project proposal |
| `Flyro_Report_2_SRS.pdf` | SRS, use cases, data dictionary, architecture |
| `Flyro_UI_UX_Prototype.pdf` | UI/UX prototype design document |
| `Flyro_FYP_Project_Documentation.md` | Main FYP documentation |
| `Flyro_mobile_app_plan.md` | Mobile app implementation plan |
| `ui.md` | Original Flutter UI prototype (single file) |
| `Instructions.docx` | Instructions for updating the final report |
| `Instructions.pdf` | Same in PDF format |
| `Flyro_Logo.png` | Brand logo |
| `CHEATSHEET.md` | This file |
