require "rails_helper"
require "bcrypt"

RSpec.describe "Recipes", type: :request do
  before do
    hash = BCrypt::Password.create("letmein").to_s
    allow(Rails.application.credentials).to receive(:app_password_hash!).and_return(hash)
    post "/login", params: { password: "letmein" }
  end

  def sample_attrs(overrides = {})
    {
      title: "Sample Recipe",
      tags: ["quick"],
      parts: [
        {
          "name" => "",
          "ingredients" => [{ "name" => "salt" }],
          "instructions" => [{ "step" => 1, "text" => "cook" }],
        },
      ],
    }.merge(overrides)
  end

  it "lists recipes" do
    Recipe.create!(sample_attrs)
    get "/"
    expect(response).to be_successful
    expect(response.body).to include("Recipes/Index")
    expect(response.body).to include("Sample Recipe")
  end

  it "filters recipes by search query" do
    Recipe.create!(sample_attrs(title: "Pasta Carbonara"))
    Recipe.create!(sample_attrs(title: "Beef Stew"))
    get "/", params: { q: "Pasta" }
    expect(response.body).to include("Pasta Carbonara")
    expect(response.body).not_to include("Beef Stew")
  end

  it "filters recipes by cuisine" do
    Recipe.create!(sample_attrs(title: "Pizza", cuisine: "Italian"))
    Recipe.create!(sample_attrs(title: "Ramen", cuisine: "Japanese"))
    get "/", params: { cuisine: "Italian" }
    expect(response.body).to include("Pizza")
    expect(response.body).not_to include("Ramen")
  end

  it "sorts recipes by title ascending" do
    Recipe.create!(sample_attrs(title: "Zebra Cake"))
    Recipe.create!(sample_attrs(title: "Apple Pie"))
    get "/", params: { sort: "title", order: "asc" }
    expect(response.body.index("Apple Pie")).to be < response.body.index("Zebra Cake")
  end

  it "respects limit and offset for pagination" do
    3.times { |i| Recipe.create!(sample_attrs(title: "Recipe #{i + 1}")) }

    get "/", params: { limit: 2, offset: 0, sort: "title", order: "asc" }
    expect(response.body).to include("Recipe 1")
    expect(response.body).to include("Recipe 2")
    expect(response.body).not_to include("Recipe 3")

    get "/", params: { limit: 2, offset: 2, sort: "title", order: "asc" }
    expect(response.body).not_to include("Recipe 1")
    expect(response.body).not_to include("Recipe 2")
    expect(response.body).to include("Recipe 3")
  end

  it "shows a recipe" do
    recipe = Recipe.create!(sample_attrs)
    get "/recipes/#{recipe.id}"
    expect(response).to be_successful
    expect(response.body).to include("Recipes/Show")
    expect(response.body).to include("Sample Recipe")
  end

  it "returns 404 for a missing recipe" do
    get "/recipes/00000000-0000-0000-0000-000000000000"
    expect(response).to have_http_status(:not_found)
  end

  it "renders the new recipe page" do
    get "/recipes/new"
    expect(response).to be_successful
    expect(response.body).to include("Recipes/New")
  end

  it "creates a recipe" do
    expect {
      post "/recipes", params: { recipe: sample_attrs(title: "New") }
    }.to change(Recipe, :count).by(1)
    expect(response).to redirect_to(recipe_path(Recipe.last))
  end

  it "redirects with errors when create fails" do
    post "/recipes", params: { recipe: { title: "" } }
    expect(response).to redirect_to(new_recipe_path(manual: 1))
  end

  it "updates a recipe" do
    recipe = Recipe.create!(sample_attrs)
    patch "/recipes/#{recipe.id}", params: { recipe: { title: "Renamed" } }
    expect(recipe.reload.title).to eq("Renamed")
  end

  it "redirects with errors when update fails" do
    recipe = Recipe.create!(sample_attrs)
    patch "/recipes/#{recipe.id}", params: { recipe: { title: "" } }
    expect(response).to redirect_to(edit_recipe_path(recipe))
  end

  it "deletes a recipe" do
    recipe = Recipe.create!(sample_attrs)
    expect { delete "/recipes/#{recipe.id}" }.to change(Recipe, :count).by(-1)
    expect(response).to redirect_to("/")
  end
end
