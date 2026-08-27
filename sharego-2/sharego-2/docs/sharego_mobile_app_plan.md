# Flyro_mobile_app_plan.md

## Inputs & assumptions

- Read: `Flyro Proposal.pdf`, `Flyro Report 2.pdf`, `Flyro UI UX prototype design.pdf`, `Flyro Logo 1.png`.
- Backend contract & guardrails from `AGENTS.md` (SQLite, OTP/JWT, Feature A escrow only, Marketplace offer/counter-only, hashed OTP/QR, media under `./media`, Pakistan-first UX).
- `Flyro Backend.docx` not found in workspace; backend alignment based on AGENTS/README and PDFs.

## A) Screen Inventory (mapped to prototype where applicable)

### 1. Auth & Onboarding

- Login (prototype: “Login screen with email/password, Sign in with …, T&C footer”).
- Sign Up (prototype: email/password/confirm/phone + “Sign Up with …”).
- Forgot Password (new).
- OTP Verify (for login/register).
- Legal docs viewer (T&C/Privacy).

### 2. Home / Dashboard

- Home (prototype: location text, welcome, hero “Learn More with Flyro’s Secure Escrow”, CTAs: EARN/Get Paid for Flying, Book Services, Travelling, Visit Marketplace). Quick cards/banners (new optional for KYC status/offers).
- Notifications/alerts tray (new, optional).

### 3. Feature A — Personal Shopping & Escrow (Buyer booking)

- Select Date to Book Services (prototype calendar From/To + courier weight).
- Traveler List (new: list filtered by date/route).
- Traveler Detail (prototype card + reviews + Book Now).
- Enter Full Details (prototype sender/item form).
- Review & Confirm (prototype summary).
- Booking Detail/Timeline (new: HOLD→PICKED_UP→DELIVERED→CLOSED).
- Pickup OTP screen (new).
- Delivery OTP screen (new).
- Handover Photos/Camera (new).

### 4. Feature A — Trip Creation (Traveler)

- Country selector (prototype “Country”).
- Select Date of Flight (prototype calendar).
- Flight Information (prototype: airport codes, e-ticket URL).
- Luggage / Capacity Details (prototype: available capacity, budget, fees/kg).
- Pricing (prototype: pricing step).
- Traveler Information (prototype: Name/Email/Phone/CNIC/expiry).
- Trip Review & Publish (new).
- Trip Detail/Manage (new: edit, pause).

### 5. Feature B — Marketplace (Classifieds)

- Marketplace List (prototype)
- Listing Detail with Safety block (prototype)
- List Product / Item Info (prototype)
- Offer Thread (new: offer/counter/accept/decline/withdraw)
- Meetup Create (OTP generation) (new)
- Meetup Confirm OTP (new)
- Mark Sold (new)
- Marketplace Reviews (new, tied to sold)
- Marketplace Disclaimer banner (always visible)

### 6. Chat

- Chat List (new)
- Chat Thread (prototype-style message screen)

### 7. AI Chat (Read-only)

- AI Chat screen with quick command chips and response cards (new)

### 8. Settings / Profile / KYC

- Profile view/edit (new)
- KYC upload/status (new)
- Payments & Payout prefs stub (info-only; no on-platform payments) (new)
- Language/theme settings (new)
- Help & Legal (links T&C/Privacy/Disclaimer) (new)

### 9. Infrastructure Screens

- Global error/fallback screen (new)
- Offline queue screen (new)
- Skeleton loaders (new)
- Connectivity banner (new)
- Permissions rationale modals (camera/gallery/GPS) (new)

---

## B) Screen-by-screen detail

### Auth & Onboarding

#### Login (prototype)

