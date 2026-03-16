defmodule Angivaonguoi.Repo.Migrations.AddVerifiedAndUploadedByToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :verified, :boolean, default: false, null: false
      add :uploaded_by_id, references(:users, on_delete: :nilify_all)
    end
  end
end
