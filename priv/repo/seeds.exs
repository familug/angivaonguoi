# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# E2E tests expect: admin@e2e.test / e2eadmin123, verified product "E2E Verified Product",
# and unverified product "E2E Unverified Product".

alias Angivaonguoi.{Accounts, Catalog, Repo}
alias Angivaonguoi.Catalog.Product
import Ecto.Query

admin =
  case Accounts.get_user_by_email("admin@e2e.test") do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{
          email: "admin@e2e.test",
          username: "e2eadmin",
          password: "e2eadmin123"
        })

      user

    user ->
      user
  end

# Ensure e2eadmin is admin for e2e tests
Repo.update_all(
  from(u in Angivaonguoi.Accounts.User, where: u.email == "admin@e2e.test"),
  set: [is_admin: true]
)

case Repo.one(from p in Product, where: p.name == "E2E Verified Product") do
  nil ->
    {:ok, p} =
      Catalog.create_product_with_ingredients_and_categories(
        "E2E Verified Product",
        ["Salt", "Sugar"],
        ["Snacks"],
        %{uploaded_by_id: admin.id}
      )

    Catalog.verify_product(p)

  _ ->
    :ok
end

case Repo.one(from p in Product, where: p.name == "E2E Unverified Product") do
  nil ->
    Catalog.create_product_with_ingredients_and_categories(
      "E2E Unverified Product",
      ["Water"],
      [],
      %{uploaded_by_id: admin.id}
    )

  _ ->
    :ok
end