- Purpose: Authenticate; start OTP/JWT flow (email-based per backend).
- Layout: Header logo; fields email, password (or switch to OTP login); “Sign in with …” row; primary CTA Login; secondary: Sign Up, Forgot Password; footer links T&C/Privacy (from prototype).
- API: `POST /auth/register` (request OTP), `POST /auth/verify-otp` (when OTP login), or custom `/auth/login` if password-backed; store JWT.
- Actions: Submit; toggle show password; go to Sign Up; go to Forgot; tap social (stub/inactive unless provided).
- States: idle, validating, loading, error (toast + inline), offline (queue prohibited).
- Validation: email format; password min 8 if used; throttle login (UI shows cooldown).
- Edge: OTP throttled; wrong creds; locked account; backend 401/429.
- Permissions: none.
- Offline: show offline banner; disallow submit, allow cached email.

#### Sign Up (prototype)

- Purpose: Create account and trigger OTP verification.
- Layout: Fields email, password, confirm, phone; “Sign Up with …”; CTA Sign Up; link Login; footer T&C/Privacy.
- API: `POST /auth/register` (email, phone optional); then `POST /auth/verify-otp`.
- Actions: Submit → OTP screen; resend OTP; switch to Login.
- Validation: email valid; password strength & match; phone numeric (PK), consent checkbox.
- Edge: duplicate email; OTP expired; rate-limit.
- Offline: disable submit; allow draft save.

#### Forgot Password (new)

- Purpose: Password reset or OTP login assist.
- Layout: Email field; CTA Send reset/OTP; info about using OTP rather than reset.
- API: If backend lacks reset, reuse `POST /auth/register` to resend OTP.
- States/edges: same throttle/expiry.

#### OTP Verify

- Purpose: Verify login/sign-up.
- Layout: 6-digit pin inputs; timer 30s resend; masked email hint.
- API: `POST /auth/verify-otp {email, otp}`.
- Edge: 3 attempts; 400 invalid; 429 resend; expiry message.
- Offline: queue disallowed.

#### First-time walkthrough (optional)

- Purpose: Explain escrow vs marketplace; safety.
- Layout: 3 slides; CTA Skip/Next/Done.
- Offline: available cached.

#### Legal docs viewer

- Purpose: Show T&C/Privacy; mandatory acceptance.
- Layout: Webview/markdown; Accept checkbox on Sign Up.
- Offline: cached snippet; warn if stale.

### Home / Dashboard

#### Home (prototype)

- Purpose: Entry hub to A & B flows.
- Layout: Location text (from GPS or manual), Welcome text, hero “Learn More with Flyro’s Secure Escrow” (tap to info), CTA tiles EARN/Get Paid for Flying (opens Trip Creation), Book Services (opens booking calendar), Travelling (alias to Trip Creation list/manage), Visit Marketplace (opens marketplace list); optional banners (KYC pending, offer updates), quick chips (My Trips, My Bookings, Marketplace Offers).
- API: `GET /me` (name, kyc_status, rating), `GET /bookings?me`, `GET /market/offers?mine` (if available).
- Actions: tap CTAs; change location; pull-to-refresh.
- States: greeting with skeleton; KYC badge (pending/verified/rejected).
- Edge: KYC rejected (show action to resubmit).
- Offline: show last cached name & CTAs; disable data refresh; queue taps to feature entry allowed (forms cached).

#### Notifications tray

- Purpose: View system alerts (offer accepted, OTP).
- API: none if push-only; else poll `/notifications` if exists.
- Offline: cached.

### Feature A — Personal Shopping & Escrow (Buyer Booking)

#### Select Date to Book Services (prototype calendar)

- Purpose: Pick From/To dates & courier weight to search trips.
- Layout: Month view calendar; From/To selectors; weight input (kg); CTA Continue/Search.
- API: `GET /trips?origin=&dest=&date=` (date range derived from selection).
- Actions: select dates; enter weight; optional origin/dest fields (extend if needed).
- Validation: From ≤ To; weight >0 <= capacity expectation (15kg default cap check).
- Edge: no results; past dates disabled; max window 90 days.
- Offline: allow selection; queue search request when online; show offline note.

