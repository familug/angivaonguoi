defmodule Angivaonguoi.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  alias Angivaonguoi.Catalog.{Ingredient, ProductIngredient, Category, ProductCategory}

  schema "products" do
    field :name, :string
    field :image_url, :string
    field :raw_text, :string
    field :barcode, :string

    many_to_many :ingredients, Ingredient,
      join_through: ProductIngredient,
      on_replace: :delete

    many_to_many :categories, Category,
      join_through: ProductCategory,
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :image_url, :raw_text, :barcode])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:name)
  end
end
