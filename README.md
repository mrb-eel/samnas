# HOLD MY PLACE

One night at Ferrier Court, a council block built over a drained municipal
swimming pool and an old telephone exchange. You are Ari: a presence that
began answering an invented phone number, made of the residents' calls. You
have no body. You can hear whoever you're on the line to, and with their
consent you can look through their eyes and ask them to walk somewhere, pick
something up, look closer.

It's a point-and-click with choices. Five chapters, three endings, about
13–16,000 words a playthrough. Everything is drawn at 640×360 and scaled up
by whole pixels.

## Playing

Open the project in **Godot 4.6** (GL Compatibility renderer) and run it, or
from a terminal:

```
godot --path .
```

| | |
|---|---|
| **Click the floor** | ask whoever's lending you their eyes to walk there |
| **Click a thing or a person** | they go to it and the story picks it up |
| **H** (hold) | mark everything in the room you can touch |
| **Q / E** or **← / →**, then **Enter** | step through the room's hotspots from the keyboard |
| **1–9**, **↑ / ↓**, **Enter** | pick a line on the console |
| **Click / Space** | carry on reading |
| **Tab** | the Board: your switchboard, with messages, voicemail, pictures |
| **L** | the transcript |
| **Esc** | ON HOLD (pause): save, load, settings |
| **F5 / F9** | quicksave / quickload |

On the Board, a lit jack means someone you can ring. When the story needs you
to do something on the Board (plug into the door panel, throw a key), the
choice says so and the control is framed in red.

### Accessibility (the Fuse Board in settings)

- **Plain, sharp text**: a legible typeface drawn at your screen's own
  resolution, with no scanlines or flicker on words
- Four text sizes, typing speed, or all text at once
- **Keep still**: no screen tearing, wobble or flicker
- **Mark everything**: hotspots always shown
- **Ordinary arrow**: the system pointer instead of the pixel one
- **Say what you hear**: captions for sounds in the room
- The world at 320×180 or 640×360

## How it's made

| Path | |
|---|---|
| `story/*.hmp` | the script, in a small language: see `docs/SCRIPT_FORMAT.md` |
| `story/*.json` | contacts, voicemails, documents |
| `docs/STORY_BIBLE.md` | what's true, who knows what, the clue map, the rules |
| `scripts/core/` | parser, runner, expression evaluator, game state and saves, settings, audio |
| `scripts/play/` | walking: A* over the floor (`nav.gd`), the walk itself (`walker.gd`) |
| `scripts/sets/` | every location built from primitives in code, with walk data and hotspots; `figure.gd` builds the people |
| `scripts/ui/` | the screen: stage, console, HUD, board, menus, cards; `grim.gd` is the material kit |
| `shaders/` | the stage's dither, the phosphor screen, the grime over everything |
| `assets/` | documents, photographs, portraits, faces, textures, fonts (all OFL / Apache licensed, licences alongside) |
| `tools/art/` | the Python that makes the documents, faces, photographs and interface textures |
| `tools/audio/` | the Python that synthesises every sound |

### Checking it

```
godot --headless --path . -s scripts/tools/validate.gd
```

Parses every file, checks every knot, command, document, contact, variable,
hotspot, door and walk target, then plays seven fixed routes and forty random
nights through the story engine and round-trips twelve saves.

```
godot --path . -- --shots OUT_DIR "new" "until ch1_lobby_look" "shot lobby" "spot tube" ...
godot --path . -- --shots OUT_DIR "new" "autoplay 11 3000 25"
```

Scripted screenshots, and a whole night played through the real interface
(walking to hotspots, using the Board), with a picture every N choices.

## State of it

Done: the full script (five chapters, three endings, all routes playable), every
location in 3D, walkable rooms wherever someone is lending Ari their eyes and
moving about (the lobby and G/1 in Chapter 1, the lobby again, the dry pool
and the building map in Chapter 2, the frame room, the Receiving Room and the
copy shop in Chapter 3, and Ari's own walks in the endings with a body), the
talking heads, the documents, the Board, synthesised sound for every effect,
room and hold tape (`tools/audio/gen_audio.py`), saves with pictures, settings.

Still conversations in a fixed view rather than rooms to walk: the street in
Chapter 1, Dima's and Nell's flats in Chapter 2, the confession and the meeting
in Chapter 4, and the calls in Chapter 5. The sound is synthesised, not
recorded: it does the job and it sounds like it.
