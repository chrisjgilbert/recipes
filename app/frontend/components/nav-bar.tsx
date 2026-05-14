import { Link, router } from "@inertiajs/react";
import { ChefHat, LogOut, Plus } from "lucide-react";

import { Button } from "@/components/ui/button";

export function NavBar() {
  return (
    <header className="sticky top-0 z-10 border-b bg-background/80 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
        <Link href="/" className="flex items-center gap-2 text-lg font-semibold">
          <ChefHat className="h-5 w-5 text-primary" />
          Recipes
        </Link>
        <div className="flex items-center gap-2">
          <Button asChild size="sm">
            <Link href="/recipes/new">
              <Plus className="h-4 w-4" />
              New
            </Link>
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => router.delete("/logout")}
          >
            <LogOut className="h-4 w-4" />
            Logout
          </Button>
        </div>
      </div>
    </header>
  );
}