#### Traveler List (new)

- Purpose: Show trips matching search.
- Layout: Cards similar to prototype (name, rating, route, capacity, rate per kg, user budget if present); filter bar (origin/dest, date); sort by earliest date/rate.
- API: `GET /trips` with filters.
- Actions: tap card → Traveler Detail; adjust filters; pull refresh.
- States: loading skeleton cards; empty with retry; error banner.
- Edge: capacity < requested weight (mark as limited).
- Offline: show cached trips if any; disallow fresh search.

#### Traveler Detail (prototype)

- Purpose: Detailed trip view before booking.
- Layout: Header with traveler name/rating/route; airport names/times; capacity, rate per kg, user budget; Reviews panel snippet; CTA Book Now; info text about escrow/OTP; show trip proof (if path provided).
- API: `GET /trips/{id}`, `GET /reviews?target=trip/traveler`.
- Actions: Book Now → Enter Full Details; view full reviews; share trip; report (if flagged).
- Validation: ensure user not owner.
- Edge: trip inactive; capacity insufficient (warn).
- Offline: show cached detail; disable Book Now if offline.

#### Enter Full Details (prototype)

- Purpose: Collect sender/buyer contact + item info.
- Layout: Sections: Sender Info (Name, Email, Phone), Item Info (Name, Weight kg, Description, Item Price PKR); CTA Continue.
- API: none yet; data carried to booking create.
- Validation: required fields; weight numeric; price ≥0; description ≤2000.
- Edge: weight exceeds trip capacity after other bookings (next step fail).
- Offline: allow entry; queue booking create when online (warn about OTP later).

#### Review & Confirm (prototype)

- Purpose: Summarize before booking create.
- Layout: Summary card (trip info, sender, item, price/weight); escrow hold notice; CTA Confirm Booking.
- API: `POST /bookings {trip_id, request_id?}` (here request_id optional; maybe use ad-hoc item -> create request first if needed; else send item details alongside booking if backend allows; if not, create `/requests` then booking).
- Actions: Confirm (creates booking -> HOLD), edit previous.
- States: loading spinner on submit; success route to Booking Detail; error inline.
- Edge: trip already full; booking duplicate; 400 illegal; show clarity.
- Offline: queue not allowed (OTP flow needed); require online.

#### Booking Detail/Timeline (new)

- Purpose: Track booking state & actions.
- Layout: Header status pill (HOLD/PICKED_UP/DELIVERED/CLOSED/REFUNDED/CANCELLED); timeline items (Booking created, Pickup event, Delivery event, Admin release); cards for traveler, item, payment note; CTA Show Pickup OTP (if buyer), Show Delivery OTP (if traveler), Upload photo, Add GPS note.
- API: `GET /bookings/{id}`, `GET /handover_events?booking_id`, `POST /bookings/{id}/pickup/verify`, `POST /bookings/{id}/delivery/verify`, `POST /admin/escrow/{bookingId}/release|refund` (view only for admin).
- Actions: copy OTP; view QR; view photos; open chat.
- States: loading; refresh; error.
- Edge: illegal state transitions -> show disabled CTA with reason.
- Offline: show cached timeline; prevent state-changing actions; allow photo queue for upload (persist locally until online).

#### Pickup OTP screen (new)

- Purpose: Buyer shares OTP/QR to traveler at pickup.
- Layout: Large OTP digits + QR; text “Share only at pickup”; instructions; regenerate? (no, single-use).
- API: OTP value likely from booking detail; verify via `POST /bookings/{id}/pickup/verify {otp|qr, gps, photos_paths[], seal_id?}` by traveler.
- Actions: copy OTP; show QR; open camera to capture proof.
- Edge: OTP reused -> 400; expired; wrong booking.
- Offline: display cached OTP; verification requires online.

#### Delivery OTP screen (new)

