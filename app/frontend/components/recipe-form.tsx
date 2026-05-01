import { useEffect } from "react";
import { Plus, Trash2 } from "lucide-react";
import { useFieldArray, useForm, type Control, type UseFormRegister } from "react-hook-form";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { RecipeInput } from "@/lib/types";

interface Props {
  defaultValues?: Partial<RecipeInput>;
  submitLabel: string;
  onSubmit: (values: RecipeInput) => Promise<void> | void;
  submitting?: boolean;
}

const EMPTY: RecipeInput = {
  title: "",
  source_url: null,
  source_site: null,
  description: null,
  image_url: null,
  prep_time_minutes: null,
  cook_time_minutes: null,
  total_time_minutes: null,
  servings: null,
  parts: [],
  tags: [],
  cuisine: null,
  course: null,
  difficulty: null,
  notes: null,
};

export function RecipeForm({ defaultValues, submitLabel, onSubmit, submitting }: Props) {
  const form = useForm<RecipeInput>({
    defaultValues: { ...EMPTY, ...defaultValues },
  });
  const { register, control, handleSubmit } = form;

  const parts = useFieldArray({ control, name: "parts" });

  useEffect(() => {
    if (parts.fields.length === 0) {
      parts.append({ name: "", ingredients: [], instructions: [] });
    }
    // Run once on mount to bootstrap an empty part for new recipes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const submit = handleSubmit(async (values) => {
    const tags = typeof (values as unknown as { tags: unknown }).tags === "string"
      ? ((values as unknown as { tags: string }).tags as string)
          .split(",")
          .map((t) => t.trim())
          .filter(Boolean)
      : values.tags;
    await onSubmit({ ...values, tags });
  });

  return (
    <form onSubmit={submit} className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Title" htmlFor="title" required>
          <Input id="title" {...register("title", { required: true })} />
        </Field>
        <Field label="Source URL" htmlFor="source_url">
          <Input id="source_url" {...register("source_url")} />
        </Field>
        <Field label="Image URL" htmlFor="image_url">
          <Input id="image_url" {...register("image_url")} />
        </Field>
        <Field label="Servings" htmlFor="servings">
          <Input
            id="servings"
            type="number"
            {...register("servings", { valueAsNumber: true })}
          />
        </Field>
        <Field label="Prep time (min)" htmlFor="prep_time_minutes">
          <Input
            id="prep_time_minutes"
            type="number"
            {...register("prep_time_minutes", { valueAsNumber: true })}
          />
        </Field>
        <Field label="Cook time (min)" htmlFor="cook_time_minutes">
          <Input
            id="cook_time_minutes"
            type="number"
            {...register("cook_time_minutes", { valueAsNumber: true })}
          />
        </Field>
        <Field label="Total time (min)" htmlFor="total_time_minutes">
          <Input
            id="total_time_minutes"
            type="number"
            {...register("total_time_minutes", { valueAsNumber: true })}
          />
        </Field>
        <Field label="Cuisine" htmlFor="cuisine">
          <Input id="cuisine" {...register("cuisine")} />
        </Field>
        <Field label="Course" htmlFor="course">
          <Input id="course" {...register("course")} />
        </Field>
        <Field label="Difficulty" htmlFor="difficulty">
          <Input id="difficulty" {...register("difficulty")} />
        </Field>
      </div>

      <Field label="Description" htmlFor="description">
        <Textarea id="description" rows={2} {...register("description")} />
      </Field>

      <Field label="Tags (comma separated)" htmlFor="tags">
        <Input
          id="tags"
          defaultValue={(defaultValues?.tags ?? []).join(", ")}
          {...register("tags" as never)}
        />
      </Field>

      <section>
        <div className="mb-2 flex items-center justify-between">
          <div>
            <h3 className="font-semibold">Ingredients &amp; instructions</h3>
            <p className="text-xs text-muted-foreground">
              Add a part for each section of the recipe. Use a blank name for a
              simple recipe, or names like &ldquo;For the rub&rdquo; / &ldquo;For
              the sauce&rdquo; for sectioned recipes.
            </p>
          </div>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() =>
              parts.append({ name: "", ingredients: [], instructions: [] })
            }
          >
            <Plus className="h-4 w-4" /> Add part
          </Button>
        </div>
        <div className="space-y-6">
          {parts.fields.map((field, i) => (
            <PartFields
              key={field.id}
              index={i}
              control={control}
              register={register}
              onRemove={() => parts.remove(i)}
            />
          ))}
        </div>
      </section>

      <Field label="Notes" htmlFor="notes">
        <Textarea id="notes" rows={3} {...register("notes")} />
      </Field>

      <div>
        <Button type="submit" disabled={submitting}>
          {submitting ? "Saving…" : submitLabel}
        </Button>
      </div>
    </form>
  );
}

