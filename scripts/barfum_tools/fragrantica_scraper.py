import argparse
import asyncio
import logging
import os
import random
import re
from dataclasses import dataclass
from typing import Any

from playwright.async_api import (
    Browser,
    BrowserContext,
    Page,
    TimeoutError as PlaywrightTimeoutError,
    async_playwright,
)

from .common import clean_text, configure_logging, get_supabase_client, write_json_preview
from .supabase_writer import write_to_supabase

try:
    from playwright_stealth import stealth_async
except ModuleNotFoundError as exc:
    if exc.name == "pkg_resources":
        raise RuntimeError(
            "playwright-stealth requires pkg_resources. Install dependencies again with: "
            "pip install -r requirements.txt"
        ) from exc
    raise
except ImportError:
    stealth_async = None


FRAGRANTICA_SEARCH_URL = "https://www.fragrantica.com/search/"
DEFAULT_TARGET_COUNT = 1000
DEFAULT_BATCH_SIZE = 50
DEFAULT_SCROLL_MIN_DELAY = 1.25
DEFAULT_SCROLL_MAX_DELAY = 3.25
DEFAULT_MAX_STALLED_SCROLLS = 4
YEAR_RE = re.compile(r"\b(19|20)\d{2}\b")
LOAD_MORE_TEXT_RE = re.compile(
    r"(show more results|show more|load more|more results|view more|see more)",
    re.I,
)


@dataclass(frozen=True)
class ScrapeConfig:
    search_url: str
    target_count: int
    batch_size: int
    headless: bool
    profile_dir: str | None
    include_year: bool
    dry_run: bool
    manual_start: bool
    output_json: str | None
    max_stalled_scrolls: int
    scroll_min_delay: float
    scroll_max_delay: float


def parse_year(text: str | None) -> int | None:
    if not text:
        return None
    match = YEAR_RE.search(text)
    return int(match.group(0)) if match else None


def normalize_image_url(url: str | None) -> str | None:
    if not url:
        return None
    if url.startswith("//"):
        return f"https:{url}"
    return url


def make_dedupe_key(item: dict[str, Any]) -> tuple[str, str]:
    return (item["name"].casefold().strip(), item["brand"].casefold().strip())


async def apply_stealth(page: Page) -> None:
    if stealth_async is not None:
        await stealth_async(page)
        return

    from playwright_stealth import Stealth

    await Stealth().apply_stealth_async(page)


async def create_browser(headless: bool) -> tuple[Any, Browser]:
    playwright = await async_playwright().start()
    browser = await playwright.chromium.launch(
        headless=headless,
        args=[
            "--disable-blink-features=AutomationControlled",
            "--disable-dev-shm-usage",
            "--no-sandbox",
        ],
    )
    return playwright, browser


async def create_persistent_context(
    headless: bool,
    profile_dir: str,
) -> tuple[Any, BrowserContext]:
    playwright = await async_playwright().start()
    context = await playwright.chromium.launch_persistent_context(
        user_data_dir=profile_dir,
        headless=headless,
        viewport={"width": 1440, "height": 1100},
        user_agent=(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/124.0.0.0 Safari/537.36"
        ),
        locale="en-US",
        timezone_id="America/New_York",
        extra_http_headers={"Accept-Language": "en-US,en;q=0.9"},
        args=[
            "--disable-blink-features=AutomationControlled",
            "--disable-dev-shm-usage",
            "--no-sandbox",
        ],
    )
    return playwright, context


async def create_page(browser: Browser) -> Page:
    context = await browser.new_context(
        viewport={"width": 1440, "height": 1100},
        user_agent=(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/124.0.0.0 Safari/537.36"
        ),
        locale="en-US",
        timezone_id="America/New_York",
        extra_http_headers={"Accept-Language": "en-US,en;q=0.9"},
    )
    page = await context.new_page()
    await apply_stealth(page)
    return page


async def create_page_from_context(context: BrowserContext) -> Page:
    page = context.pages[0] if context.pages else await context.new_page()
    await apply_stealth(page)
    return page


