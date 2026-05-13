import { router } from "@inertiajs/react";

import { ImportForm } from "@/components/import-form";
import { NavBar } from "@/components/nav-bar";
import { RecipeForm } from "@/components/recipe-form";
import type { RecipeInput } from "@/lib/types";

interface Props {
  manual: boolean;
  importError: "not_a_recipe" | "fetch_failed" | "image_failed" | null;
}

export default function RecipesNew({ manual, importError }: Props) {
  return (
    <div className="min-h-screen">
      <NavBar />
      <main className="mx-auto max-w-3xl px-4 pb-12 pt-6">
        <h1 className="mb-4 text-2xl font-semibold">Add a recipe</h1>
        {manual ? (
          <RecipeForm
            submitLabel="Create recipe"
            onSubmit={(values: RecipeInput) => {
              router.post("/recipes", { recipe: values } as never);
            }}
          />
        ) : (
          <>
            <ImportForm importError={importError} />
            <p className="mt-6 text-sm text-muted-foreground">
              Or{" "}
              <a href="/recipes/new?manual=1" className="text-primary underline">
                add manually
              </a>
              .
            </p>
          </>
        )}
      </main>
    </div>
  );
}
