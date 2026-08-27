"""AI Chat assistant — curated FAQ + read-only DB tools + policy flags + OpenAI LLM (primary) / Gemini (fallback)."""

from __future__ import annotations

import logging
import re
import time
from collections import defaultdict

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.api.deps import get_current_user_dep, get_session_dep
from app.core.config import get_settings
from app.models import (
    Booking,
    MarketListing,
    MarketOffer,
    RequestItem,
    Trip,
    User,
)
from app.schemas.ai import AiChatRequest, AiChatResponse

router = APIRouter(prefix="/ai", tags=["ai"])
logger = logging.getLogger(__name__)

# ── Curated FAQ ──────────────────────────────────────────────────────

_ABOUT_FLYRO = (
    "Flyro is a peer-to-peer platform in Pakistan with two features: "
    "Feature A lets you request products from abroad and a verified traveler "
    "brings them back with escrow protection. Feature B is an OLX-style "
    "marketplace where you can buy/sell locally with bargaining."
)

FAQ: dict[str, str] = {
    "what is flyro": _ABOUT_FLYRO,
    "what is Flyro": _ABOUT_FLYRO,
    "what is escrow": (
        "Escrow holds the buyer's funds securely until both pickup and delivery "
        "OTPs are verified. Once delivery is confirmed, funds are released to "
        "the traveler. If something goes wrong, an admin can refund."
    ),
    "how does pickup work": (
        "When a traveler picks up the item abroad, both parties verify a pickup "
        "OTP. The traveler also provides GPS location and a photo as proof. "
        "Status moves from ACCEPTED to PICKUP_OK."
    ),
    "how does delivery work": (
        "The traveler meets the buyer in Pakistan and both verify a delivery OTP. "
        "GPS and photo proof are captured. Status moves from PICKUP_OK to "
        "DELIVERY_OK, and escrow funds are released."
    ),
    "booking statuses": (
        "Booking statuses flow: REQUESTED -> HOLD_PLACED -> ACCEPTED -> "
        "PICKUP_OK -> DELIVERY_OK -> RELEASED. A booking can also be "
        "CANCELLED or EXPIRED at various stages."
    ),
    "what is kyc": (
        "KYC (Know Your Customer) verification requires uploading a CNIC or "
        "passport photo plus a selfie. An admin reviews and approves or "
        "rejects your documents. Verified travelers get higher trust."
    ),
    "marketplace rules": (
        "Feature B marketplace is peer-to-peer. Flyro does NOT handle "
        "delivery or payment for marketplace transactions. Buyers and sellers "
        "arrange meetups and exchange items directly. You can send offers, "
        "counter-offer, and schedule meetups through the app."
    ),
    "how to send offer": (
        "On a marketplace listing, tap 'Send Offer' and enter your proposed "
        "price. The seller can accept, decline, or counter your offer. "
        "Once accepted, schedule a meetup to exchange the item."
    ),
    "what are policy flags": (
        "Certain products have special shipping policies. For example, "
        "lithium batteries are high-risk and may require special handling. "
        "Electronics and perfumes may have customs duty considerations. "
        "Always declare items truthfully."
    ),
    "how to create trip": (
        "Go to the Trips tab, fill in your origin airport, destination, "
        "travel date, available capacity in kg, and your fee per kg. "
        "Buyers can then browse and book your trip."
    ),
    "how to create request": (
        "Go to the Booking flow, enter the product name, specifications, "
        "target price, destination city, weight, and your delivery window. "
        "Travelers will see your request and can accept it."
    ),
    "is my data safe": (
        "Flyro uses JWT authentication, bcrypt-hashed OTPs, and role-based "
        "access controls. Your personal data is never shared with other users. "
        "The AI assistant can only read your own data."
    ),
    "how ratings work": (
        "After a booking is completed (RELEASED) or a marketplace item is sold, "
        "both parties can leave a 1-5 star review. Your average rating is "
        "displayed on your profile."
    ),
    "contact support": (
        "For support, use the Help section in your profile or email "
        "support@flyro.local. For disputes, open a dispute from the "
        "booking timeline screen."
    ),
}

# ── Policy flags ─────────────────────────────────────────────────────

