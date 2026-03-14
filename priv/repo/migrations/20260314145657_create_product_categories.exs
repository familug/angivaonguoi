defmodule Angivaonguoi.Repo.Migrations.CreateProductCategories do
  use Ecto.Migration

  def change do
    create table(:product_categories) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:product_categories, [:product_id, :category_id])
    create index(:product_categories, [:category_id])
  end
end
