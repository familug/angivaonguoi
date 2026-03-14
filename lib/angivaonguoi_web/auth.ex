defmodule AngivaonguoiWeb.Auth do
  @moduledoc """
  Helpers for managing the current user in session and LiveView socket.
  """
  import Plug.Conn

  alias Angivaonguoi.Accounts

  # Session key
  @user_key "user_id"

  # ---------------------------------------------------------------------------
  # Plug — runs in the HTTP pipeline to load user into conn.assigns
  # ---------------------------------------------------------------------------

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, @user_key)

    user =
      if user_id do
        Accounts.get_user(user_id)
      end

    assign(conn, :current_user, user)
  end

  # ---------------------------------------------------------------------------
  # Session helpers
  # ---------------------------------------------------------------------------

  def log_in(conn, user) do
    conn
    |> put_session(@user_key, user.id)
    |> configure_session(renew: true)
  end

  def log_out(conn) do
    conn
    |> delete_session(@user_key)
    |> configure_session(drop: true)
  end

  # ---------------------------------------------------------------------------
  # LiveView on_mount hooks
  # ---------------------------------------------------------------------------

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
        |> Phoenix.LiveView.redirect(to: "/login")

      {:halt, socket}
    end
  end

  def on_mount(:load_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  defp mount_current_user(socket, session) do
    user_id = Map.get(session, @user_key)

    user =
      if user_id do
        Accounts.get_user(user_id)
      end

    Phoenix.Component.assign(socket, :current_user, user)
  end
end
