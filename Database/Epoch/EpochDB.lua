-- Questie-Epoch: Integration module
--
-- Translates the pfQuest-epoch database (loaded into the global pfDB table by
-- the raw files embedded via the .toc) into native Questie tables *before* the
-- database gets compiled into its binary form.
--
-- Strategy: only ADD new records that do not already exist in Questie's own
-- database. We never overwrite existing quest / NPC / object / item data.
-- For every Epoch quest that is added, we wire its start/end references into
-- the corresponding NPC / object / item records (even if those were already
-- present in Questie's vanilla data) so that the quest is actually pickable.

---@class EpochDB
local EpochDB = QuestieLoader:CreateModule("EpochDB")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

local _Integrated = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function copyList(src)
    if type(src) ~= "table" then return nil end
    local out = {}
    for i = 1, #src do out[i] = src[i] end
    return out
end

local function addUnique(list, value)
    for i = 1, #list do
        if list[i] == value then return end
    end
    list[#list + 1] = value
end

-- pfQuest coord format: { x, y, zoneID, respawn }
-- Questie format:       { [zoneID] = { {x, y}, ... } }
local function convertCoords(coords)
    if type(coords) ~= "table" then return nil end
    local spawns
    for i = 1, #coords do
        local c = coords[i]
        if type(c) == "table" then
            local x, y, zone = c[1], c[2], c[3]
            if x and y and zone and zone > 0 then
                if not spawns then spawns = {} end
                local list = spawns[zone]
                if not list then
                    list = {}
                    spawns[zone] = list
                end
                list[#list + 1] = { x, y }
            end
        end
    end
    return spawns
end

local function pickMainZone(spawns)
    if type(spawns) ~= "table" then return nil end
    local bestZone, bestCount = nil, 0
    for zone, list in pairs(spawns) do
        local n = #list
        if n > bestCount then
            bestCount = n
            bestZone = zone
        end
    end
    return bestZone
end

-- pfQuest lvl can be: number, "10", "6-7", "-1" (scaling)
local function parseLevelRange(lvl)
    if type(lvl) == "number" then return lvl, lvl end
    if type(lvl) == "string" then
        local a, b = string.match(lvl, "^(%-?%d+)%-(%-?%d+)$")
        if a then return tonumber(a), tonumber(b) end
        local n = tonumber(lvl)
        if n then return n, n end
    end
    return 0, 0
end

local function toInt(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) end
    return nil
end

-- Translate pfQuest's 'fac' ("A" / "H" / "AH") into Questie's friendlyToFaction
local function translateFaction(fac)
    if fac == "A" or fac == "H" or fac == "AH" then return fac end
    if fac == "HA" then return "AH" end
    return nil
end

-- ---------------------------------------------------------------------------
-- Core integration
-- ---------------------------------------------------------------------------

function EpochDB:IsLoaded()
    return _Integrated
end

function EpochDB:Integrate()
    if _Integrated then return end
    if type(_G.pfDB) ~= "table" then return end

    local pfDB = _G.pfDB

    -- Nothing to do if we didn't receive any Epoch data.
    if not pfDB.quests or not pfDB.quests["data-epoch"] then
        _G.pfDB = nil
        _Integrated = true
        return
    end

    -- QuestieDB tables must already have been loaded (string -> table).
    if type(QuestieDB.questData) ~= "table"
       or type(QuestieDB.npcData) ~= "table"
       or type(QuestieDB.objectData) ~= "table"
       or type(QuestieDB.itemData) ~= "table" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[EpochDB] Base DB not loaded yet - aborting Epoch integration.")
        return
    end

    local qKeys = QuestieDB.questKeys
    local nKeys = QuestieDB.npcKeys
    local oKeys = QuestieDB.objectKeys
    local iKeys = QuestieDB.itemKeys

    local unitData   = pfDB.units   and pfDB.units["data-epoch"]  or {}
    local unitNames  = pfDB.units   and pfDB.units["enUS-epoch"]  or {}
    local objData    = pfDB.objects and pfDB.objects["data-epoch"] or {}
    local objNames   = pfDB.objects and pfDB.objects["enUS-epoch"] or {}
    local itemData   = pfDB.items   and pfDB.items["data-epoch"]   or {}
    local itemNames  = pfDB.items   and pfDB.items["enUS-epoch"]   or {}
    local questData  = pfDB.quests  and pfDB.quests["data-epoch"]  or {}
    local questNames = pfDB.quests  and pfDB.quests["enUS-epoch"]  or {}

    local npcAdded, objAdded, itemAdded, questAdded = 0, 0, 0, 0

    -- -----------------------------------------------------------------------
    -- 1. NPCs (units)
    -- -----------------------------------------------------------------------
    for id, entry in pairs(unitData) do
        local numericId = toInt(id)
        if numericId and QuestieDB.npcData[numericId] == nil and type(entry) == "table" then
            local name = unitNames[numericId] or ("Epoch NPC " .. numericId)
            local spawns = convertCoords(entry.coords)
            local minL, maxL = parseLevelRange(entry.lvl)

            local npc = {}
            npc[nKeys.name]           = name
            npc[nKeys.minLevelHealth] = 0
            npc[nKeys.maxLevelHealth] = 0
            npc[nKeys.minLevel]       = minL or 0
            npc[nKeys.maxLevel]       = maxL or 0
            npc[nKeys.rank]           = toInt(entry.rnk) or 0
            if spawns then npc[nKeys.spawns] = spawns end
            npc[nKeys.zoneID]         = pickMainZone(spawns) or 0
            local friendly = translateFaction(entry.fac)
            if friendly then npc[nKeys.friendlyToFaction] = friendly end

            QuestieDB.npcData[numericId] = npc
            npcAdded = npcAdded + 1
        end
    end

    -- -----------------------------------------------------------------------
    -- 2. Objects
    -- -----------------------------------------------------------------------
    for id, entry in pairs(objData) do
        local numericId = toInt(id)
        if numericId and QuestieDB.objectData[numericId] == nil and type(entry) == "table" then
            local name = objNames[numericId] or ("Epoch Object " .. numericId)
            local spawns = convertCoords(entry.coords)

            local obj = {}
            obj[oKeys.name]   = name
            if spawns then obj[oKeys.spawns] = spawns end
            obj[oKeys.zoneID] = pickMainZone(spawns) or 0

            QuestieDB.objectData[numericId] = obj
            objAdded = objAdded + 1
        end
    end

    -- -----------------------------------------------------------------------
    -- 3. Items
    -- -----------------------------------------------------------------------
    for id, entry in pairs(itemData) do
        local numericId = toInt(id)
        if numericId and QuestieDB.itemData[numericId] == nil and type(entry) == "table" then
            local name = itemNames[numericId] or ("Epoch Item " .. numericId)
            local it = {}
            it[iKeys.name] = name

            if type(entry.U) == "table" then
                local drops = {}
                for npcId in pairs(entry.U) do
                    local nid = toInt(npcId)
                    if nid then drops[#drops + 1] = nid end
                end
                if #drops > 0 then it[iKeys.npcDrops] = drops end
            end
            if type(entry.O) == "table" then
                local drops = {}
                for objId in pairs(entry.O) do
                    local oid = toInt(objId)
                    if oid then drops[#drops + 1] = oid end
                end
                if #drops > 0 then it[iKeys.objectDrops] = drops end
            end
            if type(entry.V) == "table" then
                local vendors = {}
                for npcId in pairs(entry.V) do
                    local nid = toInt(npcId)
                    if nid then vendors[#vendors + 1] = nid end
                end
                if #vendors > 0 then it[iKeys.vendors] = vendors end
            end

            QuestieDB.itemData[numericId] = it
            itemAdded = itemAdded + 1
        end
    end

    -- -----------------------------------------------------------------------
    -- 4. Quests
    -- -----------------------------------------------------------------------
    for id, entry in pairs(questData) do
        local numericId = toInt(id)
        if numericId and QuestieDB.questData[numericId] == nil and type(entry) == "table" then
            local loc = questNames[numericId] or {}
            local q = {}

            q[qKeys.name]            = loc.T or ("Epoch Quest " .. numericId)
            q[qKeys.questLevel]      = toInt(entry.lvl) or 0
            q[qKeys.requiredLevel]   = toInt(entry.min) or toInt(entry.lvl) or 0
            q[qKeys.requiredRaces]   = toInt(entry.race)  or 0
            q[qKeys.requiredClasses] = toInt(entry.class) or 0

            -- startedBy: { creatureStart, objectStart, itemStart }
            if type(entry.start) == "table" then
                local sb = {}
                if type(entry.start.U) == "table" then sb[1] = copyList(entry.start.U) end
                if type(entry.start.O) == "table" then sb[2] = copyList(entry.start.O) end
                if type(entry.start.I) == "table" then sb[3] = copyList(entry.start.I) end
                if next(sb) ~= nil then q[qKeys.startedBy] = sb end
            end

            -- finishedBy: { creatureEnd, objectEnd }
            if type(entry["end"]) == "table" then
                local fb = {}
                if type(entry["end"].U) == "table" then fb[1] = copyList(entry["end"].U) end
                if type(entry["end"].O) == "table" then fb[2] = copyList(entry["end"].O) end
                if next(fb) ~= nil then q[qKeys.finishedBy] = fb end
            end

            -- objectives: { creatureObjective, objectObjective, itemObjective }
            if type(entry.obj) == "table" then
                local obs = {}
                if type(entry.obj.U) == "table" then
                    local arr = {}
                    for i = 1, #entry.obj.U do arr[i] = { entry.obj.U[i] } end
                    obs[1] = arr
                end
                if type(entry.obj.O) == "table" then
                    local arr = {}
                    for i = 1, #entry.obj.O do arr[i] = { entry.obj.O[i] } end
                    obs[2] = arr
                end
                if type(entry.obj.I) == "table" then
                    local arr = {}
                    for i = 1, #entry.obj.I do arr[i] = { entry.obj.I[i] } end
                    obs[3] = arr
                end
                if next(obs) ~= nil then q[qKeys.objectives] = obs end

                -- IR = required (source) items the player must carry but are not
                -- the kill / collect objective.
                if type(entry.obj.IR) == "table" then
                    q[qKeys.requiredSourceItems] = copyList(entry.obj.IR)
                end
            end

            if type(entry.pre) == "table" then
                q[qKeys.preQuestSingle] = copyList(entry.pre)
            end

            if type(entry.close) == "table" then
                q[qKeys.exclusiveTo] = copyList(entry.close)
            end

            if entry["next"] then
                q[qKeys.nextQuestInChain] = toInt(entry["next"])
            end

            if entry.skill then
                local s = toInt(entry.skill)
                if s then
                    q[qKeys.requiredSkill] = { s, toInt(entry.skillmin) or 1 }
                end
            end

            if loc.O then
                q[qKeys.objectivesText] = { loc.O }
            end

            QuestieDB.questData[numericId] = q
            questAdded = questAdded + 1
        end
    end

    -- -----------------------------------------------------------------------
    -- 5. Wire start / end references into NPC / object / item records
    -- -----------------------------------------------------------------------
    for id, entry in pairs(questData) do
        local qid = toInt(id)
        if qid and QuestieDB.questData[qid] and type(entry) == "table" then

            if type(entry.start) == "table" then
                if type(entry.start.U) == "table" then
                    for i = 1, #entry.start.U do
                        local uid = toInt(entry.start.U[i])
                        local n = uid and QuestieDB.npcData[uid]
                        if n then
                            local qs = n[nKeys.questStarts]
                            if not qs then
                                qs = {}
                                n[nKeys.questStarts] = qs
                            end
                            addUnique(qs, qid)
                        end
                    end
                end
                if type(entry.start.O) == "table" then
                    for i = 1, #entry.start.O do
                        local oid = toInt(entry.start.O[i])
                        local o = oid and QuestieDB.objectData[oid]
                        if o then
                            local qs = o[oKeys.questStarts]
                            if not qs then
                                qs = {}
                                o[oKeys.questStarts] = qs
                            end
                            addUnique(qs, qid)
                        end
                    end
                end
                if type(entry.start.I) == "table" then
                    for i = 1, #entry.start.I do
                        local iid = toInt(entry.start.I[i])
                        local it = iid and QuestieDB.itemData[iid]
                        if it and not it[iKeys.startQuest] then
                            it[iKeys.startQuest] = qid
                        end
                    end
                end
            end

            if type(entry["end"]) == "table" then
                if type(entry["end"].U) == "table" then
                    for i = 1, #entry["end"].U do
                        local uid = toInt(entry["end"].U[i])
                        local n = uid and QuestieDB.npcData[uid]
                        if n then
                            local qs = n[nKeys.questEnds]
                            if not qs then
                                qs = {}
                                n[nKeys.questEnds] = qs
                            end
                            addUnique(qs, qid)
                        end
                    end
                end
                if type(entry["end"].O) == "table" then
                    for i = 1, #entry["end"].O do
                        local oid = toInt(entry["end"].O[i])
                        local o = oid and QuestieDB.objectData[oid]
                        if o then
                            local qs = o[oKeys.questEnds]
                            if not qs then
                                qs = {}
                                o[oKeys.questEnds] = qs
                            end
                            addUnique(qs, qid)
                        end
                    end
                end
            end
        end
    end

    -- -----------------------------------------------------------------------
    -- 6. Derive a zoneOrSort for quests where we didn't have one (use the
    --    main spawn zone of the first start NPC / object).
    -- -----------------------------------------------------------------------
    for id, entry in pairs(questData) do
        local qid = toInt(id)
        local q = qid and QuestieDB.questData[qid]
        if q and (not q[qKeys.zoneOrSort] or q[qKeys.zoneOrSort] == 0) and type(entry) == "table" then
            local zone
            if type(entry.start) == "table" then
                if type(entry.start.U) == "table" and entry.start.U[1] then
                    local n = QuestieDB.npcData[toInt(entry.start.U[1])]
                    if n and n[nKeys.zoneID] and n[nKeys.zoneID] > 0 then
                        zone = n[nKeys.zoneID]
                    end
                end
                if (not zone) and type(entry.start.O) == "table" and entry.start.O[1] then
                    local o = QuestieDB.objectData[toInt(entry.start.O[1])]
                    if o and o[oKeys.zoneID] and o[oKeys.zoneID] > 0 then
                        zone = o[oKeys.zoneID]
                    end
                end
            end
            if zone then
                q[qKeys.zoneOrSort] = zone
            end
        end
    end

    -- Free the temporary global before the DB is compiled.
    _G.pfDB = nil
    _Integrated = true

    if Questie and Questie.Debug then
        Questie:Debug(Questie.DEBUG_INFO,
            string.format("[EpochDB] +%d quests, +%d NPCs, +%d objects, +%d items",
                          questAdded, npcAdded, objAdded, itemAdded))
    end
    print(string.format("|cFF4DDBFF[Questie-Epoch]|r added %d quests, %d NPCs, %d objects, %d items.",
                        questAdded, npcAdded, objAdded, itemAdded))
end
