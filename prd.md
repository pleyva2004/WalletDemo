# PRD — Anticipatory Ticket Details (Siri-powered island)

> Status: planned (not yet implemented). Branch: `feature/dynamic-island`.

## Problem

A World Cup ticket holds ~15 facts (venue, gate, doors, seat, terms, support, transit,
weather…). Today they live in `pass.json` as flat `backFields` — equally weighted,
statically ordered, surfaced only when the user goes looking (flip the pass / long-press
the mock card). But the fact that matters is a moving target:

- **T-3 days:** "where is it / when do doors open"
- **In the parking lot:** "Gate C, walk left"
- **In the seat:** nothing — maybe just the QR

A static back panel forces the user to scan and filter on every open. The info that matters
*right now* is buried under the info that mattered last week.

## Insight

The pass already knows the **when** (`relevantDate`, `doors`, `eventEndDate`) and the
**where** (`locations`, `semantics.venueLocation`). So the system can infer which phase of
the journey the user is in and lead with what that moment needs. The intelligence layer's
job is **ranking and rewriting** — same ticket, reordered and rephrased for the moment —
not inventing new data.

The existing Siri rainbow glow on the island is the UI promise of exactly this:
"this is intelligent; it's showing you what you need now."

## Scope (MVP)

**Mock island only.** We compute everything at open-time and render it in the existing
long-press "Ticket Details" island. Must run fully in the Simulator / `run.sh` loop.

### Architecture (build order)

1. **`JourneyPhase` engine** — pure function `(now, location?, passDates) → phase`.
   Phases: `preEvent · approaching · atVenue · inProgress · postEvent`, plus `unknown`.
   Deterministic; ships with one assert-based self-check.
2. **Field ranking** — `phase → { lead, rest, demoted }` view over the existing fields.
   **Raw `backFields` order is the fallback for `unknown`** — today's behavior becomes the
   explicit "ground" state.
3. **`Summarizer` protocol** — one natural-language line above the ranked fields.
   - Primary now: a **deterministic per-phase template** (pure Swift, testable, offline).
   - Later: an **Apple FoundationModels** implementation behind the same protocol, once
     verified to build headless / macro-free.
   - **Rules always render; the AI line swaps in only if present, else the lead rule-field
     stays.** Failure is invisible, never blank.

### UI

Island leads with the summary line (the Siri glow already signals intelligence) → ranked
fields → static fields (`terms`, `support`) behind a "More" disclosure.

### Source of truth

Still `pass.json`. The engine reads its dates (`relevantDate`, `doors`, `eventEndDate`) and
`semantics.venueLocation`; no new hardcoded ticket data, in line with the repo's
single-source-of-truth rule.

## Non-goals (this iteration)

- Real signed-Wallet anticipatory surfacing (lock-screen suggestion of the actual pass).
- Live Activity / hardware Dynamic Island.
- Live transit / weather, or any network calls.

## Done = testable

- Phase-engine self-check passes.
- `./run.sh` screenshot shows the island leading with a phase-appropriate line.
- With phase `unknown`, the island falls back to today's raw `backFields`.

## Risks

- **FoundationModels availability** in headless / Simulator builds — deferred, hidden behind
  the `Summarizer` protocol.
- **Simulator location is simulated** — phase selection by time alone must still produce a
  sensible lead.

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
| **ActivityKit Live Activity** | Kickoff countdown + seat/gate on Lock Screen **and the hardware Dynamic Island**; local `Text(date, style:.timer)` ticks with no push; `relevanceScore`/`staleDate` model priority | 16.1+ | **Yes** (core experience renders; local updates work) | **Strongest demoable fit.** Push-driven updates need a device + APNs. |
| **CoreLocation `CLMonitor` geofence** | "User arrived at MetLife" trigger → flip content to gate/seat/QR | 17+ | **Yes** (Simulator GPX route crosses the boundary) | Deterministic proximity beat, fully headless. Only a trigger — wakes your logic, doesn't surface UI itself. |
| WidgetKit Smart Stack relevance (`RelevantContext.date/location`) | Widget promoted in Smart Stack at the right time/place | 17+ | Partial (renders; promotion non-deterministic) | Lower demo payoff than Live Activity. |
| Visual Intelligence (`SemanticContentDescriptor` via App Intents) | Camera/screenshot → deep-link into app | 26+ | **No** (needs Apple-Intelligence device) | Image-driven, weak fit; skip. |

### Implication for scope (decision to revisit)

The strongest *Simulator-demoable* anticipatory surface is an **ActivityKit Live Activity in
the Dynamic Island** + a **GPX-driven geofence** — both run headless, no device/cert. This is
exactly the hardware Dynamic Island this branch (`feature/dynamic-island`) is named for, yet
the MVP currently lists Live Activity / hardware Dynamic Island as a **non-goal**. The
in-app mock-island work and a Live Activity are *complementary* (same phase engine feeds
both), so the open question is whether to **promote Live Activity into the MVP** rather than
defer it. See the decisions log.

**Verify before shipping:** `relevantDates` (~iOS 18), `RelevantIntentManager`/`RelevantIntent`
(~iOS 18), `INRelevantShortcut` deprecation, Visual-Intelligence Simulator support. The
Siri-vs-AFM conceptual split does not depend on these.

## Decisions log

| Decision | Choice |
|---|---|
| Surface | Mock island only |
| Intelligence | Rules floor + AI garnish (rules always render, AI swaps in if present) |
| AI engine | `Summarizer` protocol + deterministic template now; FoundationModels later |
