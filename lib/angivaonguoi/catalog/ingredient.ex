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
    |> update_change(:name, &normalise_name/1)
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:name)
  end

  # Trim surrounding whitespace, collapse internal runs, then capitalise the
  # very first letter while leaving the rest of the casing intact.
  # "  wheat flour  " → "Wheat flour"
  # "SUGAR"           → "SUGAR"  (already uppercase — we only touch first char)
  # "Vitamin C"       → "Vitamin C"
  defp normalise_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> capitalise_first()
  end

  defp normalise_name(other), do: other

  defp capitalise_first(""), do: ""

  defp capitalise_first(<<first::utf8, rest::binary>>) do
    String.upcase(<<first::utf8>>) <> rest
  end
end