- Purpose: Traveler collects OTP from buyer for delivery confirm.
- Layout: Input for OTP; optional QR scan button.
- API: `POST /bookings/{id}/delivery/verify {otp|qr, gps, photos_paths[], seal_id?}`.
- Edge: already delivered; pickup missing -> 400; wrong OTP.
- Offline: queue not allowed.

#### Handover Photos/Camera (new)

- Purpose: Capture images for pickup/delivery.
- Layout: Camera preview or gallery picker; thumbnail list; note “Max 10MB each, jpg/png”.
- API: Upload via Media service -> relative paths, then pass to verify endpoints.
- Validation: extension whitelist; size cap 10MB; compress to 1600px.
- Permissions: camera/gallery.
- Offline: allow capture/cache; queue upload when online.

#### GPS Capture/Manual location (new)

- Purpose: Attach location to handover.
- Layout: Map preview or text; button “Use current location” with permission rationale; fallback text field labeled “GPS unverified”.
- API: pass lat/long + text to verify endpoints.
- Edge: denied permission -> mark as unverified.
- Offline: use last known; flag as unverified.

### Feature A — Trip Creation (Traveler)

#### Country selector (prototype)

- Purpose: Pick departure/arrival countries.
- Layout: Dropdowns or search; follows prototype step “Country”.
- API: none.
- Validation: required.
- Offline: allowed.

#### Select Date of Flight (prototype)

- Purpose: Choose flight date (single).
- Layout: Calendar same as prototype; CTA Continue.
- API: none.
- Validation: date ≥ today.
- Offline: allowed.

#### Flight Information (prototype)

- Purpose: Capture LHR/RUH codes and e-ticket URL.
- Layout: Inputs: Origin airport code (IATA), Destination code, E-ticket URL; CTA Continue.
- API: none; final submission via `POST /trips`.
- Validation: 3-letter codes; URL format; optional upload path.
- Edge: same origin/dest not allowed.
- Offline: allowed; queue final submit.

#### Luggage / Capacity Details (prototype)

- Purpose: Available capacity & budget.
- Layout: Available capacity kg, budget (expected earning), fees per kg; CTA Continue.
- Validation: capacity >0; fees >=0.
- Edge: extreme values warn.
- Offline: allowed.

#### Pricing (prototype step)

- Purpose: Set rate per kg & optional minimum.
- Layout: Rate per kg PKR, optional flat fee; info tooltip about escrow.
- Validation: numeric, within sensible limits (<=100000).
- Offline: allowed.

#### Traveler Information (prototype)

- Purpose: Collect traveler identity (Name, Email, Phone, CNIC, Exp Month/Year); prefill editable if known.
- Validation: CNIC format; phone PK; expiry future.
- Edge: missing KYC -> prompt to KYC upload.
- Offline: allow edit.

#### Trip Review & Publish (new)

- Purpose: Summarize trip; submit to backend.
- Layout: cards per section; CTA Publish Trip.
- API: `POST /trips` with origin_airport, dest_airport, date, capacity_kg, flight_proof_path?, rate info.
- Edge: duplicates; unauthorized if not KYCd.
- Offline: queue submission allowed if media already uploaded? safer: require online; if offline, save draft.

#### Trip Detail/Manage (new)

- Purpose: View own trip; edit/pause; see bookings.
- API: `GET /trips/{id}`, `PATCH /trips/{id}` (if supported), `GET /bookings?trip_id`.
- Edge: cannot edit with active bookings (respect backend rules).
- Offline: view cached; disable edits.

### Feature B — Marketplace (Classifieds)

#### Marketplace List (prototype)

- Purpose: Browse listings.
- Layout: Search bar; filter chips (category, min/max, location radius); cards with title, last offer price/date, seller & rating; disclaimer banner (always visible).
- API: `GET /market/listings?query=&location=&radius_km=&category=&min=&max=&status=ACTIVE`.
- Actions: search debounce; tap card → detail; pull refresh.
- States: loading skeleton; empty; error; flagged notice for own flagged listings.
- Edge: flagged listing hidden from public; show to owner with reason.
- Offline: show cached list; disable search; mark stale.

