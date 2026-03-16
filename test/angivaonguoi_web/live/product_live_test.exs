defmodule AngivaonguoiWeb.ProductLiveTest do
  use AngivaonguoiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Angivaonguoi.{Catalog, Accounts}

  describe "Index" do
    test "lists all products", %{conn: conn} do
      {:ok, p1} = Catalog.create_product(%{name: "Oreo Cookies"})
      {:ok, p2} = Catalog.create_product(%{name: "Lay's Chips"})
      Catalog.verify_product(p1)
      Catalog.verify_product(p2)

      {:ok, _view, html} = live(conn, ~p"/products")

      assert html =~ "Oreo Cookies"
      assert html =~ "Lay&#39;s Chips"
    end

    test "renders upload form link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/products")
      assert html =~ "Upload"
    end

    test "non-admin sees only verified products", %{conn: conn} do
      {:ok, verified} = Catalog.create_product(%{name: "Verified Product"})
      {:ok, _unverified} = Catalog.create_product(%{name: "Unverified Product"})
      Catalog.verify_product(verified)

      {:ok, _view, html} = live(conn, ~p"/products")

      assert html =~ "Verified Product"
      refute html =~ "Unverified Product"
    end

    test "admin sees all products including unverified", %{conn: conn} do
      {:ok, admin} = Accounts.register_user(%{email: "admin@test.com", username: "admin", password: "pass123"})
      conn = init_test_session(conn, %{"user_id" => admin.id})

      {:ok, verified} = Catalog.create_product(%{name: "Verified Product"})
      {:ok, _unverified} = Catalog.create_product(%{name: "Unverified Product"})
      Catalog.verify_product(verified)

      {:ok, _view, html} = live(conn, ~p"/products")

      assert html =~ "Verified Product"
      assert html =~ "Unverified Product"
      assert html =~ "Unverified"
    end

    test "admin sees uploader username", %{conn: conn} do
      {:ok, admin} = Accounts.register_user(%{email: "admin@test.com", username: "admin", password: "pass123"})
      {:ok, uploader} = Accounts.register_user(%{email: "uploader@test.com", username: "uploader", password: "pass123"})
      conn = init_test_session(conn, %{"user_id" => admin.id})

      {:ok, _product} = Catalog.create_product_with_ingredients_and_categories("My Product", ["Salt"], [], %{uploaded_by_id: uploader.id})

      {:ok, _view, html} = live(conn, ~p"/products")

      assert html =~ "My Product"
      assert html =~ "uploader"
    end

    test "admin can verify a product", %{conn: conn} do
      {:ok, admin} = Accounts.register_user(%{email: "admin@test.com", username: "admin", password: "pass123"})
      conn = init_test_session(conn, %{"user_id" => admin.id})

      {:ok, product} = Catalog.create_product(%{name: "To Verify"})
      refute product.verified

      {:ok, view, _html} = live(conn, ~p"/products")
      render_click(view, "verify_product", %{"id" => to_string(product.id)})

      updated = Catalog.get_product!(product.id)
      assert updated.verified
    end
  end

  describe "Index with category filter" do
    test "filters products by category", %{conn: conn} do
      {:ok, hanoi} = Catalog.create_product_with_ingredients_and_categories("Hanoi Beer", [], ["Beer"])
      {:ok, heineken} = Catalog.create_product_with_ingredients_and_categories("Heineken", [], ["Beer"])
      {:ok, _} = Catalog.create_product_with_ingredients_and_categories("Coca-Cola", [], ["Soft Drinks"])
      Catalog.verify_product(hanoi)
      Catalog.verify_product(heineken)

      category = Catalog.get_category_by_slug!("beer")

      {:ok, _view, html} = live(conn, ~p"/products?category=#{category.id}")

      assert html =~ "Hanoi Beer"
      assert html =~ "Heineken"
      refute html =~ "Coca-Cola"
    end

    test "shows category badges on index page", %{conn: conn} do
      {:ok, sprite} = Catalog.create_product_with_ingredients_and_categories("Sprite", [], ["Soft Drinks"])
      Catalog.verify_product(sprite)

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

      {:ok, _view, html} = live(conn, ~p"/products/#{product.slug}")

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

      {:ok, _view, html} = live(conn, ~p"/products/#{product.slug}")

      assert html =~ "Salt"
      assert html =~ ~r|href="/ingredients/[0-9]+"|
    end

    test "admin sees gemini model badge when product has model info", %{conn: conn} do
      {:ok, admin} =
        Accounts.register_user(%{email: "admin@test.com", username: "admin", password: "pass123"})

      conn = init_test_session(conn, %{"user_id" => admin.id})

      {:ok, product} =
        Catalog.create_product(%{name: "Model Product", gemini_model: "gemini-2.5-flash"})

      {:ok, _view, html} = live(conn, ~p"/products/#{product.slug}")
      assert html =~ "gemini-2.5-flash"
    end

    test "non-admin does not see gemini model badge", %{conn: conn} do
      Accounts.register_user(%{email: "admin@test.com", username: "admin", password: "pass123"})

      {:ok, user} =
        Accounts.register_user(%{email: "user@test.com", username: "user2", password: "pass123"})

      conn = init_test_session(conn, %{"user_id" => user.id})

      {:ok, product} =
        Catalog.create_product(%{name: "Model Product 2", gemini_model: "gemini-2.5-flash"})

      {:ok, _view, html} = live(conn, ~p"/products/#{product.slug}")
      refute html =~ "gemini-2.5-flash"
    end

    test "admin sees delete button", %{conn: conn} do
      {:ok, admin} =
        Accounts.register_user(%{email: "admin@test.com", username: "admin", password: "pass123"})

      conn = init_test_session(conn, %{"user_id" => admin.id})

      {:ok, product} = Catalog.create_product(%{name: "Delete Me"})
      {:ok, _view, html} = live(conn, ~p"/products/#{product.slug}")

      assert html =~ "Delete Product"
    end

    test "non-admin does not see delete button", %{conn: conn} do
      # register first user as admin, then second as non-admin
      Accounts.register_user(%{email: "admin@test.com", username: "admin", password: "pass123"})

      {:ok, user} =
        Accounts.register_user(%{email: "user@test.com", username: "reguser", password: "pass123"})

      conn = init_test_session(conn, %{"user_id" => user.id})

      {:ok, product} = Catalog.create_product(%{name: "No Delete"})
      {:ok, _view, html} = live(conn, ~p"/products/#{product.slug}")

      refute html =~ "Delete Product"
    end

    test "shows energy per 100ml when product has energy info" do
      {:ok, product} =
        Catalog.create_product(%{
          name: "Pocari Sweat",
          energy_kcal_per_100: Decimal.new("25.0"),
          energy_unit: "100ml",
          volume_ml: nil
        })

      {:ok, _view, html} = live(build_conn(), ~p"/products/#{product.slug}")

      assert html =~ "25"
      assert html =~ "kcal"
      assert html =~ "100ml"
    end

    test "shows total energy when both energy and volume are present" do
      {:ok, product} =
        Catalog.create_product(%{
          name: "Coca-Cola 330ml",
          energy_kcal_per_100: Decimal.new("42.0"),
          energy_unit: "100ml",
          volume_ml: Decimal.new("330")
        })

      {:ok, _view, html} = live(build_conn(), ~p"/products/#{product.slug}")

      # 42.0 * 330 / 100 = 138.6
      assert html =~ "138.6"
      assert html =~ "330ml"
    end

    test "does not show energy section when energy info is absent" do
      {:ok, product} = Catalog.create_product(%{name: "Plain Cracker"})

      {:ok, _view, html} = live(build_conn(), ~p"/products/#{product.slug}")

      refute html =~ "kcal"
    end

    test "shows energy but not total energy when volume is absent" do
      {:ok, product} =
        Catalog.create_product(%{
          name: "Energy Bar",
          energy_kcal_per_100: Decimal.new("380.0"),
          energy_unit: "100g",
          volume_ml: nil
        })

      {:ok, _view, html} = live(build_conn(), ~p"/products/#{product.slug}")

      assert html =~ "380"
      assert html =~ "100g"
      refute html =~ "per nil"
      refute html =~ "package"
    end

    test "admin can delete a product", %{conn: conn} do
      {:ok, admin} =
        Accounts.register_user(%{email: "admin@test.com", username: "admin", password: "pass123"})

      conn = init_test_session(conn, %{"user_id" => admin.id})

      {:ok, product} = Catalog.create_product(%{name: "Bye Product"})
      {:ok, view, _html} = live(conn, ~p"/products/#{product.slug}")

      render_click(view, "delete_product")

      assert_redirect(view, ~p"/products")
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_product!(product.id) end
    end
  end
end
