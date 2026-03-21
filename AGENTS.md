# AGENTS — Project Knowledge Base
_Last updated: 2026-03-14_

## Overview

A Phoenix LiveView web app for browsing food products, their ingredients, and categories.
Users upload a product label photo; Gemini Vision AI reads it and auto-creates the product
with ingredients and categories. Products tagged "Beer" (e.g. Hanoi Beer, Heineken) share
the same category so users can filter by it. Only **verified** products appear in the public
product list; admins see all products and can verify/unverify.

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
| `Catalog.Product` | Schema — `name`, `slug`, `image_url`, `raw_text`, `verified`, `uploaded_by_id`; many_to_many ingredients & categories |
| `Catalog.Ingredient` | Schema — `name`; many_to_many products |
| `Catalog.Category` | Schema — `name`, `slug` (auto-generated); many_to_many products |
| `Catalog.ProductIngredient` | Join table schema |
| `Catalog.ProductCategory` | Join table schema |
| `GeminiParser` | Parses raw Gemini API response JSON → `%{name:, ingredients:, categories:}` |
| `ImageProcessor` | Calls Gemini with image binary, falls back across models on 429, saves to DB |

### Key Catalog functions

```elixir
Catalog.list_products()                              # Only verified (public)
Catalog.list_all_products()                          # All products, verified first (admin)
Catalog.list_products_by_category(category_id)       # Only verified in category
Catalog.list_all_products_by_category(category_id)   # All in category, verified first (admin)
Catalog.get_product_with_all!(id)                    # preloads ingredients + categories
Catalog.ingredient_amounts_for(product)              # returns %{ingredient_id => %ProductIngredient{}}
Catalog.create_product_with_ingredients_and_categories(name, ingredients, categories)
Catalog.verify_product(product)                      # Sets verified = true
Catalog.unverify_product(product)                    # Sets verified = false
Catalog.add_ingredient_to_product(product, name, amounts \\ %{})
Catalog.add_category_to_product(product, name)
Catalog.search_products_by_ingredient(name, sort: :name | :amount_desc | :amount_asc)
Catalog.get_or_create_ingredient(name)
Catalog.get_or_create_category(name)
Catalog.get_category_by_slug!(slug)
```

### Web — `lib/angivaonguoi_web/`

| LiveView | Route | Purpose |
|----------|-------|---------|
| `ProductLive.Index` | `GET /products` | Product grid; category filter; admin sees all + Verify/Unverify + uploader |
| `ProductLive.Show` | `GET /products/:slug` | Product detail; ingredient/category badges |
| `IngredientLive.Show` | `GET /ingredients/:id` | Ingredient detail; lists all products containing it |
| `CategoryLive.Show` | `GET /categories/:id` | All verified products in a category |
| `SearchLive` | `GET /search` | Search products by ingredient name |
| `UploadLive` | `GET /upload` | Image upload; passes `uploaded_by_id`; `auto_upload: true` + `progress:` |
| `CompareLive` | `GET /compare` | Compare two products; dropdown uses `list_all_products` for admin, `list_products` for others |

Root `GET /` redirects to `/products`.

### Compare page specifics

- Ingredient badges: `whitespace-normal h-auto text-left` for long names (no layout break)
- Common-ingredients table: column headers use 🅰️ and 🅱️ instead of product names
- Labels: "🅰️ Product A" and "🅱️ Product B"

## Database Migrations (in order)

```
create_products                    — id, name (unique), image_url, raw_text, timestamps
create_ingredients                 — id, name (unique), timestamps
create_product_ingredients          — product_id, ingredient_id (unique pair), timestamps
add_amount_to_product_ingredients   — amount_percent, amount_raw
create_categories                  — id, name (unique), slug (unique), timestamps
create_product_categories          — product_id, category_id (unique pair), timestamps
add_verified_and_uploaded_by_to_products — verified (boolean, default false), uploaded_by_id (FK users)
verify_existing_products           — sets existing products verified = true
```

## Key Files

