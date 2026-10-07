# SpacetimeDB & Vue 3 Integration Patterns

This guide details best practices and implementation patterns for integrating SpacetimeDB with Vue 3, Pinia, and strict TypeScript.

---

## 1. Backend Module Architecture (Rust)

### Private Tables & Public Procedural Views
For secure multi-tenant architectures, tables containing sensitive domain data should remain private. Expose data exclusively through **procedural views** that enforce Row-Level Security (RLS) based on the caller's authenticated identity (`ctx.sender()`).

```rust
use spacetimedb::{table, view, Identity, ReducerContext, ViewContext};

// 1. Private Table (Inaccessible directly from client queries)
#[table(accessor = workspaces)]
pub struct Workspace {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    pub name: String,
    pub owner_identity: Identity,
}

// 2. Procedural Public View (Filtered by caller identity)
#[view(accessor = my_workspaces, public)]
pub fn my_workspaces(ctx: &ViewContext) -> impl Iterator<Item = Workspace> + '_ {
    let caller = ctx.sender();
    workspaces()
        .iter()
        .filter(move |ws| ws.owner_identity == caller)
}
```

### Scheduled Reducers & Timers
Use SpacetimeDB Schedule Tables to run periodic background tasks (such as maintenance checks or cleanup) directly in the database engine without external cron jobs:

```rust
use spacetimedb::{table, ScheduleAt, ReducerContext};

#[table(accessor = maintenance_timer, scheduled(run_maintenance))]
pub struct MaintenanceTimer {
    #[primary_key]
    pub scheduled_id: u64,
    pub scheduled_at: ScheduleAt,
}

#[spacetimedb::reducer]
pub fn run_maintenance(ctx: &ReducerContext, _timer: MaintenanceTimer) -> Result<(), String> {
    // Perform periodic evaluation or cleanup logic here
    Ok(())
}
```

### Zero-Trust Internal HTTP Handlers
Expose secure endpoints for server-to-server validation (e.g. edge storage workers verifying user permissions) using `#[spacetimedb::http::handler]`:

```rust
use spacetimedb::http::{handler, Request, Response, StatusCode};

#[handler]
pub fn verify_access(req: Request) -> Response {
    // 1. Validate internal shared secret header
    let auth_header = req.header("authorization").unwrap_or_default();
    if auth_header != "Bearer YOUR_SHARED_STORAGE_SECRET" {
        return Response::builder()
            .status(StatusCode::UNAUTHORIZED)
            .body(b"Unauthorized".to_vec())
            .build();
    }

    // 2. Verify entity/workspace permissions
    Response::builder()
        .status(StatusCode::OK)
        .header("content-type", "application/json")
        .body(br#"{"allowed": true}"#.to_vec())
        .build()
}
```

---

## 2. Frontend Integration (TypeScript & Pinia)

### Establishing the Connection & Subscriptions
Initialize the `DbConnection` singleton and register WebSocket subscriptions to your procedural views:

```typescript
import { DbConnection } from '@/module_bindings';

export async function initSpacetimeConnection(token: string | null) {
  const conn = DbConnection.builder()
    .with_uri(import.meta.env.VITE_SPACETIMEDB_URI || 'ws://127.0.0.1:3000')
    .with_module_name('my_app_module')
    .with_token(token || undefined)
    .on_connect((ctx, identity, token) => {
      console.log('Connected to SpacetimeDB with identity:', identity);

      // Subscribe to public procedural views
      ctx.subscriptionBuilder().subscribe([
        'SELECT * FROM my_workspaces',
        'SELECT * FROM my_entities',
      ]);
    })
    .on_disconnect(() => {
      console.warn('Disconnected from SpacetimeDB');
    })
    .build();

  return conn;
}
```

### Binding SpacetimeDB Events to Pinia Setup Stores
Do not manually insert items into local state arrays when dispatching reducers. Instead, register table event listeners (`onInsert`, `onUpdate`, `onDelete`) inside your Pinia setup stores to automatically update reactive state:

```typescript
import { defineStore } from 'pinia';
import { ref } from 'vue';
import type { Workspace } from '@/module_bindings';
import { conn } from '@/services/spacetimedb';

export const useWorkspaceStore = defineStore('workspace', () => {
  const workspaces = ref<Workspace[]>([]);
  const activeWorkspace = ref<Workspace | null>(null);

  // Wire table events to reactive state
  conn.db.my_workspaces.onInsert((ctx, row) => {
    workspaces.value.push(row);
  });

  conn.db.my_workspaces.onUpdate((ctx, oldRow, newRow) => {
    const idx = workspaces.value.findIndex(w => w.id === newRow.id);
    if (idx !== -1) workspaces.value[idx] = newRow;
  });

  conn.db.my_workspaces.onDelete((ctx, row) => {
    workspaces.value = workspaces.value.filter(w => w.id !== row.id);
    if (activeWorkspace.value?.id === row.id) {
      activeWorkspace.value = null;
    }
  });

  async function createWorkspace(name: string) {
    // Invoke reducer; local state updates when the onInsert event arrives
    await conn.reducers.create_workspace({ name });
  }

  return {
    workspaces,
    activeWorkspace,
    createWorkspace,
  };
});
```

---

## 3. Tooling & Build Workflow

- **Auto-Generate Bindings** :
  ```bash
  spacetime dev --client-lang typescript --module-bindings-path src/module_bindings
  ```
- **Manual Binding Regeneration** :
  ```bash
  spacetime generate --client-lang typescript --out-dir src/module_bindings
  ```
- **Conflict Handling** :
  - In local development, use `--delete-data=on-conflict` with `spacetime dev` to allow smooth schema migrations without manual database drops.
  - In production or staging, deploy schema updates with `--delete-data=never`.
