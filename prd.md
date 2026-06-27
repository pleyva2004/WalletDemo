# PRD — Anticipatory Ticket Live Activity (Dynamic Island)

> Status: **implemented as a Simulator demo** (phase engine + shared Live Activity surfaces +
> mocked-clock harness; all six use cases screenshot-verified — see [`README.md`](README.md)).
> On-device ActivityKit registration is the remaining device-only step. Branch:
> `feature/dynamic-island`.
>
> **Pivot (2026-06-27):** the feature is now an **ActivityKit Live Activity** that surfaces
> the right ticket info at the right moment in the **Dynamic Island** and on the **Lock
> Screen** — not the in-app long-press island. Research showed this is the strongest
> *Simulator-demoable* anticipatory surface and is what this branch was named for. The
> existing in-app "Ticket Details" island stays as-is but is no longer the deliverable.

## Problem

A World Cup ticket holds ~15 facts (venue, gate, doors, seat, terms, support…). They live in
`pass.json` and are only seen when the user **opens something** (Wallet, or the app and
long-presses). But the moments that matter most — "should I leave?", "which gate?", "how
long to kickoff?" — are exactly when the user *doesn't* want to dig: they're driving, walking
through a crowd, glancing at a locked phone. The info that matters *right now* should be on
the Lock Screen / Dynamic Island, led by the journey phase, with no app-open required.

## Insight

The pass already knows the **when** (`relevantDate`, `doors`, `eventEndDate`) and the
**where** (`locations`, `semantics.venueLocation`). A Live Activity can render a live
countdown on-device (`Text(date, style: .timer)`, no push) and update its `ContentState` as
the journey phase changes. Same ticket, re-led for the moment — surfaced glanceably.

## Scope (MVP)

A **local (non-push) Live Activity** for the ticket, driven entirely on-device, demoable on
the Simulator. It presents phase-appropriate content in the Dynamic Island (compact / minimal
/ expanded) and on the Lock Screen, and flips phase from a local timer + a simulated geofence.

### Architecture (build order)

0. **Feasibility spike (gate — do first).** Add a Live Activity **widget-extension target**
   to the XcodeGen spec and confirm it builds + runs **headless** via `run.sh`, with
   `NSSupportsLiveActivities` set. This is the make-or-break risk (see Risks); validate before
   building features on top.
1. **`JourneyPhase` engine** — pure `(now, location?, passDates) → phase`. Phases:
   `preEvent · approaching · atVenue · inProgress · postEvent` + `unknown`. Deterministic,
   one assert-based self-check. *Shared* by the app and the Live Activity.
2. **`ActivityAttributes`** — static ticket data (match, teams, venue, gate, seat, QR
   payload) + **`ContentState`** (current `phase`, the lead content for that phase, the
   countdown target date, `relevanceScore`, `staleDate`). Decoded from the same
   `PassDocument` — `pass.json` stays the single source of truth.
3. **Live Activity views** — a Lock Screen view + `DynamicIsland { }` regions
   (compactLeading / compactTrailing / minimal / expanded), each rendering the phase's lead
   content (see `usecase.md` for the per-phase mapping).
4. **Drivers (Simulator-demoable)** — start the activity via `Activity.request(...)`; a local
   timer advances `preEvent → approaching → inProgress → postEvent`; a **CoreLocation
   `CLMonitor` geofence**, fed by a **Simulator GPX route**, flips to `atVenue` on arrival.
   All `ContentState` updates are local (no APNs).
5. **`Summarizer` (garnish, optional)** — one natural-language line in the expanded /
   Lock Screen presentation. Deterministic per-phase **template** now; **FoundationModels**
   behind the same protocol later. Rules always render; the line swaps in only if present.

### Presentation surfaces

- **Dynamic Island** — compact (countdown + gate), minimal (single glyph/value when sharing
  the pill), expanded (lead line + seat/gate, QR at venue).
- **Lock Screen / banner** — the fuller phase card (countdown, gate, seat, and at-venue QR).

### Source of truth

Still `pass.json`. The engine and `ActivityAttributes` read its dates + `semantics`; no new
hardcoded ticket data.

## Non-goals (this iteration)

