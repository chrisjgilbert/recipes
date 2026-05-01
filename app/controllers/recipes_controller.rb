class RecipesController < ApplicationController
  before_action :set_recipe, only: [:show, :edit, :update, :destroy]

  PAGE_SIZE = 24

  def index
    params_scope = filter_params
    scope = Recipe
      .search(params_scope[:q])
      .with_cuisine(params_scope[:cuisine])
      .with_course(params_scope[:course])
      .sorted(params_scope[:sort], params_scope[:order])

    total  = scope.count
    limit  = (params_scope[:limit].presence || PAGE_SIZE).to_i
    offset = params_scope[:offset].to_i

    items = scope.limit(limit).offset(offset).map(&:summary_attributes)

    render inertia: "Recipes/Index", props: {
      items:,
      total:,
      limit:,
      offset:,
      filters: params_scope,
    }
  end

  def show
    render inertia: "Recipes/Show", props: { recipe: @recipe.attributes }
  end

  def new
    render inertia: "Recipes/New", props: {
      manual: params[:manual] == "1",
      importError: flash[:import_error],
    }
  end

  def create
    recipe = Recipe.new(recipe_params)
    if recipe.save
      redirect_to recipe_path(recipe)
    else
      redirect_to new_recipe_path(manual: 1), inertia: { errors: recipe.errors.to_hash }
    end
  end

  def edit
    render inertia: "Recipes/Edit", props: { recipe: @recipe.attributes }
  end

  def update
    if @recipe.update(recipe_params)
      redirect_to recipe_path(@recipe)
    else
      redirect_to edit_recipe_path(@recipe), inertia: { errors: @recipe.errors.to_hash }
    end
  end

  def destroy
    @recipe.destroy
    redirect_to root_path, notice: "Recipe deleted"
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def filter_params
    params.permit(:q, :cuisine, :course, :sort, :order, :limit, :offset).to_h.symbolize_keys
  end

  def recipe_params
    params.require(:recipe).permit(
      :title, :source_url, :source_site, :description, :image_url,
      :prep_time_minutes, :cook_time_minutes, :total_time_minutes,
      :servings, :cuisine, :course, :difficulty, :notes,
      tags: [],
      parts: [:name, ingredients: [:quantity, :unit, :name, :notes], instructions: [:step, :text]],
    )
  end
end
