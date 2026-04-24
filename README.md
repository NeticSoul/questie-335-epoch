# Questie-Epoch (3.3.5a)

Hybrid Questie build for **Project Epoch** on the 3.3.5a (WotLK 12340) client. It combines:

- [Aldori15/Questie (335 branch)](https://github.com/Aldori15/Questie) &mdash; the WotLK 3.3.5a port of the Classic Questie addon.
- [Bennylavaa/pfQuest-epoch](https://github.com/Bennylavaa/pfQuest-epoch) &mdash; the pfQuest database of Project Epoch custom content (new NPCs, objects, items and quests).

The pfQuest-epoch data is translated into Questie's native schema at load time and merged into the base Wrath database, so Project Epoch's custom quests show up on the world map, minimap, tracker and tooltips the same way Blizzard quests do.

> [!WARNING]
> **Highly experimental.** The pfQuest-epoch dataset is incomplete and evolves quickly, and the runtime translation layer has not seen extensive testing. Expect missing coords, wrong pre-quest chains, misplaced icons, occasional lua errors and other rough edges. **Use at your own risk.** If you find bugs please open an issue &mdash; but please do not bother the upstream Questie or pfQuest-epoch maintainers with problems that only exist in this fork.

---

## Credits

All heavy lifting belongs to the upstream projects. This repository only glues them together.

| Project | Author(s) | License |
| --- | --- | --- |
| [Questie](https://github.com/Questie/Questie) | The Questie Team | GPL-3.0 |
| [Questie 3.3.5a port](https://github.com/Aldori15/Questie) | Aldori15 and contributors | GPL-3.0 |
| [pfQuest-epoch database](https://github.com/Bennylavaa/pfQuest-epoch) | Bennylavaa and contributors | MIT |
| [pfQuest](https://github.com/shagu/pfQuest) | shagu and contributors | MIT |

If you enjoy this addon, please go star the upstream repos &mdash; they did the actual work.

---

## Installation

1. Download this repository as a zip.
2. Extract it into `Interface/AddOns/`, rename the folder to **`Questie-335`**.
3. Launch the 3.3.5a client. On first login Questie will print *"Questie DB has updated!"* and recompile. After a few seconds you should see a line like
   `[Questie-Epoch] added N quests, N NPCs, N objects, N items.`
4. Enjoy.

### If you had Questie installed before

After replacing the folder, force a recompile once:

```
/run Questie.db.global.dbIsCompiled=false; ReloadUI()
```

or, if icons still look wrong, reset the saved variables of Questie in your WTF folder.

---

## How the Epoch integration works

- `epoch/data/` &mdash; raw pfQuest-epoch data tables (units, objects, items, quests).
- `epoch/enUS/` &mdash; enUS names / titles / descriptions from pfQuest-epoch.
- `Database/Epoch/EpochPreamble.lua` &mdash; bootstraps the `pfDB` global that the raw files populate.
- `Database/Epoch/EpochDB.lua` &mdash; translates pfDB into Questie's native schema (`startedBy`, `finishedBy`, `objectives`, `spawns`, `requiredRaces`, &hellip;) **without overwriting** any existing WotLK entry, then frees the temporary pfDB global.

The merge happens inside Questie's normal init flow, right between `LoadBaseDB` and `QuestieCorrections:Initialize`, so all Questie features (tracker, tooltips, waypoints, journey log, search) work on Epoch quests too.

Questie's schema version was bumped so existing installs recompile once on first launch.

---

## Known limitations

- Only entries **absent** from the base WotLK DB are added. Epoch overrides of existing vanilla/TBC/WotLK quests are currently ignored.
- Quest descriptions rely on `questDescription` fallbacks and may be auto-generated when pfQuest-epoch has no text.
- `requiredSkill`, reputations and many flags are only partially mapped &mdash; some quests may appear as available when they actually aren't.
- No localization beyond **enUS** for Epoch content (base Questie translations are unaffected).

---

## Reporting bugs

When opening an issue please include:

1. The exact **QuestID** (hover a map icon with Shift).
2. A screenshot of the map / tooltip.
3. The Lua error text (enable with `/console scriptErrors 1`).
4. Whether the bug reproduces on upstream [Aldori15/Questie](https://github.com/Aldori15/Questie) *without* the Epoch patch &mdash; if yes, report it upstream instead.

---

# Upstream Questie documentation

Everything below is inherited from upstream Questie and applies here as well.

## Questie Information

[![Discord](https://img.shields.io/badge/discord-Questie-738bd7)](https://discord.gg/s33MAYKeZd)
[![Stars](https://img.shields.io/github/stars/Questie/Questie)](https://img.shields.io/github/stars/Questie/Questie)

- [Frequently Asked Questions](https://github.com/Questie/Questie/wiki/FAQ)
- Come chat with the upstream team on [their Discord server](https://discord.gg/s33MAYKeZd).
- You can use the upstream [issue tracker](https://github.com/Questie/Questie/issues) for bugs that also exist in plain Questie.
- When creating an issue please follow the templated structure to speed up a possible fix.
- If you get an error message from the WoW client, please include the **complete** text or a screenshot of it in your report.
    - You need to enter `/console scriptErrors 1` once in the ingame chat for Lua error messages to be shown. You can later disable them again with `/console scriptErrors 0`.

Trust us it's (Good)!

# Features

### Show quests on map
- Show notes for quest start points, turn in points, and objectives.

![Questie Quest Givers](https://i.imgur.com/4abi5yu.png)
![Questie Complete](https://i.imgur.com/DgvBHyh.png)
![Questie Tooltip](https://i.imgur.com/uPykHKC.png)

### Quest Tracker
- Improved quest tracker:
    - Automatically tracks quests on accepting
    - Can show all 20 quests from the log (instead of default 5)
    - Left click quest to open quest log (configurable)
    - Right-click for more options, e.g.:
        - Focus quest (makes other quest icons translucent)
        - Point arrow towards objective (requires TomTom addon)

![QuestieTracker](https://user-images.githubusercontent.com/8838573/67285596-24dbab00-f4d8-11e9-9ae1-7dd6206b5e48.png)

### Quest Communication
- You can see party members quest progress on the tooltip.
- You can announce objective progress, objective complete, quest complete, quest accept, quest abandon to chat.

<img width="483" height="281" alt="image" src="https://github.com/user-attachments/assets/bed0522f-31e8-4ca1-a9fe-0927a12599df" />

### Tooltips
- Show tooltips on map notes and quest NPCs/objects.
- Holding Shift while hovering over a map icon displays more information, like quest XP.
- Show quest names on the tooltip of items that begin a quest.

<img width="707" height="160" alt="image" src="https://github.com/user-attachments/assets/d85698ba-7fdb-428c-a876-02cb8cc698f9" />

<img width="447" height="365" alt="image" src="https://github.com/user-attachments/assets/df379e3b-682c-404d-a966-c5b88d5856bf" />

#### Waypoints

- Waypoint lines for quest givers showing their pathing.
- With the TomTom addon, you can shift+left click an icon on the map to place a waypoint and navigate.

<img width="853" height="495" alt="image" src="https://github.com/user-attachments/assets/380aa249-927b-4132-aa54-3b267bbd0a2f" />

<img width="202" height="166" alt="image" src="https://github.com/user-attachments/assets/a44a1b5e-9bd0-49ae-9e27-b932050bd9f3" />

### Journey Log
- Questie records the steps of your journey in the "My Journey" window. (left-click on minimap button and select the "My Journey" tab or type `/questie journey`)

![Journey](https://user-images.githubusercontent.com/8838573/67285651-3cb32f00-f4d8-11e9-95d8-e8ceb2a8d871.png)

### Quests by Zone
- Questie lists all the quests of a zone divided between completed and available quest. Gotta complete 'em all. (left-click on minimap button (or type `/questie journey`) and select the "Quests by Zone" tab

![QuestsByZone](https://user-images.githubusercontent.com/8838573/67285665-450b6a00-f4d8-11e9-9283-325d26c7c70d.png)

### Quests by Faction
- Similarly to Quests by Zone, Questie lists all the quests of a faction divided between completed and available quest. Gotta complete 'em all. (left-click on minimap button (or type `/questie journey`) and select the "Quests by Faction" tab

### Search
- Questie's database can be searched. (left-click on minimap button (or type `/questie journey`) and select the "Advanced Search" tab

![Search](https://user-images.githubusercontent.com/8838573/67285691-4f2d6880-f4d8-11e9-8656-b3e37dce2f05.png)

### Configuration
- Extensive configuration options. (right-click on minimap button to open or type `/questie`)
