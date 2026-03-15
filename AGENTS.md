# AGENTS — Project Knowledge Base
_Last updated: 2026-03-14_

## Overview

A Phoenix LiveView web app for browsing food products, their ingredients, and categories.
Users upload a product label photo; Gemini Vision AI reads it and auto-creates the product
with ingredients and categories. Products tagged "Beer" (e.g. Hanoi Beer, Heineken) share
the same category so users can filter by it.

## Tech Stack

- **Elixir 1.19 / OTP 28**
- **Phoenix 1.8.5** with **LiveView 1.1.27**
- **Ecto + PostgreSQL** (postgrex)
- **Tailwind CSS v4 + DaisyUI v5** (via Phoenix asset pipeline)
- **Req 0.5** for HTTP calls to Gemini API
- **Gemini Vision API** (free tier) for image → product/ingredient/category extraction

## Architecture

### Domain — `lib/angivaonguoi/`

| Module | Purpose |
|--------|---------|
| `Catalog` | Main context: all DB operations for products, ingredients, categories |
| `Catalog.Product` | Schema — `name`, `image_url`, `raw_text`; many_to_many ingredients & categories |
| `Catalog.Ingredient` | Schema — `name`; many_to_many products |
| `Catalog.Category` | Schema — `name`, `slug` (auto-generated); many_to_many products |
| `Catalog.ProductIngredient` | Join table schema |
| `Catalog.ProductCategory` | Join table schema |
| `GeminiParser` | Parses raw Gemini API response JSON → `%{name:, ingredients:, categories:}` |
| `ImageProcessor` | Calls Gemini with image binary, falls back across models on 429, saves to DB |

### Key Catalog functions

```elixir
Catalog.list_products()
Catalog.get_product_with_all!(id)          # preloads ingredients + categories
Catalog.ingredient_amounts_for(product)    # returns %{ingredient_id => %ProductIngredient{}}
Catalog.create_product_with_ingredients_and_categories(name, ingredients, categories)
# ingredients can be plain strings OR maps: %{name:, amount_percent:, amount_raw:}
Catalog.add_ingredient_to_product(product, name, amounts \\ %{})
Catalog.add_category_to_product(product, name)
Catalog.search_products_by_ingredient(name, sort: :name | :amount_desc | :amount_asc)
# returns products with :amount_percent and :amount_raw merged in
Catalog.list_products_by_category(category_id)
Catalog.get_or_create_ingredient(name)
Catalog.get_or_create_category(name)        # deduplicates by slug (case-insensitive)
Catalog.get_category_by_slug!(slug)
```

### Web — `lib/angivaonguoi_web/`

| LiveView | Route | Purpose |
|----------|-------|---------|
| `ProductLive.Index` | `GET /products` | Product grid; category filter badges via `?category=<id>` |
| `ProductLive.Show` | `GET /products/:id` | Product detail; ingredient badges link to ingredient page; category badges link to filtered list |
| `IngredientLive.Show` | `GET /ingredients/:id` | Ingredient detail; lists all products containing it |
| `CategoryLive.Show` | `GET /categories/:id` | All products in a category |
| `SearchLive` | `GET /search` | Search products by ingredient name (phx-submit form) |
| `UploadLive` | `GET /upload` | Image upload; `auto_upload: true` + `progress:` callback triggers Gemini on `entry.done?` |

Root `GET /` redirects to `/products`.

## Database Migrations (in order)

```
create_products                    — id, name (unique), image_url, raw_text, timestamps
create_ingredients                 — id, name (unique), timestamps
create_product_ingredients         — product_id, ingredient_id (unique pair), timestamps
add_amount_to_product_ingredients  — adds amount_percent (decimal 7,3) and amount_raw (string)
create_categories                  — id, name (unique), slug (unique), timestamps
create_product_categories          — product_id, category_id (unique pair), timestamps
```

## Key Files

