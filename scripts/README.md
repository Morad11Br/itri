# Python Scripts

Project Python code is organized as a small package under `barfum_tools/`.

- `import_fragrance_csv_to_supabase.py` is the CLI entry point for importing a local cleaned CSV.
- `fragrantica_to_supabase.py` is the CLI entry point for scraping Fragrantica search results.
- `barfum_tools/common.py` contains shared logging, environment, text, and JSON helpers.
- `barfum_tools/supabase_writer.py` contains shared Supabase batch upsert logic.
- `barfum_tools/csv_importer.py` contains CSV import parsing and transformation logic.
- `barfum_tools/fragrantica_scraper.py` contains Playwright scraping logic.

Run scripts with the project virtualenv:

```bash
.venv/bin/python scripts/import_fragrance_csv_to_supabase.py --help
.venv/bin/python scripts/fragrantica_to_supabase.py --help
```
