from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

_BLACKLIST_KEYS = {
    "irradiance_8760",
    "load_profile_8760",
}

_HUGE_SERIES_KEY_HINTS = (
    "8760",
    "hourly",
    "timeseries",
    "time_series",
    "profile",
    "irradiance",
    "radiation",
    "curve",
)


def clean_project_parameters(parameters: dict[str, Any]) -> dict[str, Any]:
    """Remove nulls and large hourly arrays before JSONB persistence."""
    cleaned = _clean_value(parameters, parent_key=None)
    if not isinstance(cleaned, dict):
        return {}
    return cleaned


def _clean_value(value: Any, parent_key: str | None) -> Any:
    if value is None:
        return None

    if isinstance(value, Mapping):
        cleaned_map: dict[str, Any] = {}
        for raw_key, raw_val in value.items():
            key = str(raw_key)
            if _should_drop_key(key, raw_val):
                continue
            cleaned_val = _clean_value(raw_val, parent_key=key)
            if cleaned_val is None:
                continue
            cleaned_map[key] = cleaned_val
        return cleaned_map

    if _is_non_string_sequence(value):
        if _should_drop_large_series(parent_key, value):
            return None
        cleaned_items: list[Any] = []
        for item in value:
            cleaned_item = _clean_value(item, parent_key=parent_key)
            if cleaned_item is not None:
                cleaned_items.append(cleaned_item)
        return cleaned_items

    return value


def _should_drop_key(key: str, value: Any) -> bool:
    normalized = key.strip().lower()
    if normalized in _BLACKLIST_KEYS:
        return True
    if _should_drop_large_series(normalized, value):
        return True
    return False


def _should_drop_large_series(key: str | None, value: Any) -> bool:
    if not _is_non_string_sequence(value):
        return False

    size = len(value)
    if size < 8760:
        return False

    key_text = (key or "").strip().lower()
    key_looks_hourly = any(hint in key_text for hint in _HUGE_SERIES_KEY_HINTS)
    values_look_numeric = all(isinstance(v, (int, float)) for v in value)
    return key_looks_hourly or values_look_numeric


def _is_non_string_sequence(value: Any) -> bool:
    return isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray))