async def accept_optional_cookie_banner(page: Page) -> None:
    selectors = [
        "button:has-text('Accept')",
        "button:has-text('I agree')",
        "button:has-text('Agree')",
        "text=Accept all",
    ]

    for selector in selectors:
        try:
            button = page.locator(selector).first
            if await button.count() > 0 and await button.is_visible(timeout=1000):
                await button.click(timeout=2000)
                await page.wait_for_timeout(500)
                return
        except PlaywrightTimeoutError:
            continue
        except Exception:
            logging.debug("Cookie selector failed: %s", selector, exc_info=True)


async def wait_for_network_idle(page: Page, timeout: int = 10_000) -> None:
    try:
        await page.wait_for_load_state("networkidle", timeout=timeout)
    except PlaywrightTimeoutError:
        logging.debug("Timed out waiting for network idle.")


async def wait_random_delay(page: Page, config: ScrapeConfig) -> None:
    await page.wait_for_timeout(
        int(random.uniform(config.scroll_min_delay, config.scroll_max_delay) * 1000)
    )


async def extract_listing_items(page: Page, include_year: bool) -> list[dict[str, Any]]:
    raw_items = await page.evaluate(
        """
        () => {
          const baseUrl = window.location.origin;
          const anchors = [...document.querySelectorAll("a[href*='/perfume/']")];
          const seen = new Set();

          return anchors.map((anchor) => {
            const href = new URL(anchor.getAttribute("href"), baseUrl).href;
            if (seen.has(href)) return null;
            seen.add(href);

            const card =
              anchor.closest("[class*='card'], [class*='Card'], article, li, div") || anchor;
            const text = (card.innerText || anchor.innerText || "").trim();
            const img =
              card.querySelector("img[src], img[data-src], img[data-original], source[srcset]") ||
              anchor.querySelector("img[src], img[data-src], img[data-original], source[srcset]");

            let imageUrl = null;
            if (img) {
              imageUrl =
                img.getAttribute("src") ||
                img.getAttribute("data-src") ||
                img.getAttribute("data-original") ||
                (img.getAttribute("srcset") || "").split(",")[0].trim().split(" ")[0] ||
                null;
              if (imageUrl) imageUrl = new URL(imageUrl, baseUrl).href;
            }

            const name =
              anchor.getAttribute("title") ||
              anchor.getAttribute("aria-label") ||
              [...anchor.querySelectorAll("span, h2, h3, h4")]
                .map((el) => el.innerText && el.innerText.trim())
                .find(Boolean) ||
              anchor.innerText ||
              null;

            return { href, name, text, imageUrl };
          }).filter(Boolean);
        }
        """
    )

    items: list[dict[str, Any]] = []

    for raw in raw_items:
        try:
            name, brand = derive_name_and_brand(raw)
            if not name or not brand:
                continue

            item: dict[str, Any] = {
                "name": name,
                "brand": brand,
                "image_url": normalize_image_url(raw.get("imageUrl")),
            }
            if include_year:
                item["year"] = parse_year(raw.get("text"))

            items.append(item)
        except Exception:
            logging.warning("Skipping an item due to extraction error.", exc_info=True)

    return items


def derive_name_and_brand(raw: dict[str, Any]) -> tuple[str | None, str | None]:
    href = raw.get("href") or ""
    text = clean_text(raw.get("text")) or ""
    raw_name = clean_text(raw.get("name"))

    slug_parts = [part for part in href.rstrip("/").split("/") if part]
    slug = slug_parts[-1] if slug_parts else ""
    slug_name = re.sub(r"-\d+$", "", slug).replace("-", " ").strip()

    lines = [clean_text(line) for line in text.splitlines()]
    lines = [line for line in lines if line]

    name = raw_name or (lines[0] if lines else None) or clean_text(slug_name)
    brand = None

    if len(lines) >= 2:
        for line in lines[1:4]:
            if line != name and not YEAR_RE.fullmatch(line):
                brand = line
                break

    if not brand and len(slug_parts) >= 2:
        brand_slug = slug_parts[-2]
        brand = brand_slug.replace("-", " ").strip()

    return clean_text(name), clean_text(brand)


async def get_result_link_count(page: Page) -> int:
    return await page.locator("a[href*='/perfume/']").count()