#### Listing Detail with Safety block (prototype)

- Purpose: View listing; send offers; see safety info.
- Layout: Gallery; title; price; metadata (model, condition, reason, availability date, retail value); Safety Measures block (Simulated Escrow note -> adjust to “Escrow applies only to Personal Shopping; Marketplace is peer-to-peer”); Seller info; Offer history snippet; CTA Send Offer; always-visible marketplace disclaimer.
- API: `GET /market/listings/{id}`, `GET /market/offers?listing_id` (if exists), `GET /reviews?target=listing/seller`.
- Actions: send offer -> Offer Thread; flag listing (if needed); start chat.
- Edge: listing SOLD/HIDDEN/FLAGGED (disable offer).
- Offline: cached view; disable new offers.

#### List Product / Item Info (prototype)

- Purpose: Create listing.
- Layout: Inputs title, description, photos upload (multi), category, condition, location text, price PKR, availability date; CTA List Product; disclaimer note.
- API: Upload media -> paths; `POST /market/listings`.
- Validation: title 3-80; description ≤2000; price ≥0; at least one photo; file type size cap 10MB; location text required.
- Edge: duplicate submission; spam throttle.
- Permissions: camera/gallery.
- Offline: allow draft; queue submission with cached media uploads? Prefer require online for submit; save draft locally.

#### Offer Thread (new)

- Purpose: OLX-style bargaining thread.
- Layout: Timeline of offers with badges (sent/countered/accepted/declined/withdrawn); amount and message; action buttons depending on role: Seller: counter/accept/decline; Buyer: withdraw; new offer form enforces one active offer per user per listing.
- API: `POST /market/listings/{id}/offer`, `POST /market/offers/{offer_id}/counter`, `/accept`, `/decline`, `/withdraw`.
- Validation: amount >0; message optional length cap; enforce one active offer.
- Edge: accept by non-seller -> 403; offer locked after accepted; auto-withdraw previous buyer offer.
- Offline: show cached thread; queue new offer actions allowed with clear “pending sync”; apply optimistic state but reconcile.

#### Meetup Create (OTP) (new)

- Purpose: Record meetup for accepted offer.
- Layout: Inputs: place_text, scheduled_ts; CTA Generate OTP; show generated OTP (dev only) for confirmation in app.
- API: `POST /market/meetups {listing_id, place_text, scheduled_ts}`.
- Edge: only after offer accepted; duplicate meetups? handle 400.
- Offline: disallow create; allow draft.

#### Meetup Confirm OTP (new)

- Purpose: Confirm meetup occurred.
- Layout: OTP input/QR scan; instructions; timestamp result.
- API: `POST /market/meetups/{id}/confirm {otp}`.
- Edge: reuse OTP -> 400; wrong party -> 403; confirm twice -> 400.
- Offline: disallow; show pending.

#### Mark Sold (new)

- Purpose: Seller marks listing sold.
- Layout: Confirm dialog; optional note and accepted offer reference.
- API: `POST /market/listings/{id}/mark_sold {offer_id?, note?}`.
- Edge: only seller; lock new offers; allow reopen? (if backend supports).
- Offline: disallow.

#### Marketplace Reviews (new)

- Purpose: Collect/show reviews post-sale.
- Layout: Rating stars, comment; link from listing/offer completion.
- API: `POST /reviews {target_type:'market', target_id, reviewee_id, rating, comment?}`, `GET /reviews?target_id`.
- Validation: rating 1-5; comment ≤500.
- Edge: posting before sold -> 400.
- Offline: queue allowed with caution.

### Chat

#### Chat List

- Purpose: Entry to conversations per booking/listing.
- API: `GET /chat?mine` (if available else derive from offers/bookings).
- States: loading/empty/error.
- Offline: show cached; disable new thread creation.

