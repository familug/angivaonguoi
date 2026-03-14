defmodule Angivaonguoi.Repo.Migrations.AddAmountToProductIngredients do
  use Ecto.Migration

  def change do
    alter table(:product_ingredients) do
      # Stored as a decimal percentage, e.g. 61.0 means 61%.
      # NULL means no percentage info available.
      add :amount_percent, :decimal, precision: 7, scale: 3
    end

    # Also store the raw amount string from the label (e.g. "200mg", "61%", "1.2g/100ml")
    alter table(:product_ingredients) do
      add :amount_raw, :string
    end
  end
end
