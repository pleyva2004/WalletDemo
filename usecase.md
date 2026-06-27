# Use Cases — Anticipatory Ticket Details

> Companion to [`prd.md`](prd.md). Maps each `JourneyPhase` to the user's situation, the
> story behind it, and the content that should lead vs. recede in that moment.
>
> Grounded in the actual pass: **USA vs Argentina, FIFA World Cup 2026 Semi-final**,
> MetLife Stadium · Gate C · Section 112, Row 8, Seat 14 · doors 4:00 PM · kickoff 7:00 PM ET
> (Tue Jul 14, 2026).

## The core idea

The ticket holds the same ~15 facts the whole time. What changes is **which fact is the
answer to the question the user is silently asking when they open the pass.** Each phase
below names that question, the content that answers it (the *lead*), what supports it, and
what should get out of the way.

`backFields` order (VENUE · MATCH ID · ENTRANCE · DOORS · TERMS · SUPPORT) is the neutral
fallback — correct, but answers no specific question. Every phase improves on it by leading.

---

## Phase 1 — `preEvent` (days/hours out, away from venue)

**Silent question:** *"When and where is this, and do I need to do anything yet?"*

**Story.** It's the Sunday before. The user opens Wallet to reassure themselves the ticket is
real and to sanity-check the plan. They are not at the stadium and won't be for days. They
want orientation, not turn-by-turn detail.

**Lead content**
- Countdown + date/time: "Semi-final · Tue Jul 14 · doors 4:00 PM, kickoff 7:00 PM"
- Venue name + city: "MetLife Stadium, East Rutherford NJ"

**Support (visible, secondary)**
- Seat: Section 112 · Row 8 · Seat 14
- Recommended entrance: Gate C

**Demote (behind "More")**
- Terms & conditions, ticket support, match ID.

**Summary line (template):** "3 days to kickoff — doors open 4:00 PM Saturday at MetLife
Stadium. Plan to arrive early; this is a Semi-final."

---

## Phase 2 — `approaching` (within the travel window, en route)

**Silent question:** *"Should I be leaving, and where exactly am I going?"*

**Story.** It's match day, early afternoon. The user is at home or already driving. The
decision on the table is *logistics*: when to leave, which gate, where to park. Seat number
doesn't matter yet — they can't scan in from the highway.

**Lead content**
- Time-to-doors / leave-by framing: "Doors open in 2h 10m"
- Recommended entrance + plaza: "Gate C — West Plaza"

**Support**
- Venue address (for maps hand-off), parking/transit hint if available.

**Demote**
- Seat detail, terms, support, QR (not useful in transit).

**Summary line (template):** "Doors open at 4:00 PM — head for Gate C on the West Plaza.
MetLife Stadium parking fills early for Semi-finals."

> This is the phase most improved by *location*: "approaching" should trigger on proximity
> to the venue, not just clock time. On the Simulator (no real GPS) it degrades to a
> time-window heuristic.

---

## Phase 3 — `atVenue` (near the stadium, pre-kickoff)

**Silent question:** *"How do I get in — fast?"*

**Story.** The user is in the crowd outside Gate C. Phone is out, thumb hovering. The only
things that matter now are the **QR code** (to scan) and the **entrance + seat** (to find
their way). Everything else is noise in a loud, moving crowd.

**Lead content**
- **QR code, prominent** — this is the scan moment.
- Gate C · Section 112 · Row 8 · Seat 14

**Support**
- "Doors are open" confirmation.

