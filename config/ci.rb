# Run using bin/ci

CI.run do
  step "Setup: Ruby", "bin/setup --skip-server"
  step "Setup: JS", "npm ci"

  step "Tests: Ruby", "bin/rspec"
  step "Tests: JS", "npx vitest run"
  step "Typecheck: TS", "npx tsc --noEmit"
end
