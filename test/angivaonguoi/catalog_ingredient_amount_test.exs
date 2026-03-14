defmodule Angivaonguoi.CatalogIngredientAmountTest do
  use Angivaonguoi.DataCase

  alias Angivaonguoi.Catalog
  alias Angivaonguoi.Repo
  alias Angivaonguoi.Catalog.ProductIngredient

  describe "ingredient amounts on product_ingredients" do
    test "add_ingredient_to_product/4 stores amount_percent and amount_raw" do
      {:ok, product} = Catalog.create_product(%{name: "Seaweed Snack"})

      {:ok, pi} =
        Catalog.add_ingredient_to_product(product, "Seaweed", %{
          amount_percent: Decimal.new("61.0"),
          amount_raw: "61%"
        })

      assert Decimal.equal?(pi.amount_percent, Decimal.new("61.0"))
      assert pi.amount_raw == "61%"
    end

    test "add_ingredient_to_product/4 works without amount (defaults to nil)" do
      {:ok, product} = Catalog.create_product(%{name: "Mystery Snack"})
      {:ok, pi} = Catalog.add_ingredient_to_product(product, "Salt", %{})
      assert is_nil(pi.amount_percent)
      assert is_nil(pi.amount_raw)
    end

    test "create_product_with_ingredients_and_categories/3 stores amounts from ingredient maps" do
      ingredients = [
        %{name: "Seaweed", amount_percent: Decimal.new("61.0"), amount_raw: "61%"},
        %{name: "Corn Oil", amount_percent: Decimal.new("20.0"), amount_raw: "20%"},
        %{name: "Salt", amount_percent: nil, amount_raw: nil}
      ]

      {:ok, product} =
        Catalog.create_product_with_ingredients_and_categories(
          "Test Seaweed Pack",
          ingredients,
          ["Snacks"]
        )

      product = Catalog.get_product_with_all!(product.id)

      seaweed_pi =
        Repo.get_by!(ProductIngredient,
          product_id: product.id,
          ingredient_id: ingredient_id_for(product, "Seaweed")
        )

      assert Decimal.equal?(seaweed_pi.amount_percent, Decimal.new("61.0"))
      assert seaweed_pi.amount_raw == "61%"
    end

    test "search_products_by_ingredient/2 sorts by amount_percent descending" do
      ingredients_a = [%{name: "Chilli", amount_percent: Decimal.new("30.0"), amount_raw: "30%"}]
      ingredients_b = [%{name: "Chilli", amount_percent: Decimal.new("60.0"), amount_raw: "60%"}]
      ingredients_c = [%{name: "Chilli", amount_percent: Decimal.new("10.0"), amount_raw: "10%"}]

      {:ok, _} = Catalog.create_product_with_ingredients_and_categories("Sauce A", ingredients_a, [])
      {:ok, _} = Catalog.create_product_with_ingredients_and_categories("Sauce B", ingredients_b, [])
      {:ok, _} = Catalog.create_product_with_ingredients_and_categories("Sauce C", ingredients_c, [])

      results = Catalog.search_products_by_ingredient("Chilli", sort: :amount_desc)
      names = Enum.map(results, & &1.name)
      assert names == ["Sauce B", "Sauce A", "Sauce C"]
    end

    test "search_products_by_ingredient/2 sorts by amount_percent ascending" do
      ingredients_a = [%{name: "Chilli Pepper", amount_percent: Decimal.new("5.0"), amount_raw: "5%"}]
      ingredients_b = [%{name: "Chilli Pepper", amount_percent: Decimal.new("80.0"), amount_raw: "80%"}]

      {:ok, _} = Catalog.create_product_with_ingredients_and_categories("Hot Sauce A", ingredients_a, [])
      {:ok, _} = Catalog.create_product_with_ingredients_and_categories("Hot Sauce B", ingredients_b, [])

      results = Catalog.search_products_by_ingredient("Chilli Pepper", sort: :amount_asc)
      names = Enum.map(results, & &1.name)
      assert names == ["Hot Sauce A", "Hot Sauce B"]
    end

    test "get_product_with_all!/1 includes amount info on ingredients via join" do
      ingredients = [
        %{name: "Olive Oil", amount_percent: Decimal.new("9.0"), amount_raw: "9%"}
      ]

      {:ok, product} =
        Catalog.create_product_with_ingredients_and_categories("Olive Snack", ingredients, [])

      full = Catalog.get_product_with_all!(product.id)
      # ingredients are preloaded; amount lives on the join (product_ingredient)
      pi = Repo.get_by!(ProductIngredient, product_id: full.id)
      assert Decimal.equal?(pi.amount_percent, Decimal.new("9.0"))
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp ingredient_id_for(product, name) do
    product.ingredients
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:id)
  end
end
