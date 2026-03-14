defmodule AngivaonguoiWeb.SessionController do
  use AngivaonguoiWeb, :controller

  alias Angivaonguoi.Accounts
  alias AngivaonguoiWeb.Auth

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate(email, password) do
      {:ok, user} ->
        conn
        |> Auth.log_in(user)
        |> redirect(to: ~p"/")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> Auth.log_out()
    |> redirect(to: ~p"/")
  end
end
