# The .hmp script format

Story files live in `story/` and are read in filename order. Each is a list of
knots. `scripts/core/story_parser.gd` compiles them; `scripts/core/story_runner.gd`
runs them; `scripts/tools/validate.gd` checks them.

## Lines

```
=== knot_name              start a knot
JAD: Can you hear me?      dialogue (speaker in capitals)
plain text                 narration
SOUND: Relays.             a sound that carries information (always captioned)
THINK: That's for me.      a thought that arrives on its own
KAYE> Dear Ari, ...        a message that comes out of the printer
# comment
```

## Choices

```
* [look][spot:notice] {k_seen} The notice on the board.
    ...indented block runs when chosen...
    -> knot
+ [go][spot:corridor] The corridor.     sticky: offered every time
* "Yes."                                quoted: Ari says it aloud
```

Tags in square brackets come first, then an optional `{condition}`, then the
text. Tags that matter:

| Tag | Effect |
|---|---|
| `look`, `listen`, `ask`, `read`, `go`, `use`, `dial`, ... | the pointer shown on hover |
| `spot:NAME` | the choice lives in the room: hotspot NAME in the current set (walk mode), or a screen rectangle from `@spot NAME` (close-ups) |
| `jack:WHO`, `key:NAME` | the choice is done on the board: picking it opens the board with that jack or key framed in red |

## Flow and state

```
-> knot          divert        ->> knot    call (comes back)      return
~ var = expr     assignment (=, +=, -=)
if cond: / elif cond: / else:   indented blocks
```

Every variable the story reads is given a starting value in `init_vars`
(`story/00_init.hmp`). The validator fails on any that aren't.

## Walking

A set with a floor (`add_floor` in its script) can be walked. While a walk is
on, the choices tagged `spot:NAME` become things in the room; the rest stay on
the console.

```
@walk jad street_door        hand Jad to the player at the door named street_door
@walk ari corridor_mouth down  walk as Ari (arms down, no phone)
@walk none                   click things in the set, nobody walks (the building map)
@walk off                    nobody walks; the camera is the story's again
@walkto inez casio           the story walks someone to a hotspot or door (waits)
@place jad middle            put someone there at once
```

A `@cam NAME` while walking is a cutaway: the next choices that live in the
room bring the walking camera back.

In a set script:

```
add_floor(Rect2(x, z, width, depth))
add_block(center_x, center_z, width, depth)       furniture people walk round
add_entry("door", position, rot_y)                where people come in
add_hotspot("notice", center, size, stand, "The notice", "read", face)
person_spot("teodor", figure_node, "Teodor")
set_actor("jad", figure_node)                     the figure to walk, if the set built one
walk_cam = {"offset": ..., "look": ..., "fov": 50, "min": ..., "max": ...}
```

Hotspot and door names must be literal strings: the validator reads them from
the set's source to check every `spot:`, `@walk` door and `@walkto` target.

## Presentation

| Command | |
|---|---|
| `@comp black/room/call/exchange` | composition: text only, a room, a call, Ari's monitor bank |
| `@set NAME [variant]`, `@cam NAME`, `@state KEY VALUE` | the 3D set, its camera, its states |
| `@view WHO` / `@view none` / `@view plan` | whose eyes; heard not seen; the plan |
| `@xwin SLOT KIND ARG LABEL` | a monitor in the exchange composition |
| `@time 23:24`, `@chapter N "Title"`, `@drift FROM TO`, `@rupture`, `@fade in/out` | time and cards |
| `@show_doc ID`, `@gallery_add ID` | documents (from `story/documents.json`) |
| `@spot NAME x y w h`, `@spots_clear` | screen-space hotspots for close-ups (fractions of the screen) |
| `@portrait WHO EXPR` | the talking head's expression |
| `@collage on/off`, `@collage_add IMAGE x y scale deg` | expectations pinned over the room |
| `@amb`, `@amb2`, `@music`, `@sfx ID [db]`, `@acoustic` | sound |
| `@input_name VAR "prompt"`, `@casio`, `@ending ID "Title"`, `@wait S` | blocking moments |

## The board

`@call WHO`, `@hangup`, `@ring WHO|off`, `@hold on|off`, `@callable WHO KNOT|off`,
`@avail WHO on|off "reason"`, `@contact_add WHO`, `@text WHO "..."`, `@sent WHO "..."`,
`@text_doc WHO DOC "caption"`, `@reply WHO KNOT "prompt"`, `@reply_clear WHO`,
`@vm_add ID`, `@vm_mark ID`, `@vm_archive_open`, `@saved_as WHO "name"`,
`@board open|close|thread WHO|strip WHO`, `@board_lock on|off`.
