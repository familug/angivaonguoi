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
      live "/products/:id", ProductLive.Show, :show
      live "/ingredients/:id", IngredientLive.Show, :show
      live "/categories/:id", CategoryLive.Show, :show
      live "/search", SearchLive, :index
    end

    # Protected routes — require login
    live_session :authenticated,
      on_mount: {AngivaonguoiWeb.Auth, :require_authenticated} do
      live "/upload", UploadLive, :new
    end
  end

  if Application.compile_env(:angivaonguoi, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AngivaonguoiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
