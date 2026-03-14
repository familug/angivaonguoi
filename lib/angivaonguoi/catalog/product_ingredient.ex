defmodule Angivaonguoi.Catalog.ProductIngredient do
  use Ecto.Schema
  import Ecto.Changeset

  alias Angivaonguoi.Catalog.{Product, Ingredient}

  schema "product_ingredients" do
    belongs_to :product, Product
    belongs_to :ingredient, Ingredient

    # Numeric percentage, e.g. Decimal.new("61.0") for 61%
    field :amount_percent, :decimal
    # Raw string from the label, e.g. "61%", "200mg", "1.2g/100ml"
    field :amount_raw, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product_ingredient, attrs) do
    product_ingredient
    |> cast(attrs, [:product_id, :ingredient_id, :amount_percent, :amount_raw])
    |> validate_required([:product_id, :ingredient_id])
    |> validate_number(:amount_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint([:product_id, :ingredient_id])
  end
end
