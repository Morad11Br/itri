import logging
from typing import Any

from supabase import Client


def upsert_batch(
    supabase: Client,
    table: str,
    batch: list[dict[str, Any]],
    on_conflict: str,
) -> None:
    if not batch:
        return

    response = (
        supabase.table(table)
        .upsert(batch, on_conflict=on_conflict, ignore_duplicates=False)
        .execute()
    )

    if getattr(response, "error", None):
        raise RuntimeError(response.error)


def write_to_supabase(
    supabase: Client,
    items: list[dict[str, Any]],
    batch_size: int,
    *,
    table: str = "fragrances",
    on_conflict: str = "source_id",
) -> None:
    for offset in range(0, len(items), batch_size):
        batch = items[offset : offset + batch_size]
        try:
            upsert_batch(supabase, table, batch, on_conflict)
            logging.info("Upserted rows %s-%s.", offset + 1, offset + len(batch))
        except Exception:
            logging.exception("Failed to upsert batch starting at row %s.", offset + 1)
            raise
