# Campaign board

One live page that shows every campaign's phases, what happens next, and what is waiting on the maintainer.
It reads a small status header at the top of each `PROGRESS.md`; it never parses the prose below it.

```bash
python Tools/CampaignBoard/campaign_board.py serve
```

Then open <http://127.0.0.1:8766/>. The page follows the files: save a `PROGRESS.md` and the board changes within a
few seconds. `scan` prints the same summary in a terminal and writes `Saved/CampaignBoard/campaigns.json`, which is
the interface for any other app (the page reads nothing else).

## The header

The first thing in a `PROGRESS.md` (or `PROGRESS_<lane>.md`) is a JSON object between two `---` lines:

```
---
{
  "campaign": "Mars multiplayer",
  "status": "active",
  "updated": "2026-11-10",
  "phases": [
    {"id": "P0", "title": "Net wiring and the spawn owner", "state": "done", "commit": "4df957ff"},
    {"id": "P1", "title": "Mechanism graph on the host", "state": "next"},
    {"id": "P2", "title": "Hazards", "state": "pending"}
  ],
  "next": "P1 executor on PHASE_1.md",
  "blocked_on": null,
  "owed_by_maintainer": [
    "Push CkFoundation e9d7c82ca and bump the gitlink"
  ]
}
---
```

It is JSON, not YAML, so free text with colons, backticks and quotes cannot break it and every language reads it
with its standard library.

| Key | Required | Meaning |
|---|---|---|
| `campaign` | yes | Display name, a few words. |
| `status` | yes | `active`, `awaiting-review`, `parked`, `done` or `superseded` (below). |
| `updated` | yes | `YYYY-MM-DD`, the day the header was last made true. |
| `phases` | yes | Ordered list, `[]` when the campaign has no phases. Each: `id`, `state`, optional `title` (a few words) and `commit` (the hashes that landed it, in the project or a submodule). |
| `next` | when `active` or `awaiting-review` | The single next action, one line. |
| `blocked_on` | no | What stops the next action, or `null`. |
| `owed_by_maintainer` | no | Things only the maintainer can do: a PIE check, a ruling, a push, an editor restart. One line each. |
| `commits` | no | Campaign commits that belong to no single phase (hashes or `a..b` ranges). |
| `superseded_by` | when `superseded` | Where the record lives now. |

Unknown keys are refused, so a typo cannot hide a field.

**Status.** `active`: work is in flight or the next phase is ready to start. `awaiting-review`: every planned phase
ran and the maintainer owes a review, a PIE check, a commit or a push. `parked`: deliberately paused; it moves only
on a new decision. `done`: finished, nothing owed (a done campaign with `owed_by_maintainer` items is refused).
`superseded`: replaced or moved.

**Phase state.** `done`, `active` (being executed now), `next` (ready, not started), `pending`, `blocked`, `skipped`.

## Keeping it true

Rewrite the header whenever the "current state" of the file changes: at every phase boundary and at session end.
Change `updated` to today in the same edit. Then check it:

```bash
python Tools/CampaignBoard/campaign_board.py validate docs/plans/<campaign>/PROGRESS.md
```

Do not write "push" into `owed_by_maintainer` just because commits are local: name the hashes in `commit` /
`commits` and the board works out by itself which are unpushed (it checks the project and every submodule). The
board also flags a campaign as stale when it is `active` and `updated` is more than 7 days old, and as "edited since
header" when the file was modified on a later day than `updated`.

## Commands

| Command | Does |
|---|---|
| `serve [--port N]` | The live page on `127.0.0.1` (default port 8766). |
| `scan [--all]` | Writes `campaigns.json`, prints the open campaigns (`--all`: every one). |
| `validate [files]` | Checks the given files, or every `PROGRESS*.md` under the configured roots. Exits 1 on a bad header. |
| `set-header <PROGRESS.md> <header.json> [--keep-mtime]` | Inserts or replaces the header from a JSON file, refusing an invalid one. `--keep-mtime` leaves the file's modified time alone and fills a missing `updated` from it (for backfilling old campaigns). |
| `strip <files>` or `strip --all` | Removes the header again, keeping the modified time. |

`board.config.json` holds the scanned roots (`docs`, `Tools`), the excluded paths, the stale threshold and the port.
