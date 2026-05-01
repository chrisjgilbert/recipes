import { Link, router } from "@inertiajs/react";
import { Clock, ExternalLink, Pencil, Timer, Trash2, Users } from "lucide-react";

import { NavBar } from "@/components/nav-bar";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { Ingredient, InstructionStep, Recipe } from "@/lib/types";
import { formatMinutes } from "@/lib/utils";

export default function RecipesShow({ recipe }: { recipe: Recipe }) {
  function onDelete() {
    router.delete(`/recipes/${recipe.id}`);
  }

  return (
    <div className="min-h-screen">
      <NavBar />
      <main className="mx-auto max-w-4xl px-4 pb-16 pt-6">
        {recipe.image_url && (
          <img
            src={recipe.image_url}
            alt={recipe.title}
            className="mb-6 aspect-[16/9] w-full rounded-lg object-cover"
          />
        )}
        <div className="mb-2 flex items-start justify-between gap-4">
          <h1 className="text-3xl font-semibold">{recipe.title}</h1>
          <div className="flex gap-2">
            <Button asChild variant="outline" size="sm">
              <Link href={`/recipes/${recipe.id}/edit`}>
                <Pencil className="h-4 w-4" />
                Edit
              </Link>
            </Button>
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button variant="outline" size="sm" className="text-destructive">
                  <Trash2 className="h-4 w-4" />
                  Delete
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Delete this recipe?</AlertDialogTitle>
                  <AlertDialogDescription>
                    This permanently removes &ldquo;{recipe.title}&rdquo; from your
                    library.
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction
                    onClick={onDelete}
                    className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                  >
                    Delete
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>
        </div>

        {recipe.description && (
          <p className="mb-4 text-muted-foreground">{recipe.description}</p>
        )}

        <div className="mb-6 flex flex-wrap gap-2">
          {recipe.total_time_minutes != null && (
            <Chip icon={<Clock className="h-3.5 w-3.5" />}>
              Total {formatMinutes(recipe.total_time_minutes)}
            </Chip>
          )}
          {recipe.prep_time_minutes != null && (
            <Chip icon={<Timer className="h-3.5 w-3.5" />}>
              Prep {formatMinutes(recipe.prep_time_minutes)}
            </Chip>
          )}
          {recipe.cook_time_minutes != null && (
            <Chip icon={<Timer className="h-3.5 w-3.5" />}>
              Cook {formatMinutes(recipe.cook_time_minutes)}
            </Chip>
          )}
          {recipe.servings != null && (
            <Chip icon={<Users className="h-3.5 w-3.5" />}>
              Serves {recipe.servings}
            </Chip>
          )}
          {recipe.cuisine && <Badge variant="outline">{recipe.cuisine}</Badge>}
          {recipe.course && <Badge variant="outline">{recipe.course}</Badge>}
          {recipe.difficulty && (
            <Badge variant="outline">{recipe.difficulty}</Badge>
          )}
          {recipe.tags.map((t) => (
            <Badge key={t} variant="secondary" className="font-normal">
              {t}
            </Badge>
          ))}
        </div>

        {recipe.source_url && (
          <a
            href={recipe.source_url}
            target="_blank"
            rel="noopener noreferrer"
            className="mb-6 inline-flex items-center gap-1 text-sm text-primary hover:underline"
          >
            <ExternalLink className="h-4 w-4" />
            {recipe.source_site ?? "Source"}
          </a>
        )}

        <div className="space-y-8">
          {recipe.parts.map((part, idx) => (
            <div key={idx} className="grid gap-8 lg:grid-cols-[1fr_1.5fr]">
              {part.name && (
                <section className="lg:col-span-2">
                  <h2 className="text-xl font-semibold">{part.name}</h2>
                </section>
              )}
              <IngredientsList items={part.ingredients} />
              <InstructionsList items={part.instructions} />
            </div>
          ))}
        </div>

        {recipe.notes && (
          <section className="mt-8">
            <h2 className="mb-2 text-lg font-semibold">Notes</h2>
            <p className="whitespace-pre-wrap text-sm text-foreground">
              {recipe.notes}
            </p>
          </section>
        )}
      </main>
    </div>
  );
}

function Chip({
  icon,
  children,
}: {
  icon?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <span className="inline-flex items-center gap-1 rounded-md bg-secondary px-2.5 py-0.5 text-xs text-secondary-foreground">
      {icon}
      {children}
    </span>
  );
}

function IngredientsList({ items }: { items: Ingredient[] }) {
  return (
    <section>
      <h3 className="mb-3 text-lg font-semibold">Ingredients</h3>
      <ul className="space-y-1.5 text-sm">
        {items.map((ing, i) => (
          <li key={i} className="border-b pb-1.5">
            <span className="font-medium">
              {[ing.quantity, ing.unit].filter(Boolean).join(" ")}
            </span>{" "}
            {ing.name}
            {ing.notes && (
              <span className="text-muted-foreground"> — {ing.notes}</span>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}

function InstructionsList({ items }: { items: InstructionStep[] }) {
  return (
    <section>
      <h3 className="mb-3 text-lg font-semibold">Instructions</h3>
      <ol className="space-y-4">
        {items.map((s, i) => (
          <li key={i} className="flex gap-3">
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground">
              {s.step}
            </span>
            <p className="text-sm leading-relaxed">{s.text}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}