**Demote**
- Date/countdown (they're here), terms, support, match ID, venue address.

**Summary line (template):** "You're at MetLife. Enter at Gate C, then head to Section 112,
Row 8, Seat 14. Have your QR ready."

---

## Phase 4 — `inProgress` (kickoff → final whistle)

**Silent question:** *"(probably nothing — I'm watching the match.)"*

**Story.** The match is on. The user rarely opens the pass here; if they do, it's to
re-confirm their seat after a concourse trip, or to show a steward. Minimal, calm content.

**Lead content**
- Seat: Section 112 · Row 8 · Seat 14 (for re-entry / steward checks).
- QR (re-entry, if the venue allows it).

**Support**
- "No re-entry" note *if* it applies (it does — see terms).

**Demote**
- Everything time-based, directions, support.

**Summary line (template):** "USA vs Argentina is underway. Your seat: Section 112, Row 8,
Seat 14. Note: no re-entry."

---

## Phase 5 — `postEvent` (after final whistle / expiration)

**Silent question:** *"Is this over? Anything I still need this for?"*

**Story.** Full time. The ticket has done its job. The user might open it out of habit, to
keep as a memento, or to chase a refund/resale/support issue. Lead with closure and the one
remaining actionable thing (support/resale), demote the now-useless logistics.

**Lead content**
- Closure line / memento framing: "Thanks for coming — USA vs Argentina, Semi-final."
- Ticket support + official resale note.

**Support**
- Match ID (for any post-event correspondence).

**Demote**
- Gate, seat, doors, QR, countdown.

**Summary line (template):** "Match complete. Keep this as a memento — for any issues,
contact ticket support; resale only via the official FIFA platform."

---

## Phase 0 — `unknown` (fallback / ground state)

**Story.** The engine can't confidently place the user (missing/odd dates, no location, a
demo with the clock far from the event). We don't guess.

**Behavior.** Render the raw `backFields` in `pass.json` order, no lead line, no demotion.
This is exactly today's island — the safe floor the PRD calls the "ground" state.

---

## Content-importance matrix

A quick read of which content leads (●●●), supports (●●○), or recedes (○○○) per phase.

| Content | preEvent | approaching | atVenue | inProgress | postEvent |
|---|---|---|---|---|---|
| QR code | ○○○ | ○○○ | ●●● | ●●○ | ○○○ |
| Date / countdown | ●●● | ●●● | ○○○ | ○○○ | ○○○ |
| Venue + address | ●●● | ●●○ | ●●○ | ○○○ | ○○○ |
| Gate / entrance | ●●○ | ●●● | ●●● | ●●○ | ○○○ |
| Seat (sec/row/seat) | ●●○ | ○○○ | ●●● | ●●● | ○○○ |
| Doors open | ●●● | ●●● | ●●○ | ○○○ | ○○○ |
| Terms (no re-entry) | ○○○ | ○○○ | ●●○ | ●●○ | ○○○ |
| Support / resale | ○○○ | ○○○ | ○○○ | ○○○ | ●●● |

## Why this matters (the product argument)

- **The ticket never changes; the answer does.** One JSON file, five different "right
  answers," selected by `(now, location)`. No new data, pure ranking — cheap to build, high
  perceived intelligence.
- **The QR migration is the sharpest demo beat.** It's buried/absent early, then becomes the
  hero at the gate, then recedes. That single behavior sells the "it knows where I am in the
  journey" story better than any copy.
- **Failure is graceful by construction.** Unknown phase → today's flat list. We never show
  a *wrong* lead; worst case is a *neutral* one.

## How these phases map to real system surfaces (Siri research)

The in-app island renders all five phases on open. But phases **2–3 (`approaching`,
`atVenue`)** are the ones a real proactive system could surface *without the user opening
anything* — and the research clarified exactly how:

- **"Leave now" / countdown to kickoff** → an **ActivityKit Live Activity** in the Lock
  Screen and **Dynamic Island** (local timer, runs on the Simulator). Strongest demoable fit.
- **"You're at Gate C"** → a **CoreLocation `CLMonitor` geofence** around MetLife, driven by
  a Simulator GPX route, flipping the content to gate/seat/QR on arrival.
- **"Surface the pass/app at the right moment"** → real **Siri** via App Intents /
  `NSUserActivity` donation (suggests the *app*, not the panel's contents) and signed-pass
  relevance fields (surfaces the *pass* in system Wallet).

Key distinction the research settled: **the in-panel ranking/summary is AFM
(FoundationModels), not Siri** — there is no public API to have "actual Siri" rank or write
the panel text. "Siri-powered" is accurate only for the proactive *surfacing* layer above.
See `prd.md` → "Siri & system-surfacing research" for the full verdict and API map.
