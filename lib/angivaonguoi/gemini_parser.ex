defmodule Angivaonguoi.GeminiParser do
  @moduledoc """
  Parses Gemini API responses to extract product names, ingredient lists
  (with optional amounts), and categories.
  """

  @doc """
  Extracts product name, ingredients (as maps with :name, :amount_percent, :amount_raw),
  and categories from a raw Gemini API response map.
  """
  def parse_gemini_response(%{"candidates" => [candidate | _]}) do
    finish_reason = candidate["finishReason"]

    if finish_reason not in [nil, "STOP"] do
      require Logger
      Logger.error("Gemini finishReason=#{finish_reason}, candidate: #{inspect(candidate)}")
    end

    with text <- get_in(candidate, ["content", "parts", Access.at(0), "text"]),
         {:ok, json} <- extract_json(text),
         {:ok, decoded} <- Jason.decode(json),
         {:ok, name} <- fetch_name(decoded),
         {:ok, ingredients} <- fetch_ingredients(decoded),
         {:ok, categories} <- fetch_categories(decoded) do
      {:ok,
       %{
         name: name,
         ingredients: ingredients,
         categories: categories,
         barcode: fetch_barcode(decoded)
       }}
    end
  end

  def parse_gemini_response(%{"candidates" => []}),
    do: {:error, "No candidates in Gemini response"}

  def parse_gemini_response(_), do: {:error, "Unexpected Gemini response format"}

  @doc """
  Returns the text prompt to send to Gemini along with the product image.
  """
  def build_prompt do
    """
    Analyze this food or beverage product image. Extract:
    1. The product name (brand + product type, e.g. "Heineken Beer", "Lay's Classic Chips")
    2. The barcode number if visible on the label (EAN-13, UPC-A, etc.), or null if not visible.
    3. The full list of ingredients as printed on the label.
       For each ingredient, extract:
       - "name": the ingredient name WITHOUT the percentage/amount
       - "amount_raw": the raw amount/percentage string as printed (e.g. "61%", "200mg", "1.2g/100ml"), or null if not shown
       - "amount_percent": the numeric percentage as a number (e.g. 61.0), or null if not a percentage
    4. The product categories (e.g. "Beer", "Soft Drinks", "Chips", "Snacks", "Dairy", "Alcohol").
       Use broad, reusable categories so similar products share the same category.

    Return ONLY valid JSON, no extra text:
    {
      "product_name": "<name>",
      "barcode": "<barcode digits or null>",
      "ingredients": [
        {"name": "<ingredient>", "amount_raw": "<raw or null>", "amount_percent": <number or null>},
        ...
      ],
      "categories": ["<category1>", ...]
    }
    If you cannot determine the product name, return:
    {"product_name": null, "barcode": null, "ingredients": [], "categories": []}
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp extract_json(nil), do: {:error, "No text in Gemini response part"}

  defp extract_json(text) do
    cleaned =
      text
      |> String.replace(~r/```json\s*/i, "")
      |> String.replace(~r/```\s*/, "")
      |> String.trim()

    case Regex.run(~r/\{.*\}/s, cleaned) do
      [json | _] ->
        {:ok, json}

      nil ->
        require Logger
        Logger.error("Gemini response had no JSON object. Raw text: #{inspect(text)}")

        hint =
          cond do
            String.contains?(text, "cannot") or String.contains?(text, "unable") or
                String.contains?(text, "can't") ->
              "Gemini could not read this image. Try a clearer photo showing the ingredient label."

            true ->
              "Unexpected response from AI. Try a clearer photo of the product label."
          end

        {:error, hint}
    end
  end

  defp fetch_name(%{"product_name" => name}) when is_binary(name) and name != "",
    do: {:ok, name}

  defp fetch_name(_), do: {:error, "Missing or invalid product_name in parsed JSON"}

  defp fetch_ingredients(%{"ingredients" => list}) when is_list(list) do
    {:ok, Enum.map(list, &normalise_ingredient/1)}
  end

  defp fetch_ingredients(_), do: {:ok, []}

  defp fetch_categories(%{"categories" => list}) when is_list(list), do: {:ok, list}
  defp fetch_categories(_), do: {:ok, []}

  defp fetch_barcode(%{"barcode" => barcode}) when is_binary(barcode) and barcode != "",
    do: barcode

  defp fetch_barcode(_), do: nil

  # Plain string → map with nil amounts
  defp normalise_ingredient(name) when is_binary(name) do
    %{name: name, amount_raw: nil, amount_percent: nil}
  end

  # Map from Gemini with name + optional amounts
  defp normalise_ingredient(%{"name" => name} = map) do
    amount_percent =
      case map["amount_percent"] do
        nil -> nil
        v when is_number(v) -> Decimal.from_float(v / 1) |> Decimal.round(3)
        v when is_binary(v) -> Decimal.new(v)
      end

    %{
      name: name,
      amount_raw: map["amount_raw"],
      amount_percent: amount_percent
    }
  end

  defp normalise_ingredient(_), do: %{name: "Unknown", amount_raw: nil, amount_percent: nil}
end
