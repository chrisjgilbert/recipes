require "base64"

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
        chef: {
          type: ["string", "null"],
          description: "The original creator of the recipe — the chef or food writer who developed it. " \
                       "If a well-known chef's recipe is republished on someone else's website, use the " \
                       "chef's name, not the website author. Return null if the original creator is not mentioned."
        },
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

    - `chef`: the original creator of the recipe — the chef or food writer who developed
      it. Many pages republish a well-known chef's recipe; in that case use the chef's
      name, not the website author or blogger. Return null if the original creator is
      not clearly identified.
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

  def self.call_image(image_bytes, media_type:)
    new.call_image(image_bytes, media_type: media_type)
  end

  def call(markdown, source_url: nil)
    params = message_params(markdown)
    trace_input = {
      source_url: source_url,
      source_site: source_site(source_url),
      markdown_length: markdown.to_s.length
    }
    run(params, source_url: source_url, trace_input: trace_input)
  end

  def call_image(image_bytes, media_type:)
    params = image_message_params(image_bytes, media_type)
    trace_input = {
      source: "image",
      media_type: media_type,
      image_byte_size: image_bytes.to_s.bytesize
    }
    run(params, source_url: nil, trace_input: trace_input)
  end

  private

  def run(params, source_url:, trace_input:)
    return extract_recipe(params, source_url) unless langfuse_enabled?

    Langfuse.trace("recipe-extraction", input: trace_input, metadata: trace_input) do |trace|
      generation = trace.generation(
        name: "anthropic.messages",
        model: MODEL,
        input: params,
        model_parameters: {
          max_tokens: params[:max_tokens],
          tool_choice: params[:tool_choice],
          tool_names: params[:tools].map { |tool| tool[:name] }
        },
        metadata: {source_url: source_url}
      )
      generation_ended = false

      response, tool_use, data = extract_recipe_data(params)
      normalized = normalize(data, source_url)
      extraction_summary = extraction_summary(data)

      generation.end(
        output: data,
        usage: response_usage(response),
        metadata: extraction_summary.merge(
          stop_reason: response_value(response, "stop_reason"),
          tool_name: tool_use["name"],
          tool_id: tool_use["id"],
          is_recipe: data["is_recipe"]
        )
      )
      generation_ended = true

      unless data["is_recipe"]
        trace.event(
          name: "recipe-extraction.not_recipe",
          output: {title: data["title"]}
        )
        raise NotRecipeError, "Page is not a recipe"
      end

      trace.update(output: normalized)
      normalized
    rescue NotRecipeError
      raise
    rescue StandardError => e
      unless generation_ended
        generation.end(
          output: {error: e.message},
          metadata: {error_class: e.class.name}
        )
      end

      trace.event(
        name: "recipe-extraction.error",
        output: {class: e.class.name, message: e.message},
        metadata: {source_url: source_url}
      )
      raise
    end
  end

  def extract_recipe(params, source_url)
    _response, _tool_use, data = extract_recipe_data(params)
    raise NotRecipeError, "Page is not a recipe" unless data["is_recipe"]

    normalize(data, source_url)
  end

  def extract_recipe_data(params)
    response = request_with_retry(params)
    tool_use = extract_tool_use(response)
    [response, tool_use, tool_use.fetch("input")]
  end

  def request_with_retry(params)
    client.messages(parameters: params)
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

  def image_message_params(image_bytes, media_type)
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
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: media_type,
                data: Base64.strict_encode64(image_bytes)
              }
            },
            {
              type: "text",
              text: "Extract the recipe shown in this image."
            }
          ]
        }
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
      "source_site" => source_site(source_url),
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

  def response_usage(response)
    usage = response_value(response, "usage")
    return if usage.blank?

    prompt_tokens = response_value(usage, "input_tokens")
    completion_tokens = response_value(usage, "output_tokens")

    tracked_usage = {}
    tracked_usage[:prompt_tokens] = prompt_tokens if prompt_tokens
    tracked_usage[:completion_tokens] = completion_tokens if completion_tokens
    tracked_usage[:total_tokens] = prompt_tokens.to_i + completion_tokens.to_i if prompt_tokens || completion_tokens
    tracked_usage.presence
  end

  def response_value(object, key)
    return unless object.respond_to?(:[])

    object[key] || object[key.to_sym]
  end

  def extraction_summary(data)
    parts = Array(data["parts"])

    {
      title: data["title"],
      parts_count: parts.length,
      ingredient_count: parts.sum { |part| Array(part["ingredients"]).length },
      instruction_count: parts.sum { |part| Array(part["instructions"]).length },
      section_names: parts.filter_map { |part| part["name"].to_s.presence },
      has_image: data["image_url"].present?,
      has_notes: data["notes"].present?
    }
  end

  def source_site(source_url)
    URI(source_url).host
  rescue
    nil
  end

  def langfuse_enabled?
    ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
  end

  def client
    @client ||= Anthropic::Client.new(
      access_token: Rails.application.credentials.anthropic_api_key!,
      request_timeout: 90
    )
  end
end
