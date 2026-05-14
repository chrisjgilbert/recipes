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
          "ingredients" => [
            { "name" => "olive oil", "quantity" => "1", "unit" => "T", "notes" => nil },
            { "name" => "stock", "quantity" => "1", "unit" => "cup", "notes" => nil },
          ],
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
    expect(Recipe.last.parts.first["ingredients"]).to include(
      include(
        "quantity" => "1",
        "unit" => "T",
        "canonical_quantity" => "1",
        "canonical_unit" => "tbsp"
      ),
      include(
        "quantity" => "1",
        "unit" => "cup",
        "canonical_quantity" => "240",
        "canonical_unit" => "ml"
      )
    )
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

  describe "POST /recipes/import/image" do
    let(:image_data) do
      extracted_data.merge(
        "title" => "Photo Pasta",
        "source_url" => nil,
        "source_site" => nil,
      )
    end

    let(:upload) do
      fixture_file_upload(write_fixture("recipe.jpg", "fakebytes"), "image/jpeg")
    end

    def write_fixture(name, contents)
      path = Rails.root.join("tmp", "spec-uploads")
      FileUtils.mkdir_p(path)
      file = path.join(name)
      File.binwrite(file, contents)
      file
    end

    it "imports a recipe from an uploaded image and sets image_url from Cloudinary" do
      allow(ImageNormalizer).to receive(:call).and_return(["fakebytes", "image/jpeg"])
      allow(RecipeExtractor).to receive(:call_image).and_return(image_data)
      allow(CloudinaryUploader).to receive(:call).and_return("https://res.cloudinary.com/test/recipe.jpg")

      expect {
        post "/recipes/import/image", params: { image: upload }
      }.to change(Recipe, :count).by(1)

      expect(response).to redirect_to(recipe_path(Recipe.last))
      expect(Recipe.last.title).to eq("Photo Pasta")
      expect(Recipe.last.source_url).to be_nil
      expect(Recipe.last.image_url).to eq("https://res.cloudinary.com/test/recipe.jpg")
      expect(RecipeExtractor).to have_received(:call_image).with("fakebytes", media_type: "image/jpeg")
    end

    it "saves the recipe without image_url when Cloudinary upload fails" do
      allow(ImageNormalizer).to receive(:call).and_return(["fakebytes", "image/jpeg"])
      allow(RecipeExtractor).to receive(:call_image).and_return(image_data)
      allow(CloudinaryUploader).to receive(:call).and_raise(CloudinaryUploader::Error.new("timeout"))

      expect {
        post "/recipes/import/image", params: { image: upload }
      }.to change(Recipe, :count).by(1)

      expect(response).to redirect_to(recipe_path(Recipe.last))
      expect(Recipe.last.image_url).to be_nil
    end

    it "redirects with image_failed when no image is provided" do
      post "/recipes/import/image", params: {}

      expect(response).to redirect_to(new_recipe_path)
      follow_redirect!
      expect(response.body).to include("image_failed")
    end

    it "redirects with image_failed for disallowed content type" do
      bmp_upload = fixture_file_upload(write_fixture("recipe.bmp", "BM" + "x" * 10), "image/bmp")

      post "/recipes/import/image", params: { image: bmp_upload }

      expect(response).to redirect_to(new_recipe_path)
      follow_redirect!
      expect(response.body).to include("image_failed")
      expect(Recipe.count).to eq(0)
    end

    it "redirects with not_a_recipe when extractor raises NotRecipeError" do
      allow(ImageNormalizer).to receive(:call).and_return(["fakebytes", "image/jpeg"])
      allow(RecipeExtractor).to receive(:call_image).and_raise(RecipeExtractor::NotRecipeError)

      post "/recipes/import/image", params: { image: upload }

      expect(response).to redirect_to(new_recipe_path)
      follow_redirect!
      expect(response.body).to include("not_a_recipe")
      expect(Recipe.count).to eq(0)
    end

    it "redirects with image_failed on ImageNormalizer::Error" do
      allow(ImageNormalizer).to receive(:call).and_raise(ImageNormalizer::Error.new("bad heic"))

      post "/recipes/import/image", params: { image: upload }

      expect(response).to redirect_to(new_recipe_path)
      follow_redirect!
      expect(response.body).to include("image_failed")
      expect(Recipe.count).to eq(0)
    end

    it "redirects with image_failed on RecipeExtractor::Error" do
      allow(ImageNormalizer).to receive(:call).and_return(["fakebytes", "image/jpeg"])
      allow(RecipeExtractor).to receive(:call_image).and_raise(RecipeExtractor::Error.new("API down"))

      post "/recipes/import/image", params: { image: upload }

      expect(response).to redirect_to(new_recipe_path)
      follow_redirect!
      expect(response.body).to include("image_failed")
      expect(Recipe.count).to eq(0)
    end
  end
end
