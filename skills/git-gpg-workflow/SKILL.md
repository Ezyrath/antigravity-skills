---
name: git-gpg-workflow
description: >-
  Procedures for signed GPG Git commits, KDE Wallet / gpg-agent non-interactive configuration,
  multi-repository submodule synchronization, and conventional commit standards.
---

# Git GPG Signing & Multi-Repo Workflow

This skill standardizes Git operations, GPG signatures, and submodule management across repositories.

---

## 1. Strict GPG Commit Signing Rule

All commits across host repositories and submodules must be cryptographically signed:
```bash
git commit -S -m "<type>(<scope>): <subject>"
```

### Verification
```bash
git log -1 --show-signature
```
A valid commit displays:
`gpg: Good signature from "<Name> <Email>"`

### Non-Interactive Signing with KDE Wallet & gpg-agent
To ensure commits are signed without interactive prompt interruptions:
- Use `gpg-agent` configured with `pinentry-qt` or `pinentry-curses`.
- Store the GPG key passphrase securely in the system keyring (e.g. KDE Wallet).
- Once unlocked, `git commit -S` signs commits transparently and automatically.

---

## 2. Multi-Repo & Submodule Commit Protocol

When changes span both a submodule (e.g., in `Plugins/<PluginName>`) and the host repository:

1. **Step 1: Commit and Push Submodule First**
   ```bash
   cd "Plugins/<PluginName>"
   git add .
   git commit -S -m "feat(<scope>): implement new feature"
   git push origin main
   ```
2. **Step 2: Update Pointer and Push Host Repository**
   ```bash
   cd "<HostRepoRoot>"
   git add "Plugins/<PluginName>"
   git commit -S -m "chore(submodule): update <PluginName> to <hash>"
   git push origin main
   ```

---

## 3. Strict Exclusion Checklist

Never stage or commit temporary build artifacts, editor caches, or private configs:
- `Binaries/`
- `Intermediate/`
- `Saved/`
- `DerivedDataCache/`
- `.vs/`, `.idea/`, `compile_commands.json`
- Private key files or unencrypted credentials
