# AGENTS.md — stow.sh

<!--toc:start-->
- [AGENTS.md — stow.sh](#agentsmd-stowsh)
  - [Project Overview](#project-overview)
    - [Key features beyond GNU Stow](#key-features-beyond-gnu-stow)
  - [Directory Structure](#directory-structure)
  - [Architecture](#architecture)
    - [Execution Flow](#execution-flow)
    - [XDG-Aware Folding](#xdg-aware-folding)
    - [Condition + Fold Interaction](#condition-fold-interaction)
    - [Fold Resolution](#fold-resolution)
    - [Auto-Unfold](#auto-unfold)
    - [Module Dependency Graph](#module-dependency-graph)
    - [Naming Conventions](#naming-conventions)
  - [Known Issues](#known-issues)
    - [Medium](#medium)
  - [Development Guidelines](#development-guidelines)
    - [Commit Convention](#commit-convention)
    - [Shell Style](#shell-style)
    - [Testing](#testing)
    - [When Making Changes](#when-making-changes)
    - [Releasing / Version Bumps](#releasing-version-bumps)
<!--toc:end-->

## Project Overview

**stow.sh** is a pure-Bash reimplementation of GNU Stow — a symlink farm manager for dotfiles.
License: MIT | Author: David Kristiansen

### Key features beyond GNU Stow

- **Conditional dotfiles** via `##` annotations (e.g. `file##os.linux,shell.bash`)
- **Git-aware filtering** using `.gitignore` rules (including negation patterns)
- **`.stowignore` file**: per-package glob patterns to permanently exclude files and directories (e.g. `Makefile`, `*.baseline`, `.github`)
- **Quad-layer filtering**: stowignore, git-aware, regex (`-i`), glob (`-I`)
- **User-facing reports**: clean stdout output showing what was stowed/unstowed (`+`/`-`/`~`/`?` symbols)
- **Directory folding**: symlink whole directories when possible
- **XDG-aware folding**: fold barriers derived from `XDG_*` environment variables
- **Auto-unfold**: when a fold point conflicts with an existing real directory at the target, automatically falls back to creating individual file symlinks inside it

## Directory Structure

```
stow.sh/
├── bin/
│   └── stow.sh              # CLI entrypoint — sets STOW_ROOT, execs src/main.sh
├── src/
│   ├── main.sh              # Orchestrator — pipeline: parse → scan → filter → fold → stow/unstow
│   ├── args.sh              # CLI argument parsing, path setup, getter functions
│   ├── log.sh               # Logging framework (color, debug levels, stderr output, user reports)
│   ├── filter.sh            # Path filtering engine (stowignore / git / regex / glob)
│   ├── scan.sh              # Package directory scanner (find -type f)
│   ├── fold.sh              # Directory folding + target resolution (annotation + barrier + exclusion aware)
│   ├── stow.sh              # Stow/unstow operations (symlink creation/removal, conflict handling, auto-unfold)
│   ├── xdg.sh               # XDG fold barrier detection from environment variables
│   ├── conditions.sh        # Annotation parsing, condition evaluation, plugin loader
│   └── version.sh           # Version constant (managed by `make release`)
├── conditions.d/            # Built-in condition predicates (loaded as plugins)
│   ├── docker.sh            #   docker — /.dockerenv check
│   ├── desktop.sh           #   desktop — no battery (stationary machine)
│   ├── exe.sh               #   exe.<name> — executable in $PATH
│   ├── extension.sh         #   extension — always true (preserve file extensions)
│   ├── laptop.sh            #   laptop — has battery (portable machine)
│   ├── no.sh                #   no — always false (never deploy)
│   ├── os.sh                #   os.<name> — /etc/os-release match
│   ├── shell.sh             #   shell.<name> — $SHELL basename match
│   ├── wm.sh                #   wm.<name> — alias for exe
│   └── wsl.sh               #   wsl — /proc/version check
├── hooks/
│   └── commit-msg           # Git hook — validates conventional commit format (install via: make hooks)
├── test/
│   ├── args.bats            # Tests for args.sh (45 tests)
│   ├── conditions.bats      # Tests for conditions, annotations, sanitization, plugins (31 tests)
│   ├── filter.bats          # Tests for filter.sh (14 tests)
│   ├── fold.bats            # Tests for fold.sh: folding, barriers, exclusions (24 tests)
│   ├── integration.bats     # End-to-end tests via bin/stow.sh (64 tests)
│   ├── scan.bats            # Tests for scan.sh (8 tests)
│   ├── stow.bats            # Tests for stow.sh: stow/unstow operations (27 tests)
│   ├── xdg.bats             # Tests for xdg.sh: XDG barrier computation (10 tests)
│   └── fixtures/
│       └── paths.bats       # Fixture: realistic dotfile path list (unused)
├── assets/
│   └── logo.png             # Project logo (transparent PNG)
├── Makefile                 # install / uninstall / hooks / test / release targets
├── CONTRIBUTING.md          # Development setup, architecture, commit conventions
├── .github/
│   └── workflows/
│       └── release.yml      # CI: test + tarball + GitHub Release on tag push
├── .editorconfig            # shfmt formatting rules (4-space indent)
└── .gitignore               # Ignores SHOULD_BE_IGNORED/
```

## Architecture

### Execution Flow

```
bin/stow.sh  →  sets STOW_ROOT  →  exec src/main.sh "$@"
                                          │
                  sources: version.sh, log.sh, args.sh, conditions.sh,
                           filter.sh, scan.sh, fold.sh, xdg.sh, stow.sh
                  loads condition plugins (conditions.d/*.sh + user overrides)
                                          │
                                       main()
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
             parse_args()          setup_paths()      compute_xdg_barriers()
             (CLI flags)        (source/target dirs)  (XDG_* → fold barriers)
                                                               │
                              for each package: resolve_package()
                                                               │
                                                     load_stowignore()
                                                     (.stowignore glob patterns)
                                                               │
                                                        scan_package()
                                                        (find -type f)
                                                               │
                                                     filter_candidates()
                                                     (stowignore + git + regex + glob)
                                                               │
                                                     fold_targets()
                                                     (resolve: fold points + individual files)
                                                               │
                                                      resolved_targets[]
                                                     (final resolved list for symlinking)
                                                               │
                                              stow_package() / unstow_package()
                                              (evaluate conditions, strip ## annotations,
                                               create/remove symlinks, handle conflicts)
```

### XDG-Aware Folding

XDG directories (derived from set `XDG_*` environment variables) act as fold barriers:

- **No hardcoded paths** — barriers are computed purely from environment variables
- **Fold stops at the barrier** — the XDG directory itself cannot be a symlink
- **Children can still fold** — e.g. `.config/nvim/` can be symlinked as a whole
- **Ancestors are protected** — if `.local/share` is a barrier, `.local` also cannot fold
- **On by default** — disable with `--no-xdg`

Checked variables: `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`,
`XDG_CACHE_HOME`, `XDG_BIN_HOME`, `XDG_RUNTIME_DIR`

Example with `XDG_CONFIG_HOME=/home/user/.config` and target `/home/user`:
- Barrier: `.config`
- `.config/nvim/` → can be a single symlink (child of barrier)
- `.config/` → must be a real directory (barrier itself)

### Condition + Fold Interaction

Annotations (`##`) affect the pipeline at two points:

1. **Fold phase**: an annotated directory (e.g. `dir##cond/`) CAN be a fold point
   if all children inside it are clean (no `##` in their own names). Only ancestors
   ABOVE the deepest annotated segment are tainted — they would expose the raw `##`
   name if folded. A directory with a `##`-annotated child file cannot be folded.
2. **Stow phase**: each annotated path has its conditions evaluated. Conditions on
   **directory segments propagate** to all files underneath — if a directory has
   `##no`, every file inside is skipped. If conditions pass, the symlink target
   uses the annotated name while the link name is sanitized (annotations stripped).
   If conditions fail, the file/directory is skipped entirely.

Example: `.config/mise/conf.d/20-desktop.toml##!docker`
- Fold: `conf.d/` cannot be folded (has annotated child)
- Stow: if not in Docker, symlink as `20-desktop.toml`; if in Docker, skip

Example: `.local/lib/stow.sh##no/src/main.sh`
- Fold: `stow.sh##no/` CAN fold (clean children, annotation is on directory itself)
- Stow: `##no` condition fails → entire directory fold point is skipped as one unit

Example: `.config/zsh##shell.zsh/.zshrc`
- Fold: `zsh##shell.zsh/` CAN fold (clean children); `.config` is tainted (ancestor)
- Stow: if shell is zsh, symlink `~/.config/zsh → .../zsh##shell.zsh`; otherwise skip

### Fold Resolution

`fold_targets` receives a single candidate list (post-filter) and the package
root path. It returns the final resolved target list:

- **Fold points**: directories that can be symlinked as a whole (shallowest/maximal)
- **Individual files**: files not covered by any fold point

A directory is foldable only if:
1. All entries on disk under it are accounted for in the candidate list
   (verified via bash glob on the actual filesystem — no fork)
2. No descendant has a `##` annotation in its own name
3. It is not a fold barrier or ancestor of a barrier

Completeness is checked bottom-up: child directories are resolved before
parents. Symlinks inside the package directory are ignored (scan only finds
regular files via `find -type f`).

```
Usage: stow_sh::fold_targets [--barrier=PATH ...] pkg_root -- cand1 cand2 ...
```

Example output with `--barrier=.config`:
```
Input candidates:
  .config/nvim/init.lua
  .config/nvim/lua/plugins.lua
  .config/mise/conf.d/00-core.toml
  .config/mise/conf.d/20-desktop.toml##!docker
  .config/mise/config.toml
  .bashrc

Output:
  .bashrc                                      (flat file)
  .config/mise/conf.d/00-core.toml             (individual — tainted subtree)
  .config/mise/conf.d/20-desktop.toml##!docker (individual — annotated)
  .config/mise/config.toml                     (individual — tainted parent)
  .config/nvim                                 (fold point — clean subtree)
```

### Auto-Unfold

When a fold point (directory) conflicts with an existing real directory at the
target, stow automatically falls back to creating individual file symlinks
inside the existing directory. This handles common real-world scenarios:

- **`.gnupg/`**: only `gpg-agent.conf` in dotfiles, but `~/.gnupg` has private keys, keyrings
- **`.config/opencode/`**: dotfiles have config files, but target has app-generated `node_modules/`, `bun.lock`
- **`.config/teams-for-linux/`**: only `config.json` in dotfiles, but target has Electron app data

**Stow behavior**: `__create_link` detects `source_path` is a directory AND
`link_path` is an existing real directory (not a symlink). Instead of erroring,
it enumerates **immediate children** of the source directory and calls
`__create_link` for each one. Child directories that don't exist at the target
become directory symlinks (folded); those that do exist as real directories
trigger recursive auto-unfold. This minimizes the number of symlinks created.

**Unstow behavior**: `__remove_link` detects `expected_source` is a directory AND
`link_path` is a real directory (not a symlink). It enumerates immediate children
of the source directory and calls `__remove_link` for each one. Directory
symlinks are removed directly; real directories recurse. Empty directories are
cleaned up by the existing parent-directory cleanup logic.

Example with `.config/opencode` (target has `bun.lock`, `node_modules/`):
```
~/.config/opencode/           (real dir — auto-unfolded)
  agents/ → pkg/agents/       (directory symlink — didn't exist at target)
  themes/ → pkg/themes/       (directory symlink — didn't exist at target)
  opencode.json → pkg/...     (file symlink)
  bun.lock                    (untouched app file)
  node_modules/               (untouched app directory)
```

### Module Dependency Graph

```
main.sh
  ├── version.sh    (version constant — no deps)
  ├── log.sh        (logging — no deps)
  ├── args.sh       (arg parsing — calls log.sh functions)
  ├── conditions.sh (## annotations, condition evaluation, plugin loader — calls log.sh)
  │     └── loads: conditions.d/*.sh (built-ins), then $XDG_CONFIG_HOME/stow.sh/conditions/*.sh (user)
  ├── filter.sh     (filtering — calls log.sh, reads args.sh state)
  ├── scan.sh       (scanning — calls log.sh)
  ├── fold.sh       (folding — calls log.sh, calls conditions.sh for annotation detection)
  ├── xdg.sh        (XDG barriers — calls log.sh, reads XDG_* env vars)
  └── stow.sh       (stow/unstow ops — calls log.sh, args.sh, conditions.sh)
```

### Naming Conventions

All functions use `stow_sh::` namespace prefix.
Condition predicates use `stow_sh::condition::<type>` namespace (e.g. `stow_sh::condition::os`).
State variables use `_stow_sh_` prefix with getter functions (e.g. `stow_sh::get_source()`).

## Known Issues

### Medium

1. **Subshell getter overhead**: every `$(stow_sh::get_*)` call forks a subshell.

## Development Guidelines

### Commit Convention

This project enforces [Conventional Commits](https://www.conventionalcommits.org/).
A `commit-msg` git hook validates the format. Install via `make hooks`.

**Format**: `<type>[(<scope>)][!]: <description>`

**Allowed types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

**Scopes** (optional, common ones): `stow`, `fold`, `filter`, `scan`, `args`, `log`, `xdg`, `conditions`

**Examples**:
```
feat(fold): add XDG barrier support
fix: handle symlink-only subdirectories in completeness check
refactor(stow)!: rename internal link function
docs: update AGENTS.md with auto-unfold architecture
test(integration): add auto-unfold end-to-end tests
chore: bump version to 0.9.0
```

**Rules**:
- Subject line max 72 characters (soft warning)
- Description starts with lowercase (soft warning)
- Merge and revert commits (generated by git) are allowed as-is
- Breaking changes: append `!` before `:` and/or add `BREAKING CHANGE:` footer

### Shell Style

- **Formatter**: shfmt (configured in `.editorconfig`)
- **Indentation**: 4 spaces
- **Error mode**: `set -euo pipefail` in all entrypoints
- **Namespace**: all new functions must use `stow_sh::` prefix
- **Condition predicates**: `stow_sh::condition::<type>` prefix
- **State variables**: `_stow_sh_` prefix, accessed via getter functions
- **Output**: user-facing output to stdout, log/debug to stderr
- **Quoting**: always quote variables, especially in `$()` and parameter expansions

### Testing

- **Framework**: [bats-core](https://github.com/bats-core/bats-core)
- **Run tests**: `make test` or `bats --verbose-run test/`
- **Test location**: `test/*.bats`, fixtures in `test/fixtures/`
- **Current coverage** (267 tests, all passing):
  - `args.bats` — CLI argument parsing, short-flag expansion, path setup, getters, `-S`/`-D`/`-R` auto-discovery, `--dry-run` alias, mutual exclusion checks (45)
  - `conditions.bats` — annotation parsing, path sanitization, condition evaluation, plugins, directory propagation (39)
  - `filter.bats` — git-aware, regex, glob filtering, stowignore directory matching (25)
  - `fold.bats` — directory folding with annotation taint, XDG barriers, filesystem completeness, exclusion awareness (33)
  - `integration.bats` — end-to-end via `bin/stow.sh`: stow, unstow, restow, folding, XDG barriers, annotations, force, adopt, dry-run, ignore patterns, error cases, idempotency, self-stow, directory condition propagation, auto-unfold, `.stowignore`, report output, `-S`/`-D`/`-R` auto-discovery, ancestor fold point detection, mutual exclusion checks (64)
  - `scan.bats` — recursive scanning, dotfiles, annotated filenames, spaces (8)
  - `stow.bats` — stow/unstow operations: symlinks, annotations, conflicts, force, adopt, dry-run, auto-unfold, ancestor fold point detection (43)
  - `xdg.bats` — XDG barrier computation from environment variables (10)

### When Making Changes

1. Always run `make test` after changes and fix any regressions.
2. When adding/renaming/removing files, update the directory structure in this file.
3. When fixing known issues, remove them from the known issues list above.
4. When introducing new known issues, add them here.
5. Keep this file stateless — it should describe the **current** state of the project, not history.

### Releasing / Version Bumps

**Always use `make release`** to bump versions. Never manually edit `src/version.sh` or `.cz.toml`, and never manually create version tags.

`make release` runs the full pipeline:
1. Checks for a clean working tree
2. Installs git hooks
3. Runs the test suite
4. Calls `cz bump` which updates both `src/version.sh` and `.cz.toml`, creates the bump commit, and tags it with the `v` prefix (`v0.10.3`, etc.)
5. Updates `CHANGELOG.md` and amends the bump commit

After `make release` completes, push with: `git push && git push --tags`
