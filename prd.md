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

## Open investigation

Can this be powered by **actual Siri** (proactive intelligence / Siri Suggestions / App
Intents donation) rather than Apple FoundationModels? Findings to be appended once the
research lands.

## Decisions log

| Decision | Choice |
|---|---|
| Surface | Mock island only |
| Intelligence | Rules floor + AI garnish (rules always render, AI swaps in if present) |
| AI engine | `Summarizer` protocol + deterministic template now; FoundationModels later |
