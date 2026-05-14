import { Link, router } from "@inertiajs/react";
import { useEffect } from "react";
import { toast } from "sonner";

import { NavBar } from "@/components/nav-bar";
import { RecipeFilters } from "@/components/recipe-filters";
import { RecipeGrid } from "@/components/recipe-grid";
import { Button } from "@/components/ui/button";
import type { FlashProps, RecipeFiltersValue, RecipeSummary } from "@/lib/types";

interface Props {
  items: RecipeSummary[];
  total: number;
  limit: number;
  offset: number;
  filters: Partial<RecipeFiltersValue>;
  flash: FlashProps;
}

export default function RecipesIndex(props: Props) {
  const filters: RecipeFiltersValue = {
    q: props.filters.q ?? "",
    sort: (props.filters.sort as RecipeFiltersValue["sort"]) ?? "created_at",
    order: (props.filters.order as RecipeFiltersValue["order"]) ?? "desc",
  };

  useEffect(() => {
    if (props.flash.notice) toast.success(props.flash.notice);
    if (props.flash.alert) toast.error(props.flash.alert);
  }, [props.flash.notice, props.flash.alert]);

  function onFiltersChange(next: RecipeFiltersValue) {
    const query = Object.fromEntries(
      Object.entries(next).filter(([, v]) => v !== "" && v != null),
    );
    router.get("/", query, { preserveState: true, preserveScroll: true, replace: true });
  }

  const hasMore = props.items.length + props.offset < props.total;

  return (
    <div className="min-h-screen">
      <NavBar />
      <main className="mx-auto max-w-6xl px-4 pb-12 pt-4">
        <RecipeFilters value={filters} onChange={onFiltersChange} />
        <div className="mb-3 text-sm text-muted-foreground">
          {props.total} {props.total === 1 ? "recipe" : "recipes"}
        </div>
        <RecipeGrid items={props.items} />
        {hasMore && (
          <div className="mt-6 flex justify-center">
            <Button
              variant="outline"
              onClick={() =>
                router.get(
                  "/",
                  {
                    ...props.filters,
                    offset: props.offset + props.limit,
                  },
                  {
                    preserveState: true,
                    preserveScroll: true,
                    only: ["items", "offset"],
                    replace: true,
                  },
                )
              }
            >
              Load more
            </Button>
          </div>
        )}
        {props.items.length === 0 && props.total === 0 && (
          <div className="mt-8 flex justify-center">
            <Button asChild>
              <Link href="/recipes/new">Add your first recipe</Link>
            </Button>
          </div>
        )}
      </main>
    </div>
  );
}
