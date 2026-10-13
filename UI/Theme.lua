-- Theme.lua: the Lodestar-style palette. Navy panels, a violet accent, gold for BiS.
local _, SG = ...
if type(SG) ~= "table" then
    SG = _G.Stratagem or {}
    _G.Stratagem = SG
end

SG.Theme = {
    bg        = { 0.035, 0.040, 0.062, 0.97 },
    sidebar   = { 0.024, 0.027, 0.042, 0.98 },
    panel     = { 0.055, 0.060, 0.090, 0.96 },
    inset     = { 0.08, 0.085, 0.12, 1 },
    line      = { 0.42, 0.36, 0.62, 0.65 },
    lineSoft  = { 1, 1, 1, 0.06 },
    accent    = { 0.56, 0.40, 0.95, 1 },
    accentHot = { 0.68, 0.52, 1, 1 },
    gold      = { 0.93, 0.78, 0.45, 1 },
    text      = { 0.93, 0.94, 0.97, 1 },
    muted     = { 0.62, 0.64, 0.73, 1 },
    dim       = { 0.42, 0.44, 0.52, 1 },
    good      = { 0.45, 0.80, 0.55, 1 },
    row       = { 0.07, 0.075, 0.11, 0.55 },
    rowHot    = { 0.16, 0.13, 0.26, 0.95 },
    rowOn     = { 0.22, 0.16, 0.36, 0.98 },
    danger    = { 0.75, 0.32, 0.32, 1 },
}

SG.CATEGORIES = {
    { id = "leveling",     name = "Leveling",     icon = "cat_leveling.tga" },
    { id = "professions",  name = "Professions",  icon = "cat_professions.tga" },
    { id = "reputation",   name = "Reputation",   icon = "cat_reputation.tga" },
    { id = "exploration",  name = "Exploration",  icon = "cat_exploration.tga" },
    { id = "legacy",       name = "Legacy",       icon = "cat_legacy.tga" },
    { id = "collectibles", name = "Collectibles", icon = "cat_collectibles.tga" },
    { id = "dungeons",     name = "Dungeons",     icon = "cat_dungeons.tga" },
    { id = "favorites",    name = "Favorites",    icon = "cat_favorites.tga" },
    { id = "bis",          name = "Level 60 BiS", icon = "cat_collectibles.tga" },
    { id = "attune",       name = "Attunements",  icon = "cat_dungeons.tga" },
    { id = "options",      name = "Options",      icon = "cat_options.tga" },
}
