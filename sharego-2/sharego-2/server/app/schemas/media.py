from __future__ import annotations

from pydantic import BaseModel


class MediaUploadResponse(BaseModel):
    filename: str
    path: str
    url: str
    content_type: str
    size: int
