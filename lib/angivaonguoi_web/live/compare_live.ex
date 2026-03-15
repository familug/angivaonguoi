defmodule AngivaonguoiWeb.CompareLive do
  use AngivaonguoiWeb, :live_view

  alias Angivaonguoi.Catalog

  @impl true
  def mount(_params, _session, socket) do
    products = Catalog.list_products()

    {:ok,
     socket
     |> assign(:products, products)
     |> assign(:product_a, nil)
     |> assign(:product_b, nil)
     |> assign(:comparison, nil)
     |> assign(:slug_a, nil)
     |> assign(:slug_b, nil)}
  end

  @impl true
  def handle_params(%{"a" => slug_a, "b" => slug_b}, _uri, socket) do
    with {:ok, a} <- fetch_product(slug_a),
         {:ok, b} <- fetch_product(slug_b) do
      comparison = Catalog.compare_products(a, b)

      {:noreply,
       socket
       |> assign(:product_a, a)
       |> assign(:product_b, b)
       |> assign(:slug_a, slug_a)
       |> assign(:slug_b, slug_b)
       |> assign(:comparison, comparison)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "One or both products not found.")}
    end
  end

  def handle_params(%{"a" => slug_a}, _uri, socket) do
    case fetch_product(slug_a) do
      {:ok, a} ->
        {:noreply,
         socket
         |> assign(:product_a, a)
         |> assign(:slug_a, slug_a)
         |> assign(:product_b, nil)
         |> assign(:slug_b, nil)
         |> assign(:comparison, nil)}

      _ ->
        {:noreply, put_flash(socket, :error, "Product not found.")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:product_a, nil)
     |> assign(:product_b, nil)
     |> assign(:slug_a, nil)
     |> assign(:slug_b, nil)
     |> assign(:comparison, nil)}
  end

  @impl true
  def handle_event("compare", %{"a" => slug_a, "b" => slug_b}, socket) do
    {:noreply, push_patch(socket, to: ~p"/compare?a=#{slug_a}&b=#{slug_b}")}
  end

  def handle_event("compare", %{"a" => slug_a}, socket) do
    {:noreply, push_patch(socket, to: ~p"/compare?a=#{slug_a}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 py-8">
      <div class="flex items-center gap-4 mb-6">
        <.link navigate={~p"/products"} class="btn btn-ghost btn-sm">
          &larr; Back to Products
        </.link>
        <h1 class="text-2xl font-bold text-gray-900">Compare Products</h1>
      </div>

      <form phx-change="compare" class="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
        <div>
          <label class="label"><span class="label-text font-semibold">Product A</span></label>
          <select name="a" class="select select-bordered w-full">
            <option value="">— select product —</option>
            <option
              :for={p <- @products}
              value={p.slug}
              selected={p.slug == @slug_a}
            ><%= p.name %></option>
          </select>
        </div>
        <div>
          <label class="label"><span class="label-text font-semibold">Product B</span></label>
          <select name="b" class="select select-bordered w-full">
            <option value="">— select product —</option>
            <option
              :for={p <- @products}
              value={p.slug}
              selected={p.slug == @slug_b}
            ><%= p.name %></option>
          </select>
        </div>
      </form>

      <div :if={@comparison} class="space-y-8">
        <div class="grid grid-cols-2 gap-4">
          <div class="card bg-base-100 border border-base-200 shadow-sm p-4">
            <img
              :if={@product_a.image_url}
              src={@product_a.image_url}
              alt={@product_a.name}
              class="w-full h-32 object-contain rounded bg-base-200 mb-2"
            />
            <p class="font-semibold text-sm"><%= @product_a.name %></p>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm p-4">
            <img
              :if={@product_b.image_url}
              src={@product_b.image_url}
              alt={@product_b.name}
              class="w-full h-32 object-contain rounded bg-base-200 mb-2"
            />
            <p class="font-semibold text-sm"><%= @product_b.name %></p>
          </div>
        </div>

        <div :if={@comparison.common != []}>
          <h2 class="text-lg font-bold text-gray-700 mb-3">
            Common ingredients (<%= length(@comparison.common) %>)
          </h2>
          <div class="overflow-x-auto">
            <table class="table table-sm w-full">
              <thead>
                <tr>
                  <th>Ingredient</th>
                  <th><%= @product_a.name %></th>
                  <th><%= @product_b.name %></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={entry <- @comparison.common}>
                  <td>
                    <.link navigate={~p"/ingredients/#{entry.ingredient.id}"} class="link link-hover">
                      <%= entry.ingredient.name %>
                    </.link>
                  </td>
                  <td class="text-sm text-gray-500"><%= amount_display(entry.amount_a) %></td>
                  <td class="text-sm text-gray-500"><%= amount_display(entry.amount_b) %></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div :if={@comparison.only_a != []}>
          <h2 class="text-lg font-bold text-blue-600 mb-3">
            Only in <%= @product_a.name %> (<%= length(@comparison.only_a) %>)
          </h2>
          <div class="flex flex-wrap gap-2">
            <span :for={entry <- @comparison.only_a} class="badge badge-outline badge-info py-3 px-4">
              <%= entry.ingredient.name %>
              <span :if={amount_display(entry.amount_a)} class="ml-1 text-xs opacity-70">
                <%= amount_display(entry.amount_a) %>
              </span>
            </span>
          </div>
        </div>

        <div :if={@comparison.only_b != []}>
          <h2 class="text-lg font-bold text-purple-600 mb-3">
            Only in <%= @product_b.name %> (<%= length(@comparison.only_b) %>)
          </h2>
          <div class="flex flex-wrap gap-2">
            <span :for={entry <- @comparison.only_b} class="badge badge-outline badge-secondary py-3 px-4">
              <%= entry.ingredient.name %>
              <span :if={amount_display(entry.amount_b)} class="ml-1 text-xs opacity-70">
                <%= amount_display(entry.amount_b) %>
              </span>
            </span>
          </div>
        </div>

        <div :if={@comparison.common == [] and @comparison.only_a == [] and @comparison.only_b == []}
             class="text-center text-gray-400 py-8">
          No ingredient data available for comparison.
        </div>
      </div>

      <div :if={is_nil(@comparison) and (@product_a || @product_b)} class="text-center text-gray-400 py-12">
        Select a second product to compare.
      </div>

      <div :if={is_nil(@product_a) and is_nil(@product_b)} class="text-center text-gray-400 py-12">
        Select two products above to compare their ingredients.
      </div>
    </div>
    """
  end

  defp fetch_product(""), do: {:error, :empty}
  defp fetch_product(nil), do: {:error, :nil}

  defp fetch_product(slug) do
    {:ok, Catalog.get_product_by_slug!(slug)}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp amount_display(nil), do: nil
  defp amount_display(%{amount_raw: raw}) when is_binary(raw) and raw != "", do: raw
  defp amount_display(_), do: nil
end