- **Push-driven** Live Activity updates / push-to-start (APNs token flow) — local updates
  only. (Push needs a physical device + APNs key.)
- Real signed-Wallet anticipatory surfacing of the actual `.pkpass`.
- Live transit / weather, scores, or any network calls.
- The in-app long-press island is **out of scope to change** — it stays as it is today.

## Implementation status

What shipped on this branch (Simulator-demoable, screenshot-verified):

| Piece | Where | Status |
|---|---|---|
| `JourneyPhase` engine (`resolve(now:atVenue:doors:kickoff:)`) + launch self-check | `Sources/JourneyPhase.swift` | ✅ done |
| `TicketSnapshot` (typed view of `pass.json`) | `Sources/TicketSnapshot.swift` | ✅ done |
| `Summarizer` protocol + `TemplateSummarizer` | `Sources/Summarizer.swift` | ✅ done (FoundationModels impl deferred) |
| Shared surfaces: `LockScreenCard`, `DynamicIslandPill`, `PhasePresentation` | `Sources/LiveActivitySurfaces.swift` | ✅ done |
| Mocked-clock demo harness (launch args `-DemoNow`/`-DemoAtVenue`) | `Sources/DemoHarness.swift` | ✅ done |
| Headless per-phase screenshot loop | `demo-shots.sh` → `docs/uc-*.png` | ✅ done (6/6) |
| Widget-extension target / real `Activity.request` registration | — | ⛔ deferred — **device-only**, can't be screenshot-verified headlessly |
| Live `CLMonitor` geofence + GPX route | — | ⛔ deferred — the demo injects the `atVenue` signal via a launch flag (the engine's real input), not a live geofence |

The shared surface views are the *identical* SwiftUI a widget extension would render; the
deferred items are the on-device wiring that surfaces them on the real Lock Screen / Dynamic
Island, which `simctl` cannot reach headlessly. The harness renders those same views in-app
so every use case is verifiable in the `run.sh`-style loop.

## Done = testable

- [x] Phase-engine self-check passes (runs at launch via `JourneyPhaseSelfCheck`; a broken
  rule crashes on launch and fails the screenshot loop).
- [x] All six use cases render phase-appropriate content, screenshot-verified from a mocked
  clock (`docs/uc-*.png`, embedded in `README.md`).
- [x] The `atVenue` presentation leads with the QR + gate + seat when the at-venue signal is
  set; the QR is absent in every other phase (the "QR migration" demo beat).
- [x] Phase `unknown` (`-DemoNow none`) shows a neutral kickoff card with **no** narrated
  line — never a wrong lead.
- [ ] **Device-only (not headless-verifiable):** a real Live Activity registered via a widget
  extension, surfaced on the actual Lock Screen / Dynamic Island, flipped by a live
  `CLMonitor` geofence driven by a Simulator GPX route.

## Risks

- **Widget-extension target in a headless XcodeGen build (highest).** The project is
  currently single-target and built headless; ActivityKit requires a separate widget
  extension target + `NSSupportsLiveActivities`. Spike step 0 de-risks this before anything
  else. WidgetKit's `@main WidgetBundle` and `DynamicIsland { }` are result builders, not the
  banned macros (`#Preview`/`@Observable`/`@Model`), so the macro-free rule should hold —
  **but verify the extension builds clean headless.**
- **Dynamic Island hardware** exists on iPhone 14 Pro and later; the Simulator renders it
  only on those device models — `run.sh`'s default sim must be one of them.
- **Push** is device-only; the MVP stays local to remain Simulator-demoable.
- **Simulator location** needs a GPX *route* (movement), not a static point, to reliably fire
  geofence enter/exit.

## Siri & system-surfacing research

> Two independent research passes (system/proactive Siri; buildable modern paths).
> Both corroborated. Caveat: Apple docs are JS-rendered, so findings lean on WWDC
> transcripts + the assistant's Jan-2026 knowledge; version-sensitive claims flagged below
> need a one-click confirm on developer.apple.com before shipping.

### Verdict: can this be "powered by actual Siri" (not AFM)? — **PARTIAL.** Two different "Siri"s:

- **Generating / ranking the panel's text on open → NO actual-Siri API exists.** There is no
  public way to call "Siri's intelligence" to rank fields or write a summary. On-device
  generation/summarization is **Apple Intelligence via FoundationModels** — that is **AFM,
  explicitly not Siri.** Our `Summarizer` garnish is therefore AFM-or-template; labeling it
  "Siri" would be inaccurate.
- **Surfacing the right pass/app at the right moment → YES, that is genuinely Siri** — but
  it is *orchestration, not generation.* You supply hints; the system decides final
  placement/ranking. You can never force a surface at an exact moment.

### "Real Siri" proactive surfaces (orchestration)

| Path | Surfaces | iOS | Simulator | Note |
|---|---|---|---|---|
| **Signed `.pkpass` relevance** (`relevantDate`/`relevantDates`, `locations`/`beacons` + `relevantText`, `semantics`) | System Wallet surfaces the **pass** on lock screen near kickoff / at venue | 12+ (`relevantDates` ~18, verify) | n/a — needs signed pass in system Wallet | Declarative, no code. Our bundled pass is unsigned → none of this fires; the in-app mock card gets none of it. |
| **App Intents** (`AppShortcut` + `TicketEntity`/`EntityQuery`, `PredictableIntent`) | Ticket becomes Spotlight/Siri-addressable; system *may* proactively suggest the app | 16+ (`PredictableIntent` 26) | Plumbing: yes. Predicted suggestion: **no** (needs accrued usage signals) | The honest home of "Siri-powered" framing — but it surfaces the *app*, not the panel's contents. |
| **`NSUserActivity` donation** (`isEligibleForPrediction`, `RelevantIntent` date/location) | Feeds the same prediction engine; Smart Stack / Siri Suggestions | 12+ | Partial (system-ranked) | Lightweight donation; not deprecated. |

### Buildable anticipatory surfaces (the demoable paths)

| Path | What it gives | iOS | Simulator | Verdict |
|---|---|---|---|---|
| **ActivityKit Live Activity** | Kickoff countdown + seat/gate on Lock Screen **and the hardware Dynamic Island**; local `Text(date, style:.timer)` ticks with no push; `relevanceScore`/`staleDate` model priority | 16.1+ | **Yes** (core experience renders; local updates work) | **The chosen feature.** Push-driven updates need a device + APNs. |
| **CoreLocation `CLMonitor` geofence** | "User arrived at MetLife" trigger → flip content to gate/seat/QR | 17+ | **Yes** (Simulator GPX route crosses the boundary) | Deterministic proximity beat, fully headless. Only a trigger — wakes your logic, doesn't surface UI itself. |
| WidgetKit Smart Stack relevance (`RelevantContext.date/location`) | Widget promoted in Smart Stack at the right time/place | 17+ | Partial (renders; promotion non-deterministic) | Lower demo payoff than Live Activity. |
| Visual Intelligence (`SemanticContentDescriptor` via App Intents) | Camera/screenshot → deep-link into app | 26+ | **No** (needs Apple-Intelligence device) | Image-driven, weak fit; skip. |

### How "Siri-powered" stays honest here

The Live Activity itself is **system-surfaced glanceable UI**, not Siri generation. To
legitimately earn "Siri-aware," layer the proactive surfaces above: an **App Intent /
`NSUserActivity` donation** so Siri Suggestions can offer "View my World Cup ticket," and
(when signed) `.pkpass` relevance fields. Those surface the *app/pass*; they don't write the
Live Activity's contents. Any generated summary line is **AFM (FoundationModels)**, not Siri.

**Verify before shipping:** `relevantDates` (~iOS 18), `RelevantIntentManager`/`RelevantIntent`
(~iOS 18), `INRelevantShortcut` deprecation, Visual-Intelligence Simulator support. The
Siri-vs-AFM conceptual split does not depend on these.

## Decisions log

| Decision | Choice |
|---|---|
| Surface (initial) | Mock island only |
| Intelligence | Rules floor + AI garnish (rules always render, AI swaps in if present) |
| AI engine | `Summarizer` protocol + deterministic template now; FoundationModels later |
| **Surface (pivot)** | **ActivityKit Live Activity / Dynamic Island is THE feature; in-app island retained but not the deliverable** |
