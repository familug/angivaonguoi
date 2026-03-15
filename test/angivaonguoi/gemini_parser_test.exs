defmodule Angivaonguoi.GeminiParserTest do
  use ExUnit.Case, async: true

  alias Angivaonguoi.GeminiParser

  describe "parse_gemini_response/1" do
    test "extracts product name, barcode, ingredients with amounts, and categories" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{
                  "text" =>
                    ~s({"product_name": "Seaweed Snack", "barcode": "8801234567890", "ingredients": [{"name": "Seaweed", "amount_raw": "61%", "amount_percent": 61.0}, {"name": "Salt", "amount_raw": null, "amount_percent": null}], "categories": ["Snacks"]})
                }
              ]
            }
          }
        ]
      }

      assert {:ok, %{name: "Seaweed Snack", barcode: "8801234567890", categories: ["Snacks"], ingredients: ingredients}} =
               GeminiParser.parse_gemini_response(response)

      assert length(ingredients) == 2
      seaweed = Enum.find(ingredients, &(&1.name == "Seaweed"))
      assert seaweed.amount_raw == "61%"
      assert Decimal.equal?(seaweed.amount_percent, Decimal.new("61.0"))

      salt = Enum.find(ingredients, &(&1.name == "Salt"))
      assert is_nil(salt.amount_percent)
    end

    test "handles legacy plain string ingredients gracefully" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{
                  "text" =>
                    ~s({"product_name": "Heineken", "ingredients": ["Water", "Barley Malt", "Hops"], "categories": ["Beer", "Alcohol"]})
                }
              ]
            }
          }
        ]
      }

      assert {:ok, %{name: "Heineken", ingredients: ingredients}} =
               GeminiParser.parse_gemini_response(response)

      assert Enum.all?(ingredients, &is_map/1)
      assert Enum.map(ingredients, & &1.name) == ["Water", "Barley Malt", "Hops"]
    end

    test "extracts product name and ingredients when JSON is wrapped in markdown code block" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{
                  "text" =>
                    "```json\n{\"product_name\": \"Lay's Chips\", \"ingredients\": [\"Potatoes\", \"Vegetable Oil\", \"Salt\"], \"categories\": [\"Snacks\", \"Chips\"]}\n```"
                }
              ]
            }
          }
        ]
      }

      assert {:ok, %{name: "Lay's Chips", categories: ["Snacks", "Chips"], ingredients: ingredients}} =
               GeminiParser.parse_gemini_response(response)

      assert Enum.map(ingredients, & &1.name) == ["Potatoes", "Vegetable Oil", "Salt"]
    end

    test "defaults barcode to nil and categories to [] when absent" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{"text" => ~s({"product_name": "Generic Food", "ingredients": ["Water"]})}
              ]
            }
          }
        ]
      }

      assert {:ok, %{name: "Generic Food", barcode: nil, categories: [], ingredients: [%{name: "Water"}]}} =
               GeminiParser.parse_gemini_response(response)
    end

    test "returns error when response has no candidates" do
      assert {:error, _reason} = GeminiParser.parse_gemini_response(%{"candidates" => []})
    end

    test "returns error when JSON is malformed" do
      response = %{
        "candidates" => [
          %{"content" => %{"parts" => [%{"text" => "not valid json at all"}]}}
        ]
      }

      assert {:error, _reason} = GeminiParser.parse_gemini_response(response)
    end

    test "returns error when product_name is missing" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"text" => ~s({"ingredients": ["Sugar"], "categories": ["Snacks"]})}]
            }
          }
        ]
      }

      assert {:error, _reason} = GeminiParser.parse_gemini_response(response)
    end

    test "parses energy_kcal_per_100, energy_unit, and volume_ml" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{
                  "text" =>
                    ~s({"product_name": "Coca-Cola", "barcode": null, "ingredients": [], "categories": ["Soft Drinks"], "energy_kcal_per_100": 42.0, "energy_unit": "100ml", "volume_ml": 330.0})
                }
              ]
            }
          }
        ]
      }

      assert {:ok, result} = GeminiParser.parse_gemini_response(response)
      assert Decimal.equal?(result.energy_kcal_per_100, Decimal.new("42.00"))
      assert result.energy_unit == "100ml"
      assert Decimal.equal?(result.volume_ml, Decimal.new("330.00"))
    end

    test "energy and volume fields default to nil when absent" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{"text" => ~s({"product_name": "Plain Water", "ingredients": [], "categories": []})}
              ]
            }
          }
        ]
      }

      assert {:ok, result} = GeminiParser.parse_gemini_response(response)
      assert is_nil(result.energy_kcal_per_100)
      assert is_nil(result.energy_unit)
      assert is_nil(result.volume_ml)
    end

    test "energy_kcal_per_100 accepts string numeric values" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{
                  "text" =>
                    ~s({"product_name": "Beer X", "ingredients": [], "categories": [], "energy_kcal_per_100": "46", "energy_unit": "100ml", "volume_ml": null})
                }
              ]
            }
          }
        ]
      }

      assert {:ok, result} = GeminiParser.parse_gemini_response(response)
      assert Decimal.equal?(result.energy_kcal_per_100, Decimal.new("46"))
    end

    test "energy fields are nil when set to null in JSON" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{
                  "text" =>
                    ~s({"product_name": "Mystery Bar", "ingredients": [], "categories": [], "energy_kcal_per_100": null, "energy_unit": null, "volume_ml": null})
                }
              ]
            }
          }
        ]
      }

      assert {:ok, result} = GeminiParser.parse_gemini_response(response)
      assert is_nil(result.energy_kcal_per_100)
      assert is_nil(result.energy_unit)
      assert is_nil(result.volume_ml)
    end
  end

  describe "build_prompt/0" do
    test "returns a prompt mentioning product_name, ingredients, and categories" do
      prompt = GeminiParser.build_prompt()
      assert is_binary(prompt)
      assert String.length(prompt) > 0
      assert prompt =~ "product_name"
      assert prompt =~ "ingredients"
      assert prompt =~ "categories"
    end

    test "prompt includes energy extraction instructions" do
      prompt = GeminiParser.build_prompt()
      assert prompt =~ "energy_kcal_per_100"
      assert prompt =~ "energy_unit"
      assert prompt =~ "volume_ml"
    end

    test "prompt instructs to convert kJ to kcal" do
      prompt = GeminiParser.build_prompt()
      assert prompt =~ "kJ"
      assert prompt =~ "4.184"
    end
  end
end
