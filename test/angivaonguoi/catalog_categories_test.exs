defmodule Angivaonguoi.CatalogCategoriesTest do
  use Angivaonguoi.DataCase

  alias Angivaonguoi.Catalog
  alias Angivaonguoi.Catalog.Category

  describe "categories" do
    test "list_categories/0 returns all categories ordered by name" do
      {:ok, _} = Catalog.create_category(%{name: "Snacks"})
      {:ok, _} = Catalog.create_category(%{name: "Beer"})

      names = Catalog.list_categories() |> Enum.map(& &1.name)
      assert names == Enum.sort(names)
    end

    test "get_category!/1 returns the category with given id" do
      {:ok, category} = Catalog.create_category(%{name: "Juice"})
      assert Catalog.get_category!(category.id).name == "Juice"
    end

    test "create_category/1 with valid data creates category and auto-generates slug" do
      assert {:ok, %Category{name: "Soft Drinks", slug: "soft-drinks"}} =
               Catalog.create_category(%{name: "Soft Drinks"})
    end

    test "create_category/1 enforces unique name" do
      assert {:ok, _} = Catalog.create_category(%{name: "Beer"})
      assert {:error, changeset} = Catalog.create_category(%{name: "Beer"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "get_or_create_category/1 creates new category if not found" do
      assert {:ok, %Category{name: "Chips"}} = Catalog.get_or_create_category("Chips")
    end

    test "get_or_create_category/1 returns existing category" do
      {:ok, existing} = Catalog.create_category(%{name: "Water"})
      assert {:ok, category} = Catalog.get_or_create_category("Water")
      assert category.id == existing.id
    end

    test "get_or_create_category/1 is case-insensitive on lookup" do
      {:ok, existing} = Catalog.create_category(%{name: "beer"})
      assert {:ok, category} = Catalog.get_or_create_category("Beer")
      assert category.id == existing.id
    end

    test "add_category_to_product/2 associates a category with a product" do
      {:ok, product} = Catalog.create_product(%{name: "Hanoi Beer"})
      assert {:ok, _} = Catalog.add_category_to_product(product, "Beer")

      product = Catalog.get_product_with_ingredients!(product.id)
      product = Angivaonguoi.Repo.preload(product, :categories)
      assert Enum.any?(product.categories, &(&1.name == "Beer"))
    end

    test "create_product_with_ingredients_and_categories/3 creates everything at once" do
      assert {:ok, product} =
               Catalog.create_product_with_ingredients_and_categories(
                 "Heineken",
                 ["Water", "Barley Malt", "Hops"],
                 ["Beer", "Alcohol"]
               )

      product =
        product.id
        |> Catalog.get_product_with_ingredients!()
        |> Angivaonguoi.Repo.preload(:categories)

      ingredient_names = Enum.map(product.ingredients, & &1.name)
      category_names = Enum.map(product.categories, & &1.name)

      assert "Water" in ingredient_names
      assert "Barley Malt" in ingredient_names
      assert "Beer" in category_names
      assert "Alcohol" in category_names
    end

    test "list_products_by_category/1 returns products in a category" do
      {:ok, hanoi} =
        Catalog.create_product_with_ingredients_and_categories("Hanoi Beer", [], ["Beer"])

      {:ok, heineken} =
        Catalog.create_product_with_ingredients_and_categories("Heineken", [], ["Beer"])

      {:ok, _} =
        Catalog.create_product_with_ingredients_and_categories("Coca-Cola", [], ["Soft Drinks"])

      Catalog.verify_product(hanoi)
      Catalog.verify_product(heineken)

      category = Catalog.get_category_by_slug!("beer")
      results = Catalog.list_products_by_category(category.id)
      names = Enum.map(results, & &1.name)

      assert "Hanoi Beer" in names
      assert "Heineken" in names
      refute "Coca-Cola" in names
    end

    test "get_product_with_all/1 preloads both ingredients and categories" do
      {:ok, product} =
        Catalog.create_product_with_ingredients_and_categories(
          "Tiger Beer",
          ["Water", "Malt"],
          ["Beer"]
        )

      full = Catalog.get_product_with_all!(product.id)
      assert length(full.ingredients) == 2
      assert length(full.categories) == 1
      assert hd(full.categories).name == "Beer"
    end
  end
end
