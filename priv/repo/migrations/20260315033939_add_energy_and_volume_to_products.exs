defmodule Angivaonguoi.Repo.Migrations.AddEnergyAndVolumeToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      # Energy per 100ml or 100g as printed on the label (e.g. 42.0 for "42 kcal/100ml")
      add :energy_kcal_per_100, :decimal, precision: 8, scale: 2
      # The unit denominator as printed: "100ml", "100g", "serving" etc.
      add :energy_unit, :string
      # Package/serving volume in ml, used to compute total energy (e.g. 330 for a can)
      add :volume_ml, :decimal, precision: 8, scale: 2
    end
  end
end
