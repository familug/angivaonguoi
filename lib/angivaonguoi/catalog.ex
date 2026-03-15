defmodule Angivaonguoi.Catalog do
  import Ecto.Query, warn: false

  alias Angivaonguoi.Repo
  alias Angivaonguoi.Catalog.{Product, Ingredient, ProductIngredient, Category, ProductCategory}

  # ---------------------------------------------------------------------------
  # Products
  # ---------------------------------------------------------------------------

  def list_products do
    Repo.all(from p in Product, order_by: [desc: p.id])
  end

  def get_product!(id), do: Repo.get!(Product, id)

  def get_product_by_slug!(slug), do: Repo.get_by!(Product, slug: slug)

  def get_product_with_ingredients!(id) do
    Product
    |> Repo.get!(id)
    |> Repo.preload(:ingredients)
  end

  @doc """
  Preloads ingredients and categories. Ingredients are returned with their
  join row (amount_percent, amount_raw) attached as a virtual via a separate
  query; callers can get amounts from `Catalog.ingredient_amounts_for/1`.
  """
  def get_product_with_all!(id) do
    Product
    |> Repo.get!(id)
    |> Repo.preload([:ingredients, :categories])
  end

  def create_product(attrs) do
    tmp_slug = "tmp-#{System.unique_integer([:positive, :monotonic])}"

    result =
      with {:ok, product} <-
             %Product{}
             |> Product.changeset(Map.put(attrs, :slug, tmp_slug))
             |> Repo.insert() do
        slug = build_product_slug(product)

        product
        |> Product.changeset(%{slug: slug})
        |> Repo.update()
      end

    # resolve_duplicate runs a SELECT — must be outside any open transaction.
    # When create_product is called directly (no surrounding transaction), this
    # is safe. When called from within create_product_with_ingredients_and_categories,
    # we deliberately do NOT call resolve_duplicate here; the outer function does
    # it after the transaction closes.
    case Repo.in_transaction?() do
      false -> resolve_duplicate(result, attrs)
      true -> result
    end
  end

  defp resolve_duplicate({:error, %Ecto.Changeset{} = cs}, attrs) do
    if Keyword.has_key?(cs.errors, :name) or Keyword.has_key?(cs.errors, :slug) do
      case find_duplicate(attrs) do
        nil -> {:error, cs}
        existing -> {:error, {:duplicate, existing}}
      end
    else
      {:error, cs}
    end
  end

  defp resolve_duplicate(result, _attrs), do: result

  # Runs OUTSIDE any transaction — looks up the existing product by name or barcode
  # after a unique constraint failure so we can return a friendly duplicate error.
  defp find_duplicate(attrs) do
    name = Map.get(attrs, :name) || Map.get(attrs, "name")
    barcode = Map.get(attrs, :barcode) || Map.get(attrs, "barcode")

    cond do
      name -> Repo.get_by(Product, name: name)
      barcode -> Repo.one(from p in Product, where: p.barcode == ^barcode, limit: 1)
      true -> nil
    end
  end

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  def create_product_with_ingredients(name, ingredients)
      when is_binary(name) and is_list(ingredients) do
    create_product_with_ingredients_and_categories(name, ingredients, [])
  end

  def create_product_with_ingredients_and_categories(name, ingredients, category_names, extra \\ %{})
      when is_binary(name) and is_list(ingredients) and is_list(category_names) do
    attrs = Map.merge(%{name: name}, extra)

    result =
      Repo.transaction(fn ->
        with {:ok, product} <- create_product(attrs),
             :ok <- attach_ingredients(product, ingredients),
             :ok <- attach_categories(product, category_names) do
          product
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    # Transaction is now closed — safe to query DB for duplicate resolution.
    case result do
      {:error, %Ecto.Changeset{} = cs} -> resolve_duplicate({:error, cs}, attrs)
      other -> other
    end
  end

  @doc """
  Adds an ingredient to a product, optionally storing `amount_percent` and
  `amount_raw` from the `amounts` map.

  ## Examples

      add_ingredient_to_product(product, "Seaweed", %{amount_percent: Decimal.new("61"), amount_raw: "61%"})
      add_ingredient_to_product(product, "Salt", %{})
  """
  def add_ingredient_to_product(%Product{} = product, ingredient_name, amounts \\ %{})
      when is_binary(ingredient_name) do
    with {:ok, ingredient} <- get_or_create_ingredient(ingredient_name) do
      attrs =
        Map.merge(
          %{product_id: product.id, ingredient_id: ingredient.id},
          Map.take(amounts, [:amount_percent, :amount_raw])
        )

      %ProductIngredient{}
      |> ProductIngredient.changeset(attrs)
      |> Repo.insert(on_conflict: :nothing, returning: true)
    end
  end

  def add_category_to_product(%Product{} = product, category_name)
      when is_binary(category_name) do
    with {:ok, category} <- get_or_create_category(category_name) do
      %ProductCategory{}
      |> ProductCategory.changeset(%{product_id: product.id, category_id: category.id})
      |> Repo.insert(on_conflict: :nothing)
    end
  end

  def list_products_by_category(category_id) do
    from(p in Product,
      join: pc in ProductCategory,
      on: pc.product_id == p.id,
      where: pc.category_id == ^category_id,
      order_by: [desc: p.id],
      distinct: true
    )
    |> Repo.all()
  end

  @doc """
  Returns a map of %{ingredient_id => %ProductIngredient{}} for all
  ingredients of a product, used to display amounts on the UI.
  """
  def ingredient_amounts_for(%Product{id: product_id}) do
    from(pi in ProductIngredient, where: pi.product_id == ^product_id)
    |> Repo.all()
    |> Map.new(&{&1.ingredient_id, &1})
  end

  # ---------------------------------------------------------------------------
  # Ingredients
  # ---------------------------------------------------------------------------

  def list_ingredients do
    Repo.all(from i in Ingredient, order_by: [asc: i.name])
  end

  def get_ingredient!(id), do: Repo.get!(Ingredient, id)

  def get_ingredient_with_products!(id) do
    Ingredient
    |> Repo.get!(id)
    |> Repo.preload(:products)
  end

  def get_ingredient_by_name!(name) do
    Repo.get_by!(Ingredient, name: name)
  end

  def create_ingredient(attrs) do
    %Ingredient{}
    |> Ingredient.changeset(attrs)
    |> Repo.insert()
  end

  def get_or_create_ingredient(name) when is_binary(name) do
    import Ecto.Query, only: [from: 2]
    normalised = name |> String.trim() |> String.replace(~r/\s+/, " ")

    # Case-insensitive lookup so "sugar", "Sugar", "SUGAR" all map to the same row.
    # The changeset will capitalise the first letter on insert.
    case Repo.one(from i in Ingredient, where: fragment("lower(?)", i.name) == ^String.downcase(normalised), limit: 1) do
      nil ->
        %Ingredient{}
        |> Ingredient.changeset(%{name: normalised})
        |> Repo.insert()

      ingredient ->
        {:ok, ingredient}
    end
  end

  @doc """
  Searches products by ingredient name (case-insensitive).

  Options:
    - `sort: :amount_desc` — sort by amount_percent descending (highest first)
    - `sort: :amount_asc`  — sort by amount_percent ascending (lowest first)
    - default              — sort by product name ascending
  """
  def search_products_by_ingredient(ingredient_name, opts \\ [])
      when is_binary(ingredient_name) do
    name_lower = String.downcase(ingredient_name)
    sort = Keyword.get(opts, :sort, :name)

    base =
      from(p in Product,
        join: pi in ProductIngredient,
        on: pi.product_id == p.id,
        join: i in Ingredient,
        on: pi.ingredient_id == i.id,
        where: fragment("lower(?)", i.name) == ^name_lower,
        select: %{product: p, amount_percent: pi.amount_percent, amount_raw: pi.amount_raw}
      )

    ordered =
      case sort do
        :amount_desc -> from([p, pi] in base, order_by: [desc_nulls_last: pi.amount_percent, asc: p.name])
        :amount_asc -> from([p, pi] in base, order_by: [asc_nulls_last: pi.amount_percent, asc: p.name])
        _ -> from([p, _pi] in base, order_by: [asc: p.name])
      end

    ordered
    |> Repo.all()
    |> Enum.map(fn %{product: p, amount_percent: ap, amount_raw: ar} ->
      Map.merge(p, %{amount_percent: ap, amount_raw: ar})
    end)
  end

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  def list_categories do
    Repo.all(from c in Category, order_by: [asc: c.name])
  end

  def get_category!(id), do: Repo.get!(Category, id)

  def get_category_by_slug!(slug) do
    Repo.get_by!(Category, slug: slug)
  end

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  def get_or_create_category(name) when is_binary(name) do
    slug = slugify(name)

    case Repo.get_by(Category, slug: slug) do
      nil ->
        %Category{}
        |> Category.changeset(%{name: name, slug: slug})
        |> Repo.insert()

      category ->
        {:ok, category}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Accepts either plain binary names or maps with :name + optional :amount_*
  defp attach_ingredients(product, ingredients) do
    Enum.reduce_while(ingredients, :ok, fn item, :ok ->
      {name, amounts} = ingredient_name_and_amounts(item)

      case add_ingredient_to_product(product, name, amounts) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp ingredient_name_and_amounts(name) when is_binary(name), do: {name, %{}}

  defp ingredient_name_and_amounts(%{name: name} = map) do
    amounts = Map.take(map, [:amount_percent, :amount_raw])
    {name, amounts}
  end

  defp attach_categories(product, category_names) do
    Enum.reduce_while(category_names, :ok, fn name, :ok ->
      case add_category_to_product(product, name) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  # Slug = slugified-name + "-" + barcode  (if barcode present)
  #      = slugified-name + "-id" + id     (fallback when no barcode)
  defp build_product_slug(%Product{name: name, barcode: barcode, id: id}) do
    base = slugify(name)

    if barcode && barcode != "" do
      "#{base}-#{barcode}"
    else
      "#{base}-id#{id}"
    end
  end

  @doc """
  Compares the ingredient lists of two products.

  Returns a map with three keys:
    - `:common`  — ingredients present in both products
    - `:only_a`  — ingredients only in product A
    - `:only_b`  — ingredients only in product B

  Each entry is a map `%{ingredient, amount_a, amount_b}` (amounts are nil
  for sides that don't have the ingredient).
  """
  def compare_products(%Product{} = a, %Product{} = b) do
    a = Repo.preload(a, :ingredients)
    b = Repo.preload(b, :ingredients)

    amounts_a = ingredient_amounts_for(a)
    amounts_b = ingredient_amounts_for(b)

    ids_a = MapSet.new(a.ingredients, & &1.id)
    ids_b = MapSet.new(b.ingredients, & &1.id)

    all_ingredients =
      (a.ingredients ++ b.ingredients)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.name)

    Enum.reduce(all_ingredients, %{common: [], only_a: [], only_b: []}, fn ing, acc ->
      in_a = MapSet.member?(ids_a, ing.id)
      in_b = MapSet.member?(ids_b, ing.id)
      amt_a = Map.get(amounts_a, ing.id)
      amt_b = Map.get(amounts_b, ing.id)
      entry = %{ingredient: ing, amount_a: amt_a, amount_b: amt_b}

      cond do
        in_a and in_b -> Map.update!(acc, :common, &(&1 ++ [entry]))
        in_a -> Map.update!(acc, :only_a, &(&1 ++ [entry]))
        in_b -> Map.update!(acc, :only_b, &(&1 ++ [entry]))
      end
    end)
  end
end
