class IngredientUnitNormalizer
  CUP_IN_ML = 240
  UNICODE_FRACTIONS = {
    "¼" => " 1/4",
    "½" => " 1/2",
    "¾" => " 3/4",
    "⅐" => " 1/7",
    "⅑" => " 1/9",
    "⅒" => " 1/10",
    "⅓" => " 1/3",
    "⅔" => " 2/3",
    "⅕" => " 1/5",
    "⅖" => " 2/5",
    "⅗" => " 3/5",
    "⅘" => " 4/5",
    "⅙" => " 1/6",
    "⅚" => " 5/6",
    "⅛" => " 1/8",
    "⅜" => " 3/8",
    "⅝" => " 5/8",
    "⅞" => " 7/8"
  }.freeze

  def self.normalize_parts(parts)
    new.normalize_parts(parts)
  end

  def normalize_parts(parts)
    Array(parts).map { |part| normalize_part(part) }
  end

  private

  def normalize_part(part)
    part = stringify_keys(part)

    {
      "name" => part["name"].to_s,
      "ingredients" => Array(part["ingredients"]).map { |ingredient| normalize_ingredient(ingredient) },
      "instructions" => Array(part["instructions"]).map { |instruction| normalize_instruction(instruction) }
    }
  end

  def normalize_ingredient(ingredient)
    ingredient = stringify_keys(ingredient)
    quantity = presence_or_nil(ingredient["quantity"])
    unit = presence_or_nil(ingredient["unit"])
    canonical_quantity, canonical_unit = canonical_measurement(quantity, unit)

    {
      "quantity" => quantity,
      "unit" => unit,
      "name" => ingredient["name"].to_s,
      "notes" => presence_or_nil(ingredient["notes"]),
      "canonical_quantity" => canonical_quantity,
      "canonical_unit" => canonical_unit
    }
  end

  def normalize_instruction(instruction)
    instruction = stringify_keys(instruction)

    {
      "step" => instruction["step"],
      "text" => instruction["text"].to_s
    }
  end

  def canonical_measurement(quantity, unit)
    normalized_unit = normalize_unit(unit)
    return [quantity, nil] if normalized_unit.nil?

    case normalized_unit
    when "cup"
      parsed_quantity = parse_quantity(quantity)
      return [format_quantity(parsed_quantity * CUP_IN_ML), "ml"] if parsed_quantity

      [quantity, unit]
    else
      [quantity, normalized_unit]
    end
  end

  def normalize_unit(unit)
    return nil if unit.blank?

    stripped = unit.strip
    return "tsp" if stripped == "t"
    return "tbsp" if stripped == "T"

    case stripped.downcase
    when "tsp", "tsp.", "teaspoon", "teaspoons"
      "tsp"
    when "tbsp", "tbsp.", "tablespoon", "tablespoons"
      "tbsp"
    when "cup", "cups"
      "cup"
    when "ml", "ml.", "millilitre", "millilitres", "milliliter", "milliliters"
      "ml"
    when "l", "l.", "litre", "litres", "liter", "liters"
      "l"
    when "g", "g.", "gram", "grams"
      "g"
    when "kg", "kg.", "kilogram", "kilograms"
      "kg"
    else
      stripped
    end
  end

  def parse_quantity(quantity)
    return nil if quantity.blank?

    normalized = quantity.dup
    UNICODE_FRACTIONS.each { |unicode, ascii| normalized.gsub!(unicode, ascii) }
    normalized.gsub!(/(\d)-(?=\d+\/\d+)/, '\1 ')
    normalized = normalized.squish

    case normalized
    when /\A\d+\z/, /\A\d+\.\d+\z/
      Rational(normalized)
    when /\A(\d+)\s+(\d+)\/(\d+)\z/
      Rational(Regexp.last_match(1)) + Rational(Regexp.last_match(2), Regexp.last_match(3))
    when /\A(\d+)\/(\d+)\z/
      Rational(Regexp.last_match(1), Regexp.last_match(2))
    else
      nil
    end
  rescue ArgumentError
    nil
  end

  def format_quantity(quantity)
    return nil if quantity.nil?

    return quantity.numerator.to_s if quantity.denominator == 1

    format("%.2f", quantity.to_f).sub(/\.?0+\z/, "")
  end

  def presence_or_nil(value)
    value.presence
  end

  def stringify_keys(value)
    value.is_a?(Hash) ? value.transform_keys(&:to_s) : {}
  end
end
