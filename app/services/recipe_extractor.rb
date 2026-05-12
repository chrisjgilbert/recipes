class RecipeExtractor
  class Error < StandardError; end
  class NotRecipeError < Error; end

  MODEL = "claude-sonnet-4-6"

  SAVE_RECIPE_TOOL = {
    name: "save_recipe",
    description: "Extract a recipe from the provided webpage markdown into structured fields.",
    input_schema: {
      type: "object",
      properties: {
        is_recipe: {type: "boolean", description: "True if the page is a recipe."},
        title: {type: "string"},
        chef: {type: ["string", "null"], description: "Original recipe author or chef name."},
        description: {
          type: ["string", "null"],
          description: "Short summary or standfirst only when the source clearly provides one. " \
                       "Otherwise return null rather than inventing copy or moving notes here."
        },
        image_url: {type: ["string", "null"]},
        prep_time_minutes: {type: ["integer", "null"]},
        cook_time_minutes: {type: ["integer", "null"]},
        total_time_minutes: {type: ["integer", "null"]},
        servings: {type: ["integer", "null"]},
        notes: {
          type: ["string", "null"],
          description: "Recipe-level notes that are not part of the main method, such as " \
                       "serving, storage, make-ahead, or substitution advice."
        },
        parts: {
          type: "array",
          minItems: 1,
          description: "One entry per section of the recipe. If the source has named " \
                       "sections (e.g. \"For the rub\", \"For the sauce\"), use those " \
                       "names. Otherwise return a single part with name=\"\".",
          items: {
            type: "object",
            properties: {
              name: {
                type: "string",
                description: "Section heading, e.g. \"For the rub\". Use \"\" if the " \
                             "source is not divided into named sections."
              },
              ingredients: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    quantity: {
                      type: ["string", "null"],
                      description: "Ingredient amount when clear from the source. Do not " \
                                   "guess or invent missing quantities."
                    },
                    unit: {
                      type: ["string", "null"],
                      description: "Ingredient unit when clear from the source. Never use " \
                                   "bare `t` or `T`; use `tsp` or `tbsp` instead. Keep " \
                                   "`cup`/`cups` as extracted units rather than converting them."
                    },
                    name: {type: "string"},
                    notes: {
                      type: ["string", "null"],
                      description: "Ingredient-specific note or qualifier such as " \
                                   "`softened`, `divided`, or `plus extra for greasing`."
                    }
                  },
                  required: ["name"]
                }
              },
              instructions: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    step: {type: "integer"},
                    text: {type: "string"}
                  },
                  required: ["step", "text"]
                }
              }
            },
            required: ["name", "ingredients", "instructions"]
          }
        }
      },
      required: ["is_recipe", "title", "parts"]
    }
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You extract structured recipes from webpage markdown. Given the page content, call
    the save_recipe tool with the fields you can confidently extract. Preserve original
    wording in ingredient names and instruction text, but do not invent information.
    Set is_recipe=false only if the page clearly is not a recipe.

    ## Field semantics

    - `description`: a short summary/standfirst only when the source clearly provides
      one near the title or intro. Otherwise return null.
    - `notes`: recipe-level advice that is not part of the main method, such as
      serving, storage, make-ahead, or substitution notes.
    - Ingredient `notes`: ingredient-specific qualifiers like `softened`, `divided`,
      `room temperature`, or `plus extra for greasing`.

    ## Measurements

    - Extract `quantity` and `unit` when they are clearly stated.
    - Never use bare `t` or `T`; always write `tsp` for teaspoon and `tbsp` for
      tablespoon.
    - Keep `cup`/`cups` as extracted units at this stage. Do not convert units to UK
      or metric equivalents in the tool response.
    - Do not guess missing quantities or units.

    ## Parts (critical)

    Recipes are very often built from multiple components. Whenever the source groups
    its ingredients and/or instructions under headings — anywhere in the page — return
    one part per named section, using the source's own heading text as the part name.
    Common patterns include:

    - "For the rub" / "For the sauce" / "For the meat"
    - "Sponge" / "Filling" / "Frosting" / "Buttercream" / "Glaze"
    - "Dough" / "Sauce" / "Topping"
    - "Marinade" / "Dressing" / "Garnish"
    - Any heading that introduces its own ingredient list or method block

    Do not flatten, merge, or combine sections into a single part. If the source has
    three named sections, return three parts. If a section lists ingredients but no
    method of its own, still include it as a part with an empty `instructions` array,
    and vice versa. Number `step` from 1 within each part.

    Only return a single part with name="" when the source is genuinely a single
    undivided list of ingredients and instructions with no internal section headings.
  PROMPT

  def self.call(markdown, source_url: nil)
    new.call(markdown, source_url: source_url)
  end

  def call(markdown, source_url: nil)
    response = request_with_retry(markdown)
    tool_use = extract_tool_use(response)
    data = tool_use.fetch("input")
    raise NotRecipeError, "Page is not a recipe" unless data["is_recipe"]

    normalize(data, source_url)
  end

  private

  def request_with_retry(markdown)
    client.messages(parameters: message_params(markdown))
  rescue Anthropic::Error, Faraday::Error => e
    raise Error, e.message
  end

  def message_params(markdown)
    {
      model: MODEL,
      max_tokens: 4096,
      system: [
        {
          type: "text",
          text: SYSTEM_PROMPT,
          cache_control: {type: "ephemeral"}
        }
      ],
      tools: [SAVE_RECIPE_TOOL],
      tool_choice: {type: "tool", name: "save_recipe"},
      messages: [
        {role: "user", content: markdown}
      ]
    }
  end

  def extract_tool_use(response)
    content = response.is_a?(Hash) ? response["content"] : response
    raise Error, "No content in response" if content.nil?
    block = content.find { |b| b["type"] == "tool_use" || b[:type] == "tool_use" }
    raise Error, "No tool_use block returned" unless block
    block.transform_keys(&:to_s)
  end

  def normalize(data, source_url)
    data.slice(
      "title", "chef", "description", "image_url",
      "prep_time_minutes", "cook_time_minutes", "total_time_minutes",
      "servings", "notes"
    ).merge(
      "source_url" => source_url,
      "source_site" => begin
        URI(source_url).host
      rescue
        nil
      end,
      "parts" => IngredientUnitNormalizer.normalize_parts(
        Array(data["parts"]).map { |p| normalize_part(p) }
      )
    )
  end

  def normalize_part(part)
    part = part.is_a?(Hash) ? part.transform_keys(&:to_s) : {}
    {
      "name" => part["name"].to_s,
      "ingredients" => Array(part["ingredients"]).map { |ingredient| normalize_ingredient(ingredient) },
      "instructions" => Array(part["instructions"]).map { |instruction| normalize_instruction(instruction) }
    }
  end

  def normalize_ingredient(ingredient)
    ingredient = ingredient.is_a?(Hash) ? ingredient.transform_keys(&:to_s) : {}
    ingredient.slice("quantity", "unit", "name", "notes")
  end

  def normalize_instruction(instruction)
    instruction = instruction.is_a?(Hash) ? instruction.transform_keys(&:to_s) : {}
    instruction.slice("step", "text")
  end

  def client
    @client ||= Anthropic::Client.new(
      access_token: Rails.application.credentials.anthropic_api_key!,
      request_timeout: 90
    )
  end
end
