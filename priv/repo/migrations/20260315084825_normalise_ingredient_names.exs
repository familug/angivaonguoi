defmodule Angivaonguoi.Repo.Migrations.NormaliseIngredientNames do
  use Ecto.Migration

  @doc """
  For each group of ingredients that share the same lower-cased name,
  keep the one with the smallest id (oldest / first-seen) and re-point all
  product_ingredients rows to it, then delete the duplicates.

  Also capitalises the first letter of every ingredient name so storage
  is consistent with the new changeset normalisation.
  """
  def up do
    # 1. Re-point product_ingredients to the canonical (lowest id) duplicate
    execute("""
    UPDATE product_ingredients pi
    SET ingredient_id = canonical.id
    FROM (
      SELECT lower(name) AS lower_name, min(id) AS id
      FROM ingredients
      GROUP BY lower(name)
    ) canonical
    JOIN ingredients i ON lower(i.name) = canonical.lower_name
    WHERE pi.ingredient_id = i.id
      AND i.id <> canonical.id
    """)

    # 2. Remove now-orphaned duplicate ingredient rows
    execute("""
    DELETE FROM ingredients
    WHERE id NOT IN (
      SELECT min(id) FROM ingredients GROUP BY lower(name)
    )
    """)

    # 3. Capitalise first letter of every ingredient name
    execute("""
    UPDATE ingredients
    SET name = upper(substring(name, 1, 1)) || substring(name, 2)
    WHERE name <> upper(substring(name, 1, 1)) || substring(name, 2)
    """)
  end

  def down do
    :ok
  end
end
