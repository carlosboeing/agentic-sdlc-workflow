# The Debugging: A Silicon Valley Musical
## Technical Stage Design and Effects Specifications

---

## Main Stage: CtrlZ Open-Plan Office

**Location:** Center stage, full width
**Scene(s):** All scenes

### Description
Six desks in two facing rows — stacked monitors, sticky notes. Upstage-center: whiteboard with Kanban, sign reading "WE ARE AGILE." Stage left: 2m server rack with amber LEDs at 60Hz.

### Technical Requirements
- Server rack LED panel: DMX-programmable, amber default, cues to red
- Continuous 60Hz tone via rack prop speakers

---

## Upstage: Server Room

**Location:** Behind scrim (upstage)
**Scene(s):** Act I/II Scene 3 (primary)

### Description
Mechanical space behind the scrim: exposed cables, blinking racks. Legacy Codebase ensemble; independent lighting for simultaneous sightlines.

### Technical Requirements
- Scrim 4m wide with LED strip; independent lighting circuit
- Sprung floor overlay, 4m × 3m, for ensemble choreography

---

## Lighting: Fire Effect (Act II Scene 1)

**Location:** Full stage
**Scene(s):** Act II, Scene 1

### Description
Amber and red flicker simulates server overload. Snaps to cold white on Jordan's pivot. No pyrotechnics.

### Technical Requirements
- Four DMX flicker fresnels (channels 40–43); server room full red at LX-21

### Cue Sheet

| Cue | Trigger | Action | Duration |
|-----|---------|--------|----------|
| LX-20 | Demo app launched | Amber wash 20%, slight flicker | 8s fade |
| LX-21 | First error | Amber/red 80%, server room full red | 3s snap |
| LX-22 | Priya: chorus peak | Full fire 100%, 6Hz flicker | Hold |
| LX-23 | Jordan: pivot | Cold white snap, fire out | Instant |

---

## Lighting: Blue Wash ("The Rollback Waltz")

**Location:** Full stage
**Scene(s):** Act II, Scene 2

### Description
Cool blue wash evoking the cold logic of reverting progress; paired with the fog machine.

### Technical Requirements
- Full overhead cool blue (Lee 161); server room at 40% blue, independent circuit
- Fog machine active during this sequence

---

## Lighting: Merge Conflict Red

**Location:** Stage left and right booms
**Scene(s):** Act I, Scene 3

### Description
Opposing red sidelight mirrors the conflict structure, throwing the whiteboard into sharp relief for the diverging-branch choreography.

### Technical Requirements
- Two Source Four ellipsoidals, red gel (Lee 026), stage left and right
- Whiteboard backlight: cold white, independent channel

---

## Fog Machine: "The Rollback Waltz"

**Location:** Stage left/right wings and server room floor
**Scene(s):** Act II, Scene 2

### Description
Ankle-height fog rolls across the stage representing the rollback. Clears before Scene 3.

### Technical Requirements
- Two chilled-output fog units in wings; one in server room
- Non-toxic fluid; trigger at number start, cut at final chorus

---

## Projections

**Location:** Upstage, shared with server room scrim
**Scene(s):** Act I Scene 1, Act II Scene 1

### Description
Act I: pitch deck aesthetic. Act II: red-on-black terminal errors.

### Technical Requirements
- Projector: 10,000 lumens, short-throw
- Act I: pitch deck slides
- Act II: `NullPointerException`, `git merge: CONFLICT` — triggered by LX-21
