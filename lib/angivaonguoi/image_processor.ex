defmodule Angivaonguoi.ImageProcessor do
  @moduledoc """
  Processes uploaded product images via the Gemini Vision API and persists
  the extracted product name and ingredients to the database.
  """

  alias Angivaonguoi.{Catalog, GeminiParser}

  @gemini_models ~w(gemini-2.5-flash gemini-2.0-flash gemini-2.0-flash-lite)
  @gemini_base "https://generativelanguage.googleapis.com/v1beta/models"

  @doc """
  Given a raw binary image and its MIME type, calls Gemini to extract product
  information and saves it to the database.

  Returns `{:ok, product}` or `{:error, reason}`.
  """
  def process_image(image_binary, mime_type \\ "image/jpeg", image_url \\ nil) do
    with {:ok, response} <- call_gemini_with_fallback(image_binary, mime_type),
         {:ok, %{name: name, ingredients: ingredients, categories: categories, barcode: barcode}} <-
           GeminiParser.parse_gemini_response(response),
         {:ok, product} <-
           Catalog.create_product_with_ingredients_and_categories(
             name,
             ingredients,
             categories,
             %{image_url: image_url, barcode: barcode}
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
      "generationConfig" => %{"temperature" => 0.1, "maxOutputTokens" => 2048}
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
end
