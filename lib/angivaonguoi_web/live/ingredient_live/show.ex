defmodule AngivaonguoiWeb.IngredientLive.Show do
  use AngivaonguoiWeb, :live_view

  alias Angivaonguoi.Catalog

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    ingredient = Catalog.get_ingredient_with_products!(id)
    {:ok, assign(socket, :ingredient, ingredient)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-8">
      <.link navigate={~p"/products"} class="btn btn-ghost btn-sm mb-6">
        &larr; Back to Products
      </.link>

      <div class="card bg-base-100 border border-base-200 shadow mb-6">
        <div class="card-body">
          <h1 class="text-2xl font-bold text-gray-900 mb-2">
            Ingredient: <span class="text-primary"><%= @ingredient.name %></span>
          </h1>
          <p class="text-gray-500">
            Found in <%= length(@ingredient.products) %> product(s)
          </p>
        </div>
      </div>

      <h2 class="text-lg font-semibold text-gray-700 mb-4">Products containing this ingredient</h2>

      <div :if={@ingredient.products == []} class="text-gray-500">
        No products found.
      </div>

      <div class="grid grid-cols-1 gap-3">
        <.link
          :for={product <- @ingredient.products}
          navigate={~p"/products/#{product.id}"}
          class="card bg-base-100 border border-base-200 hover:border-primary transition-colors cursor-pointer"
        >
          <div class="card-body py-3">
            <p class="font-medium"><%= product.name %></p>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
