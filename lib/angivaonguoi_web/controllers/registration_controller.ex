defmodule AngivaonguoiWeb.RegistrationController do
  use AngivaonguoiWeb, :controller

  alias Angivaonguoi.Accounts
  alias AngivaonguoiWeb.Auth

  def create(conn, %{"user" => params}) do
    refer_code = Map.get(params, "refer_code", "")

    if Accounts.valid_refer_code?(refer_code) do
      case Accounts.register_user(params) do
        {:ok, user} ->
          conn
          |> Auth.log_in(user)
          |> put_flash(:info, "Welcome, #{user.username}!")
          |> redirect(to: ~p"/")

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Registration failed. Please check the fields and try again.")
          |> redirect(to: ~p"/register")
      end
    else
      conn
      |> put_flash(:error, "Invalid refer code.")
      |> redirect(to: ~p"/register")
    end
  end
end
