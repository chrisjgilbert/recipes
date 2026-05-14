class Recipe < ApplicationRecord
  SORT_COLUMNS = %w[created_at title total_time_minutes].freeze
  SORT_ORDERS  = %w[asc desc].freeze

  before_validation :normalize_parts_measurements

  validates :title, presence: true
  validate  :parts_shape

  scope :search, ->(query) {
    next all if query.blank?
    sanitized = query.strip
    where("search_tsv @@ websearch_to_tsquery('english', ?)", sanitized)
      .or(where("title ILIKE ?", "%#{sanitized}%"))
      .or(where("chef ILIKE ?", "%#{sanitized}%"))
  }

  scope :sorted, ->(sort, order) {
    column = SORT_COLUMNS.include?(sort) ? sort : "created_at"
    direction = SORT_ORDERS.include?(order) ? order : "desc"
    order(Arel.sql("#{column} #{direction.upcase} NULLS LAST"))
  }

  def summary_attributes
    attributes.slice(
      "id", "title", "image_url", "total_time_minutes", "servings",
      "chef", "created_at"
    )
  end

  private

  def normalize_parts_measurements
    return unless parts.is_a?(Array)

    self.parts = IngredientUnitNormalizer.normalize_parts(parts)
  end

  def parts_shape
    return errors.add(:parts, "must be an array") unless parts.is_a?(Array)

    parts.each_with_index do |part, i|
      unless part.is_a?(Hash)
        errors.add(:parts, "[#{i}] must be an object")
        next
      end
      errors.add(:parts, "[#{i}] name must be a string")        unless part["name"].is_a?(String)
      errors.add(:parts, "[#{i}] ingredients must be an array") unless part["ingredients"].is_a?(Array)
      errors.add(:parts, "[#{i}] instructions must be an array") unless part["instructions"].is_a?(Array)
    end
  end
end
