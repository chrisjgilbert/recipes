class Recipes::ImportsController < ApplicationController
  MAX_IMAGE_BYTES = 10 * 1024 * 1024
  ALLOWED_UPLOAD_TYPES = %w[
    image/jpeg image/png image/webp image/gif image/heic image/heif
  ].freeze

  def create
    url = params[:url].to_s
    if url.blank?
      flash[:import_error] = "not_a_recipe"
      return redirect_to new_recipe_path
    end

    markdown = JinaFetcher.call(url)
    data = RecipeExtractor.call(markdown, source_url: url)
    data["parts"] = IngredientUnitNormalizer.normalize_parts(data["parts"])
    data["image_url"] = OgImageFetcher.call(url) if data["image_url"].blank?

    recipe = Recipe.create!(data)
    redirect_to recipe_path(recipe)
  rescue RecipeExtractor::NotRecipeError
    flash[:import_error] = "not_a_recipe"
    redirect_to new_recipe_path
  rescue JinaFetcher::Error, RecipeExtractor::Error => e
    Rails.logger.warn("Import failed: #{e.class}: #{e.message}")
    flash[:import_error] = "fetch_failed"
    redirect_to new_recipe_path
  end

  def create_from_image
    uploaded = params[:image]

    if uploaded.blank? || !uploaded.respond_to?(:tempfile)
      flash[:import_error] = "image_failed"
      return redirect_to new_recipe_path
    end

    if uploaded.size > MAX_IMAGE_BYTES
      flash[:import_error] = "image_failed"
      return redirect_to new_recipe_path
    end

    if uploaded.content_type.present? && !ALLOWED_UPLOAD_TYPES.include?(uploaded.content_type.downcase)
      flash[:import_error] = "image_failed"
      return redirect_to new_recipe_path
    end

    bytes, media_type = ImageNormalizer.call(uploaded.tempfile, original_content_type: uploaded.content_type)
    data = RecipeExtractor.call_image(bytes, media_type: media_type)
    data["parts"] = IngredientUnitNormalizer.normalize_parts(data["parts"])
    data["image_url"] = upload_to_cloudinary(bytes, media_type: media_type)

    recipe = Recipe.create!(data)
    redirect_to recipe_path(recipe)
  rescue RecipeExtractor::NotRecipeError
    flash[:import_error] = "not_a_recipe"
    redirect_to new_recipe_path
  rescue ImageNormalizer::Error, RecipeExtractor::Error => e
    Rails.logger.warn("Image import failed: #{e.class}: #{e.message}")
    flash[:import_error] = "image_failed"
    redirect_to new_recipe_path
  end

  private

  def upload_to_cloudinary(bytes, media_type:)
    CloudinaryUploader.call(bytes, media_type: media_type)
  rescue CloudinaryUploader::Error => e
    Rails.logger.error("Cloudinary upload failed: #{e.message}")
    nil
  end
end
