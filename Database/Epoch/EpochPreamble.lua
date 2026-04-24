-- Questie-Epoch: Preamble
-- Creates the pfDB global that the embedded pfQuest-epoch raw data files populate.
-- The data files are loaded right after this file via the .toc. EpochDB.lua reads
-- pfDB after load and translates it into native Questie tables, then clears it.

if type(_G.pfDB) ~= "table" then
    _G.pfDB = {}
end

local pfDB = _G.pfDB
pfDB.quests      = pfDB.quests      or {}
pfDB.units       = pfDB.units       or {}
pfDB.objects     = pfDB.objects     or {}
pfDB.items       = pfDB.items       or {}
pfDB.zones       = pfDB.zones       or {}
pfDB.areatrigger = pfDB.areatrigger or {}
pfDB.refloot     = pfDB.refloot     or {}
pfDB.minimap     = pfDB.minimap     or {}
pfDB.professions = pfDB.professions or {}
pfDB.meta        = pfDB.meta        or {}
