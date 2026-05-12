require "rails_helper"

RSpec.describe RecipeExtractor do
  before do
    allow(Rails.application.credentials).to receive(:anthropic_api_key!).and_return("test-key")
  end

  def tool_response(input)
    {
      "id" => "msg_1",
      "type" => "message",
      "role" => "assistant",
      "model" => RecipeExtractor::MODEL,
      "content" => [
        {"type" => "tool_use", "id" => "tu_1", "name" => "save_recipe", "input" => input}
      ],
      "stop_reason" => "tool_use",
      "usage" => {"input_tokens" => 10, "output_tokens" => 5}
    }
  end

  it "returns normalized fields for a single-part recipe response" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        body: tool_response({
          "is_recipe" => true,
          "title" => "Spicy Ramen",
          "chef" => "Ivan Orkin",
          "description" => "Weeknight bowl",
          "image_url" => nil,
          "prep_time_minutes" => 5,
          "cook_time_minutes" => 15,
          "total_time_minutes" => 20,
          "servings" => 2,
          "notes" => nil,
          "parts" => [
            {
              "name" => "",
              "ingredients" => [{"name" => "noodles", "quantity" => "200", "unit" => "g", "notes" => nil}],
              "instructions" => [{"step" => 1, "text" => "Boil noodles"}]
            }
          ]
        }).to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = described_class.call("# markdown", source_url: "https://example.com/ramen")

    expect(result["title"]).to eq("Spicy Ramen")
    expect(result["chef"]).to eq("Ivan Orkin")
    expect(result["source_url"]).to eq("https://example.com/ramen")
    expect(result["source_site"]).to eq("example.com")
    expect(result).not_to have_key("ingredients")
    expect(result).not_to have_key("instructions")
    expect(result["parts"].length).to eq(1)
    ingredient = result["parts"].first["ingredients"].first
    expect(ingredient["name"]).to eq("noodles")
    expect(ingredient["canonical_quantity"]).to eq("200")
    expect(ingredient["canonical_unit"]).to eq("g")
  end

  it "passes through multi-part recipes" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        body: tool_response({
          "is_recipe" => true,
          "title" => "Pork Shoulder",
          "parts" => [
            {
              "name" => "For the rub",
              "ingredients" => [{"name" => "paprika"}],
              "instructions" => [{"step" => 1, "text" => "Mix the rub"}]
            },
            {
              "name" => "For the meat",
              "ingredients" => [{"name" => "pork shoulder"}],
              "instructions" => [{"step" => 1, "text" => "Smoke low and slow"}]
            }
          ]
        }).to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = described_class.call("# markdown", source_url: "https://example.com/pork")

    expect(result["parts"].length).to eq(2)
    expect(result["parts"].first).to include("name" => "For the rub")
    expect(result["parts"].first["ingredients"].first["name"]).to eq("paprika")
    expect(result["parts"].last["instructions"].first["text"]).to eq("Smoke low and slow")
  end

  it "preserves raw units while adding canonical UK measurements" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        body: tool_response({
          "is_recipe" => true,
          "title" => "Cake Batter",
          "parts" => [
            {
              "name" => "",
              "ingredients" => [
                {"name" => "vanilla", "quantity" => "1", "unit" => "t", "notes" => "optional"},
                {"name" => "milk", "quantity" => "1/2", "unit" => "cup", "notes" => nil},
                {"name" => "butter", "quantity" => "1", "unit" => "T", "notes" => "melted"}
              ],
              "instructions" => [{"step" => 1, "text" => "Mix everything together"}]
            }
          ]
        }).to_json,
        headers: {"Content-Type" => "application/json"}
      )

    ingredients = described_class.call("# markdown").dig("parts", 0, "ingredients")

    expect(ingredients[0]).to include(
      "quantity" => "1",
      "unit" => "t",
      "canonical_quantity" => "1",
      "canonical_unit" => "tsp",
      "notes" => "optional"
    )
    expect(ingredients[1]).to include(
      "quantity" => "1/2",
      "unit" => "cup",
      "canonical_quantity" => "120",
      "canonical_unit" => "ml"
    )
    expect(ingredients[2]).to include(
      "quantity" => "1",
      "unit" => "T",
      "canonical_quantity" => "1",
      "canonical_unit" => "tbsp",
      "notes" => "melted"
    )
  end

  it "uses claude-sonnet-4-6 for better multi-part extraction" do
    request_body = nil
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with { |req|
        request_body = JSON.parse(req.body)
        true
    }
      .to_return(
        status: 200,
        body: tool_response({
          "is_recipe" => true, "title" => "x", "parts" => [{"name" => "", "ingredients" => [], "instructions" => []}]
        }).to_json,
        headers: {"Content-Type" => "application/json"}
      )

    described_class.call("# markdown")

    expect(request_body["model"]).to eq("claude-sonnet-4-6")
  end

  it "system prompt instructs the model to preserve every named section as a separate part" do
    prompt = RecipeExtractor::SYSTEM_PROMPT
    # Should explicitly forbid flattening
    expect(prompt).to match(/do not (flatten|merge|combine)/i)
    # Should give concrete examples beyond just "For the X" — sponge/filling/frosting style
    expect(prompt).to match(/sponge|filling|frosting|dough|sauce/i)
    # Should default to multiple parts when sections exist
    expect(prompt).to match(/one part per (named )?section/i)
  end

  it "documents description, notes, and unambiguous spoon units" do
    prompt = RecipeExtractor::SYSTEM_PROMPT
    ingredient_properties = RecipeExtractor::SAVE_RECIPE_TOOL.dig(
      :input_schema, :properties, :parts, :items, :properties, :ingredients, :items, :properties
    )

    expect(prompt).to match(/description.*summary\/standfirst/i)
    expect(prompt).to match(/recipe-level advice/i)
    expect(prompt).to match(/Ingredient `notes`/i)
    expect(prompt).to match(/never use bare `t` or `T`/i)
    expect(prompt).to match(/tsp.*tbsp/i)

    expect(RecipeExtractor::SAVE_RECIPE_TOOL.dig(:input_schema, :properties, :description, :description))
      .to match(/standfirst|summary/i)
    expect(RecipeExtractor::SAVE_RECIPE_TOOL.dig(:input_schema, :properties, :notes, :description))
      .to match(/storage|make-ahead|substitution/i)
    expect(ingredient_properties.dig(:notes, :description)).to match(/softened|divided/i)
    expect(ingredient_properties.dig(:unit, :description)).to match(/tsp|tbsp/)
  end

  it "wraps Faraday timeouts in RecipeExtractor::Error" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_timeout

    expect { described_class.call("x") }.to raise_error(RecipeExtractor::Error)
  end

  it "raises NotRecipeError when the model says is_recipe: false" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 200,
      body: tool_response({
        "is_recipe" => false, "title" => "N/A", "parts" => []
      }).to_json,
      headers: {"Content-Type" => "application/json"}
    )

    expect { described_class.call("x") }.to raise_error(RecipeExtractor::NotRecipeError)
  end
end
