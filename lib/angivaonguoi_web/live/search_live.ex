defmodule AngivaonguoiWeb.SearchLive do
  use AngivaonguoiWeb, :live_view

  alias Angivaonguoi.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:results, [])
     |> assign(:query, "")
     |> assign(:sort, "name")
     |> assign(:searched, false)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query, "sort" => sort}}, socket) do
    query = String.trim(query)

    results =
      if query == "" do
        []
      else
        sort_opt = parse_sort(sort)
        Catalog.search_products_by_ingredient(query, sort: sort_opt)
      end

    {:noreply,
     socket
     |> assign(:results, results)
     |> assign(:query, query)
     |> assign(:sort, sort)
     |> assign(:searched, query != "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-8">
      <.link navigate={~p"/products"} class="btn btn-ghost btn-sm mb-6">
        &larr; Back to Products
      </.link>

      <h1 class="text-2xl font-bold text-gray-900 mb-6">Search by Ingredient</h1>

      <form phx-submit="search" class="flex flex-col sm:flex-row gap-3 mb-8">
        <input
          type="text"
          name="search[query]"
          value={@query}
          placeholder="e.g. Seaweed, Chilli, Palm Oil..."
          class="input input-bordered flex-1"
          autofocus
        />
        <select name="search[sort]" class="select select-bordered">
          <option value="name" selected={@sort == "name"}>Sort: A–Z</option>
          <option value="amount_desc" selected={@sort == "amount_desc"}>Sort: Highest % first</option>
          <option value="amount_asc" selected={@sort == "amount_asc"}>Sort: Lowest % first</option>
        </select>
        <button type="submit" class="btn btn-primary">Search</button>
      </form>

      <div :if={@searched and @results == []} class="text-center py-10 text-gray-500">
        No products found containing "<%= @query %>".
      </div>

      <div :if={@results != []}>
        <p class="text-sm text-gray-500 mb-4">
          Found <%= length(@results) %> product(s) containing "<%= @query %>"
        </p>
        <div class="grid grid-cols-1 gap-3">
          <.link
            :for={product <- @results}
            navigate={~p"/products/#{product.slug}"}
            class="card bg-base-100 border border-base-200 hover:border-primary transition-colors"
          >
            <div class="card-body py-3 flex-row items-center justify-between">
              <p class="font-medium"><%= product.name %></p>
              <span :if={product.amount_raw} class="badge badge-primary badge-outline text-xs font-semibold">
                <%= product.amount_raw %>
              </span>
              <span :if={!product.amount_raw and product.amount_percent} class="badge badge-primary badge-outline text-xs font-semibold">
                <%= Decimal.to_string(product.amount_percent) %>%
              </span>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp parse_sort("amount_desc"), do: :amount_desc
  defp parse_sort("amount_asc"), do: :amount_asc
  defp parse_sort(_), do: :name
end
