require "rails_helper"

RSpec.describe Recipe, type: :model do
  let(:valid_attrs) do
    {
      title: "Tomato Pasta",
      parts: [
        {
          "name" => "",
          "ingredients" => [{ "name" => "pasta" }, { "name" => "tomato" }],
          "instructions" => [{ "step" => 1, "text" => "Boil" }],
        },
      ],
    }
  end

  it "is valid with minimum attributes" do
    expect(Recipe.new(valid_attrs)).to be_valid
  end

  it "requires a title" do
    expect(Recipe.new(valid_attrs.merge(title: nil))).not_to be_valid
  end

  it "populates search_tsv via trigger including ingredient names from parts" do
    recipe = Recipe.create!(valid_attrs)
    recipe.reload
    rows = Recipe.where("search_tsv @@ websearch_to_tsquery('english', 'tomato')")
    expect(rows).to include(recipe)
  end

  it "indexes ingredient names across multiple named parts" do
    recipe = Recipe.create!(
      title: "Pork Shoulder",
      parts: [
        {
          "name" => "For the rub",
          "ingredients" => [{ "name" => "paprika" }],
          "instructions" => [{ "step" => 1, "text" => "Mix" }],
        },
        {
          "name" => "For the meat",
          "ingredients" => [{ "name" => "pork shoulder" }],
          "instructions" => [{ "step" => 1, "text" => "Smoke" }],
        },
      ],
    )
    rows = Recipe.where("search_tsv @@ websearch_to_tsquery('english', 'paprika')")
    expect(rows).to include(recipe)
  end

  describe "scopes" do
    before do
      @pasta = Recipe.create!(valid_attrs)
      @curry = Recipe.create!(valid_attrs.merge(
        title: "Curry",
        chef: "Yotam Ottolenghi",
        parts: [
          {
            "name" => "",
            "ingredients" => [{ "name" => "chicken" }],
            "instructions" => [{ "step" => 1, "text" => "Cook" }],
          },
        ],
      ))
    end

    it ".search matches title" do
      expect(Recipe.search("Curry")).to contain_exactly(@curry)
    end

    it ".search matches chef name" do
      expect(Recipe.search("Ottolenghi")).to contain_exactly(@curry)
    end

    it ".sorted rejects unknown columns and orders" do
      ordered = Recipe.sorted("title", "asc")
      expect(ordered.first.title).to eq("Curry")
      ordered_default = Recipe.sorted("drop_table", "---")
      expect(ordered_default.to_sql).to include("created_at DESC")
    end
  end

  describe "parts validation" do
    it "defaults to an empty array" do
      recipe = Recipe.create!(title: "Empty")
      expect(recipe.parts).to eq([])
    end

    it "is invalid when parts is not an array" do
      recipe = Recipe.new(valid_attrs.merge(parts: { "name" => "x" }))
      expect(recipe).not_to be_valid
      expect(recipe.errors[:parts]).to be_present
    end

    it "coerces a missing part name to an empty string via the normalizer" do
      recipe = Recipe.new(valid_attrs.merge(parts: [
        { "ingredients" => [], "instructions" => [] },
      ]))
      expect(recipe).to be_valid
      expect(recipe.parts.first["name"]).to eq("")
    end

    it "coerces a non-array ingredients value into an array via the normalizer" do
      recipe = Recipe.new(valid_attrs.merge(parts: [
        { "name" => "rub", "ingredients" => "salt", "instructions" => [] },
      ]))
      expect(recipe).to be_valid
      expect(recipe.parts.first["ingredients"]).to be_an(Array)
    end
  end
end