POLICY_FLAGS: dict[str, dict] = {
    "lithium battery": {
        "risk": "high",
        "advisory": "Lithium batteries are classified as dangerous goods. "
        "Most airlines restrict them in checked baggage. Declare them "
        "and check airline policies before booking.",
    },
    "perfume": {
        "risk": "medium",
        "advisory": "Perfumes are flammable liquids. Limited to 100ml in "
        "hand luggage. Customs may apply duty on fragrances.",
    },
    "electronics": {
        "risk": "medium",
        "advisory": "Electronics over PKR 50,000 may attract customs duty. "
        "Keep purchase receipts for customs clearance.",
    },
    "medicine": {
        "risk": "high",
        "advisory": "Prescription medicines require a valid prescription. "
        "Controlled substances are strictly prohibited. "
        "Flyro does not facilitate illegal shipments.",
    },
    "food": {
        "risk": "medium",
        "advisory": "Perishable food items are not recommended. Packaged "
        "food with long shelf life is acceptable. Check customs "
        "regulations for food imports.",
    },
    "jewelry": {
        "risk": "medium",
        "advisory": "Declare valuable jewelry items. Insurance is recommended "
        "for high-value shipments. Keep proof of purchase.",
    },
    "weapon": {
        "risk": "prohibited",
        "advisory": "Weapons and ammunition are strictly prohibited. "
        "Flyro will not facilitate such transactions.",
    },
    "alcohol": {
        "risk": "prohibited",
        "advisory": "Alcohol import is prohibited in Pakistan. "
        "Flyro cannot assist with prohibited items.",
    },
    "tobacco": {
        "risk": "prohibited",
        "advisory": "Tobacco products are restricted. Heavy customs duties "
        "apply and quantity limits exist.",
    },
}

# ── Safety refusal patterns ──────────────────────────────────────────

_REFUSAL_PATTERNS = [
    r"\b(hack|exploit|crack|bypass)\w*\b",
    r"\b(sue|lawsuit|court\s+case)\b",
    r"\b(smuggl|contrab)\w*\b",
    r"\b(narcotic|cocaine|heroin|meth)\w*\b",
]

_REFUSAL_MSG = (
    "I can only help with Flyro features, escrow steps, marketplace rules, "
    "and shipping policies. I cannot provide legal advice, facilitate illegal "
    "activities, or answer questions outside Flyro's scope."
)


# ── Tool helpers (read-only DB queries) ──────────────────────────────


def _tool_my_bookings(user: User, session: Session) -> AiChatResponse:
    """List the user's bookings (as requester via RequestItem)."""
    req_ids = session.exec(
        select(RequestItem.id).where(RequestItem.user_id == user.id)
    ).all()
    trip_ids = session.exec(
        select(Trip.id).where(Trip.user_id == user.id)
    ).all()

    bookings = session.exec(
        select(Booking).where(
            (Booking.request_id.in_(req_ids)) | (Booking.trip_id.in_(trip_ids))  # type: ignore[union-attr]
        )
    ).all()

    if not bookings:
        return AiChatResponse(
            reply="You have no bookings yet.",
            source="tool",
            data={"bookings": []},
        )

    items = []
    for b in bookings:
        items.append({"id": b.id, "status": b.status, "trip_id": b.trip_id, "request_id": b.request_id})

    summary = ", ".join(f"#{b['id']} ({b['status']})" for b in items)
    return AiChatResponse(
        reply=f"You have {len(items)} booking(s): {summary}.",
        source="tool",
        data={"bookings": items},
    )


def _tool_booking_status(user: User, session: Session, booking_id: int) -> AiChatResponse:
    """Get status of a specific booking (owner check)."""
    booking = session.get(Booking, booking_id)
    if not booking:
        return AiChatResponse(reply=f"Booking #{booking_id} not found.", source="tool")

    req = session.get(RequestItem, booking.request_id)
    trip = session.get(Trip, booking.trip_id)
    is_owner = (req and req.user_id == user.id) or (trip and trip.user_id == user.id)
    if not is_owner:
        return AiChatResponse(reply="You don't have access to that booking.", source="tool")

    return AiChatResponse(
        reply=f"Booking #{booking_id} status: {booking.status}.",
        source="tool",
        data={
            "id": booking.id,
            "status": booking.status,
            "trip_id": booking.trip_id,
            "request_id": booking.request_id,
            "created_at": str(booking.created_at),
        },
    )


