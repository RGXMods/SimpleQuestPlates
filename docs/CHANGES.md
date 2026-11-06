## v2.1.16 - 2026-11-05
- Fixed the options preview showing the nameplate but no questplate until an options control was clicked: the preview now refreshes again on the next frames after it opens, once the client has laid the preview nameplate out.

## v2.1.15 - 2026-11-05
- Fixed the Minimap Icon option showing the wrong state after the icon was hidden with Ctrl+Right-click or `/sqp icon off`: the checkbox now follows the saved setting, so the next click no longer undoes it.

## v2.1.14 - 2026-11-04
- Fixed "?" showing instead of the remaining count on drop-item and uniquely named item quests. When the game marks an enemy as quest-related but its tooltip has no objective line, the plate now resolves the unfinished item objective from your quest log and shows the real count.
- Tooltip data is fully resolved before it is read, so objective lines are no longer missed on clients that defer line text.
- Retail 12.1.5 / Interface `120105` and Forever `16001` unchanged.
