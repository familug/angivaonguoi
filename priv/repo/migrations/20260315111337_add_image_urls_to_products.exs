defmodule Angivaonguoi.Repo.Migrations.AddImageUrlsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :image_urls, {:array, :string}, default: []
    end
  end
end
