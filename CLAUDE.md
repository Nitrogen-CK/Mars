# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mars (formerly CkPlugins / Orion; GitHub: `Nitrogen-CK/Mars`) is an Unreal Engine 5.5 project that serves as the **development host for the Chainkemists plugin ecosystem**. The host project itself is intentionally minimal — a default `GameModeBase` and a near-empty `Source/Mars/` module. The real content is the plugin submodules under `Plugins/`, which are developed, tested, and iterated on inside this clean project before being consumed by downstream game projects.

Use this project when you need to work on a Chainkemists plugin in isolation: you get a full UE project to compile against, the AngelScript runtime via CkFoundation, and the CkTests harness — without the weight of a full game project on top.

## Framework Development Guides

Before writing code against CkFoundation, read the appropriate guide in the submodule:

- **AngelScript (.as):** [Plugins/CkFoundation/Script/ARCHITECTURE.md](Plugins/CkFoundation/Script/ARCHITECTURE.md) — language differences from C++, `utils_*` shortcuts, entity script lifecycle, asset definitions, dynamic handle registration gotcha, actors and components (§8), common mistakes (§21).
- **C++ framework patterns:** [Plugins/CkFoundation/Source/CLAUDE.md](Plugins/CkFoundation/Source/CLAUDE.md) — full development guidelines: function formatting, ECS patterns, `CK_PROPERTY`, request structs, component lifetimes, module tier table.
- **C++ quick reference:** [Plugins/CkFoundation/CLAUDE.md](Plugins/CkFoundation/CLAUDE.md) — condensed architecture overview (macros, fragments, processors, naming).

## Per-plugin versioning

When changes touch `Plugins/GitLink/Source/`, follow the bump rule in [Plugins/GitLink/CLAUDE.md](Plugins/GitLink/CLAUDE.md)'s **Versioning** section at end of session:

1. Bump `GITLINK_VERSION` in `Plugins/GitLink/Source/GitLink/Public/GitLink/GitLink_Version.h`.
2. Bump `VersionName` (and `Version`) in `Plugins/GitLink/GitLink.uplugin` to match.
3. Add a row at the top of the **Version log** table in `Plugins/GitLink/CLAUDE.md`.
4. Rebuild so the binary's build timestamp refreshes.

Other plugins under `Plugins/` may adopt the same pattern over time; check their `CLAUDE.md` for an analogous section before assuming there isn't one.

## Repository Structure

- `/Source/Mars/` — Minimal host module (`GameModeBase` only). You will rarely edit this.
- `/Plugins/` — The Chainkemists plugin submodules and a few third-party dev tools. See **Plugin Ecosystem** below.
- `/CkAuto/` — Shared developer scripts (build, run, submodule management) — itself a submodule.
- `/Config/` — UE project config (`DefaultEngine.ini`, `DefaultGame.ini`, etc.). Mostly stock.
- `/Content/` — Minimal — host project has almost no Blueprint or asset content. Real assets live inside each plugin's `Plugins/<Name>/Content/`.
- `/Script/` — The Mars gameplay AngelScript (features under `ECS/`, player, HFSM, UI, world objects, editor map builders, tests); conventions below. Framework AngelScript lives in `Plugins/CkFoundation/Script/` and other plugins' `Script/` folders. Note: the Grep tool skips `Script/*.as` because of the superproject `.ignore`; use `rg --no-ignore` or Read.
- `/.runreal/` — Build pipeline configuration using the runreal build system.

## Build System and Development Commands

The project uses the **runreal** build system. The engine source comes from `https://github.com/Chainkemists/UnrealEngine-Internal` (configured in `runreal.config.json`).