def _tool_my_trips(user: User, session: Session) -> AiChatResponse:
    trips = session.exec(select(Trip).where(Trip.user_id == user.id)).all()
    if not trips:
        return AiChatResponse(reply="You have no trips.", source="tool", data={"trips": []})

    items = []
    for t in trips:
        items.append({
            "id": t.id,
            "origin": t.origin_airport,
            "dest": t.dest_airport,
            "date": str(t.date),
            "capacity_kg": t.capacity_kg,
        })

    summary = ", ".join(f"#{t['id']} {t['origin']}->{t['dest']}" for t in items)
    return AiChatResponse(
        reply=f"You have {len(items)} trip(s): {summary}.",
        source="tool",
        data={"trips": items},
    )


def _tool_my_requests(user: User, session: Session) -> AiChatResponse:
    reqs = session.exec(select(RequestItem).where(RequestItem.user_id == user.id)).all()
    if not reqs:
        return AiChatResponse(reply="You have no requests.", source="tool", data={"requests": []})

    items = []
    for r in reqs:
        items.append({
            "id": r.id,
            "product": r.product_name,
            "dest_city": r.dest_city,
            "target_price": r.target_price,
        })

    summary = ", ".join(f"#{r['id']} {r['product']}" for r in items)
    return AiChatResponse(
        reply=f"You have {len(items)} request(s): {summary}.",
        source="tool",
        data={"requests": items},
    )


def _tool_search_listings(session: Session, query: str) -> AiChatResponse:
    listings = session.exec(
        select(MarketListing)
        .where(MarketListing.status == "active")
        .where(
            MarketListing.title.contains(query)  # type: ignore[union-attr]
            | MarketListing.description.contains(query)  # type: ignore[union-attr]
        )
        .limit(5)
    ).all()

    if not listings:
        return AiChatResponse(
            reply=f'No active listings found for "{query}".',
            source="tool",
            data={"listings": []},
        )

    items = []
    for l in listings:
        items.append({"id": l.id, "title": l.title, "price": l.ask_price, "location": l.location_text})

    summary = ", ".join(f'"{i["title"]}" PKR {i["price"]}' for i in items)
    return AiChatResponse(
        reply=f'Found {len(items)} listing(s) for "{query}": {summary}.',
        source="tool",
        data={"listings": items},
    )


def _tool_my_listing_offers(user: User, session: Session) -> AiChatResponse:
    listing_ids = session.exec(
        select(MarketListing.id).where(MarketListing.seller_id == user.id)
    ).all()

    if not listing_ids:
        return AiChatResponse(reply="You have no listings.", source="tool", data={"offers": []})

    offers = session.exec(
        select(MarketOffer).where(MarketOffer.listing_id.in_(listing_ids))  # type: ignore[union-attr]
    ).all()

    if not offers:
        return AiChatResponse(
            reply="No offers on your listings yet.",
            source="tool",
            data={"offers": []},
        )

    items = []
    for o in offers:
        items.append({
            "id": o.id,
            "listing_id": o.listing_id,
            "amount": o.amount,
            "status": o.status,
        })

    summary = ", ".join(f"Offer #{o['id']} PKR {o['amount']} ({o['status']})" for o in items)
    return AiChatResponse(
        reply=f"You have {len(items)} offer(s): {summary}.",
        source="tool",
        data={"offers": items},
    )


# ── Intent detection helpers ─────────────────────────────────────────


def _normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.lower().strip())


def _extract_booking_id(text: str) -> int | None:
    m = re.search(r"booking\s*#?\s*(\d+)", text, re.IGNORECASE)
    if m:
        return int(m.group(1))
    m = re.search(r"#(\d+)", text)
    if m:
        return int(m.group(1))
    return None


def _match_faq(text: str) -> str | None:
    """Return FAQ answer if text matches any FAQ key (fuzzy substring)."""
    norm = _normalize(text)
    for key, answer in FAQ.items():
        if key in norm:
            return answer
    best_score = 0
    best_answer = None
    for key, answer in FAQ.items():
        key_words = set(key.split())
        text_words = set(norm.split())
        overlap = len(key_words & text_words)
        if overlap > best_score and overlap >= 2:
            best_score = overlap
            best_answer = answer
    return best_answer


def _match_policy(text: str) -> AiChatResponse | None:
    norm = _normalize(text)
    for product, info in POLICY_FLAGS.items():
        if product in norm:
            return AiChatResponse(
                reply=f"Policy for '{product}': Risk level: {info['risk']}. {info['advisory']}",
                source="policy",
                data={"product": product, **info},
            )
    return None


