defmodule Angivaonguoi.Catalog.Category do
  use Ecto.Schema
  import Ecto.Changeset

  alias Angivaonguoi.Catalog.{Product, ProductCategory}

  schema "categories" do
    field :name, :string
    field :slug, :string

    many_to_many :products, Product,
      join_through: ProductCategory,
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> maybe_generate_slug()
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        name = get_field(changeset, :name) || ""
        put_change(changeset, :slug, slugify(name))

      _ ->
        changeset
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
