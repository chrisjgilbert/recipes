export interface Ingredient {
  quantity: string | null;
  unit: string | null;
  name: string;
  notes: string | null;
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
  source_url: string | null;
  source_site: string | null;
  description: string | null;
  image_url: string | null;
  prep_time_minutes: number | null;
  cook_time_minutes: number | null;
  total_time_minutes: number | null;
  servings: number | null;
  parts: RecipePart[];
  tags: string[];
  cuisine: string | null;
  course: string | null;
  difficulty: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface RecipeSummary {
  id: string;
  title: string;
  image_url: string | null;
  total_time_minutes: number | null;
  servings: number | null;
  tags: string[];
  cuisine: string | null;
  course: string | null;
  created_at: string;
}

export type SortKey = "created_at" | "title" | "total_time_minutes";
export type SortOrder = "asc" | "desc";

export interface RecipeFiltersValue {
  q: string;
  cuisine: string;
  course: string;
  sort: SortKey;
  order: SortOrder;
}

export type RecipeInput = Omit<Recipe, "id" | "created_at" | "updated_at">;

export interface FlashProps {
  notice: string | null;
  alert: string | null;
}
