defmodule AngivaonguoiWeb.IngredientLiveTest do
  use AngivaonguoiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Angivaonguoi.Catalog

  describe "Show" do
    test "displays ingredient name and products containing it", %{conn: conn} do
      {:ok, _product} =
        Catalog.create_product_with_ingredients("Doritos", ["Salt", "Corn", "Chili"])

      ingredient = Catalog.get_ingredient_by_name!("Salt")

      {:ok, _view, html} = live(conn, ~p"/ingredients/#{ingredient.id}")

      assert html =~ "Salt"
      assert html =~ "Doritos"
    end

    test "links back to product", %{conn: conn} do
      {:ok, _product} =
        Catalog.create_product_with_ingredients("Cheetos", ["Corn Flour", "Cheddar"])

      ingredient = Catalog.get_ingredient_by_name!("Cheddar")

      {:ok, _view, html} = live(conn, ~p"/ingredients/#{ingredient.id}")

      assert html =~ ~r|href="/products/cheetos-id\d+"|
    end
  end

  describe "Search" do
    test "searching by ingredient name returns matching products", %{conn: conn} do
      {:ok, _} = Catalog.create_product_with_ingredients("Product A", ["Sugar", "Vanilla"])
      {:ok, _} = Catalog.create_product_with_ingredients("Product B", ["Sugar", "Cocoa"])
      {:ok, _} = Catalog.create_product_with_ingredients("Product C", ["Honey"])

      {:ok, view, _html} = live(conn, ~p"/search")

      html =
        view
        |> form("form", %{search: %{query: "Sugar"}})
        |> render_submit()

      assert html =~ "Product A"
      assert html =~ "Product B"
      refute html =~ "Product C"
    end
  end
end
