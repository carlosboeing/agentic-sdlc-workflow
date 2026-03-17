# The Debugging: A Silicon Valley Musical
## Technical Stage Design and Effects Specifications

---

## Main Stage: CtrlZ Open-Plan Office

**Location:** Center stage, full width
**Scene(s):** All scenes

### Description
Six desks in two facing rows — stacked monitors, sticky notes on every surface. Upstage-center: a whiteboard covered in sprint boards, a Kanban with everything stuck in "In Progress," and a sign reading "WE ARE AGILE." Stage left: a 2m server rack with amber LEDs humming at 60Hz throughout the show.

### Technical Requirements
- Server rack LED panel: DMX-programmable, defaults to amber, cues to red on demand
- Continuous 60Hz tone via speakers in the rack prop

---

## Upstage: Server Room

**Location:** Behind semi-transparent scrim, upstage
**Scene(s):** Act I Scene 3, Act II Scene 3 (primary); visible throughout

### Description
Darker mechanical space behind a frosted glass partition. The Legacy Codebase ensemble performs here: exposed cable runs, blinking racks, industrial tile. Scrim allows simultaneous sightlines with independent lighting.

### Technical Requirements
- Scrim minimum 4m wide with LED strip; independent lighting circuit
- Sprung floor overlay for ensemble choreography (4m × 3m)

---

## Lighting: Fire Effect (Act II Scene 1)

**Location:** Full stage
**Scene(s):** Act II, Scene 1 — "It Worked on My Machine"

### Description
Amber and red flicker simulates server overload during the demo failure. Builds through Priya's chorus; snaps to cold white on Jordan's pivot. No pyrotechnics.

### Technical Requirements
- Four DMX flicker fresnels (channels 40–43); server room to full red at LX-21

### Cue Sheet

| Cue | Trigger | Action | Duration |
|-----|---------|--------|----------|
| LX-20 | Demo app launched | Amber wash 20%, slight flicker | 8s fade |
| LX-21 | First error message | Amber/red 80%, server room full red | 3s snap |
| LX-22 | Priya: "It worked on MY machine!" | Full fire 100%, 6Hz flicker | Hold |
| LX-23 | Jordan: "What if we called it a feature?" | Cold white snap, fire out | Instant |

---

## Lighting: Blue Wash ("The Rollback Waltz")

**Location:** Full stage
**Scene(s):** Act II, Scene 2

### Technical Requirements
- Full overhead cool blue (Lee 161); server room at 40% blue, independent circuit
- Fog machine active during this sequence

---

## Lighting: Merge Conflict Red

**Location:** Stage left and right booms
**Scene(s):** Act I, Scene 3 — "The Merge Conflict" tango

### Technical Requirements
- Two Source Four ellipsoidals, red gel (Lee 026), stage left and right
- Whiteboard backlight: cold white, independent channel

---

## Fog Machine: "The Rollback Waltz"

**Location:** Stage left/right wings; server room floor
**Scene(s):** Act II, Scene 2

### Description
Low-lying fog at ankle height rolls across the stage, representing the rollback washing over the codebase. Builds through the number; dissipates before Scene 3.

### Technical Requirements
- Two chilled-output fog units in wings; one unit inside server room
- Non-toxic fluid; trigger at number start, cutoff at final chorus

---

## Projections

**Location:** Upstage surface, shared with server room scrim
**Scene(s):** Act I Scene 1 (slide deck), Act II Scene 1 (error messages)

### Description
Act I: pitch deck aesthetic. Act II: red-on-black terminal with scrolling errors.

### Technical Requirements
- Projector: 10,000 lumens minimum, short-throw
- Act I: "10x the undo," "Ctrl+Z as a Service," "Series A: $50M pending"
- Act II: `NullPointerException`, `FATAL: main branch unreachable`, `git merge: CONFLICT` — triggered by LX-21
