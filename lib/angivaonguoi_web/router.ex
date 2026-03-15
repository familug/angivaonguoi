defmodule AngivaonguoiWeb.Router do
  use AngivaonguoiWeb, :router

  import AngivaonguoiWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AngivaonguoiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_admin do
    plug :fetch_session
    plug :fetch_current_user
    plug :ensure_admin
  end

  defp ensure_admin(conn, _opts) do
    if conn.assigns[:current_user] && conn.assigns[:current_user].is_admin do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Admin access required.")
      |> Phoenix.Controller.redirect(to: "/login")
      |> Plug.Conn.halt()
    end
  end

  scope "/", AngivaonguoiWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Auth session (POST/DELETE via regular controller to write cookies)
    post "/session", SessionController, :create
    delete "/session", SessionController, :delete
    post "/register", RegistrationController, :create

    # Public routes — current_user loaded but not required
    live_session :default,
      on_mount: {AngivaonguoiWeb.Auth, :load_current_user} do
      live "/login", AuthLive.Login, :new
      live "/register", AuthLive.Register, :new
      live "/products", ProductLive.Index, :index
      live "/products/:slug", ProductLive.Show, :show
      live "/ingredients/:id", IngredientLive.Show, :show
      live "/categories/:id", CategoryLive.Show, :show
      live "/search", SearchLive, :index
      live "/compare", CompareLive, :index
    end

    # Protected routes — require login
    live_session :authenticated,
      on_mount: {AngivaonguoiWeb.Auth, :require_authenticated} do
      live "/upload", UploadLive, :new
    end
  end

  import Phoenix.LiveDashboard.Router

  scope "/admin" do
    pipe_through [:browser, :require_admin]

    live_dashboard "/dashboard", metrics: AngivaonguoiWeb.Telemetry
  end

  if Application.compile_env(:angivaonguoi, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