def _should_refuse(text: str) -> bool:
    norm = _normalize(text)
    return any(re.search(p, norm) for p in _REFUSAL_PATTERNS)


# ── Simple calculators ───────────────────────────────────────────────


def _calc_shipping(text: str) -> AiChatResponse | None:
    """Estimate shipping cost from weight mention."""
    m = re.search(r"(\d+(?:\.\d+)?)\s*kg", text, re.IGNORECASE)
    if not m:
        return None
    norm = _normalize(text)
    if not any(w in norm for w in ["cost", "estimate", "calculate", "price", "how much", "fee"]):
        return None
    weight = float(m.group(1))
    estimate = weight * 500
    return AiChatResponse(
        reply=(
            f"Estimated shipping fee for {weight} kg: ~PKR {estimate:,.0f} "
            f"(at average rate PKR 500/kg). Actual fee depends on the traveler's rate."
        ),
        source="tool",
        data={"weight_kg": weight, "estimated_pkr": estimate, "rate_per_kg": 500},
    )


# ── Gemini LLM integration ──────────────────────────────────────────

SYSTEM_PROMPT = """\
You are the Flyro AI assistant. Flyro is a peer-to-peer platform in Pakistan with two main features:

**Feature A (Cross-Border Delivery):**
- Users post "requests" for products from abroad (electronics, medicine, etc.)
- Verified travelers post their upcoming flights with available luggage capacity
- A booking matches a request with a trip. Escrow holds buyer funds until delivery is confirmed.
- Booking statuses: REQUESTED → HOLD_PLACED → ACCEPTED → PICKUP_OK → DELIVERY_OK → RELEASED
- Pickup and delivery are verified via OTP codes, GPS, and photos.

**Feature B (Local Marketplace):**
- OLX-style buy/sell marketplace for local transactions
- Users create listings, send offers, counter-offer, and schedule meetups
- Flyro does NOT handle delivery or payment for marketplace transactions

**Other features:**
- KYC verification (CNIC/passport + selfie) is required for travelers
- Reviews and ratings after completed transactions
- Admin panel for dispute resolution and escrow management
- Shipping policy flags for restricted/high-risk items

**You MUST help travelers and buyers with these topics:**
- Travel safety: Which countries are safe to travel to, travel advisories, war zones, conflict areas, political instability — help travelers decide safe routes for courier trips
- Country-specific courier guidance: What items can be legally carried FROM and TO specific countries (e.g., electronics from China, perfumes from Dubai, medicine from UK)
- Customs and import rules: Duty limits, restricted items, required documentation per country (especially Pakistan, UAE, UK, US, Turkey, China, Saudi Arabia)
- Airline baggage policies: General weight limits, restricted items in luggage, lithium battery rules
- Destination tips: Places to explore, local food, cultural tips, safety advice, best shopping areas for popular items
- Shipping cost estimates: Help estimate fees based on weight, route, and item type
- Item legality: Whether specific items are legal to transport between two countries, risk levels, and required paperwork

**Rules for your responses:**
- Be helpful, concise, and knowledgeable — you are a travel and courier expert
- Answer travel safety questions openly — travelers NEED this info to plan safe routes
- Answer item legality and customs questions with practical guidance
- When discussing restricted/prohibited items, explain WHY and suggest legal alternatives
- Do not facilitate clearly illegal activities (drug smuggling, weapons trafficking)
- Do not provide formal legal advice — recommend consulting customs authorities for edge cases
- If you don't know something specific about the user's account, suggest they check the relevant screen in the app
- Keep responses SHORT — max 3-4 sentences for simple questions, max 150 words for detailed ones
- Get straight to the point — no filler, no introductions, no "Great question!"
- NEVER use markdown tables — they render badly on mobile
- Write like you are texting a friend — casual, direct, and helpful
- Use bullet points only when listing 3+ items
- Do NOT use formal report-style formatting
- Remember the conversation context — refer back to what the user asked before
"""

_gemini_model = None
_rate_limits: dict[int, list[float]] = defaultdict(list)


