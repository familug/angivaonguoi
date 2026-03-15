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
         {:ok, decoded} <- decode_json(json),
         {:ok, name} <- fetch_name(decoded),
         {:ok, ingredients} <- fetch_ingredients(decoded),
         {:ok, categories} <- fetch_categories(decoded) do
      {:ok,
       %{
         name: name,
         ingredients: ingredients,
         categories: categories,
         barcode: fetch_barcode(decoded),
         energy_kcal_per_100: fetch_decimal(decoded, "energy_kcal_per_100"),
         energy_unit: fetch_string(decoded, "energy_unit"),
         volume_ml: fetch_decimal(decoded, "volume_ml")
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
    You are a food label data extractor. Your job is to read a product packaging image and extract specific fields.

    STRICT RULES — read carefully before extracting:
    - Only extract text that is CLEARLY VISIBLE and LEGIBLE in the image. If you cannot read it clearly, use null.
    - Do NOT guess, infer, or hallucinate any value. If unsure, use null.
    - The label may contain a lot of text (nutrition tables, marketing slogans, warnings, certifications). IGNORE everything except the fields listed below.

    FIELDS TO EXTRACT:

    1. PRODUCT NAME
       - Brand + product type as printed on the front of the pack (e.g. "Heineken Beer", "Lay's Classic Chips", "Mì Hảo Hảo").
       - Keep exactly as printed. If Vietnamese, keep Vietnamese. Do NOT translate.

    2. BARCODE
       - The numeric barcode digits (EAN-13, UPC-A, etc.) if clearly visible, or null.

    3. INGREDIENTS LIST
       - Find the section explicitly labelled "Ingredients", "Thành phần", or equivalent.
       - DO NOT read from the nutrition facts table — that is a different section.
       - Copy each ingredient name EXACTLY as printed. Do NOT simplify, merge, or paraphrase.
         Example: if the label lists "Đường HFCS" and "Đường mía" as separate items, they are TWO separate entries. Never merge them into "Đường".
       - Each ingredient must have:
         - "name": ingredient name only, WITHOUT any percentage or amount
         - "amount_raw": the amount/percentage string as printed (e.g. "61%", "4%", "200mg"), or null
         - "amount_percent": the numeric percentage as a float (e.g. 61.0), or null if not a percentage

    4. CATEGORIES
       - Broad English category tags for this product type (e.g. "Beer", "Soft Drinks", "Instant Noodles", "Chips", "Dairy").
       - ALWAYS English, regardless of the product language.

    5. ENERGY (from the NUTRITION FACTS panel only — ignore marketing claims like "only 90 kcal!")
       - "energy_kcal_per_100": kcal per 100ml or per 100g as a number, or null.
         If shown in kJ, convert: kJ ÷ 4.184, round to 1 decimal.
       - "energy_unit": denominator as printed, e.g. "100ml", "100g", "serving (330ml)", or null.
       - "volume_ml": total package volume in ml (e.g. 330, 500), or null if not applicable or not shown.

    Return ONLY valid JSON, no extra text, no markdown:
    {
      "product_name": "<name or null>",
      "barcode": "<digits or null>",
      "ingredients": [
        {"name": "<ingredient>", "amount_raw": "<raw or null>", "amount_percent": <number or null>},
        ...
      ],
      "categories": ["<category>", ...],
      "energy_kcal_per_100": <number or null>,
      "energy_unit": "<string or null>",
      "volume_ml": <number or null>
    }
    If the product name cannot be determined, return:
    {"product_name": null, "barcode": null, "ingredients": [], "categories": [], "energy_kcal_per_100": null, "energy_unit": null, "volume_ml": null}
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp decode_json(json) do
    case Jason.decode(json) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, %Jason.DecodeError{} = err} ->
        require Logger
        Logger.error("Gemini returned truncated/invalid JSON: #{inspect(err)}")
        {:error, "AI response was cut off mid-way (JSON truncated). Try a clearer photo or retry."}
    end
  end

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

  defp fetch_decimal(map, key) do
    case map[key] do
      nil -> nil
      v when is_number(v) -> Decimal.from_float(v / 1) |> Decimal.round(2)
      v when is_binary(v) ->
        case Decimal.parse(v) do
          {d, ""} -> d
          _ -> nil
        end
      _ -> nil
    end
  end

  defp fetch_string(map, key) do
    case map[key] do
      v when is_binary(v) and v != "" -> v
      _ -> nil
    end
  end
end
