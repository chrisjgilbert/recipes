class RecipeExtractor
  class Error < StandardError; end
  class NotRecipeError < Error; end

  MODEL = "claude-haiku-4-5-20251001"

  SAVE_RECIPE_TOOL = {
    name: "save_recipe",
    description: "Extract a recipe from the provided webpage markdown into structured fields.",
    input_schema: {
      type: "object",
      properties: {
        is_recipe: { type: "boolean", description: "True if the page is a recipe." },
        title: { type: "string" },
        description: { type: ["string", "null"] },
        image_url: { type: ["string", "null"] },
        prep_time_minutes: { type: ["integer", "null"] },
        cook_time_minutes: { type: ["integer", "null"] },
        total_time_minutes: { type: ["integer", "null"] },
        servings: { type: ["integer", "null"] },
        cuisine: { type: ["string", "null"] },
        course: { type: ["string", "null"] },
        difficulty: { type: ["string", "null"] },
        tags: { type: "array", items: { type: "string" } },
        notes: { type: ["string", "null"] },
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
                    quantity: { type: ["string", "null"] },
                    unit: { type: ["string", "null"] },
                    name: { type: "string" },
                    notes: { type: ["string", "null"] }
                  },
                  required: ["name"]
                }
              },
              instructions: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    step: { type: "integer" },
                    text: { type: "string" }
                  },
                  required: ["step", "text"]
                }
              }
            },
            required: ["name", "ingredients", "instructions"]
          }
        }
      },
      required: ["is_recipe", "title", "parts", "tags"]
    }
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You extract structured recipes from webpage markdown. Given the page content, call
    the save_recipe tool with the fields you can confidently extract. Preserve original
    wording in ingredient names and instruction text; normalize quantities but do not
    invent information. Set is_recipe=false only if the page clearly is not a recipe.

    Always return at least one part. If the source organises its ingredients and/or
    instructions into clearly named sections (e.g. "For the rub", "For the sauce",
    "For the meat"), return one part per section using the source's own section
    names. If a section only lists ingredients (no method of its own), still include
    it as a part with an empty `instructions` array, and vice versa. Number `step`
    from 1 within each part.

    If the source is not divided into sections, return a single part with name=""
    containing every ingredient and instruction.
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
    tries = 0
    begin
      tries += 1
      client.messages(parameters: message_params(markdown))
    rescue Anthropic::Error => e
      raise Error, e.message if tries > 1 || !retryable?(e)
      sleep(1.5)
      retry
    end
  end

  def retryable?(error)
    error.message.to_s.include?("529") || error.message.to_s.include?("overloaded")
  end

  def message_params(markdown)
    {
      model: MODEL,
      max_tokens: 4096,
      system: [
        {
          type: "text",
          text: SYSTEM_PROMPT,
          cache_control: { type: "ephemeral" }
        }
      ],
      tools: [SAVE_RECIPE_TOOL],
      tool_choice: { type: "tool", name: "save_recipe" },
      messages: [
        { role: "user", content: markdown }
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
      "title", "description", "image_url",
      "prep_time_minutes", "cook_time_minutes", "total_time_minutes",
      "servings", "cuisine", "course", "difficulty",
      "tags", "notes"
    ).merge(
      "source_url" => source_url,
      "source_site" => (URI(source_url).host rescue nil),
      "tags" => Array(data["tags"]),
      "parts" => Array(data["parts"]).map { |p| normalize_part(p) }
    )
  end

  def normalize_part(part)
    part = part.is_a?(Hash) ? part.transform_keys(&:to_s) : {}
    {
      "name" => part["name"].to_s,
      "ingredients" => Array(part["ingredients"]),
      "instructions" => Array(part["instructions"]),
    }
  end

  def client
    @client ||= Anthropic::Client.new(access_token: Rails.application.credentials.anthropic_api_key!)
  end
end
