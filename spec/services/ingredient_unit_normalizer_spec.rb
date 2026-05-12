require "rails_helper"

RSpec.describe IngredientUnitNormalizer do
  it "preserves raw measurements while adding canonical spoon and cup units" do
    parts = [
      {
        "name" => "",
        "ingredients" => [
          {"quantity" => "1", "unit" => "T", "name" => "olive oil", "notes" => nil},
          {"quantity" => "1 1/2", "unit" => "cups", "name" => "stock", "notes" => "warm"},
        ],
        "instructions" => [{"step" => 1, "text" => "Mix."}],
      },
    ]

    result = described_class.normalize_parts(parts)
    oil, stock = result.first["ingredients"]

    expect(oil).to include(
      "quantity" => "1",
      "unit" => "T",
      "canonical_quantity" => "1",
      "canonical_unit" => "tbsp"
    )
    expect(stock).to include(
      "quantity" => "1 1/2",
      "unit" => "cups",
      "canonical_quantity" => "360",
      "canonical_unit" => "ml",
      "notes" => "warm"
    )
  end

  it "handles unicode fractions when converting cups" do
    parts = [
      {
        "name" => "",
        "ingredients" => [
          {"quantity" => "½", "unit" => "cup", "name" => "milk"},
        ],
        "instructions" => [],
      },
    ]

    result = described_class.normalize_parts(parts)

    expect(result.first["ingredients"].first).to include(
      "quantity" => "½",
      "unit" => "cup",
      "canonical_quantity" => "120",
      "canonical_unit" => "ml"
    )
  end
end