async def click_load_more_control(page: Page) -> bool:
    locator_candidates = [
        "button:has-text('Show more results')",
        "a:has-text('Show more results')",
        "[role='button']:has-text('Show more results')",
        "text=Show more results",
    ]

    for selector in locator_candidates:
        try:
            control = page.locator(selector).last
            if await control.count() > 0 and await control.is_visible(timeout=1000):
                await control.scroll_into_view_if_needed(timeout=2000)
                await control.click(timeout=3000)
                logging.info("Clicked load-more control with selector: %s", selector)
                return True
        except PlaywrightTimeoutError:
            continue
        except Exception:
            logging.debug("Load-more selector failed: %s", selector, exc_info=True)

    clicked = await page.evaluate(
        """
        (patternSource) => {
          const pattern = new RegExp(patternSource, "i");
          const controls = [...document.querySelectorAll("button, a, [role='button']")];
          const visibleControls = controls.filter((el) => {
            const text = (el.innerText || el.textContent || "")
              .replace(/[+＋]/g, " ")
              .replace(/\\s+/g, " ")
              .trim();
            const rect = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            return (
              text &&
              pattern.test(text) &&
              rect.width > 0 &&
              rect.height > 0 &&
              style.visibility !== "hidden" &&
              style.display !== "none"
            );
          });

          const control = visibleControls.at(-1);
          if (!control) return false;
          control.scrollIntoView({ block: "center", inline: "center" });
          control.click();
          return true;
        }
        """,
        LOAD_MORE_TEXT_RE.pattern,
    )

    if clicked:
        logging.info("Clicked a visible load-more control.")
    return bool(clicked)


async def perform_scroll_attempt(page: Page, config: ScrapeConfig) -> None:
    await page.evaluate(
        """
        () => {
          const perfumeLinks = [...document.querySelectorAll("a[href*='/perfume/']")];
          const lastLink = perfumeLinks.at(-1);
          if (lastLink) {
            lastLink.scrollIntoView({ block: "end", inline: "nearest" });
          }

          const scrollables = [...document.querySelectorAll("main, section, div")]
            .filter((el) => el.scrollHeight > el.clientHeight + 200)
            .sort((a, b) => b.scrollHeight - a.scrollHeight)
            .slice(0, 4);

          for (const el of scrollables) {
            el.scrollTop = el.scrollHeight;
          }

          window.scrollBy(0, Math.max(window.innerHeight * 0.9, 900));
          window.scrollTo(0, document.body.scrollHeight);
        }
        """
    )
    await page.mouse.wheel(0, random.randint(1800, 5200))
    await wait_for_network_idle(page)
    await wait_random_delay(page, config)

    before_click_count = await get_result_link_count(page)
    if await click_load_more_control(page):
        await wait_for_network_idle(page)
        await wait_random_delay(page, config)
        after_click_count = await get_result_link_count(page)
        logging.info(
            "Result links after load-more click: %s -> %s.",
            before_click_count,
            after_click_count,
        )


async def scroll_until_target(page: Page, config: ScrapeConfig) -> list[dict[str, Any]]:
    collected: dict[tuple[str, str], dict[str, Any]] = {}
    stalled_scrolls = 0
    last_count = 0

    while len(collected) < config.target_count and stalled_scrolls < config.max_stalled_scrolls:
        for item in await extract_listing_items(page, config.include_year):
            collected.setdefault(make_dedupe_key(item), item)

        current_count = len(collected)
        if current_count > last_count:
            stalled_scrolls = 0
            last_count = current_count
            logging.info("Collected %s unique fragrances.", current_count)
        else:
            stalled_scrolls += 1
            logging.info(
                "No new items found after scroll attempt %s/%s.",
                stalled_scrolls,
                config.max_stalled_scrolls,
            )

        await perform_scroll_attempt(page, config)

    if len(collected) < config.target_count:
        logging.warning(
            "Stopped at %s unique fragrances. The current search URL did not expose %s rows "
            "after %s stalled scroll attempts.",
            len(collected),
            config.target_count,
            config.max_stalled_scrolls,
        )

    return list(collected.values())[: config.target_count]


