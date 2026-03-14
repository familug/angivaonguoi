defmodule AngivaonguoiWeb.PageControllerTest do
  use AngivaonguoiWeb.ConnCase

  test "GET / redirects to /products", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/products"
  end
end
