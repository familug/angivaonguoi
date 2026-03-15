defmodule Angivaonguoi.ImageProcessor do
  @moduledoc """
  Processes uploaded product images via the Gemini Vision API and persists
  the extracted product name and ingredients to the database.
  """

  alias Angivaonguoi.{Catalog, GeminiParser}

  # Fallback chain — tries models in order, moves to next on 429 rate-limit:
  #
  # 1. gemini-3.1-flash-lite-preview — newest, fastest (paid preview)
  # 2. gemini-3-flash-preview         — Gemini 3 Flash (paid preview)
  # 3. gemini-2.5-flash               — free tier, 10 RPM / 250 RPD
  # 4. gemini-2.5-flash-lite          — free tier, higher daily quota
  @gemini_models ~w(gemini-3.1-flash-lite-preview gemini-3-flash-preview gemini-2.5-flash gemini-2.5-flash-lite)
  @gemini_base "https://generativelanguage.googleapis.com/v1beta/models"

  @doc """
  Given one or more `{binary, mime_type}` image tuples and their persisted URLs,
  calls Gemini with all images in a single request and saves the result.

  Returns `{:ok, product}` or `{:error, reason}`.
  """
  def process_images(images, image_urls) when is_list(images) and is_list(image_urls) do
    resized = Enum.map(images, fn {binary, mime} -> do_resize_image(binary, mime) end)

    with {:ok, {response, model}} <- call_gemini_with_fallback_multi(resized),
         {:ok, %{name: name, ingredients: ingredients, categories: categories, barcode: barcode,
                  energy_kcal_per_100: energy_kcal_per_100, energy_unit: energy_unit,
                  volume_ml: volume_ml}} <-
           GeminiParser.parse_gemini_response(response),
         {:ok, product} <-
           Catalog.create_product_with_ingredients_and_categories(
             name,
             ingredients,
             categories,
             %{image_url: List.first(image_urls),
               image_urls: image_urls,
               barcode: barcode,
               energy_kcal_per_100: energy_kcal_per_100,
               energy_unit: energy_unit,
               volume_ml: volume_ml,
               gemini_model: model}
           ) do
      {:ok, product}
    else
      {:error, {:duplicate, existing}} -> {:error, {:duplicate, existing}}
      other -> other
    end
  end

  @doc "Convenience wrapper for a single image (backwards compat)."
  def process_image(image_binary, mime_type \\ "image/jpeg", image_url \\ nil) do
    process_images([{image_binary, mime_type}], [image_url])
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp call_gemini_with_fallback_multi(images) do
    Enum.reduce_while(@gemini_models, {:error, "No models available"}, fn model, _acc ->
      case call_gemini_multi(model, images) do
        {:ok, response} ->
          {:halt, {:ok, {response, model}}}

        {:error, :rate_limited, retry_after} ->
          {:cont, {:error, "Quota exceeded on all models. Retry after #{retry_after}."}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp call_gemini_multi(model, images) do
    api_key = Application.fetch_env!(:angivaonguoi, :gemini_api_key)
    url = "#{@gemini_base}/#{model}:generateContent?key=#{api_key}"

    image_parts =
      Enum.map(images, fn {binary, mime} ->
        %{"inline_data" => %{"mime_type" => mime, "data" => Base.encode64(binary)}}
      end)

    body = %{
      "contents" => [
        %{
          "parts" => [%{"text" => GeminiParser.build_prompt()}] ++ image_parts
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