**Build + run automation/Gauntlet tests via the Unreal Toolbox** — use the
`/build-test` skill (canonical doc: [CkAuto/.claude/skills/build-test/SKILL.md](CkAuto/.claude/skills/build-test/SKILL.md);
the project-root `.claude/skills/build-test/` is a thin wrapper over it, needed
because skills inside submodules aren't auto-discovered). Never invoke
`Build.bat`, UnrealBuildTool, or `UnrealEditor-Cmd.exe -ExecCmds="Automation ..."`
directly for build/test automation — the toolbox owns engine resolution, the
machine-wide build lock, watchdogs, and structured results.

### The automation gate (`AutomationGate.json`)

A plain `./CkAuto/UnrealToolbox.exe --test --no-live --discover-fresh` is the full gate. Its population is declared by
[`AutomationGate.json`](AutomationGate.json) at the project root (toolbox v1.49+): the `roots` listed there (`Ck`,
`CkAngelscriptGenerator`, `CkGrid`, `CkSubsystemBrowser`, `CkGoapDebugger` - naming roots, not plugin names), plus functional
tests and tests named after an enabled plugin/module. Read the `[population]` block every run; `--test --print-population`
prints it without running anything.

**Size and time (measured twice 2026-10-03, 8 cores, 3 lanes): 4243 tests in about 44 min (43m 45s, 43m 10s).** About 3700 tests run in the three
lanes (~35 min); the 326 `.Net.`/snapshot tests run in 28 serial groups, one editor at a time, alongside the lanes (~38 min);
the 201 renderer-only tests run last in one real-renderer editor (~6 min). The serial groups finish last and are not a hang.
If the gate grows past an agent's 2 h background-command limit, launch it as a detached process and wait on its exit.
A `--build --test` adds 5-30 min of editor build on top, so batch the edits, iterate with `--test-pattern <Feature>`, and
run the full gate once at the end. Say which pattern produced a result; a focused green is not the full gate.

**The baseline is `knownReds` in `AutomationGate.json`** (toolbox v1.50+). This project carries pre-existing failures, and
that list names them, each with a reason and the gate that proved it. With the list current, a full gate exits 0 only when
every failure is listed, and it names any **new** failure for you - no pre-change baseline run needed. Read the
`=== Known reds ===` block. Rules for the list (full detail in the `/build-test` skill):

- **Never add an entry to make your own change's red go away.** An entry is for a failure that is red *before* your change,
  proven by a full gate; it goes in its own commit with `reason` and `evidence`.
- **`red` = red in two full gates on one build AND red again when run on its own; `flaky` = red in at least one full gate
  but green on its own.** A test that passes alone sometimes and fails alone other times is listed `red`. A listed `flaky`
  that fails is re-run alone once; it counts only if it fails again. A passing `flaky` is reported (`Listed flaky, passed`,
  toolbox v1.52+) but never prunes itself, so remove a `flaky` entry by hand once its cause is fixed.
- **A listed `red` test that passes is reported `Now passing`** - prune it (`--known-reds prune` on a fresh-boot
  `--test --no-live`) and commit the file. A renamed or deleted listed test exits 80.
- **A Ck plugin's reds live in that plugin's own list** (toolbox v1.52+): `Plugins/CkTests`, `Plugins/CkGameplayDebugger` and
  `Plugins/CkFoundation` each carry an `AutomationGate.json` seeded in the Ck home project (CkPlugins), changed there by PR -
  never from here, and `--known-reds prune` never edits them. The root file keeps Mars's own tests, the Monolith plugin's
  tests, and Ck tests that are red *only here* (`reason` starts `HOST-COUPLED` and names the coupling). A test listed in both
  exits 80, so a pin bump that moves an entry into a plugin list drops it from the root file in the same change.
- **The entries are bugs to fix, not a baseline to keep.** Most of the root list is one cause: in Mars the multi-client PIE
  tests trip the engine fork's Iris ensure `Disallowed to write first packet in batch` (`DataStreamChannel.cpp`), which
  never fires in CkPlugins or BusterBlock. `Ck.Snapshot.Meta.FragmentPostureCoverage` needs Mars's `_FragmentNamePrefixes`
  set in `[/Script/CkSnapshot.Ck_Snapshot_PostureRatchet_Settings]`.

Without a current list (an older toolbox, or `--known-reds off`), capture the baseline before the first change: record the
starting pass/fail counts and the *names* of the tests already red, and diff names, not counts.

**Renderer-only tests (toolbox v1.51+).** A test flagged `EAutomationTestFlags::NonNullRHI` needs a real renderer; a
`-nullrhi` editor does not even list it. The gate runs those in one off-screen real-renderer editor after the headless lanes
(`renderer-only: N` in the `[population]` block). Flag a test that genuinely renders (layout capture, render targets, real
Slate windows, shader compiles) - never guard it with `if (!FApp::CanEverRender()) { return true; }`, which passes every
headless gate while testing nothing. Exit `81` means those tests did not run (no GPU, or the list could not be discovered);
on a machine that cannot render, pass `--skip-renderer-tests` and say so.

**A full gate dirties the tree.** It rewrites `Config/DefaultGameplayTags.ini` (fixture tags) and can leave generated
assets under `Content/`. Never stage those; commit with explicit pathspecs.

### Setup and building

```bash
# Install and setup Unreal Engine
runreal engine install
runreal engine update --setup

# Build the editor (runs the "Build Editor" workflow from runreal.config.json)
runreal build editor
```

Configurations available: Development, Test, Shipping, Debug.

#### Building the editor directly (Build.bat)

For editor-only iteration without going through runreal, invoke the engine's `Build.bat` directly. The engine path is resolved dynamically from this project's `.uproject` `EngineAssociation` GUID via a tiny helper — do not hardcode it:

```powershell
$engine = & "$env:CLAUDE_PROJECT_DIR\CkAuto\Get-ProjectEnginePath.ps1"
& "$engine\Engine\Build\BatchFiles\Build.bat" MarsEditor Win64 Development `
    -Project="$env:CLAUDE_PROJECT_DIR\Mars.uproject" -WaitMutex -FromMsBuild
```

The same `PreToolUse` hook that guards git ops (see *Hooks / safety guards*) also blocks `Build.bat` invocations whenever UnrealEditor is running for this project — building while the editor has DLLs loaded corrupts hot-reload state. Close the editor first, or set `SKIP_UNREAL_GUARD=1` if you know what you're doing.

### Running

```bash
# Run with basic logging
CkAuto/CkRun_LogOnly.bat

# Run with full tracing (network, CPU, frames)
CkAuto/CkRun_TraceAll.bat
```

## Submodule Management

This project uses Git submodules heavily — every plugin under `Plugins/` is a submodule, as is `CkAuto/`. The shared scripts in `CkAuto/` provide bulk operations:

```bash
# Initialize all submodules (after a fresh clone)
git submodule update --init --recursive

# Update all submodules to latest dev branch
CkAuto/UpdateAllSubmodules_PULL_DEV_ToLatest.bat

# Update all submodules to latest main branch
CkAuto/UpdateAllSubmodules_PULL_MAIN_ToLatest.bat

# Push changes to dev branch
CkAuto/UpdateAllSubmodules_PUSH_DEV.bat

# Run a custom command across every submodule
CkAuto/SubmodulesCustomCommand.bat "git status"
```

## Plugin Ecosystem

### Chainkemists plugins (the reason this project exists)

- **CkFoundation** — ECS framework using EnTT 3.15.0; the foundation everything else builds on.
- **CkGameplayDebugger** — Debug tools integration with UE's gameplay debugger.
- **CkTests** — Test harness (AutoTests + Gym framework). See its own CLAUDE.md and the `Script/Common/` specifications for authoring tests and gyms against CkFoundation features.
- **GitLink** — Source-control / git integration plugin.

### Third-party dev tools

- **AutoSizeComments** — Comment node enhancements in the Blueprint editor.
- **GitSourceControl** (chainkemists fork of UEGitPlugin) — Git source control provider for the editor.

## CkFoundation Architecture Notes

When working in the plugin ecosystem (most edits in this project), the patterns to know:

- **ECS-first.** CkFoundation provides an EnTT-backed entity-component-system; gameplay logic is data-oriented, with processors operating over fragment groups rather than UObject methods. Read the framework guides linked above before adding new features.
- **EntityBridge** components connect Unreal `AActor`s to ECS entities when interop is needed.
- **AngelScript** is the primary scripting language for plugin content (`.as` files). Entity Scripts and Entity Construction Scripts express data-driven entity behaviour.
- **Asset definitions** (data-driven config) are preferred over Blueprint subclassing for new gameplay systems.

## Working in CkFoundation submodules

Most work in this project is *inside* a plugin submodule (e.g. editing `Plugins/CkFoundation/Source/...`). When you do this:

1. The change lives in the submodule's git history, not Mars's.
2. Commit and push from inside the submodule (`cd Plugins/CkFoundation && git commit && git push`).
3. Then bump Mars's pointer to the new submodule SHA: `cd <project root> && git add Plugins/CkFoundation && git commit -m "chore(submodule): bump CkFoundation"`.
4. The same submodule may also need pointer-bumping in any downstream consumer that uses it.

The `CkAuto/UpdateAllSubmodules_PUSH_DEV.bat` helper can automate steps 2–3 across all submodules in one pass.

## Hooks / safety guards

`.claude/settings.json` registers a `PreToolUse` hook (`CkAuto/Check-UnrealNotRunning.ps1`) that intercepts file-mutating git commands (`checkout`, `switch`, `rebase`, `merge`, `reset`, `pull`, `clean`, `restore`, `cherry-pick`, `revert`, `stash pop/apply`) and engine `Build.bat` invocations. Behaviour:

- **Editor closed for this project** → silent pass.
- **Editor open, op only touches source/config** → soft-warn prompt (`permissionDecision: "ask"`); user confirms or declines.
- **Editor open, op touches engine-locked paths** (`.uasset`/`.umap`/`Content/`/`Binaries/`/`Saved/`/`Intermediate/`/`DerivedDataCache/`/`Plugins/*/{Content,Binaries,Intermediate}/`) → hard block (`permissionDecision: "deny"`), enforced even in `--dangerously-skip-permissions` mode.
- **Editor open, command invokes `Build.bat`** → hard block (`permissionDecision: "deny"`). Building the editor while it's running corrupts hot-reload state.

Detection is per-project: probes `Saved/Logs/*.log` for an exclusive write lock (UE holds the active log exclusively while running). Other UE instances open for unrelated projects do not trip the guard, and renamed editor binaries don't matter (no process-name scan).

Submodule-aware: commands like `cd Plugins/CkFoundation && git checkout <ref>` are recognised — the script resolves the effective repo root via `git rev-parse --show-toplevel`, enumerates against that repo, and prefixes the resulting paths with the submodule's offset under the project root before classification.

**Limitation — submodule-rooted sessions:** the hook is wired through `Mars/.claude/settings.json`, which Claude Code only loads when the session's project root *is* Mars. If you launch Claude Code from inside a submodule, our hook is not active. Workarounds: (a) launch Claude Code from the Mars root for any session that may do git ops, or (b) add a personal `~/.claude/settings.json` invoking a copy of the script kept somewhere stable outside the repo — note this only protects you, not teammates.

Override for the deny tier: `SKIP_UNREAL_GUARD=1`. Use only when you know the affected assets aren't loaded in the editor — the natural recovery is to close the editor and retry.

## Naming Conventions

### Code
- `Ck` prefix for plugin classes (e.g. `UCk_Handle_X`, `FCk_Fragment_X`, `ACk_GameMode`).
- Consistent naming patterns are enforced across all `Ck*` plugins — check the framework guides in `Plugins/CkFoundation/`.

### Assets
- Plugin assets live under `Plugins/<Plugin>/Content/` with the plugin's prefix in the asset name.
- Type suffixes: `_BP` (Blueprint), `_DA` (DataAsset), `_ST` (Struct), `_WBP` (Widget Blueprint).

## Mars gameplay script conventions (`Script/`, code name Mars)

These are maintainer rulings; they override defaults from the framework skills where the two differ.

- **Naming.** Game code uses the code name: `Mars_` AngelScript prefix, `FMars_`/`UMars_`/`AMars_` types,
  `_Mars_` asset suffix. Never the concept title in code or asset names.
- **Features.** Every gameplay system is a feature set under `Script/ECS/<Feature>/` with a typed handle
  (`asset Mars_<Feature>Handle of UCkDynamic_HandleDefinition`, `FMars_Feature_<Feature>` marker) and a
  `utils_<feature>` namespace. Spec passed to `Add` is `FMars_<Feature>_Spec`; retained spec fields live in
  `FMars_Fragment_<Feature>_Params`; primary state is the bare noun `FMars_Fragment_<Feature>` (no `_Current`).
  Visuals live in entity scripts, never in features. New typed handles are hand-added to
  `Script/Generated/DynamicHandleTypes.json` (headless boots cannot self-heal it).
- **Request doctrine.** Only a feature's processors (and its `Add`) write its fragments. No `Set_X` mixins that
  write state, no fragment writes from HFSM tasks, entity scripts, widgets or actors. Every mutation is a
  `FMars_Request_<Feature>_<Verb>` struct (UPROPERTY fields, ctors, a placeholder field when payload-less) in a
  `TArray<...>` per kind on `FMars_Fragment_<Feature>_Requests`, drained by `UMars_Processor_<Feature>_HandleRequests`
  (snapshot → `Request_TryRemove` → apply in documented order → broadcast). Signals are `delegate`/`event _MC` pairs in
  `FMars_Fragment_<Feature>_Signals`, bound lazily, broadcast only `if (Has_Fragment(Signals))`.
- **Namespaces.** Only `utils_<feature>` namespaces exist. No helper namespaces (`mars_foo`, `mars_foo_math`); fold
  them into the feature's utils when you touch them. Functions that read feature state are `mixin`s on the typed
  handle; pure helpers are `utils_<feature>` functions.
- **Parameters.** A function takes at most 3 parameters (a mixin's `Self` excluded, out-params included). Beyond
  that, pack inputs into a struct (`FMars_<Feature>_<Thing>Query` / `_Frame` / `_State`). A struct that grows past
  roughly seven fields nests related fields into sub-structs instead of staying flat. Request mixins take the request
  struct (`Request_X(const FMars_Request_<Feature>_X&)`) with full positional ctors so call sites stay one line.
- **`Add` takes the handle and the Spec, nothing else** (`utils_<feature>::Add(Handle, FMars_<Feature>_Spec)`), as the C++
  features do: setup handles, child nodes, action lists and other construction inputs are Spec fields (C++ specs carry
  handles too, e.g. `FCk_ProceduralRig_Spec._Segments`). A class reference a retained Spec must hold is a `TSoftClassPtr`.
- **Spec validity** is a `mixin FMars_Validation Validate(const FMars_X_Spec& Self)` on the Spec
  (`Script/Common/Mars_Validation.as`); `Add` wraps it in `ck::EnsureIfNot`. No `DoGet_SpecError`-style helpers.
- **Fragments hold no strong `UObject`/`UClass` refs** (`Schema.IsSafe` rejects the fragment): use
  `TSoftObjectPtr`/`TSoftClassPtr`/`TWeakObjectPtr`/handles.
- **Stations are three layers, and a designer should be able to make a new station by writing only the entity script.**
  1. *Kernel* (`Script/ECS/<Feature>/`): the simulation and its ledger only: fragments, requests, processors, signals
     (edges or quantized), the typed handle, `Add(Handle, Spec)`, `Validate`. It owns every clock and every rule that must
     hold headless and deterministically (what cooks, what counts as a flip, when a piece is lost). It knows no mesh,
     material, particle, text, colour, input action, hint, camera or grip; a mesh reference may appear only as a physics
     source (a collision shape). Construction inputs the kernel needs (nodes, bodies, implements) arrive as handles in
     the Spec, built by the caller; a shared builder for such a body may live in the kernel's utils when the test rig
     needs the same geometry.
  2. *Control* (`Script/WorldObjects/Stations/Mars_<Station>Station_Hfsm.as`): the operator's state machine. It reads
     the station and the kernel, reads the operator's intents and looks, issues kernel requests, registers hint rows,
     and sequences phases (Idle / Operated / sub-SMs). It owns no clock the simulation depends on and draws nothing.
     Shared station conditions (`StationIsOperated`) live in `Mars_Station_SmConditions.as` beside them.
  3. *Assembly* (`Script/WorldObjects/Stations/Mars_<Station>Station_EntityScript.as`): the actor-like assembler. It builds
     nodes, parts and bodies, composes the features, binds their signals, and owns everything seen or heard: meshes,
     materials and their parameters, custom primitive data, Niagara, labels and their text, colours, scale constants,
     grips, camera framing, prompts, and any per-frame dressing (a `utils_timer::Create_Tick` on the script). It reads
     kernel state through mixins and writes nothing but requests and its own components.
  The test for a line of code: *runs every frame whoever is operating and must be testable headless* → kernel;
  *depends on an operator being present or on their input, or sequences the interaction* → control; *is seen or heard*
  → assembly. A `Get_StateLabel`, a hint string or an `Mars_IA_*` reference inside `Script/ECS/` is a leak.
- **Behaviour lives in HFSM tasks; actors are composition.** Sequences with phases are state machines (sub-SMs under
  the owning state), with enter tasks issuing requests and polled/event-driven conditions deciding transitions.
- **Widgets** are `UCLASS(Abstract)` with `meta = (BindWidget)` members and logic only; child widget classes are
  `EditDefaultsOnly` set in the WBP; never build widget trees in code.
- **Input** buttons are CkIntent level rows on the gameplay input profile, read by HFSM tasks; only Move/Look bind
  Enhanced Input directly.
- **View.** The player's view is the CkCamera director on `Player.Head` (a CkGait bob node at eye height); the hand chain
  hangs off the director's view anchor; the interaction trace rides the anchor. Never add a `UCameraComponent` or read
  `GetPlayerViewPoint` — go through `utils_player_viewpoint`. The gait (`utils_gait`) is the one stride clock for every bob.
- **Surfaces** use the CkUsf ProtoGrid material instances under `/Game/Mars/Materials/ProtoGrid`.