#### Chat Thread (prototype style)

- Purpose: Messaging between parties.
- Layout: Messages bubbles, timestamps; input “Type your message here”; send button; attachment icon for images; optional quick replies.
- API: `GET /chat/{id}`, `POST /chat/{id}/message` (or reuse offers/bookings chat endpoint).
- Validation: message length cap; image upload via media.
- Edge: blocked users; listing closed -> warn read-only.
- Offline: queue outgoing messages with retry; show pending indicator.

### AI Chat (Read-only)

- Purpose: Provide FAQ/policy answers & read-only user data tools.
- Layout: Chat bubbles; command chips (“Show my bookings”, “Search marketplace”, “What is escrow?”); cards for data responses.
- API: AI endpoint (read-only): prompt plus tool calls `get_booking_status`, `list_my_trips/requests`, `search_market_listings`, `get_offers_for_my_listing`, `policy_flags`.
- Edge: refuses write/legal advice; rate-limit messages.
- Offline: show cached FAQs; disable queries.

### Settings / Profile / KYC

#### Profile view/edit

- Purpose: Show user details, rating_avg, KYC status.
- API: `GET /me`, `PATCH /users/me` (if available).
- Actions: edit phone/name; view ratings; logout.
- Offline: show cached; queue edits? (generally disallow).

#### KYC upload/status

- Purpose: Submit documents; track status.
- Layout: Status banner (pending/approved/rejected with reason); form fields doc_type, file uploads (CNIC/passport), selfie; CTA Submit.
- API: `POST /kyc/submit` multipart; `GET /kyc/status`.
- Validation: allowed MIME (jpg/png/pdf); size ≤10MB; doc_type required.
- Permissions: camera/gallery/files.
- Edge: resubmit after reject allowed; throttle.
- Offline: allow capture; queue submit when online with warning.

#### Payments & Payout prefs (info-only)

- Purpose: Clarify off-platform payments; show bank info if collected (but no transfers).
- Content: Static text referencing disclaimer.

#### Language/Theme

- Purpose: Toggle English/Urdu; light/dark.
- Offline: fully local.

#### Help & Legal

- Purpose: Links to FAQ, marketplace disclaimer, OTP notice; contact support stub.

### Infrastructure Screens

#### Global error

- Purpose: Show fatal errors; action retry/back.
- States: 4xx user error vs 5xx.

#### Offline queue

- Purpose: Show queued actions (offers, chat msgs) with retry/cancel.
- API: local only.

#### Skeleton loaders

- Purpose: Visible on list/detail screens.

#### Connectivity banner

- Purpose: Show online/offline; auto-hide.

#### Permissions rationale modals

- Purpose: Explain need for camera/gallery/GPS; handle deny/permanent deny.

---

## C) Global Mobile Architecture & Behaviour

### State management

- Riverpod (recommended) or BLoC per module; feature folders: auth, profile, kyc, trips, requests, booking, handover, marketplace, offers, meetups, reviews, chat, ai, app(shell).
- Each feature: Repository (Dio), Notifier/Controller (state sealed classes: idle/loading/success/error/offline/pendingSync).
- Offline queue service for non-idempotent actions (offers, messages, booking create drafts, KYC submit optional).

### Networking (Dio)

- Base URL from `.env`; interceptors: auth (Bearer), refresh/reauth (if refresh token; else redirect to login on 401), retry with exponential backoff for network errors (respect offline detection), logging (redact PII).
- Timeouts: connect/read 15s; upload 30s.
- JSON serialization; handle date as ISO-8601 UTC.
- Media upload: multipart; compress images to 1600px; enforce 10MB; return relative path.

### Navigation

- Root: Splash/auth gate -> Home.
- Tabs or drawer? Use bottom nav with Home, Marketplace, Trips/Bookings, Chat, Profile.
- Nested flows: Auth stack; Feature A booking wizard; Trip creation wizard; Offer thread; AI chat modal route.
- Deep links: OTP screen from booking detail; chat from booking/listing detail.

