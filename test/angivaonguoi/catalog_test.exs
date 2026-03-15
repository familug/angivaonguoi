defmodule Angivaonguoi.CatalogTest do
  use Angivaonguoi.DataCase

  alias Angivaonguoi.Catalog
  alias Angivaonguoi.Catalog.{Product, Ingredient}

  describe "products" do
    test "list_products/0 returns all products" do
      {:ok, product} = Catalog.create_product(%{name: "Oreo Cookies"})
      products = Catalog.list_products()
      assert Enum.any?(products, &(&1.id == product.id))
    end

    test "get_product!/1 returns the product with given id" do
      {:ok, product} = Catalog.create_product(%{name: "Oreo Cookies"})
      fetched = Catalog.get_product!(product.id)
      assert fetched.id == product.id
      assert fetched.name == "Oreo Cookies"
    end

    test "get_product_with_ingredients!/1 preloads ingredients" do
      {:ok, product} = Catalog.create_product(%{name: "Oreo"})
      {:ok, _} = Catalog.add_ingredient_to_product(product, "Sugar")
      fetched = Catalog.get_product_with_ingredients!(product.id)
      assert length(fetched.ingredients) == 1
      assert hd(fetched.ingredients).name == "Sugar"
    end

    test "delete_product/1 removes the product" do
      {:ok, product} = Catalog.create_product(%{name: "Delete Me"})
      assert {:ok, _} = Catalog.delete_product(product)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_product!(product.id) end
    end

    test "create_product/1 with valid data creates a product" do
      assert {:ok, %Product{} = product} = Catalog.create_product(%{name: "Lay's Chips"})
      assert product.name == "Lay's Chips"
    end

    test "create_product/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_product(%{name: ""})
    end

    test "create_product/1 persists energy and volume fields" do
      attrs = %{
        name: "Coca-Cola 330ml",
        energy_kcal_per_100: Decimal.new("42.0"),
        energy_unit: "100ml",
        volume_ml: Decimal.new("330")
      }

      assert {:ok, product} = Catalog.create_product(attrs)
      assert Decimal.equal?(product.energy_kcal_per_100, Decimal.new("42.0"))
      assert product.energy_unit == "100ml"
      assert Decimal.equal?(product.volume_ml, Decimal.new("330"))
    end

    test "create_product_with_ingredients_and_categories/4 persists energy and volume extras" do
      extra = %{
        energy_kcal_per_100: Decimal.new("46.0"),
        energy_unit: "100ml",
        volume_ml: Decimal.new("500"),
        barcode: "4890008100309"
      }

      assert {:ok, product} =
               Catalog.create_product_with_ingredients_and_categories(
                 "Pocari Sweat 500ml",
                 ["Water", "Sugar"],
                 ["Sports Drinks"],
                 extra
               )

      fetched = Catalog.get_product!(product.id)
      assert Decimal.equal?(fetched.energy_kcal_per_100, Decimal.new("46.0"))
      assert fetched.energy_unit == "100ml"
      assert Decimal.equal?(fetched.volume_ml, Decimal.new("500"))
      assert fetched.barcode == "4890008100309"
    end

    test "energy and volume fields default to nil" do
      assert {:ok, product} = Catalog.create_product(%{name: "Plain Cracker"})
      assert is_nil(product.energy_kcal_per_100)
      assert is_nil(product.energy_unit)
      assert is_nil(product.volume_ml)
    end

    test "create_product/1 returns duplicate tuple on unique name conflict" do
      assert {:ok, existing} = Catalog.create_product(%{name: "Pringles"})
      assert {:error, {:duplicate, found}} = Catalog.create_product(%{name: "Pringles"})
      assert found.id == existing.id
    end

    test "create_product_with_ingredients/2 creates product with associated ingredients" do
      assert {:ok, product} =
               Catalog.create_product_with_ingredients("Kit Kat", ["Sugar", "Cocoa", "Milk"])

      product = Catalog.get_product_with_ingredients!(product.id)
      ingredient_names = Enum.map(product.ingredients, & &1.name)
      assert "Sugar" in ingredient_names
      assert "Cocoa" in ingredient_names
      assert "Milk" in ingredient_names
    end
  end

  describe "ingredients" do
    test "list_ingredients/0 returns all ingredients" do
      {:ok, ingredient} = Catalog.create_ingredient(%{name: "Sugar"})
      ingredients = Catalog.list_ingredients()
      assert Enum.any?(ingredients, &(&1.id == ingredient.id))
    end

    test "get_ingredient!/1 returns the ingredient with given id" do
      {:ok, ingredient} = Catalog.create_ingredient(%{name: "Salt"})
      fetched = Catalog.get_ingredient!(ingredient.id)
      assert fetched.name == "Salt"
    end

    test "get_ingredient_with_products!/1 preloads products" do
      {:ok, product} = Catalog.create_product(%{name: "Doritos"})
      {:ok, _} = Catalog.add_ingredient_to_product(product, "Salt")
      ingredient = Catalog.get_ingredient_by_name!("Salt")
      fetched = Catalog.get_ingredient_with_products!(ingredient.id)
      assert length(fetched.products) == 1
      assert hd(fetched.products).name == "Doritos"
    end

    test "create_ingredient/1 with valid data creates an ingredient" do
      assert {:ok, %Ingredient{} = ingredient} = Catalog.create_ingredient(%{name: "Wheat"})
      assert ingredient.name == "Wheat"
    end

    test "create_ingredient/1 enforces unique name" do
      assert {:ok, _} = Catalog.create_ingredient(%{name: "Flour"})
      assert {:error, changeset} = Catalog.create_ingredient(%{name: "Flour"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "search_products_by_ingredient/1 returns products containing the ingredient" do
      {:ok, product1} = Catalog.create_product(%{name: "Biscuit A"})
      {:ok, product2} = Catalog.create_product(%{name: "Biscuit B"})
      {:ok, _} = Catalog.create_product(%{name: "Biscuit C"})

      {:ok, _} = Catalog.add_ingredient_to_product(product1, "Gluten")
      {:ok, _} = Catalog.add_ingredient_to_product(product2, "Gluten")

      results = Catalog.search_products_by_ingredient("Gluten")
      result_names = Enum.map(results, & &1.name)
      assert "Biscuit A" in result_names
      assert "Biscuit B" in result_names
      refute "Biscuit C" in result_names
    end

    test "search_products_by_ingredient/1 is case-insensitive" do
      {:ok, product} = Catalog.create_product(%{name: "Cracker"})
      {:ok, _} = Catalog.add_ingredient_to_product(product, "Palm Oil")

      results = Catalog.search_products_by_ingredient("palm oil")
      assert Enum.any?(results, &(&1.name == "Cracker"))
    end

    test "get_or_create_ingredient/1 creates new ingredient if not found" do
      assert {:ok, %Ingredient{name: "Soy Lecithin"}} =
               Catalog.get_or_create_ingredient("Soy Lecithin")
    end

    test "get_or_create_ingredient/1 returns existing ingredient" do
      {:ok, existing} = Catalog.create_ingredient(%{name: "Vanilla"})
      assert {:ok, ingredient} = Catalog.get_or_create_ingredient("Vanilla")
      assert ingredient.id == existing.id
    end

    test "get_or_create_ingredient/1 is case-insensitive — returns same row for sugar/Sugar/SUGAR" do
      {:ok, first} = Catalog.get_or_create_ingredient("Sugar")
      {:ok, second} = Catalog.get_or_create_ingredient("sugar")
      {:ok, third} = Catalog.get_or_create_ingredient("SUGAR")
      assert first.id == second.id
      assert first.id == third.id
    end

    test "ingredient name is trimmed and whitespace collapsed on save" do
      {:ok, ingredient} = Catalog.get_or_create_ingredient("  wheat   flour  ")
      assert ingredient.name == "Wheat flour"
    end

    test "ingredient name first letter is capitalised on save" do
      {:ok, ingredient} = Catalog.get_or_create_ingredient("palm oil")
      assert ingredient.name == "Palm oil"
    end

    test "two products with same ingredient in different casing share the same ingredient row" do
      {:ok, p1} = Catalog.create_product_with_ingredients_and_categories("Product A", ["corn oil"], [])
      {:ok, p2} = Catalog.create_product_with_ingredients_and_categories("Product B", ["Corn Oil"], [])

      p1 = Catalog.get_product_with_ingredients!(p1.id)
      p2 = Catalog.get_product_with_ingredients!(p2.id)

      id1 = hd(p1.ingredients).id
      id2 = hd(p2.ingredients).id
      assert id1 == id2
    end

    test "compare_products shows shared ingredient as common when casing differs" do
      {:ok, a} = Catalog.create_product_with_ingredients_and_categories("Cola A", ["sugar"], [])
      {:ok, b} = Catalog.create_product_with_ingredients_and_categories("Cola B", ["Sugar"], [])
      result = Catalog.compare_products(a, b)
      assert length(result.common) == 1
      assert result.only_a == []
      assert result.only_b == []
    end

    test "create_product returns {:error, {:duplicate, existing}} when name already taken" do
      {:ok, existing} = Catalog.create_product(%{name: "Duplicate Product"})
      result = Catalog.create_product(%{name: "Duplicate Product"})
      assert {:error, {:duplicate, found}} = result
      assert found.id == existing.id
      assert found.slug == existing.slug
    end
  end
end
