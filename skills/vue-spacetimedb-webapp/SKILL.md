---
name: vue-spacetimedb-webapp
description: >-
  Workflows, architectural guidelines, and testing runbooks for modern web applications
  built with Vue 3, Vuetify, Pinia, Vue Router, SpacetimeDB (real-time relational backend),
  Vitest, and Cypress E2E with real in-memory backends.
---

# Vue 3, Vuetify & SpacetimeDB Web Application Workflows

This skill provides architectural guidelines, best practices, and operational runbooks for developing and maintaining modern, real-time web applications using Vue 3, Vuetify, Pinia, SpacetimeDB, Cloudflare Workers/R2, Vitest, and Cypress.

---

## 1. Core Architecture & Philosophy

1. **Strict TypeScript & Composition API** :
   - Use `<script setup lang="ts">` exclusively.
   - Keep TypeScript in strict mode (`"strict": true` in `tsconfig.json`).
   - Run type checking via `vue-tsc --noEmit`.

2. **Single Source of Truth (No Ghost State)** :
   - SpacetimeDB (or your authoritative backend) is the sole source of truth.
   - **Never** perform fake optimistic client-side mutations or persist divergent ghost state in `localStorage`.
   - Local state in Pinia stores must reactively mirror database views via WebSocket subscriptions and event listeners (`onInsert`, `onUpdate`, `onDelete`).

3. **Decoupled Architecture & Multi-Tenancy** :
   - **Frontend** : Vue 3 + Vuetify + Pinia + Vue Router + Vue I18n.
   - **Authoritative Database** : SpacetimeDB (Rust module compiled to WebAssembly, in-memory relational engine with WebSocket sync).
   - **Edge & Blob Storage** : Cloudflare Workers + R2 (or S3-compatible object storage) for large assets (PDFs, images).
   - **Zero-Trust Storage Auth** : The edge worker verifies user permissions against SpacetimeDB via secure internal HTTP handlers before reading or mutating blobs.

---

## 2. Vuetify UI & Design System Guidelines

1. **Semantic Theming (Light & Dark)** :
   - Define explicit semantic tokens in the Vuetify configuration (`surface`, `surface-variant`, `on-surface`, `on-surface-variant`, `background`, `on-background`, `primary`, `secondary`, `error`, `info`, `success`, `warning`).
   - Avoid hardcoded palette colors (e.g., `color="red-darken-2"`). Rely on semantic tokens so styles adapt naturally between light and dark modes.
   - Store theme preferences in `localStorage` with automatic system fallback via `window.matchMedia('(prefers-color-scheme: dark)')`.

2. **Badge & Chip Contrast Rule** :
   - **Never** use `color="surface-variant"` for status chips, badges, or placeholder text (e.g., "Not specified"). On dark or light themes, this often produces unreadable low-contrast text.
   - Use semantic accents such as `color="secondary"` or `color="info"` with `variant="tonal"` to ensure optimal contrast and readability in all themes.

3. **Responsive Navigation Pattern** :
   - **Desktop (`mdAndUp`)** : Top application bar (`v-app-bar`), horizontal navigation tabs or menu dropdowns, workspace/tenant selector, profile menu.
   - **Mobile (`smAndDown`)** : Burger icon toggling a side navigation drawer (`v-navigation-drawer`) containing navigation links, workspace selector, locale switcher, and theme toggle.

4. **Page Header Hierarchy** :
   - On detail views (e.g. `/entities/:id`), place the back button or breadcrumb above the main heading (e.g. `← Back to list`) rather than beside it, preserving clean horizontal alignment for titles, subtitles, and action buttons.

5. **Icon Verification** :
   - When using Material Design Icons (`mdi-*`), ensure the icon name exists in `@mdi/font`.

---

## 3. Pinia State Management & SpacetimeDB Integration

1. **Setup Stores Pattern** :
   - Always prefer Setup Stores (`defineStore('name', () => { ... })`) using `ref()` and `computed()`.
   - Setup stores eliminate `this` context ambiguity and integrate cleanly with Vue's Composition API and TypeScript inference.

