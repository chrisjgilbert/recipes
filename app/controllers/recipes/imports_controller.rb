class Recipes::ImportsController < ApplicationController
  def create
    url = params[:url].to_s
    if url.blank?
      flash[:import_error] = "not_a_recipe"
      return redirect_to new_recipe_path
    end

    markdown = JinaFetcher.call(url)
    data = RecipeExtractor.call(markdown, source_url: url)
    data["parts"] = IngredientUnitNormalizer.normalize_parts(data["parts"])

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
end
