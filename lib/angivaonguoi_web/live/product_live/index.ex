defmodule AngivaonguoiWeb.ProductLive.Index do
  use AngivaonguoiWeb, :live_view

  alias Angivaonguoi.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:categories, Catalog.list_categories())
     |> assign(:selected_category, nil)
     |> assign(:products, Catalog.list_products())}
  end

  @impl true
  def handle_params(%{"category" => category_id}, _uri, socket) do
    category = Catalog.get_category!(category_id)

    {:noreply,
     socket
     |> assign(:selected_category, category)
     |> assign(:products, Catalog.list_products_by_category(category.id))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:selected_category, nil)
     |> assign(:products, Catalog.list_products())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-3xl font-bold text-gray-900">Food Products</h1>
        <.link navigate={~p"/upload"} class="btn btn-primary">
          Upload Product
        </.link>
      </div>

      <div :if={@categories != []} class="flex flex-wrap gap-2 mb-8">
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

      <div :if={@products == []} class="text-center py-20 text-gray-500">
        <p class="text-xl">No products yet.</p>
        <p class="mt-2">
          <.link navigate={~p"/upload"} class="link link-primary">Upload a product image</.link>
          to get started.
        </p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <.link
          :for={product <- @products}
          navigate={~p"/products/#{product.slug}"}
          class="card bg-base-100 border border-base-200 shadow-sm hover:shadow-md transition-shadow cursor-pointer"
        >
          <figure :if={product.image_url} class="px-4 pt-4">
            <img
              src={product.image_url}
              alt={product.name}
              class="w-full h-36 object-contain rounded-lg bg-base-200"
            />
          </figure>
          <div class="card-body">
            <h2 class="card-title text-base"><%= product.name %></h2>
            <p class="text-sm text-gray-500">Click to view ingredients</p>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