def _get_gemini_model():
    """Lazy-init the Gemini model."""
    global _gemini_model
    if _gemini_model is not None:
        return _gemini_model

    settings = get_settings()
    if not settings.gemini_api_key:
        return None

    try:
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", FutureWarning)
            import google.generativeai as genai

        genai.configure(api_key=settings.gemini_api_key)
        _gemini_model = genai.GenerativeModel(
            model_name=settings.gemini_model,
            system_instruction=SYSTEM_PROMPT,
        )
        logger.info("Gemini model initialized: %s", settings.gemini_model)
        return _gemini_model
    except Exception:
        logger.exception("Failed to initialize Gemini model")
        return None


def _check_rate_limit(user_id: int) -> bool:
    """Return True if the user is within rate limits."""
    settings = get_settings()
    now = time.time()
    window = 3600  # 1 hour
    limit = settings.gemini_rate_limit_per_hour

    # Prune old timestamps.
    _rate_limits[user_id] = [
        ts for ts in _rate_limits[user_id] if now - ts < window
    ]

    if len(_rate_limits[user_id]) >= limit:
        return False

    _rate_limits[user_id].append(now)
    return True


def _call_gemini(user: User, message: str, history: list) -> AiChatResponse | None:
    """Call Gemini with conversation history. Returns None on failure."""
    model = _get_gemini_model()
    if model is None:
        return None

    if not _check_rate_limit(user.id):
        return AiChatResponse(
            reply="You've reached the AI chat limit for this hour. "
                  "Try again later or ask about a specific Flyro feature.",
            source="llm",
        )

    try:
        # Build chat history from last 10 messages (plain dicts).
        chat_history = []
        for msg in history[-10:]:
            role = msg.role if hasattr(msg, "role") else msg.get("role", "user")
            content = msg.content if hasattr(msg, "content") else msg.get("content", "")
            gemini_role = "user" if role == "user" else "model"
            chat_history.append(
                {"role": gemini_role, "parts": [content]}
            )

        chat = model.start_chat(history=chat_history)
        response = chat.send_message(message)

        reply_text = response.text.strip() if response.text else None
        if not reply_text:
            return None

        return AiChatResponse(reply=reply_text, source="llm")

    except Exception as exc:
        exc_str = str(exc).lower()
        if "quota" in exc_str or "resource_exhausted" in exc_str or "429" in exc_str:
            logger.warning("Gemini quota exceeded for user %s", user.id)
            return AiChatResponse(
                reply="The AI service is temporarily at capacity. "
                      "Please try again in a few minutes, or ask about "
                      "a specific Flyro feature for an instant answer.",
                source="llm",
            )
        logger.exception("Gemini API call failed")
        return None


# ── NVIDIA NIM (MiniMax-M2.5) integration ─────────────────────────

_nvidia_client = None


def _get_nvidia_client():
    """Lazy-init the NVIDIA NIM client (OpenAI-compatible)."""
    global _nvidia_client
    if _nvidia_client is not None:
        return _nvidia_client

    settings = get_settings()
    if not settings.nvidia_api_key:
        return None

    try:
        from openai import OpenAI
        _nvidia_client = OpenAI(
            base_url="https://integrate.api.nvidia.com/v1",
            api_key=settings.nvidia_api_key,
        )
        logger.info("NVIDIA NIM client initialized: %s", settings.nvidia_model)
        return _nvidia_client
    except Exception:
        logger.exception("Failed to initialize NVIDIA NIM client")
        return None


def _call_nvidia(user: User, message: str, history: list) -> AiChatResponse | None:
    """Call NVIDIA NIM with conversation history. Returns None on failure."""
    client = _get_nvidia_client()
    if client is None:
        return None

    if not _check_rate_limit(user.id):
        return AiChatResponse(
            reply="You've reached the AI chat limit for this hour. "
                  "Try again later or ask about a specific Flyro feature.",
            source="llm",
        )

    try:
        settings = get_settings()

        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        for msg in history[-10:]:
            role = msg.role if hasattr(msg, "role") else msg.get("role", "user")
            content = msg.content if hasattr(msg, "content") else msg.get("content", "")
            openai_role = "user" if role == "user" else "assistant"
            messages.append({"role": openai_role, "content": content})
        messages.append({"role": "user", "content": message})

        response = client.chat.completions.create(
            model=settings.nvidia_model,
            messages=messages,
            max_tokens=1024,
            temperature=0.7,
        )

        reply_text = response.choices[0].message.content
        # Some reasoning models put output in reasoning_content instead of content
        if not reply_text or not reply_text.strip():
            reply_text = getattr(response.choices[0].message, "reasoning_content", None)
        if not reply_text or not reply_text.strip():
            return None

        # Strip <think>...</think> reasoning tags if present.
        clean = re.sub(r"<think>.*?</think>\s*", "", reply_text, flags=re.DOTALL).strip()
        if not clean:
            return None

        return AiChatResponse(reply=clean, source="llm")

    except Exception as exc:
        exc_str = str(exc).lower()
        if "rate" in exc_str or "429" in exc_str or "quota" in exc_str:
            logger.warning("NVIDIA NIM rate limit for user %s", user.id)
            return AiChatResponse(
                reply="The AI service is temporarily at capacity. "
                      "Please try again in a few minutes, or ask about "
                      "a specific Flyro feature for an instant answer.",
                source="llm",
            )
        logger.exception("NVIDIA NIM API call failed")
        return None


