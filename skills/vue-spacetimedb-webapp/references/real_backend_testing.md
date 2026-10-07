# Real-Backend End-to-End Testing with Cypress & SpacetimeDB

This guide outlines the "No-Mock" testing methodology, showing how to execute end-to-end Cypress tests against live local backend services, perform direct database assertions via CLI tasks, and enforce clean console standards.

---

## 1. The "No-Mock" Testing Philosophy

Mocking API calls in frontend tests often hides race conditions, serialization mismatches, authentication token handling bugs, and cascading deletion flaws.

In this architecture:
1. **Live Local Database** : SpacetimeDB runs locally in-memory (`spacetime start --in-memory`).
2. **Real WebSockets** : The client connects via standard WebSocket subscriptions and dispatches real reducers.
3. **Real Edge Worker** : A local instance of Cloudflare Worker (Miniflare / Wrangler) emulates object storage and endpoints.
4. **Local Auth Provider** : A lightweight local OIDC/PKCE server simulates identity provider flows.

---

## 2. Setting Up Database Assertions in Cypress

To verify that UI actions accurately persist data in SpacetimeDB, configure a Node task in `cypress.config.ts` that executes SQL queries using the SpacetimeDB CLI:

```typescript
// cypress.config.ts
import { defineConfig } from 'cypress';
import { execSync } from 'child_process';

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3001',
    setupNodeEvents(on, config) {
      on('task', {
        spacetimeSql({ query, database = 'my_app_module' }: { query: string; database?: string }) {
          try {
            const raw = execSync(
              `spacetime sql --server local ${database} "${query}" --format json`,
              { encoding: 'utf-8', timeout: 5000 }
            );
            return JSON.parse(raw);
          } catch (err: any) {
            console.error('Failed to execute SpacetimeDB SQL query:', err.message);
            throw err;
          }
        },
      });
    },
  },
});
```

---

## 3. Writing Database-Audited Tests

Use `cy.task('spacetimeSql')` within test specs to verify both UI updates and true database state:

```typescript
// cypress/e2e/entity_lifecycle.cy.ts
describe('Entity Lifecycle with Real Database Auditing', () => {
  beforeEach(() => {
    cy.visit('/entities');
  });

  it('creates an entity and confirms record in SpacetimeDB', () => {
    const entityName = `Test Entity ${Date.now()}`;

    // 1. UI Interaction
    cy.get('[data-cy="add-entity-btn"]').click();
    cy.get('[data-cy="entity-name-input"]').type(entityName);
    cy.get('[data-cy="submit-btn"]').click();

    // 2. DOM Assertion
    cy.contains(entityName).should('be.visible');

    // 3. Direct Database Audit (Verify real persistence)
    cy.task('spacetimeSql', {
      query: `SELECT count(*) as count FROM entity WHERE name = '${entityName}'`,
    }).then((res: any) => {
      expect(Number(res[0]?.count)).to.equal(1);
    });
  });

  it('deletes an entity and verifies cascading database cleanup', () => {
    // 1. Delete entity via UI
    cy.get('[data-cy="delete-entity-btn"]').first().click();
    cy.get('[data-cy="confirm-delete-btn"]').click();

    // 2. Direct Database Audit (Verify cascading cleanup)
    cy.task('spacetimeSql', {
      query: `SELECT count(*) as count FROM entity_attachment WHERE entity_id = 1`,
    }).then((res: any) => {
      expect(Number(res[0]?.count)).to.equal(0);
    });
  });
});
```

---

## 4. Enforcing Clean Browser Consoles

A rigorous web app should produce zero unhandled errors or console warnings during test execution:

```typescript
// cypress/support/e2e.ts
Cypress.on('window:before:load', (win) => {
  cy.spy(win.console, 'error').as('consoleError');
  cy.spy(win.console, 'warn').as('consoleWarn');
});

afterEach(() => {
  cy.get('@consoleError').should((spy: any) => {
    const calls = spy.getCalls();
    if (calls.length > 0) {
      const messages = calls.map((c: any) => c.args.join(' ')).join('\n');
      throw new Error(`Unexpected browser console errors found during test:\n${messages}`);
    }
  });
});
```

---

## 5. Automated Orchestration

For CI/CD and single-command local runs, orchestrate the full stack with automated teardown:

```json
// package.json scripts example
{
  "scripts": {
    "test:e2e:all": "start-server-and-test 'npm run spacetime:start' 3000 'npm run dev:client-only' 3001 'npm run cypress:run'"
  }
}
```
