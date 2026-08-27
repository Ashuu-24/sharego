from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


def _validate_window(window_start: datetime | None, window_end: datetime | None) -> None:
    if window_start is not None and window_end is not None and window_end < window_start:
        raise ValueError("window_end must be greater than or equal to window_start")


class RequestCreate(BaseModel):
    product_name: str = Field(min_length=3, max_length=120)
    specs_json: str | None = None
    target_price: float = Field(ge=0)
    dest_city: str = Field(min_length=2, max_length=80)
    weight_kg: float = Field(gt=0)
    window_start: datetime
    window_end: datetime
    declaration_path: str | None = None

    @model_validator(mode="after")
    def validate_window(self):
        _validate_window(self.window_start, self.window_end)
        return self


class RequestRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    product_name: str
    specs_json: str | None
    target_price: float
    dest_city: str
    weight_kg: float
    window_start: datetime
    window_end: datetime
    declaration_path: str | None
    created_at: datetime


class RequestUpdate(BaseModel):
    product_name: str | None = Field(default=None, min_length=3, max_length=120)
    specs_json: str | None = None
    target_price: float | None = Field(default=None, ge=0)
    dest_city: str | None = Field(default=None, min_length=2, max_length=80)
    weight_kg: float | None = Field(default=None, gt=0)
    window_start: datetime | None = None
    window_end: datetime | None = None
    declaration_path: str | None = None

    @model_validator(mode="after")
    def validate_window(self):
        _validate_window(self.window_start, self.window_end)
        return self