```
lib/angivaonguoi/catalog.ex                        # All business logic, list/list_all, verify/unverify
lib/angivaonguoi/catalog/product.ex                # Schema: verified, uploaded_by
lib/angivaonguoi/gemini_parser.ex                  # Parses Gemini JSON response
lib/angivaonguoi/image_processor.ex                # Gemini API call + fallback; passes uploaded_by_id
lib/angivaonguoi_web/live/upload_live.ex           # Image upload; passes current_user.id as uploaded_by_id
lib/angivaonguoi_web/live/product_live/index.ex    # Product list; admin vs public; verify buttons
lib/angivaonguoi_web/live/product_live/show.ex    # Product detail
lib/angivaonguoi_web/live/compare_live.ex         # Compare two products; emoji headers
lib/angivaonguoi_web/live/ingredient_live/show.ex  # Ingredient detail
lib/angivaonguoi_web/live/search_live.ex          # Ingredient search
priv/repo/seeds.exs                                # E2E seeds: admin, verified/unverified products
config/config.exs                                  # gemini_api_key from env
```

## Running the App

```bash
# Prerequisites: PostgreSQL running, Elixir installed
export GEMINI_API_KEY=your_key_here   # or: source .env

mix deps.get
mix ecto.migrate
mix phx.server
# App runs at http://0.0.0.0:4000
```

### E2E tests (Playwright)

```bash
mix run priv/repo/seeds.exs   # Seeds admin@e2e.test / e2eadmin123, verified + unverified products
cd e2e && npx playwright test
```

## Conventions

- **Red/Green TDD**: write failing tests first, then implement. Test files mirror lib paths under `test/`.
- **Context pattern**: all DB access goes through `Angivaonguoi.Catalog`, never direct Repo calls from LiveViews.
- **Verified products**: `list_products` / `list_products_by_category` return only verified; `list_all_*` for admin.
- **Category deduplication**: `get_or_create_category/1` looks up by `slug` (lowercased, hyphenated).
- **No form submit for uploads**: `auto_upload: true` + `progress: &handle_progress/3` — processing when `entry.done? == true`.
- **Gemini calls are async**: `Task.start/1` + `send(lv, {:image_processed, result})` in `UploadLive`.
- **Gemini model fallback**: `ImageProcessor` tries `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-2.0-flash-lite` on 429.

## Current State

- All features complete: upload → AI parse → save → browse → search → compare
- Verified products: only verified show publicly; admin sees all, can verify/unverify, sees uploader
- Compare page: badge CSS fixed, 🅰️/🅱️ column headers
- Unit tests + LiveView tests + Playwright e2e tests, all passing

## Gotchas

- **Arch Linux Erlang** — install individual `erlang-*` packages, NOT the `erlang` meta-package (pulls webkit2gtk).
- **PostgreSQL on Arch**: `sudo -u postgres initdb -D /var/lib/postgres/data` before first `systemctl start postgresql`.
- **`consume_uploaded_entries` returns `[]`** if called before upload channel completes. Use `progress:` with `entry.done?` check.
- **Gemini API key**: env var must be `GEMINI_API_KEY` (not `GEMINI_API_TOKEN`).
- **Gemini model names**: exact names — `gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-2.0-flash-lite`.
- **`config/dev.exs`**: `http: [ip: {0, 0, 0, 0}]` for LAN access.
- **Never do Repo queries inside a failed transaction** — after a constraint violation, Postgres aborts the block (`ERROR 25P02`). Run fallback/lookup **after** the transaction closes; use `Repo.in_transaction?()` to guard. `create_product` does not call `resolve_duplicate` when inside a transaction; the outer `create_product_with_ingredients_and_categories` does it after the transaction returns.
- **E2E login form**: use `input[name='email']` and `input[name='password']` (not `user[email]`).
- **E2E admin**: seeds set `is_admin: true` via `Repo.update_all` for the e2e admin user.
- **E2E test isolation**: admin verify test must unverify at the end to restore state; otherwise "unverified hidden" test fails on rerun.
