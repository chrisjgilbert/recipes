import { router, useForm, usePage } from "@inertiajs/react";
import { ChefHat } from "lucide-react";
import { useEffect } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface PageProps extends Record<string, unknown> {
  errors: { password?: string };
  flash: { alert?: string | null; notice?: string | null };
}

export default function Login() {
  const { errors, flash } = usePage<PageProps>().props;
  const form = useForm({ password: "" });

  useEffect(() => {
    if (errors.password) toast.error(errors.password);
    if (flash.alert) toast.error(flash.alert);
  }, [errors.password, flash.alert]);

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    form.post("/login", { preserveScroll: true });
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ChefHat className="h-6 w-6 text-primary" />
            Recipes
          </CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                autoFocus
                value={form.data.password}
                onChange={(e) => form.setData("password", e.target.value)}
              />
            </div>
            <Button
              type="submit"
              className="w-full"
              disabled={!form.data.password || form.processing}
            >
              {form.processing ? "Signing in…" : "Sign in"}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
