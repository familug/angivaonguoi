defmodule AngivaonguoiWeb.UploadLiveTest do
  use AngivaonguoiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Angivaonguoi.Accounts

  defp register_and_log_in(%{conn: conn}) do
    {:ok, user} =
      Accounts.register_user(%{
        email: "uploader@example.com",
        username: "uploader",
        password: "pass1234"
      })

    conn =
      conn
      |> init_test_session(%{"user_id" => user.id})

    %{conn: conn, user: user}
  end

  describe "Upload page" do
    setup :register_and_log_in

    test "renders file upload form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/upload")

      assert html =~ "Upload Image"
      assert html =~ ~r/input[^>]+type="file"/i
    end
  end

  describe "Upload page (unauthenticated)" do
    test "redirects to login when not logged in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/upload")
    end
  end
end
