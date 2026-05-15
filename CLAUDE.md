# CLAUDE.md

Guidance for Claude Code when working in this repo. Keep it terse; trust the reader.

## What this is

Cookery Notes — a personal recipe library. Paste a URL (or upload a photo),
an LLM extracts structured recipe JSON, the result is stored in Postgres and
browsable via a searchable / sortable React UI.

Single-user app deployed to one Hetzner VPS via Kamal 2. Auth is a single
shared password (no user accounts).

## Stack

- **Backend**: Rails 8.1, Ruby 3.3.6, Postgres 16, Solid Queue, Solid Cache
- **Frontend**: Inertia.js + React 18 + TypeScript, Vite, Tailwind, shadcn/ui
- **LLM**: Anthropic API via `ruby-anthropic`, optional Langfuse tracing
- **Tests**: RSpec (Ruby), Vitest + Testing Library (JS), Playwright (E2E)
- **Deploy**: Kamal 2, Docker, Hetzner CX22

## Layout

- `app/controllers/` — Rails controllers; render Inertia pages, no API/JSON layer
- `app/models/recipe.rb` — the only domain model; `parts` is a JSONB array of `{name, ingredients[], instructions[]}`
- `app/services/` — extraction pipeline: `JinaFetcher` → `RecipeExtractor` (Anthropic) → `IngredientUnitNormalizer`
- `app/frontend/pages/` — Inertia page components (PascalCase, mirror controller actions)
- `app/frontend/components/` — shared UI; `ui/` is shadcn primitives
- `app/frontend/entrypoints/inertia.tsx` — SPA boot
- `spec/` — RSpec (models, requests, services)
- `e2e/` — Playwright; uses `E2E_FAKE_SERVICES=1` initializer to stub Anthropic/Jina/credentials
- `config/credentials/test.yml.enc` — encrypted under `master.key`; intentionally empty (specs mock `credentials.*`)
- `bin/ci` + `config/ci.rb` — local CI runner; mirrors `.github/workflows/ci.yml`

## TDD workflow (RED → GREEN → REFACTOR)

Default to TDD for new behaviour. Skip only for pure refactors, doc edits,
config tweaks, or one-line tweaks where a test would just restate the change.

1. **RED** — write the smallest failing test that pins the new behaviour.
   Run it and confirm it fails *for the right reason* (assertion failure,
   not a typo or missing import).
2. **GREEN** — write the minimum code to make that test pass. Resist the
   urge to add neighbouring features; one assertion at a time.
3. **REFACTOR** — clean up names, extract helpers, remove duplication. Tests
   stay green throughout.

Pick the test level that matches the behaviour:
- **Model/service logic** → RSpec unit (`spec/models/`, `spec/services/`)
- **Request/response, redirects, auth** → RSpec request spec (`spec/requests/`)
- **Component rendering, debouncing, form state** → Vitest + Testing Library
- **Full user flow across pages** → Playwright (`e2e/`); slow, reserve for golden paths

When fixing a bug, write the failing test first — it locks the regression in.
PR #21 (CSRF token re-sync) is the canonical example: extract the unit
(`app/frontend/lib/csrf.ts`), test the rotation case, then wire it back in.

## Commands

```sh
bin/dev                       # foreman: Rails + Vite + Solid Queue
bin/ci                        # full local CI: rspec, vitest, tsc
bin/rspec spec/models         # subset
npx vitest run path/to/file   # one JS test file
npx vitest                    # JS test watcher
npm run test:e2e              # Playwright (builds + boots a real server)
bin/rails db:prepare          # create + migrate + seed
bin/rails credentials:edit    # uses config/master.key
```

`config/master.key` is gitignored; ask the owner if you don't have it.
Without it, `bin/rspec` boots fail at `ActiveRecord::Encryption` config.

## Conventions

- **Credentials**: `Rails.application.credentials.app_password_hash!` and
  `anthropic_api_key!` are the only secrets read at runtime. Specs `allow`
  these on `Rails.application.credentials`; never read real ENV in tests.
- **Recipe shape**: `parts` is the canonical structure (not flat ingredient
  list). One unnamed part is fine; multiple named parts (`"For the rub"`,
  `"For the sauce"`) are also supported.
- **Normalizer is lenient**: `IngredientUnitNormalizer.normalize_parts`
  coerces malformed LLM output into the canonical shape *before* validation.
  Validations only catch shapes the normalizer can't rescue (e.g. `parts`
  not being an array at all). Don't add validations for cases the normalizer
  already coerces — write a normalizer spec instead.
- **Inertia, not JSON APIs**: controllers `render inertia: "Pages/Name", props:`.
  Add JSON endpoints only when a non-Inertia client actually needs them.
- **CSRF**: `app/frontend/lib/csrf.ts#syncCsrfToken` re-reads the meta tag
  on every successful Inertia navigation. Rails rotates the token on
  `reset_session` (logout), so the axios default must stay in sync.
- **Service worker** (`public/sw.js`): bump `VERSION` whenever caching
  behaviour changes; the activate handler purges old caches. Auth paths
  (`/login`, `/logout`) are never cached — they carry per-session CSRF tokens.
- **Search**: a Postgres trigger maintains `recipes.search_tsv` from title
  + chef + flattened ingredient names across `parts`. Use the `Recipe.search`
  scope; don't add a separate index.

## Things to avoid

- Don't add rubocop, brakeman, or bundler-audit steps to CI without first
  installing those gems — `config/ci.rb` only runs what's actually wired up.
- Don't reintroduce a separate "chef" filter input on the recipes index;
  it was unified into the single search box in #20.
- Don't bake CSRF tokens into precached HTML in the service worker (PR #21).
- Don't `git rm` `config/credentials/test.yml.enc` — it's intentionally empty
  but must exist and be decryptable under `master.key` for Rails 8's
  `ActiveRecord::Encryption` boot hook.
