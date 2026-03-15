// @ts-check
const { test, expect } = require("@playwright/test");

// Real data from the first uploaded image
const PRODUCT = {
  id: 1,
  name: "Hongki Traditional Original Roasted Seasoned Laver",
  ingredient: "Seaweed (Korea) (61%)",
  ingredientId: 1,
  category: "Snacks",
  categoryId: 1,
};

const PRODUCT2 = {
  // partial name — matches both "Hongki" and "HONGKI" capitalisation variants
  nameFragment: "Olive Oil Roasted Seasoned Seaweed",
};

// Wait for LiveView to connect and render
async function goto(page, url) {
  await page.goto(url);
  await page.waitForLoadState("networkidle");
}

// ---------------------------------------------------------------------------
// Product listing
// ---------------------------------------------------------------------------

test.describe("Product listing page", () => {
  test("redirects / to /products", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/products/);
  });

  test("shows uploaded product on listing page", async ({ page }) => {
    await goto(page, "/products");
    await expect(page.getByText(PRODUCT.name)).toBeVisible();
  });

  test("shows category filter badges", async ({ page }) => {
    await goto(page, "/products");
    await expect(page.getByRole("link", { name: "Snacks", exact: true })).toBeVisible();
    await expect(page.getByRole("link", { name: "Seaweed", exact: true })).toBeVisible();
  });

  test("filtering by Snacks category shows both products", async ({ page }) => {
    await goto(page, "/products");
    await page.getByRole("link", { name: "Snacks", exact: true }).click();
    await page.waitForURL(/category=/);
    await expect(page.getByText(PRODUCT.name)).toBeVisible();
    await expect(page.getByText(PRODUCT2.nameFragment).first()).toBeVisible();
  });

  test("has Upload Product link in navbar", async ({ page }) => {
    await goto(page, "/products");
    await expect(
      page.getByRole("navigation").getByRole("link", { name: "Upload Product" })
    ).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Product detail
// ---------------------------------------------------------------------------

test.describe("Product detail page", () => {
  test("shows product name", async ({ page }) => {
    await goto(page, `/products/${PRODUCT.id}`);
    await expect(page.getByRole("heading", { name: PRODUCT.name })).toBeVisible();
  });

  test("shows ingredient as a clickable badge", async ({ page }) => {
    await goto(page, `/products/${PRODUCT.id}`);
    await expect(page.getByRole("link", { name: PRODUCT.ingredient })).toBeVisible();
  });

  test("shows category badge linking to filtered product list", async ({ page }) => {
    await goto(page, `/products/${PRODUCT.id}`);
    const badge = page.getByRole("link", { name: PRODUCT.category, exact: true });
    await expect(badge).toBeVisible();
    await badge.click();
    await page.waitForURL(/\/products\?category=/);
    await expect(page.getByText(PRODUCT.name)).toBeVisible();
  });

  test("clicking ingredient navigates to ingredient page", async ({ page }) => {
    await goto(page, `/products/${PRODUCT.id}`);
    await page.getByRole("link", { name: PRODUCT.ingredient }).click();
    await page.waitForURL(`/ingredients/${PRODUCT.ingredientId}`);
    await expect(page.getByText(PRODUCT.ingredient)).toBeVisible();
  });

  test("back link returns to product list", async ({ page }) => {
    await goto(page, `/products/${PRODUCT.id}`);
    await page.getByRole("link", { name: /back to products/i }).click();
    await page.waitForURL(/\/products$/);
    await expect(page.getByText(PRODUCT.name)).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Ingredient detail
// ---------------------------------------------------------------------------

test.describe("Ingredient detail page", () => {
  test("shows ingredient name", async ({ page }) => {
    await goto(page, `/ingredients/${PRODUCT.ingredientId}`);
    await expect(page.getByText(PRODUCT.ingredient)).toBeVisible();
  });

  test("lists the product that contains the ingredient", async ({ page }) => {
    await goto(page, `/ingredients/${PRODUCT.ingredientId}`);
    await expect(page.getByText(PRODUCT.name)).toBeVisible();
  });

  test("clicking product link navigates to product detail", async ({ page }) => {
    await goto(page, `/ingredients/${PRODUCT.ingredientId}`);
    await page.getByRole("link", { name: PRODUCT.name }).click();
    await page.waitForURL(`/products/${PRODUCT.id}`);
    await expect(page.getByRole("heading", { name: PRODUCT.name })).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Ingredient search
// ---------------------------------------------------------------------------

test.describe("Search by ingredient", () => {
  test("searching an ingredient returns matching products", async ({ page }) => {
    await goto(page, "/search");
    await page.fill("input[name='search[query]']", PRODUCT.ingredient);
    await page.keyboard.press("Enter");
    await expect(page.getByText(PRODUCT.name)).toBeVisible();
  });

  test("searching unknown ingredient shows no results message", async ({ page }) => {
    await goto(page, "/search");
    await page.fill("input[name='search[query]']", "xyzunknowningredient999");
    await page.keyboard.press("Enter");
    await expect(page.getByText(/no products found/i)).toBeVisible();
  });

  test("search is reachable from navbar", async ({ page }) => {
    await goto(page, "/products");
    await page.getByRole("navigation").getByRole("link", { name: /search by ingredient/i }).click();
    await page.waitForURL(/\/search/);
    await expect(page.locator("input[name='search[query]']")).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Energy / nutrition display
// ---------------------------------------------------------------------------

// Product seeded via: mix run -e '...' with energy_kcal_per_100=42, volume_ml=330
const ENERGY_PRODUCT = {
  id: 7,
  name: "Coca-Cola 330ml (test)",
  energyPer100: "42",
  totalEnergy: "138.6",
  volumeMl: "330",
  unit: "100ml",
};

test.describe("Energy display on product detail page", () => {
  test("shows energy per 100ml stat card", async ({ page }) => {
    await goto(page, `/products/${ENERGY_PRODUCT.id}`);
    await expect(page.getByText(ENERGY_PRODUCT.energyPer100)).toBeVisible();
    await expect(page.getByText(ENERGY_PRODUCT.unit)).toBeVisible();
  });

  test("shows total energy calculated from volume", async ({ page }) => {
    await goto(page, `/products/${ENERGY_PRODUCT.id}`);
    // 42 kcal/100ml × 330 ml = 138.6 kcal
    await expect(page.getByText(ENERGY_PRODUCT.totalEnergy)).toBeVisible();
    await expect(page.getByText(`${ENERGY_PRODUCT.volumeMl}ml`).first()).toBeVisible();
  });

  test("energy labels include 'kcal' unit", async ({ page }) => {
    await goto(page, `/products/${ENERGY_PRODUCT.id}`);
    const kcalLabels = page.getByText("kcal", { exact: false });
    await expect(kcalLabels.first()).toBeVisible();
  });

  test("products without energy data do not show energy section", async ({ page }) => {
    // PRODUCT (id=1) was uploaded before energy feature — has no energy data
    await goto(page, `/products/${PRODUCT.id}`);
    await expect(page.getByText("kcal", { exact: false })).not.toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Upload page
// ---------------------------------------------------------------------------

test.describe("Upload page", () => {
  test("renders file input and title", async ({ page }) => {
    await goto(page, "/upload");
    await expect(page.getByText(/upload product image/i)).toBeVisible();
    await expect(page.locator("input[type=file]")).toBeAttached();
  });

  test("is reachable from navbar Upload Product button", async ({ page }) => {
    await goto(page, "/products");
    await page.getByRole("navigation").getByRole("link", { name: "Upload Product" }).click();
    await page.waitForURL(/\/upload/);
    await expect(page.getByText(/upload product image/i)).toBeVisible();
  });
});