### Design tokens

- Colors: Keep prototype feel; primary (teal/green similar to prototype accent), secondary warm yellow/orange; background light neutral; error red; success green. Ensure AA contrast.
- Typography: Prefer modern sans supporting Urdu (e.g., Poppins + Noto Nastaliq Urdu); defined sizes for H1/H2, body, caption; consistent button text.
- Components: Elevated buttons with rounded corners per prototype; cards with subtle shadow; chips for filters.

### Localization

- English default. Use `intl`. Copy strings dual-language; date/time localized to Asia/Karachi; currency formatter PKR; distance km.

### Permissions handling

- Camera/gallery: `permission_handler`; explain and fall back to file picker.
- Location: request when needed; if denied, allow manual text and mark gps_unverified.
- QR Scanner: runtime camera permission; degrade to manual OTP entry.

### Offline behaviour

- Detect connectivity; show banner.
- Cache: lists/details in local storage; queued actions persisted (offers, chat, some forms).
- Non-idempotent actions require explicit user consent to queue.
- Conflict resolution: refresh after reconnect; reconcile server truth vs optimistic.

### Error handling

- Normalize errors: validation (show field messages), 400 illegal transition text, 401 reauth, 403 owner check message, 404 not found, 429 throttle.
- Toast/snackbar for transient; inline for forms.

---

## D) UX Flow Diagrams (text)

### Feature A: Booking & Escrow

Home (prototype CTA Book Services) → Select Date to Book Services (prototype calendar) → Search trips → Traveler List (new) → Traveler Detail (prototype) → Book Now → Enter Full Details (prototype) → Review & Confirm (prototype) → Submit `POST /bookings` (HOLD) → Booking Detail Timeline (new) → Pickup OTP screen (new, buyer shares) → Traveler verifies pickup `POST /bookings/{id}/pickup/verify` with GPS/photos → Delivery OTP screen (new) → Traveler verifies delivery `POST /bookings/{id}/delivery/verify` → Admin Release (backend) → Booking status CLOSED → Reviews screen (post booking review).

### Feature B: Marketplace OLX-style

Home (prototype CTA Visit Marketplace) → Marketplace List (prototype) → Listing Detail (prototype + disclaimer) → Send Offer (opens Offer Thread new) → Offer sent `POST /market/listings/{id}/offer` → Seller counters `POST /market/offers/{id}/counter` → Buyer accepts `POST /market/offers/{id}/accept` → Create Meetup `POST /market/meetups` (new) → Meetup Confirm OTP `POST /market/meetups/{id}/confirm` → Seller Mark Sold `POST /market/listings/{id}/mark_sold` → Reviews (market) screen → Listing shows SOLD; disclaimer always visible.

---

## E) MVP Done Checklist

- [X]  All prototype screens implemented: Login, Sign Up, Home hero + CTAs, booking calendar, traveler detail/reviews, Enter Full Details, Review & Confirm, trip creation steps, marketplace list/detail, list product, chat input.
- [ ]  New screens implemented: Forgot/OTP, booking timeline, pickup/delivery OTP, handover photos/GPS, trip review/manage, offer thread, meetup create/confirm, mark sold, marketplace reviews, AI chat, profile/KYC, settings/legal, error/offline/permissions.
- [ ]  Feature A happy path works with escrow states (HOLD→PICKED_UP→DELIVERED→CLOSED) plus failure paths (invalid OTP, double release, offline retries for uploads).
- [ ]  Feature B bargaining flow works with offer/counter/accept/decline/withdraw, meetup OTP confirm, mark sold; disclaimer visible on all marketplace surfaces; no escrow applied.
- [ ]  Offline handling tested: cached lists/details, queued offers/messages/forms where allowed, clear warnings for blocked actions.
- [ ]  Validations enforced per fields; OTP expiry/throttle; file size/type; owner/state guard errors surfaced.
- [ ]  Permissions flows handled for camera/gallery/GPS/QR with graceful fallbacks.
- [ ]  Localization ready (English/Urdu), PKR currency, Asia/Karachi times, km distances.
- [ ]  AI chat read-only; refuses writes/legal advice; uses allowed tools only.
- [ ]  QA coverage aligns with AGENTS test matrix for key UI states and edge cases.

