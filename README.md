# Antigravity Skills & Developer Toolkit

[![Antigravity](https://img.shields.io/badge/Antigravity-Customization-blue)](https://github.com/Ezyrath/antigravity-skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A curated collection of modular skills, operational runbooks, and rules for the **Antigravity AI** coding assistant.

This toolkit turns Antigravity into a specialized pair programmer for **Unreal Engine 5**, **C++ development**, **Git/GPG workflows**, and modern simulation architecture.

---

## 📦 What's Inside

### 1. `unreal-engine` (Skill)
- **Compilation Runbook**: Universal UBT and `make` compilation procedures for Linux and Windows.
- **Headless Testing**: Non-interactive command-line test runner (`-nullrhi -nosplash -unattended`).
- **Unreal MCP Integration**: Zero-Token Cold-Start interaction patterns for `unreal-mcp`.
- **Nanite Procedural Geometry**: Guidelines for `FMeshDescription`, `ComputeTriangleTangentsAndNormals`, and hybrid visual/physics architectures.
- **Helper Scripts**:
  - `scripts/build.sh`: Automatically detects `.uproject` and builds the target.
  - `scripts/run_headless_tests.sh`: Runs automated test queues headlessly.

### 2. `git-gpg-workflow` (Skill)
- **GPG Commit Signing**: Enforces `git commit -S` with KDE Wallet / `gpg-agent` non-interactive caching.
- **Multi-Repo Synchronization**: Step-by-step protocol for submodules and host repositories.
- **Clean Commits**: Rules and exclusions for intermediate build folders and temporary caches.

### 3. `vue-spacetimedb-webapp` (Skill)
- **Modern Full-Stack Architecture**: Vue 3 `<script setup lang="ts">`, Vuetify 3/4 semantic tokens, Pinia Setup Stores, and SpacetimeDB real-time WebSockets backend.
- **The "No-Mock" Testing Philosophy**: Fast Vitest unit/integration testing combined with live-backend Cypress E2E tests featuring direct database CLI auditing (`cy.task('spacetimeSql')`) and clean console enforcement.
- **Edge & Blob Storage**: Cloudflare Workers + R2 integration with Zero-Trust internal authorization callbacks to SpacetimeDB HTTP handlers.
- **Helper Scripts**:
  - `scripts/validate_webapp.sh`: Universal validation pipeline running TypeScript check (`vue-tsc`), linting (`eslint`), unit tests (`vitest`), and optional E2E suites.

### 4. Universal Rules (`rules/AGENTS.md`)
- Modern C++ standards for Unreal Engine (`UObject`, `AActor`, `TObjectPtr`, IWYU).
- Large World Coordinates (LWC 64-bit precision).
- Asynchronous multithreading (`TaskGraph`, `ParallelFor`).

---

## 🚀 Installation & Integration

### Option A: Global Installation (Recommended)
Clone directly into your global Antigravity plugins directory. All projects on your machine will automatically discover and load the skills:

```bash
git clone git@github.com:Ezyrath/antigravity-skills.git ~/.gemini/config/plugins/antigravity-skills
```

### Option B: Project Submodule (For Teams)
If you want the skills tracked directly within a specific repository:

```bash
cd "YourProjectRoot"
git submodule add git@github.com:Ezyrath/antigravity-skills.git .agents/plugins/antigravity-skills
git commit -S -m "chore: add antigravity-skills plugin"
```

### Option C: External Path via `plugins.json`
If you cloned the repository in a custom folder (e.g. `~/Documents/antigravity-skills`):

Add to `~/.gemini/config/plugins.json` (or `.agents/plugins.json` in your workspace):
```json
{
  "import_paths": [
    "/path/to/antigravity-skills"
  ]
}
```

---

## 📄 License
Released under the [MIT License](LICENSE).