2. **SpacetimeDB Row-Level Security (RLS) & Private Tables** :
   - Master tables (`UserAccount`, `Workspace`, `Entity`, etc.) should remain **private** in the SpacetimeDB module.
   - Expose data exclusively through **Procedural Views** (`#[spacetimedb::view(public)]`) filtered by caller identity (`ctx.sender()`).
   - Subscribe from the client using view queries:
     ```typescript
     conn.subscriptionBuilder().subscribe([
       "SELECT * FROM my_workspaces",
       "SELECT * FROM my_entities"
     ]);
     ```

3. **Reducers as Transactions** :
   - All mutations occur by calling SpacetimeDB reducers (e.g. `conn.reducers.create_item(...)`).
   - Do not manually mutate client store arrays in the action that triggers the reducer; wait for the reactive WebSocket table event (`table.onInsert`) to update the store.

4. **Cascading Deletions & Entity-Centric Storage** :
   - When deleting an entity or workspace, implement cascading cleanup in both the database reducer and the storage worker (e.g., prefix deletion in R2: `entities/{entityId}/`).
   - Store entity attachments partitioned by entity ID (`entities/{entityId}/{fileId}`) rather than workspace ID, allowing entity transfers between workspaces without costly blob copies.

---

## 4. The "No-Mock" Testing Philosophy

Reliability comes from testing real systems together rather than testing mock assumptions.

### Level 1: Fast Unit & Integration Testing (Vitest)
- Test utilities, service logic, Pinia store state calculations, and i18n dictionaries.
- Command: `npm run test` or `npx vitest run`.

### Level 2: End-to-End Real Backend Testing (Cypress)
- **Zero Mock Policy** : Run Cypress against **live local services** :
  1. SpacetimeDB running locally in-memory (`spacetime start --in-memory`).
  2. Local Dev OIDC / auth emulator.
  3. Local Cloudflare Worker / Miniflare R2 emulator (`wrangler dev`).
  4. Vite frontend dev server.
- **Direct Database Auditing** :
  - Use custom Cypress tasks (e.g. `cy.task('spacetimeSql', { query: ... })`) to inspect database tables directly via the SpacetimeDB CLI.
  - Verify that UI actions actually persist data, trigger cascading deletions, or fail when unauthorized.
- **Clean Console Enforcement** :
  - Assert that test runs produce zero unhandled JavaScript errors or warnings in the browser console.

---

## 5. Operational Runbook & Common Commands

| Command | Purpose |
| :--- | :--- |
| `npm run dev` | Starts full local stack concurrently (SpacetimeDB, Auth, Worker, Vite). |
| `npm run type-check` | Runs `vue-tsc --noEmit` to validate all TypeScript types. |
| `npm run lint` / `npm run lint:fix` | Runs ESLint and auto-formats code according to project rules. |
| `npm run test` | Executes Vitest unit and integration test suite. |
| `npm run test:e2e` / `cypress:run` | Runs full Cypress E2E suite headlessly against the live local backend. |
| `npm run test:e2e:all` | Automatically boots all background services, runs Cypress, and tears down. |
| `npm run spacetime:start` | Boots local in-memory SpacetimeDB instance. |
| `npm run spacetime:dev` | Watches SpacetimeDB Rust module, auto-rebuilds and generates TS bindings. |
| `npm run spacetime:generate` | Manually regenerates TypeScript module bindings into `src/module_bindings/`. |
| `cargo test --manifest-path spacetimedb/Cargo.toml` | Executes SpacetimeDB backend unit and reducer tests in Rust. |

---

## 6. Helper Scripts & References

- Check out [spacetimedb_patterns.md](references/spacetimedb_patterns.md) for subscription lifecycles, RLS views, and HTTP handlers.
- Check out [real_backend_testing.md](references/real_backend_testing.md) for Cypress database auditing tasks and service orchestration.
- Use `scripts/validate_webapp.sh` to run the complete validation pipeline (`type-check`, `lint`, and `test`) in one command.