function Field({
  label,
  htmlFor,
  required,
  children,
}: {
  label: string;
  htmlFor?: string;
  required?: boolean;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor={htmlFor}>
        {label}
        {required && <span className="text-primary"> *</span>}
      </Label>
      {children}
    </div>
  );
}

function PartFields({
  index,
  control,
  register,
  onRemove,
}: {
  index: number;
  control: Control<RecipeInput>;
  register: UseFormRegister<RecipeInput>;
  onRemove: () => void;
}) {
  const ingredients = useFieldArray({
    control,
    name: `parts.${index}.ingredients` as const,
  });
  const instructions = useFieldArray({
    control,
    name: `parts.${index}.instructions` as const,
  });

  return (
    <div className="rounded-md border border-border p-4 space-y-4">
      <div className="flex items-end gap-2">
        <div className="flex-1">
          <Label htmlFor={`parts.${index}.name`}>
            Part name
          </Label>
          <Input
            id={`parts.${index}.name`}
            placeholder="Leave blank for a simple recipe, or e.g. &quot;For the rub&quot;"
            {...register(`parts.${index}.name` as const)}
          />
        </div>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          onClick={onRemove}
          aria-label="Remove part"
        >
          <Trash2 className="h-4 w-4" />
        </Button>
      </div>

      <div>
        <div className="mb-2 flex items-center justify-between">
          <h4 className="text-sm font-medium">Ingredients</h4>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() =>
              ingredients.append({ quantity: null, unit: null, name: "", notes: null })
            }
          >
            <Plus className="h-4 w-4" /> Add
          </Button>
        </div>
        <div className="space-y-2">
          {ingredients.fields.map((field, i) => (
            <div key={field.id} className="grid grid-cols-12 gap-2">
              <Input
                placeholder="Qty"
                {...register(`parts.${index}.ingredients.${i}.quantity` as const)}
                className="col-span-2"
              />
              <Input
                placeholder="Unit"
                {...register(`parts.${index}.ingredients.${i}.unit` as const)}
                className="col-span-2"
              />
              <Input
                placeholder="Name"
                {...register(`parts.${index}.ingredients.${i}.name` as const, {
                  required: true,
                })}
                className="col-span-4"
              />
              <Input
                placeholder="Notes"
                {...register(`parts.${index}.ingredients.${i}.notes` as const)}
                className="col-span-3"
              />
              <Button
                type="button"
                variant="ghost"
                size="icon"
                onClick={() => ingredients.remove(i)}
                aria-label="Remove ingredient"
                className="col-span-1"
              >
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          ))}
        </div>
      </div>

      <div>
        <div className="mb-2 flex items-center justify-between">
          <h4 className="text-sm font-medium">Instructions</h4>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() =>
              instructions.append({ step: instructions.fields.length + 1, text: "" })
            }
          >
            <Plus className="h-4 w-4" /> Add
          </Button>
        </div>
        <div className="space-y-2">
          {instructions.fields.map((field, i) => (
            <div key={field.id} className="grid grid-cols-12 gap-2">
              <Input
                type="number"
                {...register(`parts.${index}.instructions.${i}.step` as const, {
                  valueAsNumber: true,
                  required: true,
                })}
                className="col-span-1"
              />
              <Textarea
                rows={2}
                {...register(`parts.${index}.instructions.${i}.text` as const, {
                  required: true,
                })}
                className="col-span-10"
              />
              <Button
                type="button"
                variant="ghost"
                size="icon"
                onClick={() => instructions.remove(i)}
                aria-label="Remove step"
                className="col-span-1"
              >
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
