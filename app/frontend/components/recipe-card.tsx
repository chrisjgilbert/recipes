import { Link } from "@inertiajs/react";
import { Clock, Users } from "lucide-react";

import { Card, CardContent } from "@/components/ui/card";
import type { RecipeSummary } from "@/lib/types";
import { formatMinutes } from "@/lib/utils";

export function RecipeCard({ recipe }: { recipe: RecipeSummary }) {
  const time = formatMinutes(recipe.total_time_minutes);
  return (
    <Link
      href={`/recipes/${recipe.id}`}
      className="group block focus-visible:outline-none"
    >
      <Card className="overflow-hidden transition hover:border-primary hover:shadow-md">
        <div className="aspect-[4/3] w-full bg-muted">
          {recipe.image_url ? (
            <img
              src={recipe.image_url}
              alt={recipe.title}
              className="h-full w-full object-cover transition group-hover:scale-[1.02]"
              loading="lazy"
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-muted-foreground">
              No image
            </div>
          )}
        </div>
        <CardContent className="space-y-1 p-3">
          <h3 className="line-clamp-2 font-medium leading-snug">{recipe.title}</h3>
          {recipe.chef && (
            <p className="text-xs text-muted-foreground">{recipe.chef}</p>
          )}
          <div className="flex items-center gap-3 text-xs text-muted-foreground">
            {time && (
              <span className="inline-flex items-center gap-1">
                <Clock className="h-3.5 w-3.5" />
                {time}
              </span>
            )}
            {recipe.servings != null && (
              <span className="inline-flex items-center gap-1">
                <Users className="h-3.5 w-3.5" />
                {recipe.servings}
              </span>
            )}
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}
