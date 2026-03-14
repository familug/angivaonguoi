defmodule Angivaonguoi.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string, null: false
      add :image_url, :string
      add :raw_text, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:products, [:name])
  end
end
