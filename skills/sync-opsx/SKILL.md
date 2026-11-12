---
name: sync-opsx
description: Sync the generated OpenSpec tooling (the openspec-* skills, plus the .claude opsx commands of CLI 1.x) across every openspec-enabled repo on this machine. Use after upgrading the openspec CLI, when a repo's opsx skills lag `openspec --version` (check the `generatedBy` frontmatter), or when asked to "sync opsx" / "refresh openspec tooling".
---

# sync-opsx: refresh generated OpenSpec tooling machine-wide

The openspec CLI **generates** its skills into each repo it is initialized in
(`generatedBy` frontmatter records the CLI version). From CLI 2.0 the skill bodies live in
`.agents/skills/openspec-*/` (one shared copy, plus a `.openspec-target` marker) and each
`.claude/skills/openspec-*` is a **symlink** to its body; there are no slash commands. CLI
1.x generated real `.claude/skills/openspec-*/` folders plus `.claude/commands/opsx/*`, and
`openspec update` to 2.0 deletes the commands and converts the folders to links.
Repos drift silently: `openspec update` only runs where it is invoked, so a CLI upgrade
leaves every other repo on the old generation. This skill finds them all and updates the
stale ones.

**Requires:** the `openspec` CLI, `git`, and a bash shell (Git Bash on Windows).

**Convention:** the generated set is *vendored and tracked* per repo, never hoisted to
`~/.claude/skills`, because `openspec update` regenerates repo-local copies that would
shadow the global ones. Tracked: `.agents/skills/`, `.claude/skills/` (the links commit
as symlink entries, mode 120000), `.claude/commands/` where one remains,
`.claude/settings.json`. Ignored: `.claude/settings.local.json` (machine-local permission
accretion), via a repo `.gitignore` rule. If the user does not track `.claude/` in their
repos, ask before the first commit and follow their answer.

## The state file

`~/.config/sync-opsx/state.txt`, deliberately **outside** this skill's folder so that
reinstalling the skill (replacing its folder) does not wipe it. Plain text, three sections,
one absolute path per line, `#` comments allowed; the user may edit it by hand:

```
[folders]      # where to scan; chosen by the user
[synced]       # roots found and confirmed last run (the drift baseline, never the input)
[skipped]      # roots the user declined; never asked about again
```

Store paths as `find` prints them, but **never compare paths as strings**: one folder can
print several ways (`C:/x` from git, `/c/x` from find, a mount alias such as `/tmp/...` from
`pwd`, a different letter case). Match by identity with bash's `[ "$a" -ef "$b" ]` (same
file). "Inside a folder" means some ancestor matches:
```bash
d="$top"; while :; do [ "$d" -ef "$folder" ] && break; p=$(dirname "$d"); [ "$p" = "$d" ] && break; d="$p"; done
```

## Procedure

1. **Load state.** No state file means a first run: ask which folders hold the user's
   projects (one or more). If step 2 finds the session inside an openspec repo, suggest
   that repo's parent folder. Do not suggest the whole home directory: it is slow and
   sweeps in caches and cloud-sync copies. Create the file with their answer.

2. **Check where it is run from.** Resolve the session's repo:
   `top=$(git rev-parse --show-toplevel 2>/dev/null)` (no repo: the working directory
   itself). If it holds an `openspec/` directory,
   is not the home directory, lies outside every saved folder, and is in neither `[synced]`
   nor `[skipped]`, offer three choices:
   - **add its parent folder** (recommended: covers its sibling repos too),
   - **add only this repo's folder**,
   - **leave it out** (recorded under `[skipped]`, so the offer is not repeated).

   People usually run this from the repo they just set up, so this catches the common
   case of a repo outside the scan.

