import logging
import os
import re

from dotenv import load_dotenv
from supabase import Client, create_client


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )


def get_supabase_client() -> Client:
    load_dotenv()
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")

    if not supabase_url or not supabase_key:
        raise RuntimeError(
            "Missing SUPABASE_URL or SUPABASE_KEY. Add them to your environment or a .env file."
        )

    return create_client(supabase_url, supabase_key)


def clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = re.sub(r"\s+", " ", value).strip()
    return value or None


def display_name_from_slug(value: str | None) -> str | None:
    value = clean_text(value)
    if not value:
        return None
    value = value.replace("-", " ").replace("_", " ")
    return " ".join(word.capitalize() for word in value.split())


def write_json_preview(items: list[dict], output_json: str) -> None:
    import json

    with open(output_json, "w", encoding="utf-8") as file:
        json.dump(items, file, indent=2, ensure_ascii=False)
    logging.info("Wrote %s rows to %s.", len(items), output_json)

