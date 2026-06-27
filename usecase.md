# Use Cases — Anticipatory Ticket Live Activity

> Companion to [`prd.md`](prd.md). Maps each `JourneyPhase` to the user's situation, the
> story behind it, and what the **Live Activity** should present in that moment — across the
> Dynamic Island (minimal / compact / expanded) and the Lock Screen.
>
> Grounded in the actual pass: **USA vs Argentina, FIFA World Cup 2026 Semi-final**,
> MetLife Stadium · Gate C · Section 112, Row 8, Seat 14 · doors 4:00 PM · kickoff 7:00 PM ET
> (Tue Jul 14, 2026).

## The core idea

The ticket holds the same ~15 facts the whole time. What changes is **which fact answers the
question the user is silently asking when they glance at a locked phone.** A Live Activity
puts that one answer on the Lock Screen / Dynamic Island with no app-open required, and the
`JourneyPhase` engine drives which answer leads. Each phase below names that question, what
the activity should show in each surface, and what should get out of the way.

`unknown` phase = a neutral countdown card (no wrong lead). Every other phase improves on it
by leading with the moment's answer.

### The Dynamic Island regions, in plain terms

- **minimal** — a single glyph/value when the activity shares the pill with another app.
- **compactLeading / compactTrailing** — the two small slots flanking the camera when this is
  the only activity.
- **expanded** — the tap/long-press detail (and the Lock Screen card uses the same content).

---

## Phase 1 — `preEvent` (days/hours out, away from venue)

**Silent question:** *"When is this, and do I need to do anything yet?"*

**Story.** The Sunday before. The user glances to reassure themselves it's real and to keep
the date in mind. Not at the venue, won't be for days. Orientation, not detail.

| Surface | Content |
|---|---|
| minimal | countdown glyph (`⏱`) |
| compact | "Sat" · `Text(doors, style:.relative)` to doors |
| expanded / Lock Screen | "Semi-final · doors 4:00 PM, kickoff 7:00 PM · MetLife Stadium" + days-to-go |

**Summary line (template):** "3 days to kickoff — doors open 4:00 PM Saturday at MetLife
Stadium. Plan to arrive early; this is a Semi-final."

`relevanceScore`: low. `staleDate`: well after kickoff.

---

## Phase 2 — `approaching` (within the travel window, en route)

**Silent question:** *"Should I be leaving, and where am I going?"*

**Story.** Match day, early afternoon, at home or driving. The decision is logistics — when
to leave, which gate. Seat doesn't matter yet; they can't scan in from the highway.

| Surface | Content |
|---|---|
| minimal | gate glyph or countdown |
| compact | `Text(doors, style:.timer)` + "Gate C" |
| expanded / Lock Screen | "Doors in 2h 10m → Gate C, West Plaza" + venue address for maps hand-off |

**Summary line (template):** "Doors open at 4:00 PM — head for Gate C on the West Plaza.
MetLife parking fills early for Semi-finals."

> Most improved by *location*. On the Simulator this is driven by the **GPX route** crossing
> into the travel window; absent location it falls back to the clock.

`relevanceScore`: rising as doors near.

---

## Phase 3 — `atVenue` (near the stadium, pre-kickoff)

**Silent question:** *"How do I get in — fast?"*

**Story.** In the crowd outside Gate C, phone out. Only two things matter: the **QR** (to
scan) and **gate + seat** (to find the way). Everything else is noise. This is the beat the
**Simulator GPX geofence** fires.

| Surface | Content |
|---|---|
| minimal | gate glyph (`🎫`) |
| compact | "Gate C" · "112" |
| expanded / Lock Screen | **QR prominent** + "Gate C → Section 112 · Row 8 · Seat 14" |

**Summary line (template):** "You're at MetLife. Enter at Gate C, then Section 112, Row 8,
Seat 14. Have your QR ready."

`relevanceScore`: highest — this is the moment the activity should win the pill.

> Note: a scannable QR really lives on the **Lock Screen / expanded** surface; the Dynamic
> Island compact slots are too small for a QR, so they carry gate/section and a "tap for QR"
> affordance.

---

## Phase 4 — `inProgress` (kickoff → final whistle)

**Silent question:** *"(probably nothing — I'm watching.)"*

