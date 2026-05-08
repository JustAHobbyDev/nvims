# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`nvims` is a single Bash script that lets a user install, run, reset, delete, or set-as-default any of a curated list of Neovim distributions side-by-side, without touching the standard `~/.config/nvim`, `~/.cache/nvim`, `~/.local/share/nvim`, or `~/.local/state/nvim` directories. Isolation is achieved entirely through Neovim's `NVIM_APPNAME` environment variable.

The repo has three real source files:
- `nvims` — the main script (installed to `/usr/local/bin/nvims`)
- `neovim_distros` — the data file listing supported distributions (installed to `~/.config/nvims/neovim_distros`)
- `install.sh` / `uninstall.sh` — bootstrappers fetched via `curl | bash` from the README

`fzf` is a runtime dependency.

## Commands

```bash
# Install from a working copy (mirrors install.sh, but skips the git clone to /tmp).
./testFirst.sh

# Full install / uninstall (the user-facing path; clones to /tmp first).
./install.sh
./uninstall.sh

# Lint the script (no test suite exists).
shellcheck nvims install.sh uninstall.sh testFirst.sh
```

There are no unit tests. Verification is manual: install, then exercise `nvims`, `nvims -d`, `nvims -r`, `nvims -s`, `nvims -h` against a throwaway distro entry.

## Architecture

### Two-file split: code vs. data
`nvims` (the script) sources `~/.config/nvims/neovim_distros` at runtime. That file declares a Bash array `neovim_distros` of pipe-delimited rows: `alias | sn | URL | branch`. Adding a distribution is a data change to `neovim_distros` only — no code changes.

The `sn` ("short name") column is a string holding the literal short alias to emit, or empty for none. When non-empty, `nvims` writes a *second* alias line (`alias {sn}="NVIM_APPNAME=nvim-{alias} nvim"`) in addition to the always-written `nvim-{alias}` form. By convention the `sn` is set to the distro's own name (e.g. `traap|...|traap`), but any name is allowed (e.g. `LazyVim|...|lv`). `validateAliasUniqueness` runs early in `main` and aborts before any file writes if two distros claim the same primary alias or `sn`. The `branch` column accepts the literal `default` (uses `--depth 1` shallow clone) or any ref/tag/commit (full clone + `git checkout`).

### Per-distro isolation via NVIM_APPNAME
For each selected distribution, `nvims` clones the repo to `~/.config/nvim-{alias}` and then runs Neovim with `NVIM_APPNAME=nvim-{alias} nvim`. Neovim itself remaps all four of its standard directories under that name, so distributions cannot collide with each other or with the user's own `~/.config/nvim`. Every distribution **must bootstrap itself on first launch** — `nvims` does not run any post-clone setup.

### Alias file as the user's shell integration
`~/.config/nvims/nvim_appnames` is the integration point with the user's shell. `nvims` appends alias lines to it on install and removes them with `sed -i` on `nvims -d`. The README instructs the user to `source` this file from their `.bashrc`/`.zshrc`. This is why `writeAliasIfNotExists` and `deleteAliasIfExists` are careful to grep for exact-match lines (`grep -Fx`) — they're editing a file the user's shell loads. After every alias write, `checkBashrcSourcing` greps `~/.bashrc` and `~/.bash_profile` for a reference to `nvim_appnames` and warns to stderr when neither sources it.

### `default` is special
The `default` row in `neovim_distros` is a sentinel, not a real distro (`URL=none`, `branch=none`). When the user picks it, `nvims` reads `~/.config/nvims/nvim_default_app` and substitutes that alias as `$choice`. `nvims -s` writes that file. If `nvim_default_app` is empty/missing, picking `default` falls through to `extractNeovimAppFields` with `default`, which then runs `NVIM_APPNAME=nvim-default nvim` — effectively a stock Neovim launch.

### Flag semantics in `main`
`main` toggles three booleans (`writeAlias`, `cloneOrPull`, `runNeovim`) based on `-d`/`-r`/`-s`/`-E`, then executes whichever steps remain true. Only one flag is processed (intentional design choice, see comment in the script). Flagless invocation runs all three steps; `-d` runs none of them (just deletes); `-r` clears cache/share/state but keeps the clone and skips the alias write; `-s` writes the default-app file and still does alias-write + clone-or-pull + launch; `-E` writes the `$EDITOR` wrapper + state file and also still does alias-write + clone-or-pull + launch.

### `$EDITOR` wrapper subsystem
`nvims -E` designates a distro as the `$EDITOR` target, independent of the interactive default set by `-s`. `setEditorTarget` writes a wrapper script `$NVIMS_BIN_DIR/nvim-{alias}` (default bin dir `~/.local/bin`) whose body is `NVIM_APPNAME=nvim-{alias} exec nvim "$@"`, then records the alias in `~/.config/nvims/editor` (`editorTargetFile`) via tmp+mv. Switching targets removes the previous wrapper first. The function also greps `$PATH` for the bin dir and inspects `$EDITOR` against `nvim-{alias}`, printing a warning or an `export EDITOR=...` instruction when the user's environment isn't aligned. `deleteNvimApp` reads `editorTargetFile` and refuses (exit 1) if asked to remove the current target, avoiding orphaned wrappers.

### `gitcheck` short-circuit
`pullRepository` is gated by `runCommandCheck` → `gitcheck`, which compares local/remote/merge-base SHAs and only allows the pull when the state is `Need-to-Pull`. This avoids spurious pulls every time the user launches an already-up-to-date distro.

## Conventions

- Bash with `# {{{ … # }}}` Vim folds throughout. Preserve the fold markers when editing `nvims`.
- The script uses globals (`selected_alias`, `selected_url`, `selected_branch`, `selected_location`, `selected_alias_line`, `selected_sn_line`) populated by `extractNeovimAppFields` and consumed by every downstream function. Don't refactor these into locals without rethreading every caller.
- `removeSpaces` is applied to every field read out of `neovim_distros` because the data file is human-aligned with spaces inside the pipe-delimited columns.

## Adding a Neovim distribution

Per the README contract: open a PR that adds a row to `neovim_distros`. The upstream repo *must* bootstrap itself (clone + `nvim` is all that runs). The maintainer tests on Arch or Ubuntu before merging.