# ── OpenAI LLM integration ─────────────────────────────────────────

_openai_client = None


def _get_openai_client():
    """Lazy-init the OpenAI client."""
    global _openai_client
    if _openai_client is not None:
        return _openai_client

    settings = get_settings()
    if not settings.openai_api_key:
        return None

    try:
        from openai import OpenAI
        _openai_client = OpenAI(api_key=settings.openai_api_key)
        logger.info("OpenAI client initialized: %s", settings.openai_model)
        return _openai_client
    except Exception:
        logger.exception("Failed to initialize OpenAI client")
        return None


def _call_openai(user: User, message: str, history: list) -> AiChatResponse | None:
    """Call OpenAI with conversation history. Returns None on failure."""
    client = _get_openai_client()
    if client is None:
        return None

    if not _check_rate_limit(user.id):
        return AiChatResponse(
            reply="You've reached the AI chat limit for this hour. "
                  "Try again later or ask about a specific Flyro feature.",
            source="llm",
        )

    try:
        settings = get_settings()

        # Build messages from history (last 10 messages).
        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        for msg in history[-10:]:
            role = msg.role if hasattr(msg, "role") else msg.get("role", "user")
            content = msg.content if hasattr(msg, "content") else msg.get("content", "")
            openai_role = "user" if role == "user" else "assistant"
            messages.append({"role": openai_role, "content": content})
        messages.append({"role": "user", "content": message})

        response = client.chat.completions.create(
            model=settings.openai_model,
            messages=messages,
            max_tokens=400,
            temperature=0.7,
        )

        reply_text = response.choices[0].message.content
        if not reply_text or not reply_text.strip():
            return None

        return AiChatResponse(reply=reply_text.strip(), source="llm")

    except Exception as exc:
        exc_str = str(exc).lower()
        if "rate" in exc_str or "429" in exc_str or "quota" in exc_str:
            logger.warning("OpenAI rate limit for user %s", user.id)
            return AiChatResponse(
                reply="The AI service is temporarily at capacity. "
                      "Please try again in a few minutes, or ask about "
                      "a specific Flyro feature for an instant answer.",
                source="llm",
            )
        logger.exception("OpenAI API call failed")
        return None


# ── Travel exploration & item legality ────────────────────────────────

_TRAVEL_PATTERNS = [
    "explore", "visit", "places in", "things to do", "tourist",
    "travel to", "suggest places", "places to visit", "what to see",
    "food in", "sightseeing", "attractions", "safe to travel",
    "war", "conflict", "travel advisory", "safe country", "safe countries",
    "dangerous", "travel ban", "visa", "which country", "can i travel",
    "travel during", "is it safe", "safety", "travel warning",
]

_LEGALITY_PATTERNS = [
    "legal", "allowed", "can i send", "customs", "import", "export",
    "restricted", "banned", "prohibited in", "can i ship", "is it legal",
    "duty", "declaration", "can i carry", "can i bring", "courier",
    "what can i", "items from", "bring from", "ship from", "send from",
    "carry from", "transport", "what items", "which items", "which products",
]

TRAVEL_SYSTEM_PROMPT = """\
The user is a Flyro traveler planning a courier trip. You MUST help them with:
- Travel safety: Which countries are safe, which have active conflicts/wars, travel advisories
- Safe route planning: Suggest alternative countries if a destination is unsafe
- Visa requirements for Pakistani passport holders
- Best cities for shopping specific items (electronics, clothing, etc.)
- Local tips, food, cultural insights, and safety precautions
- Airport tips and baggage handling advice
Be direct and practical. If a country has active conflict, say so clearly and suggest safer alternatives.
Write conversationally like a friend chatting. Use bullet points, NOT tables.
"""

