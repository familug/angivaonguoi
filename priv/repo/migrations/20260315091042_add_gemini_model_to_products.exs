defmodule Angivaonguoi.Repo.Migrations.AddGeminiModelToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :gemini_model, :string
    end
  end
end
