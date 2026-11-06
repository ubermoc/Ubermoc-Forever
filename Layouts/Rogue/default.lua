-- Layout: Rogue (default gamepad layout, checkpoint 5)
--
-- Layouts are Lua data files loaded from the .toc — WoW addons cannot read
-- JSON. This file is loaded before Input/Layout.lua reads it on PLAYER_LOGIN
-- (Core/Init.lua calls ns.Layout.Load).
--
-- Spell IDs are verified in the forever branch,
-- Blizzard_CooldownBroadcaster/TrackedCooldowns.lua:
--   spec IDs: 259 Assassination, 260 Outlaw, 261 Subtlety
--   360194 Deathmark, 13750 Adrenaline Rush, 51690 Killing Spree,
--   121471 Shadow Blades, 185313 Shadow Dance,
--   31224 Cloak of Shadows, 5277 Evasion, 1856 Vanish, 2094 Blind, 1766 Kick
-- No other spell IDs are used: they are not listed in this branch's data,
-- and unverified IDs must not be guessed. The loader keeps only spells the
-- character knows (C_Spell.GetSpellInfo, verified in Blizzard_BoostTutorial)
-- and stores the result in ns.db.layout.spells, so a wrong ID can never
-- reach a binding.
--
-- Three-bar template per spec: primary (the active bar), secondary
-- (shoulder-accessed), tertiary (optional utility).

local _, ns = ...

ns.LAYOUTS = ns.LAYOUTS or {}

ns.LAYOUTS.Rogue = {
    class = "Rogue",
    -- Show only the currently active bar (spec 5.4 default: on).
    show_only_active_bar = true,

    -- Keyed by spec ID (C_SpecializationInfo.GetSpecialization, verified in
    -- Blizzard_ClickBindingUI / Blizzard_AzeriteUI).
    specs = {
        [259] = {
            label = "Assassination",
            primary = {
                360194, -- Deathmark
                1766,   -- Kick
                5277,   -- Evasion
            },
            secondary = {
                31224,  -- Cloak of Shadows
                1856,   -- Vanish
                2094,   -- Blind
            },
            tertiary = {},
        },
        [260] = {
            label = "Outlaw",
            primary = {
                13750,  -- Adrenaline Rush
                51690,  -- Killing Spree
                1766,   -- Kick
            },
            secondary = {
                5277,   -- Evasion
                31224,  -- Cloak of Shadows
                1856,   -- Vanish
                2094,   -- Blind
            },
            tertiary = {},
        },
        [261] = {
            label = "Subtlety",
            primary = {
                121471, -- Shadow Blades
                185313, -- Shadow Dance
                1766,   -- Kick
            },
            secondary = {
                5277,   -- Evasion
                31224,  -- Cloak of Shadows
                1856,   -- Vanish
                2094,   -- Blind
            },
            tertiary = {},
        },
    },
}
