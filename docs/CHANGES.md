## v2.1.18 - 2026-11-06
- The minimap icon choice is now saved the moment you change it, even if the button was not built yet, and it is re-applied at login and after every loading screen. Another addon re-showing the button can no longer bring back an icon you hid, and a failed first setup is retried at login instead of being skipped for the whole session.

## v2.1.17 - 2026-11-06
- Fixed enemy nameplate debuffs (and classification and raid-target icons) disappearing on some nameplates after you had opened the SQP options. The options preview reuses one of the game's pooled nameplate frames and hid its aura frame with a hook that was never removed, so a live nameplate that later received that frame kept its debuffs hidden. The hook now only acts while the preview owns the frame, and the frame is handed back with its decorations shown when the preview closes.

## v2.1.16 - 2026-11-05
- Fixed the options preview showing the nameplate but no questplate until an options control was clicked: the preview now refreshes again on the next frames after it opens, once the client has laid the preview nameplate out.

## v2.1.15 - 2026-11-05
- Fixed the Minimap Icon option showing the wrong state after the icon was hidden with Ctrl+Right-click or `/sqp icon off`: the checkbox now follows the saved setting, so the next click no longer undoes it.

## v2.1.14 - 2026-11-04
- Fixed "?" showing instead of the remaining count on drop-item and uniquely named item quests. When the game marks an enemy as quest-related but its tooltip has no objective line, the plate now resolves the unfinished item objective from your quest log and shows the real count.
- Tooltip data is fully resolved before it is read, so objective lines are no longer missed on clients that defer line text.
- Retail 12.1.5 / Interface `120105` and Forever `16001` unchanged.
