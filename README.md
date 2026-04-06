# stow.sh

A pure-Bash reimplementation of [GNU Stow](https://www.gnu.org/software/stow/) -- a symlink farm manager for dotfiles.

Built for managing `~/.dotfiles` repos with features GNU Stow does not have: conditional dotfiles, git-aware filtering, XDG-aware directory folding, and auto-unfold for real-world conflicts.

## Features

- **Conditional dotfiles** via `##` annotations (e.g. `file##os.linux,shell.bash`)
- **Git-aware filtering** using `.gitignore` rules (including negation patterns)
- **`.stowignore` file**: per-package glob patterns to permanently exclude files and directories
- **Quad-layer filtering**: stowignore, git-aware, regex (`-i`), glob (`-I`)
- **User-facing reports**: clean stdout output showing what was stowed/unstowed
- **Directory folding**: symlink whole directories when possible, minimizing link count
- **XDG-aware folding**: fold barriers derived from `XDG_*` environment variables
- **Auto-unfold**: when a fold point conflicts with an existing real directory, falls back to individual symlinks inside it
- **Pluggable conditions**: ship your own predicates as shell functions
- **Zero dependencies**: pure Bash 4+, no Python, no Ruby, no Node.js

## Installation

### From source (recommended)

```bash
git clone https://github.com/davidKristiansen/stow.sh.git
cd stow.sh
make install
```

This symlinks `stow.sh` into `$XDG_BIN_HOME` (or `~/.local/bin`) and copies built-in condition plugins to `$XDG_DATA_HOME/stow.sh/conditions.d/`.

### As a git submodule

Useful when you want stow.sh tracked inside your dotfiles repo:

```bash
cd ~/.dotfiles
git submodule add https://github.com/davidKristiansen/stow.sh.git .local/lib/stow.sh
make -C .local/lib/stow.sh install
```

### Uninstall

```bash
make uninstall
```

## Quick Start

```bash
# Stow all packages (subdirectories) from current dir into parent dir
cd ~/.dotfiles
stow.sh

# Stow a specific package
stow.sh -S vim

# Unstow a package
stow.sh -D vim

# Restow (unstow + stow) to refresh symlinks
stow.sh -R vim

# Dry-run to preview what would happen
stow.sh -n

# Force overwrite existing files/symlinks
stow.sh -f
```

### Self-stow mode

When the source directory has no subdirectories (or none are specified), stow.sh treats the source directory itself as the package. This is the typical setup for a flat dotfiles repo:

```bash
cd ~/.dotfiles
stow.sh -t ~
```

This symlinks everything in `~/.dotfiles/` directly into `~/`.

## Usage

```
stow.sh [OPTIONS] [<directory>]

Options:
  -d DIR, --dir=DIR             Source directory (default: current directory)
  -t DIR, --target=DIR          Target directory (default: parent of source)
  -S PATH, --stow PATH          Stow the specified path(s) (default: . if no args)
  -D PATH, --delete PATH        Unstow the specified path(s) (default: . if no args)
  -R PATH, --restow PATH        Restow the specified path(s) (default: . if no args)
  -i REGEX, --ignore=REGEX      Ignore paths matching regex (repeatable)
  -I GLOB, --ignore-glob=GLOB   Ignore paths matching glob (repeatable)
  --defer=PATH                  Defer link creation for specified path (repeatable)
  --override=PATH               Override for specified path (repeatable)
  --adopt                       Adopt pre-existing files into stow structure
  --no-folding                  Disable directory folding
  --no-xdg                      Disable XDG-aware fold barriers
  -g, --git                     Enable git-aware filtering
  -G, --no-git                  Disable git-aware filtering
  -f, --force                   Overwrite existing symlinks/files
  -n, --no, --dry-run          Dry-run mode (no filesystem changes)
  -v, --verbose                 Increase verbosity (repeatable: -vvv)
      --verbose=N               Set verbosity level directly
      --color=WHEN              Colorize output: never, always, auto
  -h, --help                    Show help and exit
      --version                 Show version and exit
```

### Git-aware filtering

When run inside a git repository (auto-detected), stow.sh respects `.gitignore` rules. Files ignored by git are excluded from stowing. This includes negation patterns (`!important.txt`).

Disable with `-G` or `--no-git`. Force enable with `-g`.

### Filtering priority

Filters are applied in order:

1. **Stowignore** -- excludes files matching `.stowignore` patterns (always active)
2. **Git-aware** -- excludes files matching `.gitignore` (if enabled)
3. **Regex** (`-i`) -- excludes files matching any regex pattern
4. **Glob** (`-I`) -- excludes files matching any glob pattern

### .stowignore

A `.stowignore` file in a package directory lists glob patterns (one per line) to permanently exclude files and directories from stowing. The `.stowignore` file itself is always excluded.

```
# .stowignore — project management files, not dotfiles
AGENTS.md
.github
.gitignore
.gitmodules
*.baseline
bootstrap
```

Patterns match against the full relative path, the basename, and every ancestor directory segment. A pattern like `.github` excludes `.github/CODEOWNERS`, `.github/workflows/ci.yml`, etc.

Lines starting with `#` are comments. Blank lines are ignored.

## Conditional Dotfiles

Annotate files and directories with `##` followed by conditions. Conditions are evaluated at stow time; the annotation is stripped from the symlink name.

### Syntax

```
filename##condition
filename##cond1,cond2        # AND: all must pass
filename##!condition          # NOT: negation
dir##condition/file           # directory condition propagates to all children
```

### Built-in conditions

| Condition | Description | Example |
|-----------|-------------|---------|
| `os.<name>` | Matches OS name from `/etc/os-release` (case-insensitive) | `file##os.arch` |
| `shell.<name>` | Matches `$SHELL` basename | `file##shell.zsh` |
| `exe.<name>` | True if executable is in `$PATH` | `file##exe.nvim` |
| `wm.<name>` | Alias for `exe` (window manager check) | `file##wm.sway` |
| `docker` | True if running inside Docker (`/.dockerenv`) | `file##!docker` |
| `wsl` | True if running inside WSL (`/proc/version`) | `file##wsl` |
| `no` | Always false -- file is never deployed | `cache##no` |
| `extension` | Always true -- preserves file extension in source name | `script.conf##extension.sh` |

### Examples

```
.bashrc##shell.bash            # Only deploy if shell is bash
.zshrc##shell.zsh              # Only deploy if shell is zsh
.config/sway##wm.sway/        # Entire directory only if sway is installed
gpg-agent.conf##!wsl           # Deploy everywhere except WSL
20-desktop.toml##!docker       # Skip in Docker containers
.local/lib/stow.sh##no/       # Never deploy (e.g. git submodule)
```

### Directory propagation

When a directory segment has a condition, it propagates to all files inside:

```
.config/zsh##shell.zsh/
  .zshrc
  .zprofile
```

If shell is not zsh, both `.zshrc` and `.zprofile` are skipped. If shell is zsh, the whole directory is symlinked: `~/.config/zsh -> dotfiles/.config/zsh##shell.zsh`.

### Custom conditions

Create shell scripts in `$XDG_CONFIG_HOME/stow.sh/conditions/`:

```bash
# ~/.config/stow.sh/conditions/work.sh
stow_sh::condition::work() {
    [[ "$(hostname)" == *corp* ]]
}
```

Now you can use `file##work` or `file##!work` in your dotfiles.

## Directory Folding

stow.sh minimizes the number of symlinks by "folding" -- when an entire directory can be represented by a single symlink, it creates one directory symlink instead of individual file symlinks.

```
# Without folding (--no-folding):
~/.config/nvim/init.lua -> dotfiles/.config/nvim/init.lua
~/.config/nvim/lua/plugins.lua -> dotfiles/.config/nvim/lua/plugins.lua

# With folding (default):
~/.config/nvim -> dotfiles/.config/nvim
```

A directory can be folded only if:
1. All files on disk inside it are accounted for in the candidate list
2. No descendant has a `##` annotation in its own name
3. It is not a fold barrier

### XDG-aware fold barriers

XDG directories act as fold barriers -- they cannot become symlinks because other applications expect them to be real directories.

Barriers are computed from set `XDG_*` environment variables:
- `XDG_CONFIG_HOME` (typically `~/.config`)
- `XDG_DATA_HOME` (typically `~/.local/share`)
- `XDG_STATE_HOME` (typically `~/.local/state`)
- `XDG_CACHE_HOME` (typically `~/.cache`)
- `XDG_BIN_HOME` (typically `~/.local/bin`)
- `XDG_RUNTIME_DIR`

The barrier directory itself must be real, but children can still fold:

```
~/.config/                 # real directory (barrier)
~/.config/nvim -> dotfiles # single symlink (child of barrier, folded)
~/.config/mise/config.toml # individual symlink (sibling has annotation)
```

Disable with `--no-xdg`.

### Auto-unfold

When a fold point conflicts with an existing real directory at the target (e.g. `~/.gnupg` already has private keys), stow.sh automatically falls back to individual symlinks inside that directory.

Child directories that don't exist at the target become directory symlinks (folded). Those that already exist as real directories trigger recursive auto-unfold.

```
~/.gnupg/                     # real directory (has private keys, keyrings)
  gpg-agent.conf -> dotfiles  # individual symlink (auto-unfolded)
  pubring.kbx                 # untouched (not in dotfiles)
  private-keys-v1.d/          # untouched (not in dotfiles)
```

## Development

### Prerequisites

- Bash 4+
- [bats-core](https://github.com/bats-core/bats-core) (for tests)
- shfmt (for formatting, configured in `.editorconfig`)

### Running tests

```bash
make test
# or
bats --verbose-run test/
```

### Commit convention

This project enforces [Conventional Commits](https://www.conventionalcommits.org/). Install the git hook:

```bash
make hooks
```

Format: `<type>[(<scope>)][!]: <description>`

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

### Project structure

```
bin/stow.sh        CLI entrypoint
src/main.sh        Orchestrator pipeline
src/args.sh        CLI argument parsing
src/log.sh         Logging framework
src/filter.sh      Path filtering (git/regex/glob)
src/scan.sh        Package directory scanner
src/fold.sh        Directory folding + target resolution
src/stow.sh        Stow/unstow operations
src/xdg.sh         XDG fold barrier computation
src/conditions.sh  Annotation parsing + condition evaluation
conditions.d/      Built-in condition plugins
hooks/             Git hooks (conventional commits)
test/              bats test suite (255 tests)
```

## License

MIT

## Acknowledgements

- [GNU Stow](https://www.gnu.org/software/stow/) -- the original symlink farm manager that inspired this project's core design and CLI interface.
- [yadm](https://yadm.io/) -- its conditional file handling (`##` annotations) was the direct inspiration for stow.sh's conditional dotfiles system.
