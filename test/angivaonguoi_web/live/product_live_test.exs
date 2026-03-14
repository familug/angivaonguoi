defmodule AngivaonguoiWeb.ProductLiveTest do
  use AngivaonguoiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Angivaonguoi.Catalog

  describe "Index" do
    test "lists all products", %{conn: conn} do
      {:ok, _} = Catalog.create_product(%{name: "Oreo Cookies"})
      {:ok, _} = Catalog.create_product(%{name: "Lay's Chips"})

      {:ok, _view, html} = live(conn, ~p"/products")

      assert html =~ "Oreo Cookies"
      assert html =~ "Lay&#39;s Chips"
    end

    test "renders upload form link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/products")
      assert html =~ "Upload Product"
    end
  end

  describe "Index with category filter" do
    test "filters products by category", %{conn: conn} do
      {:ok, _} =
        Catalog.create_product_with_ingredients_and_categories("Hanoi Beer", [], ["Beer"])

      {:ok, _} =
        Catalog.create_product_with_ingredients_and_categories("Heineken", [], ["Beer"])

      {:ok, _} =
        Catalog.create_product_with_ingredients_and_categories("Coca-Cola", [], ["Soft Drinks"])

      category = Catalog.get_category_by_slug!("beer")

      {:ok, _view, html} = live(conn, ~p"/products?category=#{category.id}")

      assert html =~ "Hanoi Beer"
      assert html =~ "Heineken"
      refute html =~ "Coca-Cola"
    end

    test "shows category badges on index page", %{conn: conn} do
      {:ok, _} =
        Catalog.create_product_with_ingredients_and_categories("Sprite", [], ["Soft Drinks"])

      {:ok, _view, html} = live(conn, ~p"/products")
      assert html =~ "Soft Drinks"
    end
  end

  describe "Show" do
    test "displays product name, ingredients, and categories", %{conn: conn} do
      {:ok, product} =
        Catalog.create_product_with_ingredients_and_categories(
          "Kit Kat",
          ["Sugar", "Cocoa Butter", "Milk"],
          ["Chocolate", "Snacks"]
        )

      {:ok, _view, html} = live(conn, ~p"/products/#{product.id}")

      assert html =~ "Kit Kat"
      assert html =~ "Sugar"
      assert html =~ "Cocoa Butter"
      assert html =~ "Milk"
      assert html =~ "Chocolate"
      assert html =~ "Snacks"
    end

    test "each ingredient is a clickable link", %{conn: conn} do
      {:ok, product} =
        Catalog.create_product_with_ingredients_and_categories(
          "Pringles",
          ["Potato Starch", "Salt"],
          ["Chips"]
        )

      {:ok, _view, html} = live(conn, ~p"/products/#{product.id}")

      assert html =~ "Salt"
      assert html =~ ~r|href="/ingredients/[0-9]+"|
    end
  end
end
