from __future__ import annotations

from collections.abc import Mapping, Sequence
from copy import deepcopy
from typing import Any

_MONTH_HOURS = (744, 672, 744, 720, 744, 720, 744, 744, 720, 744, 720, 744)


def optimize_results_for_db(raw_results: dict[str, Any]) -> dict[str, Any]:
    """
    Optimize result payload before JSONB persistence.

    Pipeline:
    A) round all floats to 2 decimals
    B) aggregate 8760 hourly arrays into compact summary charts
    C) drop oversized raw arrays (len > 100)
    """
    rounded = _round_floats_recursive(deepcopy(raw_results))
    summary_charts = _build_summary_charts(rounded)
    compact = _drop_large_arrays_recursive(rounded)
    if summary_charts:
        compact["summary_charts"] = summary_charts
    return compact if isinstance(compact, dict) else {}


def _round_floats_recursive(value: Any) -> Any:
    if isinstance(value, float):
        return round(value, 2)
    if isinstance(value, Mapping):
        return {str(k): _round_floats_recursive(v) for k, v in value.items()}
    if _is_non_string_sequence(value):
        return [_round_floats_recursive(v) for v in value]
    return value


def _build_summary_charts(value: Any) -> dict[str, list[float]]:
    charts: dict[str, list[float]] = {}
    for key_path, series in _iter_hourly_series(value):
        base_name = _normalize_series_name(key_path[-1])
        charts[f"monthly_{base_name}"] = _monthly_sum(series)
        charts[f"average_daily_{base_name}"] = _average_daily_profile(series)
    return charts


def _iter_hourly_series(value: Any, path: tuple[str, ...] = ()) -> list[tuple[tuple[str, ...], list[float]]]:
    found: list[tuple[tuple[str, ...], list[float]]] = []
    if isinstance(value, Mapping):
        for raw_key, nested in value.items():
            key = str(raw_key)
            found.extend(_iter_hourly_series(nested, (*path, key)))
        return found

    if _is_non_string_sequence(value) and _is_numeric_series(value) and len(value) == 8760:
        found.append((path, [float(v) for v in value]))
    return found


def _drop_large_arrays_recursive(value: Any) -> Any:
    if isinstance(value, Mapping):
        compact_map: dict[str, Any] = {}
        for raw_key, nested in value.items():
            cleaned = _drop_large_arrays_recursive(nested)
            if cleaned is None:
                continue
            compact_map[str(raw_key)] = cleaned
        return compact_map

    if _is_non_string_sequence(value):
        if len(value) > 100:
            return None
        compact_list: list[Any] = []
        for item in value:
            cleaned = _drop_large_arrays_recursive(item)
            if cleaned is not None:
                compact_list.append(cleaned)
        return compact_list

    return value


def _monthly_sum(series: list[float]) -> list[float]:
    monthly: list[float] = []
    start = 0
    for hours in _MONTH_HOURS:
        end = start + hours
        monthly.append(round(sum(series[start:end]), 2))
        start = end
    return monthly


def _average_daily_profile(series: list[float]) -> list[float]:
    days = 365
    hourly_avg: list[float] = []
    for hour in range(24):
        values = [series[hour + day * 24] for day in range(days)]
        hourly_avg.append(round(sum(values) / days, 2))
    return hourly_avg


def _normalize_series_name(key: str) -> str:
    name = key.strip().lower()
    for token in ("hourly_", "_hourly", "_8760", "profile_"):
        name = name.replace(token, "")
    name = name.replace("__", "_").strip("_")
    return name or "series"


def _is_numeric_series(value: Sequence[Any]) -> bool:
    return all(isinstance(v, (int, float)) for v in value)


def _is_non_string_sequence(value: Any) -> bool:
    return isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray))
