defmodule Angivaonguoi.Catalog.Ingredient do
  use Ecto.Schema
  import Ecto.Changeset

  alias Angivaonguoi.Catalog.{Product, ProductIngredient}

  schema "ingredients" do
    field :name, :string

    many_to_many :products, Product,
      join_through: ProductIngredient,
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ingredient, attrs) do
    ingredient
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:name)
  end
end
