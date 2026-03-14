defmodule Angivaonguoi.Repo.Migrations.CreateProductIngredients do
  use Ecto.Migration

  def change do
    create table(:product_ingredients) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :ingredient_id, references(:ingredients, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:product_ingredients, [:product_id, :ingredient_id])
    create index(:product_ingredients, [:ingredient_id])
  end
end
