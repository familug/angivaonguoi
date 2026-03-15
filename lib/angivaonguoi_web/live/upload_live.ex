defmodule AngivaonguoiWeb.UploadLive do
  use AngivaonguoiWeb, :live_view

  alias Angivaonguoi.ImageProcessor

  @max_file_size 10 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:status, :idle)
     |> assign(:error, nil)
     |> assign(:product, nil)
     |> allow_upload(:product_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: @max_file_size,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  defp handle_progress(:product_image, entry, socket) do
    if entry.done? do
      process_upload(socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:product_image, ref)
     |> assign(:status, :idle)
     |> assign(:error, nil)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:image_processed, {:ok, product}}, socket) do
    {:noreply,
     socket
     |> assign(:status, :done)
     |> assign(:product, product)
     |> assign(:error, nil)}
  end

  def handle_info({:image_processed, {:error, reason}}, socket) do
    message =
      cond do
        is_binary(reason) -> reason
        is_exception(reason) -> Exception.message(reason)
        true -> inspect(reason)
      end

    {:noreply,
     socket
     |> assign(:status, :error)
     |> assign(:error, message)
     |> assign(:product, nil)}
  end

  defp process_upload(socket) do
    api_key = Application.get_env(:angivaonguoi, :gemini_api_key, "")

    if api_key == "" do
      {:noreply,
       socket
       |> assign(:status, :error)
       |> assign(
         :error,
         "Gemini API key is not configured. Set the GEMINI_API_KEY environment variable and restart the server."
       )}
    else
      lv = self()

      consume_uploaded_entries(socket, :product_image, fn %{path: tmp_path}, entry ->
        original = File.read!(tmp_path)
        mime = entry.client_type

        # Resize once here — the resized binary is both saved to disk and sent
        # to Gemini, so we never store the original multi-MB file.
        {resized, resized_mime} = ImageProcessor.resize_image(original, mime)
        image_url = persist_image(resized, resized_mime)

        Task.start(fn ->
          result = ImageProcessor.process_image(resized, resized_mime, image_url)
          send(lv, {:image_processed, result})
        end)

        {:ok, :started}
      end)

      {:noreply, assign(socket, :status, :processing)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-8">
      <.link navigate={~p"/products"} class="btn btn-ghost btn-sm mb-6">
        &larr; Back to Products
      </.link>

      <h1 class="text-2xl font-bold text-gray-900 mb-6">Upload Image</h1>

      <div :if={@status == :done and @product} class="alert alert-success mb-6">
        <span>
          Product "<%= @product.name %>" added successfully!
          <.link navigate={~p"/products/#{@product.slug}"} class="link font-semibold ml-1">
            View product &rarr;
          </.link>
        </span>
      </div>

      <div :if={@status == :error and @error} class="alert alert-error mb-6">
        <span>Error: <%= @error %></span>
      </div>

      <form phx-change="validate" class="card bg-base-100 border border-base-200 shadow">
        <div class="card-body space-y-6">
          <div
            class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors"
            phx-drop-target={@uploads.product_image.ref}
          >
            <.live_file_input upload={@uploads.product_image} class="hidden" />

            <label for={@uploads.product_image.ref} class="cursor-pointer">
              <div class="flex flex-col items-center gap-3">
                <svg
                  class="w-12 h-12 text-gray-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
                </svg>
                <p class="text-gray-600">
                  <span class="text-primary font-semibold">Click to upload</span>
                  or drag and drop
                </p>
                <p class="text-xs text-gray-400">JPG, PNG, WEBP up to 10MB</p>
              </div>
            </label>
          </div>

          <div :for={entry <- @uploads.product_image.entries} class="flex items-center gap-3">
            <.live_img_preview entry={entry} class="w-16 h-16 object-cover rounded" />
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-700"><%= entry.client_name %></p>
              <div class="w-full bg-base-200 rounded-full h-1.5 mt-1">
                <div
                  class="bg-primary h-1.5 rounded-full transition-all"
                  style={"width: #{entry.progress}%"}
                />
              </div>
            </div>
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              class="btn btn-ghost btn-xs text-error"
            >
              &times;
            </button>
          </div>

          <div :for={err <- upload_errors(@uploads.product_image)} class="text-error text-sm">
            <%= error_to_string(err) %>
          </div>

          <div :if={@status == :processing} class="flex items-center justify-center gap-3 py-2 text-gray-600">
            <span class="loading loading-spinner loading-sm"></span>
            Analyzing image with AI...
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp persist_image(binary, mime) do
    ext = if mime == "image/jpeg", do: ".jpg", else: ".webp"
    filename = "#{System.unique_integer([:positive])}_#{:erlang.phash2(binary)}#{ext}"
    dest = Path.join([:code.priv_dir(:angivaonguoi), "static", "uploads", filename])
    File.write!(dest, binary)
    "/uploads/#{filename}"
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "Unsupported file type. Use JPG, PNG, or WEBP"
  defp error_to_string(:too_many_files), do: "Only one file allowed at a time"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