3. **Version + scan.** `openspec --version`, then for each saved folder:
   ```bash
   find "$folder" -mindepth 1 \
        \( -name node_modules -o -name .git -o -name .venv -o -name venv \) -prune \
        -o -type d -name openspec -print -prune
   ```
   No `-maxdepth`: a depth bound drops deep roots silently. Speed comes from the prunes.
   A saved folder that no longer exists is reported as **missing**, and the `[synced]`
   entries under it are kept, not counted as gone (an unplugged drive is not a deletion).
   The candidate root is the parent of each `openspec/` hit.

4. **Classify each candidate.**

   | Candidate | Action |
   |---|---|
   | `openspec/` holds neither `specs/` nor `changes/` | Not a root (a folder that happens to be named openspec): list it, no action |
   | It is the home directory | **Never update**: the generated set would land in `~/.claude`, the global config, shadowing every repo's copy. Report it |
   | Listed in `[skipped]` | Skip; count it in the report |
   | No `.claude/skills/openspec-*` set | Report it; never `openspec init` it (an init chooses the user's tools) |
   | `git -C <root> rev-parse --show-prefix` prints a path | Nested folder: a commit would land in the parent repo. Ask while it is new; if confirmed (a test fixture inside its repo, say), stage its `.claude/` in that parent repo's commit |
   | Not a git repo | Report it; it can update but there is nothing to commit. Ask while it is new |

   (`--show-prefix` prints nothing at a repo's top level, which avoids comparing Windows
   and POSIX path forms. It also prints nothing outside any repo, so read the exit status
   first: non-zero is the "not a git repo" row, and only a zero status with empty output
   means a top-level root.)

5. **Compare against the last run, before anything rewrites the state file.** The state
   file is written only in step 8 (a folder added in step 2 is held until then).
   - **Gone:** check every `[synced]` entry explicitly, not by eye against the scan:
     ```bash
     [ -d "$p/openspec" ] || echo "gone: $p"
     ```
     Then take off this gone list (and keep in `[synced]`) any entry under a missing
     folder: compare it to that folder as text,
     with the stored forms (`-ef` cannot test a path that no longer exists).
     Report each one (moved, renamed, or deleted); no action. Step 8 drops it, so this
     line in the report is the only trace it leaves.
   - **New:** a root with a `.claude/skills/openspec-*` set that is not in `[synced]` or
     `[skipped]` (a root without the set is only a report line, step 4). List each by path with any flags
     from step 4, plus a flag for a path inside a cloud-sync folder (OneDrive, Dropbox,
     iCloud, Google Drive: likely a copy of a repo that lives elsewhere). Ask once which
     to sync; the declined ones go to `[skipped]`.

6. **Per repo: skip if current.** Read `generatedBy` from
   `.claude/skills/openspec-apply-change/SKILL.md` (a real file in 1.x, a link into
   `.agents/skills/` from 2.0, so the one path reads both). Equal to the CLI version means
   "current". Never pass `--force` (the CLI refuses on a current repo, correctly). Record
   the old version **before** updating, or read it afterwards from
   `git show HEAD:./.claude/skills/openspec-apply-change/SKILL.md`: once the update has
   run, the link resolves to the new body. A stamp that cannot be read where the set
   exists (the link is a text stub, see **Symlinks**) counts as stale: `openspec update`
   repairs the links without `--force`. If nothing is staged afterwards, there is no
   commit; note "links repaired" in the report.

7. **Per stale repo, update and then commit only the tooling.**
   - Run `openspec update` in the root.
   - If `.claude/settings.local.json` exists and `git check-ignore` does not ignore it, add
     the ignore rule to `.gitignore` first (in a current repo too: commit just that rule).
   - **Stage only the generated paths**: `git add -A --` on `.claude/commands/opsx`,
     `.agents/skills`, and each `.claude/skills/openspec-*` by name (plus `.gitignore` when
     edited). Not the whole of `.claude/`: hand-authored skills there may be dirty. Never
     sweep unrelated dirty files into the commit. Before committing, check that nothing
     outside those paths is staged. A nested folder (step 4) is committed in its parent
     repo, its paths carrying its prefix: in the parent's own tooling commit when the
     parent is refreshed in the same run, otherwise in a commit of its own.
   - Commit message: `chore(tooling): opsx skill refresh at CLI <ver>`, with a body
     noting old -> new version, verbs added or removed (compare the `openspec-*` names
     under `.claude/skills`, and `.claude/commands/opsx` while it exists, before and
     after), and what changed beyond the version stamp (diff each old body from `HEAD`
     against the new one, ignoring the `generatedBy` line).
   - **When a verb was removed or renamed, find what still names it.** Search the repo's
     tracked files, outside the generated paths, for each old name (a removed
     `/opsx:<verb>` command, a renamed skill, the path `.claude/commands/opsx`):
     ```bash
     git grep -lE '/opsx:|commands/opsx' -- . ':!.agents' ':!.claude/skills/openspec-*'
     ```
     and `.claude/settings.local.json`, which is untracked, for permission entries that
     name it (`Skill(opsx:<verb>)`). Report the hits and change nothing. A living document
     (a router, a reference doc, a spec) needs its owner's wording and sometimes the repo's
     own change process; a dated record (a journal, an archived change) keeps the names it
     was written with; a dead permission entry is harmless.

8. **Save state.** `[folders]` gains any folder added in step 2; `[synced]` becomes the
   roots synced or current this run, plus any under a missing folder; `[skipped]` gains
   the declined ones. Edit the sections in place and keep the user's comments.

9. **Report.** First line: the folders scanned (and any missing), so a gap in scope is
   visible. Then one table: repo, old -> new version (or "current"), skills count, commit
   hash ("-" when none), notes. Then the new, gone, skipped, not-a-root, and
   no-Claude-tooling lines. The last two are recomputed each run and never stored: they
   cost one line and would hide a change if silenced. Last, when a verb was removed or
   renamed: the files that still name it (step 7), per repo, living documents apart from
   dated records.

## Handling rules

- **`.claude/` wholly ignored:** a blanket rule usually predates the convention: narrow it
  to `.claude/settings.local.json` and track the tooling, quoting the old rule in the commit
  body. If the ignore comment suggests a deliberate policy, ask instead of changing it.
- **First-time tracking:** add the `settings.local.json` ignore rule *before* staging
  anything under `.claude/`, or the permission file lands in history.
- **Symlinks:** the CLI creates the `.claude/skills/openspec-*` links itself (on Windows
  that needs Developer Mode or the symlink privilege). Git records them as mode 120000
  whatever `core.symlinks` says, and a clone made where symlinks work checks them out as
  real links. In a repo whose effective `core.symlinks` is `false` (often a local setting
  left by an old `git init`; check with `git config --show-origin core.symlinks`), any
  git operation that rewrites those paths (a branch switch, a restore, a stash) writes
  each as a small text file holding the target path, and the agent then finds no skill
  there. `openspec update` repairs such stubs, in a current repo too. Report every synced
  repo with symlinks off; changing the setting is the user's call. Do not replace the
  links with copies: the next `openspec update` converts them back.
- **Repo-specific skills are sacred:** only `.claude/commands/opsx/*`,
  `.claude/skills/openspec-*` and `.agents/skills/openspec-*` (with its `.openspec-target`)
  are generated. Anything else under `.claude/` is hand-authored. Never delete, regenerate, or
  "sync" it.
- **CRLF warnings:** repos with `core.autocrlf` normalize on add, so the warnings are
  cosmetic. Do not "fix" line endings.
- **Dirty tree:** unrelated modifications do not block the sync, since the tooling commit
  is surgical. Mention what you saw.

## Verify

Every synced repo reports the same `generatedBy`; `diff -rq --strip-trailing-cr` between
any two repos' `.agents/skills` is empty (ignoring repo-specific extras); every
`.claude/skills/openspec-*/SKILL.md` is readable through its link; every touched tree is
clean afterwards.
