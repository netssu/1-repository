# UI Controller Modularization — Design

Date: 2026-06-19
Target: `src/Shared/UI/Controller/init.luau` (+ new `src/Shared/UI/Controller/DefaultTransition.luau`)

## Goal

Refactor the UI Controller so it holds no hardcoded references to specific UI
instances, drives all configuration through setter functions, splits the default
open/close menu animation into its own module, supports per-section custom open
and close animations, and closes the previously-open section with its proper
close animation whenever a new one opens.

## Scope

In scope:
- Rewrite `src/Shared/UI/Controller/init.luau`.
- New module `src/Shared/UI/Controller/DefaultTransition.luau`.

Out of scope (user wires these):
- The bootstrap/call site that calls the setters and `:init()`.
- Changes to `src/Shared/UI/init.luau` loader or any consumer.

## Decisions (from brainstorming)

- Custom animation contract: `fn(section) -> { Ended = Signal }`, matching
  `GuiClass:LoadFrame`.
- Default animation module lives beside the Controller (`Controller/DefaultTransition.luau`),
  not in `Classes/Gui`, because it owns menu-specific blur/FOV behavior.
- Configuration via individual setter functions, not a config table.
- `:init()` is guarded: it no-ops until a root is configured, so the existing
  auto-call from the UI Modules loader is harmless. The user's bootstrap calls
  the setters, then `:init()`.

## Module 1 — DefaultTransition.luau (new)

Owns the default per-section visual and the ambient menu effect (blur + FOV).
No path-based instance lookups.

Behavior:
- On require, create a `BlurEffect` in `Lighting` (name `MenuBlur`), `Size = 0`,
  `Enabled = true`. Created, never `WaitForChild`'d. If one with that name
  already exists, reuse it (defensive against re-require).
- `:Open(section) -> { Ended = Signal }`: ensure a `Scale` `UIScale` child exists
  on `section`, set `Scale = 0`, tween to `1` with
  `TweenInfo.new(0.3, Back, Out)`. Fire/destroy `Ended` on completion.
- `:Close(section) -> { Ended = Signal }`: tween the `Scale` to `0` with
  `TweenInfo.new(0.3, Back, In)`. Fire/destroy `Ended` on completion.
- `:RaiseAmbient(section)`: tween FOV to open value (`TweenFov:TweenTo`) and blur
  `Size` to blur size — unless the section name is in the no-blur set.
- `:LowerAmbient()`: tween FOV to close value and blur `Size` to `0`.
- Config setters: `:SetOpenFov(n)` (default 80), `:SetCloseFov(n)` (default 70),
  `:SetBlurSize(n)` (default 20), `:DisableBlurFor({names})`.

Constants (named, no magic numbers): default open FOV 80, close FOV 70, blur
size 20, tween time 0.3.

Rationale for splitting ambient from per-section animation: the blur must stay up
while swapping section A to B and only drop when the last menu closes. Keeping
blur inside each section's open/close fn would tween it down then up during a
swap, causing a flicker. The Controller raises ambient on the first open and
lowers it on the last close; per-section fns (default or custom) only drive the
section's own motion.

## Module 2 — Controller/init.luau (rewritten)

Removed top-level hardcoded references: `PlayerGui`, `Game` frame, `ButtonsFrame`,
`Currencies`, currency icons, `GuiBlur`, `Sections.Achievements/Settings` literal
paths, `GuisHiddenPostions` do-block, `AutomaticButtonList` + `Right_side` block.
`TweenFov` and blur usage move into `DefaultTransition`.

### State (private)
- `_root`, `_sectionsContainer`
- `_hideFrames` (`{ [GuiObject]: UDim2 }`), `_hideGuiObj`
- `_hotkeys`, `_nameOverrides`
- `_openCallbacks`, `_closeCallbacks` (keyed by section name)
- `_buttonContainers`
- `_loadAnimations` (keyed by section name)
- `_floatingIcons`
- `_openAnims`, `_closeAnims` (keyed by section instance)
- `_initialized`
- existing isolated-frame state, return-target state, tween tracking retained.

