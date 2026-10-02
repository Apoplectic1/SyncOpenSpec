# SyncOpenSpec

A Claude Code skill that keeps the [OpenSpec](https://github.com/Fission-AI/OpenSpec) tooling current in every repo on your machine.

`openspec init` and `openspec update` generate Claude Code commands (`.claude/commands/opsx/`) and skills (`.claude/skills/openspec-*/`) into each repo. `openspec update` only touches the repo it runs in, so after you upgrade the CLI, every other repo silently stays on the old generation. `/sync-opsx` finds them all and brings the stale ones up to date.

## What it does

- **Finds your OpenSpec repos** by scanning the folders you name (asked once, remembered). No depth limit, so deeply nested repos are found too.
- **Updates only what is stale**: compares each repo's `generatedBy` stamp with `openspec --version` and runs `openspec update` where they differ.
- **Commits only the tooling**: stages `.claude/` and nothing else, so unrelated work in progress is never swept into the commit.
- **Reports drift by name**: repos that are new since the last run, repos that are gone, and folders that are missing (an unplugged drive is not treated as deleted repos).
- **Notices repos outside your folders**: run it from inside a repo it does not know about and it offers to add that folder.
- **Asks, then remembers**: a repo you decline to sync (a copy in a cloud-sync folder, a test fixture) is never asked about again.

## Install

```bash
git clone https://github.com/Apoplectic1/SyncOpenSpec.git
cd SyncOpenSpec
bash deploy.sh        # copies skills/sync-opsx/ to ~/.claude/skills/
```

Or copy `skills/sync-opsx/` into `~/.claude/skills/` by hand. Start a new Claude Code session, then run `/sync-opsx`.

**Requirements:** Claude Code, the `openspec` CLI, `git`, and a bash shell (Git Bash on Windows).

## Usage notes

- **It commits the generated tooling into each repo.** The skill treats `.claude/commands/` and `.claude/skills/` as tracked files and keeps `.claude/settings.local.json` out with a `.gitignore` rule. If you do not version `.claude/` in your repos, it asks before the first commit.
- **Its memory lives in `~/.config/sync-opsx/state.txt`**: the folders to scan, the repos it synced, and the ones you skipped. It is plain text and safe to edit by hand; your comments are kept.
- **It never runs `openspec update` in your home directory**, which would write the generated files into `~/.claude` and override every repo's own copy.
- **It never initializes a repo.** An OpenSpec repo without Claude Code tooling is reported, not changed, since `openspec init` chooses which AI tools to set up.

## License

MIT
