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
      tags: ["italian"],
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
        cuisine: "Indian",
        parts: [
          {
            "name" => "",
            "ingredients" => [{ "name" => "chicken" }],
            "instructions" => [{ "step" => 1, "text" => "Cook" }],
          },
        ],
      ))
    end

    it ".with_cuisine filters by cuisine" do
      expect(Recipe.with_cuisine("Indian")).to contain_exactly(@curry)
    end

    it ".search matches title" do
      expect(Recipe.search("Curry")).to contain_exactly(@curry)
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
      recipe = Recipe.create!(title: "Empty", tags: [])
      expect(recipe.parts).to eq([])
    end

    it "is invalid when parts is not an array" do
      recipe = Recipe.new(valid_attrs.merge(parts: { "name" => "x" }))
      expect(recipe).not_to be_valid
      expect(recipe.errors[:parts]).to be_present
    end

    it "is invalid when a part is missing a name" do
      recipe = Recipe.new(valid_attrs.merge(parts: [
        { "ingredients" => [], "instructions" => [] },
      ]))
      expect(recipe).not_to be_valid
      expect(recipe.errors[:parts].join).to include("name")
    end

    it "is invalid when a part's ingredients is not an array" do
      recipe = Recipe.new(valid_attrs.merge(parts: [
        { "name" => "rub", "ingredients" => "salt", "instructions" => [] },
      ]))
      expect(recipe).not_to be_valid
      expect(recipe.errors[:parts].join).to include("ingredients")
    end
  end
end
