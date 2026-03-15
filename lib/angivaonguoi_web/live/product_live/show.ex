defmodule AngivaonguoiWeb.ProductLive.Show do
  use AngivaonguoiWeb, :live_view

  alias Angivaonguoi.Catalog

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    product = Catalog.get_product_by_slug!(slug) |> then(&Catalog.get_product_with_all!(&1.id))
    amounts = Catalog.ingredient_amounts_for(product)

    host = AngivaonguoiWeb.Endpoint.host()
    canonical_url = "https://#{host}/products/#{product.slug}"

    ingredient_preview =
      product.ingredients
      |> Enum.take(5)
      |> Enum.map(& &1.name)
      |> Enum.join(", ")

    description =
      if ingredient_preview != "",
        do: "Ingredients: #{ingredient_preview}",
        else: "View full ingredient list on FoodCheck."

    og = %{
      title: "#{product.name} — FoodCheck",
      description: description,
      url: canonical_url,
      image: product.image_url && absolute_url(host, product.image_url)
    }

    {:ok, assign(socket, product: product, amounts: amounts, page_og: og)}
  end

  @impl true
  def handle_event("delete_product", _params, socket) do
    case Catalog.delete_product(socket.assigns.product) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product deleted.")
         |> redirect(to: ~p"/products")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete product.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-6">
        <.link navigate={~p"/products"} class="btn btn-ghost btn-sm">
          &larr; Back to Products
        </.link>

        <div class="flex gap-2">
          <.link navigate={~p"/compare?a=#{@product.slug}"} class="btn btn-outline btn-sm">
            Compare
          </.link>

          <button
            :if={@current_user && @current_user.is_admin}
            phx-click="delete_product"
            data-confirm={"Delete \"#{@product.name}\"? This cannot be undone."}
            class="btn btn-error btn-sm"
          >
            Delete Product
          </button>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-200 shadow">
        <div class="card-body space-y-6">
          <img
            :if={@product.image_url}
            src={@product.image_url}
            alt={@product.name}
            class="w-full max-h-72 object-contain rounded-lg bg-base-200 mb-2"
          />

          <div>
            <h1 class="text-2xl font-bold text-gray-900"><%= @product.name %></h1>

            <div :if={@product.barcode} class="mt-1 text-sm text-gray-400 font-mono">
              Barcode: <%= @product.barcode %>
            </div>

            <div :if={@product.energy_kcal_per_100} class="mt-3 flex flex-wrap gap-3">
              <div class="stat bg-base-200 rounded-box px-4 py-2 min-w-0">
                <div class="stat-title text-xs">Energy</div>
                <div class="stat-value text-lg text-orange-500">
                  <%= @product.energy_kcal_per_100 %> kcal
                </div>
                <div class="stat-desc">per <%= @product.energy_unit || "100ml" %></div>
              </div>
              <div :if={total_energy(@product)} class="stat bg-base-200 rounded-box px-4 py-2 min-w-0">
                <div class="stat-title text-xs">Total energy</div>
                <div class="stat-value text-lg text-orange-500">
                  <%= total_energy(@product) %> kcal
                </div>
                <div class="stat-desc">per <%= @product.volume_ml %>ml package</div>
              </div>
            </div>

            <div :if={@product.categories != []} class="flex flex-wrap gap-2 mt-3">
              <.link
                :for={category <- @product.categories}
                navigate={~p"/products?category=#{category.id}"}
                class="badge badge-primary badge-outline cursor-pointer hover:badge-primary transition-colors"
              >
                <%= category.name %>
              </.link>
            </div>
          </div>

          <div>
            <h2 class="text-lg font-semibold text-gray-700 mb-3">Ingredients</h2>

            <div :if={@product.ingredients == []} class="text-gray-500">
              No ingredients recorded.
            </div>

            <div class="flex flex-wrap gap-2">
              <.link
                :for={ingredient <- @product.ingredients}
                navigate={~p"/ingredients/#{ingredient.id}"}
                class="group flex items-center gap-1.5 badge badge-outline hover:badge-secondary transition-colors cursor-pointer py-3 px-4 text-sm"
              >
                <span><%= ingredient.name %></span>
                <span
                  :if={amount_label(@amounts, ingredient.id)}
                  class="text-xs font-semibold text-primary opacity-80"
                >
                  <%= amount_label(@amounts, ingredient.id) %>
                </span>
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp amount_label(amounts, ingredient_id) do
    case Map.get(amounts, ingredient_id) do
      %{amount_raw: raw} when is_binary(raw) and raw != "" -> raw
      _ -> nil
    end
  end

  defp total_energy(%{energy_kcal_per_100: e, volume_ml: v})
       when not is_nil(e) and not is_nil(v) do
    Decimal.mult(e, v)
    |> Decimal.div(Decimal.new(100))
    |> Decimal.round(1)
  end

  defp total_energy(_), do: nil

  defp absolute_url(_host, "http" <> _ = url), do: url
  defp absolute_url(host, path), do: "https://#{host}#{path}"
end
