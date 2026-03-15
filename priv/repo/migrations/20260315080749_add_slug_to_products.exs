defmodule Angivaonguoi.Repo.Migrations.AddSlugToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :slug, :string
    end

    # Back-fill existing rows: slug = name-based slug + "-id<id>"
    execute(
      """
      UPDATE products
      SET slug = regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g') || '-id' || id::text
      WHERE slug IS NULL
      """,
      "SELECT 1"
    )

    alter table(:products) do
      modify :slug, :string, null: false
    end

    create unique_index(:products, [:slug])
  end
end
