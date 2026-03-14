defmodule Angivaonguoi.Catalog.ProductCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Angivaonguoi.Catalog.{Product, Category}

  schema "product_categories" do
    belongs_to :product, Product
    belongs_to :category, Category

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product_category, attrs) do
    product_category
    |> cast(attrs, [:product_id, :category_id])
    |> validate_required([:product_id, :category_id])
    |> unique_constraint([:product_id, :category_id])
  end
end
