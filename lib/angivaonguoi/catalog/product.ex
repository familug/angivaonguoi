defmodule Angivaonguoi.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  alias Angivaonguoi.Catalog.{Ingredient, ProductIngredient, Category, ProductCategory}

  schema "products" do
    field :name, :string
    field :slug, :string
    field :image_url, :string
    field :image_urls, {:array, :string}, default: []
    field :raw_text, :string
    field :barcode, :string
    field :energy_kcal_per_100, :decimal
    field :energy_unit, :string
    field :volume_ml, :decimal
    field :gemini_model, :string

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
    |> cast(attrs, [:name, :slug, :image_url, :image_urls, :raw_text, :barcode, :energy_kcal_per_100, :energy_unit, :volume_ml, :gemini_model])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