### Setters
- `:SetRoot(frame)`, `:SetSectionsContainer(frame)`
- `:SetHideFrames(map)` — stored; `_hideGuiObj` built in `:init()` via
  `GuiClass:CreateHideObject`.
- `:SetHotkeys(map)`, `:SetSectionNameOverrides(map)`
- `:SetOpenCallback(name, fn)`, `:SetCloseCallback(name, fn)`
- `:RegisterButtonContainer(frame)`, `:SetButtonContainers({...})`
- `:RegisterLoadAnimation(name, {GuiObject})`
- `:RegisterFloatingIcon(obj, opts?)`
- `:SetNoBlurFor({names})` — forwards to `DefaultTransition:DisableBlurFor`.
- `:SetOpen(section, fn)`, `:SetClose(section, fn)` — per-section custom
  animations, `fn(section) -> { Ended = Signal }`.

### Animation resolvers
- `getOpenAnim(section)` returns `_openAnims[section]` or a default that calls
  `DefaultTransition:Open(section)`.
- `getCloseAnim(section)` returns `_closeAnims[section]` or a default that calls
  `DefaultTransition:Close(section)`.

### Open / Close / swap
- `:Open(Frame, LoadWithAnimation?)`:
  - Existing guards (`GuisHidden`, `GuisOpenable`, `TargetUi == Frame`,
    return-target clearing, closing-frame cleanup) retained.
  - If `OpenedUi` exists and `~= Frame`: run its resolved close animation (so it
    animates out) and run its close callback; do NOT lower ambient (swap keeps
    blur up).
  - Park/restore isolated frames and run `_loadAnimations[name]` /
    `LoadWithAnimation` via `GuiClass:LoadFrame` as today.
  - Run `getOpenAnim(Frame)`; if no menu was open before, `RaiseAmbient(Frame)`.
  - Run open callback `_openCallbacks[name]`.
- `:Close(Frame)`:
  - Existing guard `TargetUi == Frame`. Run `getCloseAnim(Frame)`; on its `Ended`,
    hide the frame unless re-opened, and `ReopenReturnTarget`. Run close callback.
  - `LowerAmbient()` because closing leaves no menu open.
- `:Toggle`, `:OpenWithReturn`, `:ClearReturn` keep current semantics, routed
  through the resolvers.
- `:MatchFrame` uses `_sectionsContainer` (default `_root.Sections`), no
  `PlayerGui` lookup.
- `:HideGuis` / `:ShowGuis` use `_root.Enabled` and `_hideGuiObj`.

### init (guarded)
- If `_root` is nil: warn once and return (no-op) — makes the loader auto-call
  harmless.
- If already `_initialized`: return.
- Build `_hideGuiObj` from `_hideFrames`. Iterate `_buttonContainers`, wire
  buttons via `:AddFunctions` (unchanged logic). Apply
  `GuiClass:CreateFloatingAnimation` to each `_floatingIcons` entry.
- Set `_initialized = true`.

## Error handling

- Setters tolerate nil/empty inputs (guard, no error) so partial configuration
  is safe.
- `getOpenAnim`/`getCloseAnim` always return a callable (default fallback).
- `DefaultTransition` reuses an existing `MenuBlur` if present.
- All instance access remains nil-guarded as in the current code.

## Testing

Roblox runtime; manual verification in Studio:
- Configure root + a couple of sections + hide frames + hotkeys, call `:init()`.
- Open a section: it scales in, blur raises.
- Open a second while the first is open: first animates out via its close
  animation, second scales in, blur stays up (no flicker).
- Close the last: it scales out, blur lowers.
- Register a custom `:SetOpen`/`:SetClose` on one section and confirm it runs
  instead of the default.
- Call `:init()` with no root configured: no-op, no error.

## Coding guidelines (project)

- Private fields prefixed `_`.
- No comments unless explaining non-obvious rationale already present.
- Named constants, no magic numbers.
- No deprecated Luau/Roblox APIs.
