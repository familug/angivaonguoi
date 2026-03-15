defmodule AngivaonguoiWeb.CategoryLive.Show do
  use AngivaonguoiWeb, :live_view

  alias Angivaonguoi.Catalog

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    category = Catalog.get_category!(id)
    products = Catalog.list_products_by_category(id)

    {:ok,
     socket
     |> assign(:category, category)
     |> assign(:products, products)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <.link navigate={~p"/products"} class="btn btn-ghost btn-sm mb-6">
        &larr; All Products
      </.link>

      <div class="mb-8">
        <div class="flex items-center gap-3 mb-2">
          <span class="badge badge-primary badge-lg py-3 px-5 text-base"><%= @category.name %></span>
        </div>
        <p class="text-gray-500"><%= length(@products) %> product(s) in this category</p>
      </div>

      <div :if={@products == []} class="text-center py-16 text-gray-500">
        No products in this category yet.
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <.link
          :for={product <- @products}
          navigate={~p"/products/#{product.slug}"}
          class="card bg-base-100 border border-base-200 shadow-sm hover:shadow-md transition-shadow"
        >
          <div class="card-body">
            <h2 class="card-title text-base"><%= product.name %></h2>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