LEGALITY_SYSTEM_PROMPT = """\
The user wants to know what items can be legally couriered between countries via Flyro travelers.
You MUST provide practical, detailed customs/import guidance including:
- Whether the item is legal to carry as personal luggage on flights
- Country-specific restrictions (especially Pakistan, UAE, UK, US, Turkey, China, Saudi Arabia, Malaysia)
- Popular items travelers commonly bring: electronics, phones, laptops, clothing, cosmetics, supplements, spices, dry food
- Required documentation: purchase receipts, invoices, prescriptions for medicines
- Weight and value limits that trigger customs duties (e.g., Pakistan customs duty-free limit)
- Risk level clearly stated: LOW / MEDIUM / HIGH / PROHIBITED
- If an item is restricted, suggest legal alternatives or proper documentation to make it legal
- Common items from specific countries: electronics from China/Japan, perfumes from Dubai, clothing from Turkey, supplements from US/UK

Be helpful and informative. Travelers need this info to earn money safely on Flyro.
When unsure about a specific regulation, say so and recommend checking the destination country's customs website.
Write conversationally like a friend chatting. Use bullet points, NOT tables.
"""


def _is_travel_query(text: str) -> bool:
    norm = _normalize(text)
    return any(p in norm for p in _TRAVEL_PATTERNS)


def _is_legality_query(text: str) -> bool:
    norm = _normalize(text)
    return any(p in norm for p in _LEGALITY_PATTERNS)


def _call_llm_with_context(
    user: User, message: str, history: list, extra_system: str, source: str
) -> AiChatResponse | None:
    """Call LLM with an extra system prompt prepended for context-specific queries."""
    combined_prompt = extra_system + "\n\n" + SYSTEM_PROMPT

    # Try NVIDIA first, then OpenAI, then Gemini — same priority as main endpoint.
    client = _get_nvidia_client()
    if client:
        if not _check_rate_limit(user.id):
            return AiChatResponse(
                reply="You've reached the AI chat limit for this hour.",
                source=source,
            )
        try:
            settings = get_settings()
            messages = [{"role": "system", "content": combined_prompt}]
            for msg in history[-10:]:
                role = msg.role if hasattr(msg, "role") else msg.get("role", "user")
                content = msg.content if hasattr(msg, "content") else msg.get("content", "")
                messages.append({"role": "user" if role == "user" else "assistant", "content": content})
            messages.append({"role": "user", "content": message})

            response = client.chat.completions.create(
                model=settings.nvidia_model,
                messages=messages,
                max_tokens=1024,
                temperature=0.7,
            )
            reply_text = response.choices[0].message.content
            if not reply_text or not reply_text.strip():
                reply_text = getattr(response.choices[0].message, "reasoning_content", None)
            if reply_text:
                clean = re.sub(r"<think>.*?</think>\s*", "", reply_text, flags=re.DOTALL).strip()
                if clean:
                    return AiChatResponse(reply=clean, source=source)
        except Exception:
            logger.exception("NVIDIA NIM call failed for %s query", source)

    openai_client = _get_openai_client()
    if openai_client:
        if not _check_rate_limit(user.id):
            return AiChatResponse(
                reply="You've reached the AI chat limit for this hour.",
                source=source,
            )
        try:
            settings = get_settings()
            messages = [{"role": "system", "content": combined_prompt}]
            for msg in history[-10:]:
                role = msg.role if hasattr(msg, "role") else msg.get("role", "user")
                content = msg.content if hasattr(msg, "content") else msg.get("content", "")
                messages.append({"role": "user" if role == "user" else "assistant", "content": content})
            messages.append({"role": "user", "content": message})

            response = openai_client.chat.completions.create(
                model=settings.openai_model,
                messages=messages,
                max_tokens=500,
                temperature=0.7,
            )
            reply_text = response.choices[0].message.content
            if reply_text and reply_text.strip():
                return AiChatResponse(reply=reply_text.strip(), source=source)
        except Exception:
            logger.exception("OpenAI call failed for %s query", source)

    # Fallback to Gemini
    model = _get_gemini_model()
    if model:
        if not _check_rate_limit(user.id):
            return AiChatResponse(
                reply="You've reached the AI chat limit for this hour.",
                source=source,
            )
        try:
            chat_history = []
            for msg in history[-10:]:
                role = msg.role if hasattr(msg, "role") else msg.get("role", "user")
                content = msg.content if hasattr(msg, "content") else msg.get("content", "")
                chat_history.append({"role": "user" if role == "user" else "model", "parts": [content]})
            chat = model.start_chat(history=chat_history)
            response = chat.send_message(f"{extra_system}\n\nUser query: {message}")
            if response.text and response.text.strip():
                return AiChatResponse(reply=response.text.strip(), source=source)
        except Exception:
            logger.exception("Gemini call failed for %s query", source)

    return None


