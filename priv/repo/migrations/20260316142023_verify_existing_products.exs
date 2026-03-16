defmodule Angivaonguoi.Repo.Migrations.VerifyExistingProducts do
  use Ecto.Migration

  def up do
    execute "UPDATE products SET verified = true"
  end

  def down do
    execute "UPDATE products SET verified = false"
  end
end
