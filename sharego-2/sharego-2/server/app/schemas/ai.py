from pydantic import BaseModel, Field


class AiChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class AiChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=500)
    history: list[AiChatMessage] = Field(default_factory=list, max_length=20)


class AiChatResponse(BaseModel):
    reply: str
    source: str  # "faq", "tool", "policy", "fallback", "llm"
    data: dict | None = None  # Optional structured data from DB tools
