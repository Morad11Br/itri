import argparse
import csv
import logging
import math
import re
from pathlib import Path
from typing import Any

from .common import (
    clean_text,
    configure_logging,
    display_name_from_slug,
    get_supabase_client,
    write_json_preview,
)
from .supabase_writer import write_to_supabase


DEFAULT_CSV_PATH = "/Users/devacc/Downloads/fra_cleaned.csv"
DEFAULT_BATCH_SIZE = 500
FRAGRANTICA_IMAGE_TEMPLATE = "https://fimgs.net/mdimg/perfume-thumbs/dark-375x500.{source_id}.2x.avif"
FRAGRANTICA_FALLBACK_IMAGE_TEMPLATE = "https://fimgs.net/mdimg/perfume/375x500.{source_id}.jpg"
PERFUME_ID_RE = re.compile(r"-(\d+)\.html(?:$|[?#])", re.I)


def parse_float(value: str | None) -> float | None:
    value = clean_text(value)
    if not value:
        return None
    try:
        return float(value.replace(",", "."))
    except ValueError:
        return None


def parse_int(value: str | None) -> int | None:
    value = clean_text(value)
    if not value:
        return None
    try:
        return int(value)
    except ValueError:
        return None


def parse_list(value: str | None) -> list[str]:
    value = clean_text(value)
    if not value:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def parse_source_id(url: str | None) -> str | None:
    url = clean_text(url)
    if not url:
        return None
    match = PERFUME_ID_RE.search(url)
    return match.group(1) if match else None


def generated_image_url(source_id: str | None) -> str | None:
    if not source_id:
        return None
    return FRAGRANTICA_IMAGE_TEMPLATE.format(source_id=source_id)


def generated_fallback_image_url(source_id: str | None) -> str | None:
    if not source_id:
        return None
    return FRAGRANTICA_FALLBACK_IMAGE_TEMPLATE.format(source_id=source_id)


def popularity_score(rating: float | None, rating_count: int | None) -> float:
    if rating is None:
        return 0.0
    votes = rating_count or 0
    return round(rating * math.log10(votes + 1), 6)


def transform_row(row: dict[str, str]) -> dict[str, Any] | None:
    source_url = clean_text(row.get("url"))
    source_id = parse_source_id(source_url)
    name = display_name_from_slug(row.get("Perfume"))
    brand = display_name_from_slug(row.get("Brand"))

    if not source_id or not name or not brand:
        return None

    rating = parse_float(row.get("Rating Value"))
    rating_count = parse_int(row.get("Rating Count"))
    top_notes = parse_list(row.get("Top"))
    middle_notes = parse_list(row.get("Middle"))
    base_notes = parse_list(row.get("Base"))
    accords = [
        clean_text(row.get(f"mainaccord{i}"))
        for i in range(1, 6)
        if clean_text(row.get(f"mainaccord{i}"))
    ]
    perfumers = [
        display_name_from_slug(row.get("Perfumer1")),
        display_name_from_slug(row.get("Perfumer2")),
    ]
    perfumers = [
        perfumer
        for perfumer in perfumers
        if perfumer and perfumer.lower() != "unknown"
    ]

    return {
        "source_id": source_id,
        "source_url": source_url,
        "name": name,
        "brand": brand,
        "country": display_name_from_slug(row.get("Country")),
        "image_url": generated_image_url(source_id),
        "fallback_image_url": generated_fallback_image_url(source_id),
        "year": parse_int(row.get("Year")),
        "gender": clean_text(row.get("Gender")),
        "rating": rating,
        "rating_votes": rating_count,
        "reviews_count": None,
        "description": None,
        "accords": accords,
        "notes": {
            "top": top_notes,
            "middle": middle_notes,
            "base": base_notes,
        },
        "perfumers": perfumers,
        "popularity_score": popularity_score(rating, rating_count),
    }


def read_items(csv_path: str) -> list[dict[str, Any]]:
    path = Path(csv_path)
    if not path.exists():
        raise FileNotFoundError(f"CSV file not found: {path}")

    with path.open("r", encoding="latin-1", newline="") as file:
        reader = csv.DictReader(file, delimiter=";")
        items = [item for row in reader if (item := transform_row(row))]

    deduped: dict[str, dict[str, Any]] = {}
    for item in items:
        existing = deduped.get(item["source_id"])
        if existing is None or item["popularity_score"] > existing["popularity_score"]:
            deduped[item["source_id"]] = item

    return list(deduped.values())


def select_items(
    items: list[dict[str, Any]],
    limit: int | None,
    sort: str,
) -> list[dict[str, Any]]:
    if sort == "popular":
        items = sorted(
            items,
            key=lambda item: item["popularity_score"],
            reverse=True,
        )
    elif sort == "rating":
        items = sorted(
            items,
            key=lambda item: (item["rating"] or 0, item["rating_votes"] or 0),
            reverse=True,
        )
    elif sort == "source_id":
        items = sorted(items, key=lambda item: int(item["source_id"]))

    return items[:limit] if limit else items


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Import fragrance CSV rows into Supabase."
    )
    parser.add_argument("--csv", default=DEFAULT_CSV_PATH, help="Path to fra_cleaned.csv.")
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--limit", type=int, help="Optional row limit after sorting.")
    parser.add_argument(
        "--sort",
        choices=["popular", "rating", "source_id", "none"],
        default="popular",
        help="Sort before optional limiting.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse only; do not write to Supabase.",
    )
    parser.add_argument("--output-json", help="Write transformed rows to JSON for inspection.")
    return parser.parse_args()


def main() -> None:
    configure_logging()
    args = parse_args()

    items = read_items(args.csv)
    items = select_items(items, args.limit, args.sort)

    logging.info("Prepared %s fragrance rows from %s.", len(items), args.csv)
    if items:
        logging.info(
            "Top row: %s by %s, score=%s",
            items[0]["name"],
            items[0]["brand"],
            items[0]["popularity_score"],
        )

    if args.output_json:
        write_json_preview(items, args.output_json)

    if args.dry_run:
        logging.info("Dry run complete. Skipping Supabase write.")
        return

    supabase = get_supabase_client()
    write_to_supabase(
        supabase,
        items,
        args.batch_size,
        table="fragrances",
        on_conflict="source_id",
    )
    logging.info("Done.")