async def scrape(config: ScrapeConfig) -> list[dict[str, Any]]:
    playwright = None
    browser = None
    context = None

    try:
        if config.profile_dir:
            playwright, context = await create_persistent_context(
                config.headless,
                config.profile_dir,
            )
            page = await create_page_from_context(context)
        else:
            playwright, browser = await create_browser(config.headless)
            page = await create_page(browser)

        logging.info("Opening %s", config.search_url)
        await page.goto(config.search_url, wait_until="domcontentloaded", timeout=60_000)
        await accept_optional_cookie_banner(page)
        await wait_for_network_idle(page, timeout=20_000)

        if config.manual_start:
            logging.info(
                "Manual mode is active. Configure the Fragrantica page in the browser, "
                "then press Enter in this terminal to start scraping."
            )
            await asyncio.to_thread(input)

        return await scroll_until_target(page, config)
    finally:
        if context:
            await context.close()
        if browser:
            await browser.close()
        if playwright:
            await playwright.stop()


def parse_args() -> ScrapeConfig:
    parser = argparse.ArgumentParser(
        description="Scrape Fragrantica search results and bulk upsert them into Supabase."
    )
    parser.add_argument(
        "--search-url",
        default=os.getenv("FRAGRANTICA_SEARCH_URL", FRAGRANTICA_SEARCH_URL),
    )
    parser.add_argument(
        "--target-count",
        type=int,
        default=int(os.getenv("TARGET_COUNT", DEFAULT_TARGET_COUNT)),
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=int(os.getenv("BATCH_SIZE", DEFAULT_BATCH_SIZE)),
    )
    parser.add_argument("--headed", action="store_true", help="Run with a visible browser.")
    parser.add_argument(
        "--profile-dir",
        default=os.getenv("PLAYWRIGHT_PROFILE_DIR"),
        help="Use a persistent browser profile directory for cookies/session reuse.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Scrape without writing to Supabase.")
    parser.add_argument(
        "--manual-start",
        action="store_true",
        help="Open the browser and wait for Enter before scraping the current page state.",
    )
    parser.add_argument("--output-json", help="Write scraped rows to a JSON file.")
    parser.add_argument(
        "--include-year",
        action="store_true",
        default=os.getenv("INCLUDE_YEAR", "").lower() in {"1", "true", "yes"},
        help="Include a year field in Supabase payloads. Requires a year column.",
    )
    parser.add_argument("--scroll-min-delay", type=float, default=DEFAULT_SCROLL_MIN_DELAY)
    parser.add_argument("--scroll-max-delay", type=float, default=DEFAULT_SCROLL_MAX_DELAY)
    parser.add_argument(
        "--max-stalled-scrolls",
        type=int,
        default=int(os.getenv("MAX_STALLED_SCROLLS", DEFAULT_MAX_STALLED_SCROLLS)),
        help="Stop after this many scrolls produce no new unique rows.",
    )

    args = parser.parse_args()

    return ScrapeConfig(
        search_url=args.search_url,
        target_count=args.target_count,
        batch_size=args.batch_size,
        headless=not args.headed,
        profile_dir=args.profile_dir,
        include_year=args.include_year,
        dry_run=args.dry_run,
        manual_start=args.manual_start,
        output_json=args.output_json,
        max_stalled_scrolls=args.max_stalled_scrolls,
        scroll_min_delay=args.scroll_min_delay,
        scroll_max_delay=args.scroll_max_delay,
    )


async def main_async() -> None:
    configure_logging()
    config = parse_args()
    items = await scrape(config)

    if not items:
        logging.warning("No fragrances collected. Nothing to insert.")
        return

    if config.output_json:
        write_json_preview(items, config.output_json)

    if config.dry_run:
        logging.info("Dry run complete. Skipping Supabase write.")
        return

    supabase = get_supabase_client()
    logging.info("Scraping complete. Writing %s rows to Supabase.", len(items))
    write_to_supabase(
        supabase,
        items,
        config.batch_size,
        table="fragrances",
        on_conflict="name,brand",
    )
    logging.info("Done.")


def main() -> None:
    asyncio.run(main_async())
