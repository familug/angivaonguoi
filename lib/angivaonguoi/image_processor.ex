defmodule Angivaonguoi.ImageProcessor do
  @moduledoc """
  Processes uploaded product images via the Gemini Vision API and persists
  the extracted product name and ingredients to the database.
  """

  alias Angivaonguoi.{Catalog, GeminiParser}

  # Free-tier fallback chain (all support vision / generateContent):
  #
  # 1. gemini-2.5-flash       — best quality, 10 RPM / 250 RPD free
  # 2. gemini-2.5-flash-lite  — lighter, 15 RPM / 1 000 RPD free (highest free daily quota)
  #
  # gemini-2.0-flash / 2.0-flash-lite are deprecated (retiring 2026-03-03) and
  # already exhausted on this free project — removed from fallback.
  # gemini-3.x preview models respond 200 but are paid-only previews, not free-tier.
  @gemini_models ~w(gemini-2.5-flash gemini-2.5-flash-lite)
  @gemini_base "https://generativelanguage.googleapis.com/v1beta/models"

  @doc """
  Given a raw binary image and its MIME type, calls Gemini to extract product
  information and saves it to the database.

  Returns `{:ok, product}` or `{:error, reason}`.
  """
  def process_image(image_binary, mime_type \\ "image/jpeg", image_url \\ nil) do
    # resize_image is called by UploadLive before persisting, so the binary
    # arriving here is already small. Call again only as a safety net.
    {image_binary, mime_type} = do_resize_image(image_binary, mime_type)

    with {:ok, response} <- call_gemini_with_fallback(image_binary, mime_type),
         {:ok, %{name: name, ingredients: ingredients, categories: categories, barcode: barcode,
                  energy_kcal_per_100: energy_kcal_per_100, energy_unit: energy_unit,
                  volume_ml: volume_ml}} <-
           GeminiParser.parse_gemini_response(response),
         {:ok, product} <-
           Catalog.create_product_with_ingredients_and_categories(
             name,
             ingredients,
             categories,
             %{image_url: image_url, barcode: barcode,
               energy_kcal_per_100: energy_kcal_per_100,
               energy_unit: energy_unit,
               volume_ml: volume_ml}
           ) do
      {:ok, product}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp call_gemini_with_fallback(image_binary, mime_type) do
    Enum.reduce_while(@gemini_models, {:error, "No models available"}, fn model, _acc ->
      case call_gemini(model, image_binary, mime_type) do
        {:ok, response} ->
          {:halt, {:ok, response}}

        {:error, :rate_limited, retry_after} ->
          {:cont, {:error, "Quota exceeded on all models. Retry after #{retry_after}."}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp call_gemini(model, image_binary, mime_type) do
    api_key = Application.fetch_env!(:angivaonguoi, :gemini_api_key)
    url = "#{@gemini_base}/#{model}:generateContent?key=#{api_key}"
    encoded = Base.encode64(image_binary)

    body = %{
      "contents" => [
        %{
          "parts" => [
            %{"text" => GeminiParser.build_prompt()},
            %{"inline_data" => %{"mime_type" => mime_type, "data" => encoded}}
          ]
        }
      ],
      "generationConfig" => %{"temperature" => 0.1, "maxOutputTokens" => 4096}
    }

    case Req.post(url, json: body, receive_timeout: 60_000) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: 429, body: body}} ->
        retry_after = extract_retry_delay(body)
        {:error, :rate_limited, retry_after}

      {:ok, %{status: status, body: body}} ->
        {:error, "Gemini API error #{status}: #{error_message(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp extract_retry_delay(body) do
    body
    |> get_in(["error", "details"])
    |> List.wrap()
    |> Enum.find_value(fn
      %{"@type" => "type.googleapis.com/google.rpc.RetryInfo", "retryDelay" => delay} -> delay
      _ -> nil
    end)
    |> case do
      nil -> "a moment"
      delay -> delay
    end
  end

  defp error_message(body) do
    get_in(body, ["error", "message"]) || inspect(body)
  end

  @doc """
  Resize the longest edge to ≤ 1024px and re-encode as JPEG quality ~75.
  Returns `{resized_binary, "image/jpeg"}`.
  Falls back to `{original_binary, original_mime}` if ffmpeg is unavailable.
  Public so UploadLive can resize before persisting to disk.
  """
  def resize_image(binary, mime_type), do: do_resize_image(binary, mime_type)

  # Resize the longest edge to ≤ 1024px and re-encode as JPEG quality ~75.
  # Reduces a typical 4 MB phone photo to ~100–200 KB before base64 encoding,
  # cutting Gemini token usage and latency significantly.
  # Falls back to the original binary if ffmpeg is unavailable or fails.
  defp do_resize_image(binary, mime_type) do
    tmp_in = Path.join(System.tmp_dir!(), "fcheck_in_#{:rand.uniform(999_999)}.jpg")
    tmp_out = Path.join(System.tmp_dir!(), "fcheck_out_#{:rand.uniform(999_999)}.jpg")

    try do
      File.write!(tmp_in, binary)

      case System.cmd(
             "ffmpeg",
             [
               "-y", "-i", tmp_in,
               "-vf", "scale='if(gt(iw\\,ih)\\,min(iw\\,1024)\\,-2)':'if(gt(ih\\,iw)\\,min(ih\\,1024)\\,-2)'",
               "-q:v", "5",
               tmp_out
             ],
             stderr_to_stdout: true
           ) do
        {_, 0} ->
          resized = File.read!(tmp_out)
          {resized, "image/jpeg"}

        {err, code} ->
          require Logger
          Logger.warning("ffmpeg resize failed (exit #{code}): #{err}")
          {binary, mime_type}
      end
    rescue
      e ->
        require Logger
        Logger.warning("resize_image error: #{inspect(e)}")
        {binary, mime_type}
    after
      File.rm(tmp_in)
      File.rm(tmp_out)
    end
  end
end