# ── Main endpoint ────────────────────────────────────────────────────


@router.post("/chat", response_model=AiChatResponse)
def ai_chat(
    body: AiChatRequest,
    user: User = Depends(get_current_user_dep),
    session: Session = Depends(get_session_dep),
) -> AiChatResponse:
    text = body.message
    norm = _normalize(text)

    # 1. Safety refusal check.
    if _should_refuse(text):
        return AiChatResponse(reply=_REFUSAL_MSG, source="fallback")

    # 2. Read-only DB tools — intent detection.
    if any(w in norm for w in ["my booking", "my bookings", "show booking", "list booking"]):
        bid = _extract_booking_id(text)
        if bid is not None:
            return _tool_booking_status(user, session, bid)
        return _tool_my_bookings(user, session)

    if any(w in norm for w in ["my trip", "my trips", "show trip", "list trip"]):
        return _tool_my_trips(user, session)

    if any(w in norm for w in ["my request", "my requests", "show request", "list request"]):
        return _tool_my_requests(user, session)

    if any(w in norm for w in ["my offer", "offers on my listing", "listing offer"]):
        return _tool_my_listing_offers(user, session)

    if any(w in norm for w in ["search listing", "find listing", "search market", "find item"]):
        q = re.sub(r"(search|find)\s+(listing|market|item)s?\s*(for)?\s*", "", norm).strip()
        if q:
            return _tool_search_listings(session, q)

    # 3. Simple calculator.
    calc = _calc_shipping(text)
    if calc:
        return calc

    # 4. Policy flags.
    policy = _match_policy(text)
    if policy:
        return policy

    # 5. Travel exploration queries (BEFORE FAQ to avoid false matches on "safe").
    if _is_travel_query(text):
        travel_resp = _call_llm_with_context(user, text, body.history, TRAVEL_SYSTEM_PROMPT, "travel_guide")
        if travel_resp:
            return travel_resp

    # 5b. Item legality queries.
    if _is_legality_query(text):
        legality_resp = _call_llm_with_context(user, text, body.history, LEGALITY_SYSTEM_PROMPT, "legality_check")
        if legality_resp:
            return legality_resp

    # 5c. FAQ matching (after travel/legality to avoid false matches).
    faq_answer = _match_faq(text)
    if faq_answer:
        return AiChatResponse(reply=faq_answer, source="faq")

    # 6. NVIDIA NIM MiniMax-M2.5 (primary).
    nvidia_response = _call_nvidia(user, text, body.history)
    if nvidia_response:
        return nvidia_response

    # 6b. OpenAI (fallback 1).
    openai_response = _call_openai(user, text, body.history)
    if openai_response:
        return openai_response

    # 6c. Gemini LLM (fallback 2).
    gemini_response = _call_gemini(user, text, body.history)
    if gemini_response:
        return gemini_response

    # 7. Check if LLM keys are configured at all.
    settings = get_settings()
    if not settings.nvidia_api_key and not settings.openai_api_key and not settings.gemini_api_key:
        return AiChatResponse(
            reply=(
                "AI chat is not configured yet. I can still help with "
                "Flyro features, escrow steps, booking statuses, "
                "marketplace rules, and shipping policies — just ask!"
            ),
            source="fallback",
        )

    # 8. LLM keys exist but calls failed (likely quota exhausted).
    return AiChatResponse(
        reply=(
            "The AI service is temporarily unavailable (quota may be exhausted). "
            "I can still answer questions about Flyro features, escrow, "
            "bookings, marketplace rules, and shipping policies instantly. "
            "Try asking about one of those!"
        ),
        source="fallback",
    )
