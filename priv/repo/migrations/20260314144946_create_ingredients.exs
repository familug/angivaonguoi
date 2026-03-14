defmodule Angivaonguoi.Repo.Migrations.CreateIngredients do
  use Ecto.Migration

  def change do
    create table(:ingredients) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ingredients, [:name])
  end
end
