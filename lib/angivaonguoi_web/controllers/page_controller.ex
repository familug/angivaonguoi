defmodule AngivaonguoiWeb.PageController do
  use AngivaonguoiWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/products")
  end
end