```
lib/angivaonguoi/catalog.ex                        # All business logic
lib/angivaonguoi/gemini_parser.ex                  # Parses Gemini JSON response
lib/angivaonguoi/image_processor.ex                # Gemini API call + fallback
lib/angivaonguoi_web/live/upload_live.ex           # Image upload LiveView
lib/angivaonguoi_web/live/product_live/index.ex    # Product listing + category filter
lib/angivaonguoi_web/live/product_live/show.ex     # Product detail
lib/angivaonguoi_web/live/ingredient_live/show.ex  # Ingredient detail
lib/angivaonguoi_web/live/search_live.ex           # Ingredient search
lib/angivaonguoi_web/components/layouts/root.html.heex  # Navbar
config/config.exs                                  # gemini_api_key from env
config/dev.exs                                     # http: [{0,0,0,0}] — listens on all interfaces
```

## Running the App

```bash
# Prerequisites: PostgreSQL running, Elixir installed
# Required erlang packages: erlang-core, erlang-inets, erlang-ssl, erlang-crypto,
#   erlang-public_key, erlang-parsetools, erlang-syntax_tools, erlang-tools,
#   erlang-runtime_tools, erlang-xmerl

# Set API key (get free key at https://aistudio.google.com/app/apikey)
export GEMINI_API_KEY=your_key_here
# or: source .env  (file exists at project root)

mix deps.get
mix ecto.migrate
mix phx.server
# App runs at http://0.0.0.0:4000
```

## Conventions

- **Red/Green TDD**: write failing tests first, then implement. Test files mirror lib paths under `test/`.
- **Context pattern**: all DB access goes through `Angivaonguoi.Catalog`, never direct Repo calls from LiveViews.
- **Category deduplication**: `get_or_create_category/1` looks up by `slug` (lowercased, hyphenated), so "Beer" and "beer" resolve to the same record.
- **No form submit for uploads**: `auto_upload: true` + `progress: &handle_progress/3` — processing triggers when `entry.done? == true`, not on form submit. This avoids the race where submit fires before bytes arrive.
- **Gemini calls are async**: `Task.start/1` + `send(lv, {:image_processed, result})` pattern in `UploadLive` — keeps LiveView socket responsive.
- **Gemini model fallback**: `ImageProcessor` tries `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-2.0-flash-lite` on 429 rate limit errors.

## Current State (as of last update)

- All features complete and working: upload → AI parse → save → browse → search
- 56 unit tests + 18 Playwright e2e tests, all passing
- Ingredient amounts (% and raw string) stored on `product_ingredients` join table and shown in UI
- Search page has sort dropdown: A-Z, highest % first, lowest % first
- Gemini free tier quota can be exhausted; fallback chain handles it

## Gotchas

- **Arch Linux Erlang is split packages** — need to install individual `erlang-*` packages (`erlang-xmerl`, `erlang-parsetools`, `erlang-syntax_tools`, etc.), NOT the `erlang` meta-package which pulls in webkit2gtk and fails.
- **PostgreSQL on Arch**: must `initdb` manually before first `systemctl start postgresql`. Use `sudo -u postgres initdb -D /var/lib/postgres/data` (no locale flag — default locale works).
- **`consume_uploaded_entries` returns `[]`** if called before upload channel completes. Always use `progress:` callback with `entry.done?` check instead of a form submit handler.
- **Gemini API key env var name**: must be `GEMINI_API_KEY` — the `.env` file originally had `GEMINI_API_TOKEN` (wrong name).
- **Gemini model names**: use exact names from ListModels — `gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-2.0-flash-lite`. No preview suffixes. `gemini-1.5-*` not available on v1beta.
- **`config/dev.exs`** has `http: [ip: {0, 0, 0, 0}]` to allow LAN access. Default Phoenix is `{127, 0, 0, 1}`.
- **Never do Repo queries inside a failed transaction** — after a constraint violation inside `Repo.transaction`, Postgres aborts the entire transaction block (`ERROR 25P02`). Any subsequent `Repo` call in the same transaction will fail with "current transaction is aborted, commands ignored until end of transaction block". Always run fallback/lookup queries (e.g. duplicate detection) **after** the transaction closes, using `Repo.in_transaction?()` to guard or by restructuring so the lookup only happens at the outermost caller after `Repo.transaction` returns.
- **Test the full production call path, not just individual functions** — a unit test for `create_product/1` in isolation won't catch bugs that only appear when it's called inside `Repo.transaction/1` from `create_product_with_ingredients_and_categories/4`. Always add an integration test that exercises the real entry point used in production.
