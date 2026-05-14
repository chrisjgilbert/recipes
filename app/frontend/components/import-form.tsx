import { useForm } from "@inertiajs/react";
import { ImagePlus, Link as LinkIcon, Loader2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface Props {
  importError: "not_a_recipe" | "fetch_failed" | "image_failed" | null;
}

type Tab = "url" | "photo";

export function ImportForm({ importError }: Props) {
  const [tab, setTab] = useState<Tab>("url");

  useEffect(() => {
    if (importError === "fetch_failed") {
      toast.error("Failed to fetch that URL. Try again or add manually.");
    } else if (importError === "image_failed") {
      toast.error("Couldn't read that photo. Try a clearer image or add manually.");
    }
  }, [importError]);

  return (
    <div className="space-y-4">
      <div role="tablist" className="inline-flex rounded-md border bg-muted p-1">
        <button
          role="tab"
          aria-selected={tab === "url"}
          type="button"
          onClick={() => setTab("url")}
          className={`rounded px-3 py-1.5 text-sm font-medium ${
            tab === "url" ? "bg-background shadow-sm" : "text-muted-foreground"
          }`}
        >
          URL
        </button>
        <button
          role="tab"
          aria-selected={tab === "photo"}
          type="button"
          onClick={() => setTab("photo")}
          className={`rounded px-3 py-1.5 text-sm font-medium ${
            tab === "photo" ? "bg-background shadow-sm" : "text-muted-foreground"
          }`}
        >
          Photo
        </button>
      </div>

      {tab === "url" ? <UrlForm /> : <PhotoForm />}

      {importError === "not_a_recipe" && (
        <div className="rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900">
          That doesn&apos;t look like a recipe.{" "}
          <a href="/recipes/new?manual=1" className="font-medium underline">
            Add manually
          </a>
          .
        </div>
      )}
    </div>
  );
}

function UrlForm() {
  const form = useForm({ url: "" });

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    form.post("/recipes/import", { preserveScroll: true });
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="import-url">Recipe URL</Label>
        <div className="relative">
          <LinkIcon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            id="import-url"
            type="url"
            required
            placeholder="https://www.bbcgoodfood.com/recipes/…"
            value={form.data.url}
            onChange={(e) => form.setData("url", e.target.value)}
            className="pl-9"
          />
        </div>
      </div>
      <Button type="submit" disabled={form.processing || !form.data.url}>
        {form.processing && <Loader2 className="animate-spin" />}
        {form.processing ? "Fetching and extracting…" : "Import"}
      </Button>
      {form.processing && (
        <p className="text-xs text-muted-foreground">
          This usually takes 3–15 seconds while we fetch the page and extract the
          recipe with the LLM.
        </p>
      )}
    </form>
  );
}

function PhotoForm() {
  const fileRef = useRef<HTMLInputElement>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const form = useForm<{ image: File | null; chef: string }>({ image: null, chef: "" });

  useEffect(() => {
    if (!form.data.image) {
      setPreview(null);
      return;
    }
    const url = URL.createObjectURL(form.data.image);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [form.data.image]);

  function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0] ?? null;
    form.setData("image", file);
  }

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.data.image) return;
    form.post("/recipes/import/image", {
      forceFormData: true,
      preserveScroll: true,
    });
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="import-photo">Recipe photo</Label>
        <label
          htmlFor="import-photo"
          className="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-md border border-dashed border-input bg-muted/40 px-4 py-8 text-sm text-muted-foreground hover:bg-muted"
        >
          {preview ? (
            <img
              src={preview}
              alt="Selected recipe"
              className="max-h-64 rounded-md object-contain"
            />
          ) : (
            <>
              <ImagePlus className="h-6 w-6" />
              <span>Tap to take or choose a photo of a recipe</span>
              <span className="text-xs">JPEG, PNG, WebP, GIF or HEIC, up to 10 MB</span>
            </>
          )}
        </label>
        <input
          ref={fileRef}
          id="import-photo"
          type="file"
          accept="image/*,.heic,.heif"
          capture="environment"
          className="sr-only"
          onChange={onFileChange}
        />
        {form.data.image && (
          <p className="text-xs text-muted-foreground">{form.data.image.name}</p>
        )}
      </div>
      <div className="space-y-2">
        <Label htmlFor="import-chef">Chef / author <span className="text-muted-foreground font-normal">(optional)</span></Label>
        <Input
          id="import-chef"
          type="text"
          placeholder="e.g. Nigella Lawson"
          value={form.data.chef}
          onChange={(e) => form.setData("chef", e.target.value)}
        />
      </div>
      <Button type="submit" disabled={form.processing || !form.data.image}>
        {form.processing && <Loader2 className="animate-spin" />}
        {form.processing ? "Extracting from photo…" : "Import from photo"}
      </Button>
      {form.processing && (
        <p className="text-xs text-muted-foreground">
          This usually takes 5–20 seconds while the LLM reads your photo.
        </p>
      )}
    </form>
  );
}
