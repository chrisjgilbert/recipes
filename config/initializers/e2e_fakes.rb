return unless ENV["E2E_FAKE_SERVICES"] == "1"

require "bcrypt"

Rails.application.config.after_initialize do
  Rails.logger.warn "[e2e] Swapping JinaFetcher + RecipeExtractor and credentials with fakes"

  e2e_password = ENV.fetch("APP_PASSWORD", "e2e-secret")
  e2e_hash = BCrypt::Password.create(e2e_password).to_s

  Rails.application.credentials.define_singleton_method(:app_password_hash!) { e2e_hash }
  Rails.application.credentials.define_singleton_method(:anthropic_api_key!) { "e2e-fake" }

  JinaFetcher.define_singleton_method(:call) { |_url| "# fake markdown" }

  RecipeExtractor.define_singleton_method(:call) do |_markdown, source_url: nil|
    {
      "title" => "Playwright Pasta",
      "source_url" => source_url,
      "source_site" => (URI(source_url).host rescue nil),
      "description" => "E2E fake",
      "image_url" => nil,
      "prep_time_minutes" => 5,
      "cook_time_minutes" => 15,
      "total_time_minutes" => 20,
      "servings" => 2,
      "cuisine" => "Italian",
      "course" => "Main",
      "difficulty" => "easy",
      "tags" => ["quick", "italian"],
      "notes" => nil,
      "parts" => [
        {
          "name" => "",
          "ingredients" => [{ "name" => "pasta", "quantity" => "200", "unit" => "g", "notes" => nil }],
          "instructions" => [{ "step" => 1, "text" => "Boil pasta." }],
        },
      ],
    }
  end
end