---

## Flutter Prototype Implementation Plan (UI-only, mock data)

Goal: Build a fully interactive Flutter app prototype with all flows using go_router, local mock data/JSON, and the prototype PDF visuals. No backend calls.

### Architecture snapshot

- Routing: go_router shell with bottom nav (Home, Marketplace, Bookings/Trips, Chat, Profile).
- State: simple ChangeNotifier/Riverpod mocks per feature (auth_mock, trips_mock, bookings_mock, listings_mock, offers_mock, chat_mock, audit_mock, ai_mock, kyc_mock).
- Data: bundled JSON for trips/bookings/listings/offers/issues/chats; placeholder images.
- Theme: match prototype colors/typography; PKR formatter; bilingual labels where helpful.
- Components: CTA cards (home), calendar month view, status pills, timeline list, offer/chat bubbles, disclaimer banner, OTP pin, skeleton loaders.

### Screen coverage (all wired with mock navigation)

- Auth: login, signup, OTP, forgot password.
- Home: location + welcome + hero + CTA cards (Earn, Book Services, Travelling, Visit Marketplace).
- Feature A booking: date/calendar, traveler list/detail, enter details, review, booking success, booking timeline, pickup/delivery OTP, QR scan mock, photo capture mock, GPS mock.
- Feature A trip creation: date, flight info, capacity, pricing, traveler info, summary, posted success, trip detail/manage.
- Feature B marketplace: list, detail (safety + disclaimer), create listing (review + success), offer panel, offer thread, counter/accept/decline/withdraw, meetup create/OTP, mark sold.
- Chat: chat list, chat thread with mock send.
- Audit Center: tabs (Open/Pending/Resolved), issue detail (timeline/evidence), report issue, add evidence; entry points from booking/listing/offer/handover screens.
- Profile/Settings: profile overview, edit, KYC upload mock with status banners, settings, logout confirm.
- AI Chat: command chips + dummy responses.
- Admin (hidden): admin audit panel list/detail with mock actions.

### Mock behaviors

- OTP always accepts "123456"; simulate 800ms loading.
- Lists/details show skeletons before mock load.
- Success screens after submits with CTA to detail/home.
- Error simulation buttons to show banners and Report Issue prompts.

### TODO (execution checklist)

- [ ]  Set up Flutter project skeleton with go_router, base theme matching prototype.
- [ ]  Add mock data models and seed JSON for users, trips, bookings, listings, offers, chats, issues.
- [ ]  Implement shared components (CTA cards, calendar, pills, bubbles, disclaimer, OTP pin, skeletons).
- [ ]  Build auth screens and wire mock auth flow to home.
- [ ]  Build home dashboard per prototype and link CTAs to flows.
- [ ]  Implement Feature A booking flow screens and navigation (including success, timeline, OTP, scan/photo/GPS mocks, report issue entry).
- [ ]  Implement Feature A trip creation wizard and success/detail.
- [ ]  Implement Feature B marketplace list/detail/create/offer thread/meetup/mark sold with disclaimer visible.
- [ ]  Implement chat list/thread with mock send.
- [ ]  Implement Audit Center (tabs, detail, report, add evidence) and hook entry points.
- [ ]  Implement profile/edit/KYC/status and settings + logout confirm.
- [ ]  Implement AI chat mock screen with command chips.
- [ ]  Implement admin audit panel (hidden route).
- [ ]  Add error/success/offline mock states and "simulate error" buttons where relevant.
