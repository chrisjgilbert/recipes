require "rails_helper"
require "bcrypt"

RSpec.describe "Recipes::Imports", type: :request do
  before do
    hash = BCrypt::Password.create("letmein").to_s
    allow(Rails.application.credentials).to receive(:app_password_hash!).and_return(hash)
    post "/login", params: { password: "letmein" }
  end

  let(:extracted_data) do
    {
      "title" => "Imported Pasta",
      "chef" => "Marcella Hazan",
      "source_url" => "https://example.com/pasta",
      "source_site" => "example.com",
      "description" => nil,
      "image_url" => nil,
      "prep_time_minutes" => 10,
      "cook_time_minutes" => 20,
      "total_time_minutes" => 30,
      "servings" => 4,
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

  it "imports a recipe and redirects to the detail page" do
    allow(JinaFetcher).to receive(:call).and_return("# markdown")
    allow(RecipeExtractor).to receive(:call).and_return(extracted_data)

    expect {
      post "/recipes/import", params: { url: "https://example.com/pasta" }
    }.to change(Recipe, :count).by(1)

    expect(response).to redirect_to(recipe_path(Recipe.last))
    expect(Recipe.last.title).to eq("Imported Pasta")
    expect(Recipe.last.chef).to eq("Marcella Hazan")
  end

  it "redirects with import_error=not_a_recipe when URL is blank" do
    post "/recipes/import", params: { url: "" }

    expect(response).to redirect_to(new_recipe_path)
    follow_redirect!
    expect(response.body).to include("not_a_recipe")
  end

  it "redirects with import_error=not_a_recipe on NotRecipeError" do
    allow(JinaFetcher).to receive(:call).and_return("# not a recipe page")
    allow(RecipeExtractor).to receive(:call).and_raise(RecipeExtractor::NotRecipeError)

    post "/recipes/import", params: { url: "https://example.com/blog" }

    expect(response).to redirect_to(new_recipe_path)
    follow_redirect!
    expect(response.body).to include("not_a_recipe")
    expect(Recipe.count).to eq(0)
  end

  it "redirects with import_error=fetch_failed on JinaFetcher::Error" do
    allow(JinaFetcher).to receive(:call).and_raise(JinaFetcher::Error.new("connection timed out"))

    post "/recipes/import", params: { url: "https://example.com/down" }

    expect(response).to redirect_to(new_recipe_path)
    follow_redirect!
    expect(response.body).to include("fetch_failed")
    expect(Recipe.count).to eq(0)
  end

  it "redirects with import_error=fetch_failed on RecipeExtractor::Error" do
    allow(JinaFetcher).to receive(:call).and_return("# content")
    allow(RecipeExtractor).to receive(:call).and_raise(RecipeExtractor::Error.new("API unavailable"))

    post "/recipes/import", params: { url: "https://example.com/recipe" }

    expect(response).to redirect_to(new_recipe_path)
    follow_redirect!
    expect(response.body).to include("fetch_failed")
    expect(Recipe.count).to eq(0)
  end
end
