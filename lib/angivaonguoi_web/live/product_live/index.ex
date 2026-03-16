defmodule AngivaonguoiWeb.ProductLive.Index do
  use AngivaonguoiWeb, :live_view

  alias Angivaonguoi.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:categories, Catalog.list_categories())
     |> assign(:selected_category, nil)
     |> assign(:products, load_products(socket, nil))}
  end

  @impl true
  def handle_params(%{"category" => category_id}, _uri, socket) do
    category = Catalog.get_category!(category_id)

    {:noreply,
     socket
     |> assign(:selected_category, category)
     |> assign(:products, load_products(socket, category.id))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:selected_category, nil)
     |> assign(:products, load_products(socket, nil))}
  end

  @impl true
  def handle_event("verify_product", %{"id" => id}, socket) do
    if socket.assigns[:current_user] && socket.assigns.current_user.is_admin do
      product = Catalog.get_product!(id)
      Catalog.verify_product(product)
    end

    {:noreply,
     socket
     |> put_flash(:info, "Product verified.")
     |> assign(:products, load_products(socket, socket.assigns.selected_category && socket.assigns.selected_category.id))}
  end

  def handle_event("unverify_product", %{"id" => id}, socket) do
    if socket.assigns[:current_user] && socket.assigns.current_user.is_admin do
      product = Catalog.get_product!(id)
      Catalog.unverify_product(product)
    end

    {:noreply,
     socket
     |> put_flash(:info, "Product unverified.")
     |> assign(:products, load_products(socket, socket.assigns.selected_category && socket.assigns.selected_category.id))}
  end

  defp load_products(socket, category_id) do
    admin? = socket.assigns[:current_user] && socket.assigns.current_user.is_admin

    if admin? do
      if category_id, do: Catalog.list_all_products_by_category(category_id), else: Catalog.list_all_products()
    else
      if category_id, do: Catalog.list_products_by_category(category_id), else: Catalog.list_products()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-3xl font-bold text-gray-900">Food Products</h1>
        <.link navigate={~p"/upload"} class="btn btn-primary">
          Upload
        </.link>
      </div>

      <div :if={@products == []} class="text-center py-20 text-gray-500">
        <p class="text-xl">No products yet.</p>
        <p class="mt-2">
          <.link navigate={~p"/upload"} class="link link-primary">Upload a product image</.link>
          to get started.
        </p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          :for={product <- @products}
          class="card bg-base-100 border border-base-200 shadow-sm hover:shadow-md transition-shadow relative"
        >
          <div :if={@current_user && @current_user.is_admin} class="absolute top-2 right-2 z-10 flex flex-col gap-1">
            <span :if={!product.verified} class="badge badge-warning badge-sm">Unverified</span>
            <span :if={product.uploaded_by} class="text-xs text-gray-500">@<%= product.uploaded_by.username %></span>
            <button
              :if={!product.verified}
              phx-click="verify_product"
              phx-value-id={product.id}
              class="btn btn-success btn-xs"
            >
              Verify
            </button>
            <button
              :if={product.verified}
              phx-click="unverify_product"
              phx-value-id={product.id}
              class="btn btn-ghost btn-xs"
            >
              Unverify
            </button>
          </div>
          <.link navigate={~p"/products/#{product.slug}"} class="block cursor-pointer">
            <figure :if={product.image_url} class="px-4 pt-4">
              <img
                src={product.image_url}
                alt={product.name}
                class="w-full h-36 object-contain rounded-lg bg-base-200"
              />
            </figure>
            <div class="card-body">
              <h2 class="card-title text-base"><%= product.name %></h2>
              <div class="flex items-center gap-2 mt-1">
                <p class="text-sm text-gray-500 flex-1">Click to view ingredients</p>
                <span :if={product.barcode} title="Has barcode" class="text-base">🔖</span>
                <span :if={product.energy_kcal_per_100} title="Has calorie info" class="text-base">🔥</span>
              </div>
            </div>
          </.link>
        </div>
      </div>

      <div :if={@categories != []} class="flex flex-wrap gap-2 mt-8">
        <.link
          patch={~p"/products"}
          class={["badge badge-lg py-3 px-4 cursor-pointer transition-colors",
            if(@selected_category == nil, do: "badge-primary", else: "badge-outline")]}
        >
          All
        </.link>
        <.link
          :for={category <- @categories}
          patch={~p"/products?category=#{category.id}"}
          class={["badge badge-lg py-3 px-4 cursor-pointer transition-colors",
            if(@selected_category && @selected_category.id == category.id,
              do: "badge-primary",
              else: "badge-outline"
            )]}
        >
          <%= category.name %>
        </.link>
      </div>
    </div>
    """
  end
end
