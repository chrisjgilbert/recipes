export interface Ingredient {
  quantity: string | null;
  unit: string | null;
  name: string;
  notes: string | null;
  canonical_quantity?: string | null;
  canonical_unit?: string | null;
}

export interface InstructionStep {
  step: number;
  text: string;
}

export interface RecipePart {
  name: string;
  ingredients: Ingredient[];
  instructions: InstructionStep[];
}

export interface Recipe {
  id: string;
  title: string;
  chef: string | null;
  source_url: string | null;
  source_site: string | null;
  description: string | null;
  image_url: string | null;
  prep_time_minutes: number | null;
  cook_time_minutes: number | null;
  total_time_minutes: number | null;
  servings: number | null;
  parts: RecipePart[];
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface RecipeSummary {
  id: string;
  title: string;
  chef: string | null;
  image_url: string | null;
  total_time_minutes: number | null;
  servings: number | null;
  created_at: string;
}

export type SortKey = "created_at" | "title" | "total_time_minutes";
export type SortOrder = "asc" | "desc";

export interface RecipeFiltersValue {
  q: string;
  sort: SortKey;
  order: SortOrder;
}

export type RecipeInput = Omit<Recipe, "id" | "created_at" | "updated_at">;

export interface FlashProps {
  notice: string | null;
  alert: string | null;
}