**Story.** The match is on. The user rarely looks; if they do, it's to re-confirm their seat
after a concourse trip or show a steward. Minimal, calm.

| Surface | Content |
|---|---|
| minimal | seat glyph |
| compact | "Sec 112" · "Seat 14" |
| expanded / Lock Screen | "Section 112 · Row 8 · Seat 14 — no re-entry" |

**Summary line (template):** "USA vs Argentina is underway. Your seat: Section 112, Row 8,
Seat 14. Note: no re-entry."

`relevanceScore`: low. (We have no live score — keep it to seat; don't fake data.)

---

## Phase 5 — `postEvent` (after final whistle / expiration)

**Silent question:** *"Is this over? Anything I still need this for?"*

**Story.** Full time. The ticket's done its job. Lead with closure + the one remaining
actionable thing (support/resale), then **end the activity** so it dismisses from the pill.

| Surface | Content |
|---|---|
| expanded / Lock Screen (final frame) | "Full time — thanks for coming. Issues? Ticket support; resale via the official FIFA platform." |

Then call `activity.end(...)` with a short dismissal so it clears.

**Summary line (template):** "Match complete. Keep this as a memento — for any issues,
contact ticket support; resale only via the official FIFA platform."

`staleDate`: at/just after `eventEndDate`.

---

## Phase 0 — `unknown` (fallback / ground state)

**Story.** The engine can't confidently place the user (missing/odd dates, no location, demo
clock far from the event). We don't guess.

**Behavior.** Show a neutral countdown card — match, teams, kickoff time — no phase-specific
lead, no QR. The safe floor; we never present a *wrong* lead.

---

## Content-importance matrix

Which content leads (●●●), supports (●●○), or recedes (○○○) per phase — now read as "what
fills the Dynamic Island / Lock Screen surfaces."

| Content | preEvent | approaching | atVenue | inProgress | postEvent |
|---|---|---|---|---|---|
| QR code (Lock Screen / expanded) | ○○○ | ○○○ | ●●● | ●●○ | ○○○ |
| Date / countdown | ●●● | ●●● | ○○○ | ○○○ | ○○○ |
| Venue + address | ●●● | ●●○ | ●●○ | ○○○ | ○○○ |
| Gate / entrance | ●●○ | ●●● | ●●● | ●●○ | ○○○ |
| Seat (sec/row/seat) | ●●○ | ○○○ | ●●● | ●●● | ○○○ |
| Doors open | ●●● | ●●● | ●●○ | ○○○ | ○○○ |
| Terms (no re-entry) | ○○○ | ○○○ | ●●○ | ●●○ | ○○○ |
| Support / resale | ○○○ | ○○○ | ○○○ | ○○○ | ●●● |

## Why this matters (the product argument)

- **The ticket never changes; the answer does.** One JSON file, five "right answers," picked
  by `(now, location)` and pushed to the Lock Screen — no app-open, no scanning.
- **The QR migration is the sharpest demo beat.** It's absent early, becomes the hero when
  the GPX route crosses the venue geofence, then recedes. That single behavior sells "it
  knows where I am in the journey" better than any copy — and it fires on the Simulator.
- **Failure is graceful by construction.** Unknown phase → neutral countdown. Worst case is a
  *neutral* card, never a wrong one. Push is absent → the local timer still ticks.

## How these phases map to real system surfaces (Siri research)

- **"Leave now" / countdown** → the **Live Activity** itself (Dynamic Island + Lock Screen,
  local timer, runs on the Simulator).
- **"You're at Gate C"** → **CoreLocation `CLMonitor` geofence**, driven by a Simulator GPX
  route, flipping `ContentState` to `atVenue`.
- **"Surface the pass/app at the right moment"** → real **Siri** via App Intents /
  `NSUserActivity` donation (suggests the *app*) and signed-pass relevance fields (surfaces
  the *pass* in system Wallet) — the honest "Siri-aware" layer.

Settled distinction: **the lead/summary content is chosen by the rules engine + AFM
(FoundationModels), not Siri** — there's no public API to have actual Siri rank or write it.
"Siri-powered" is accurate only for the proactive *surfacing* layer. See `prd.md` →
"Siri & system-surfacing research" for the full verdict and API map.
