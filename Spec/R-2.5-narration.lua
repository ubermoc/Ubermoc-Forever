-- R-2.5 (round-4 feedback 2026-11-13: "narrating in menus doesn't work"): when the game's screen-reader
-- setting is ON, moving the highlight must SPEAK the highlighted control's name; with it OFF nothing is
-- ever spoken. Blizzard's own narration cannot help in-game - NarrationUtil.lua:122 gates it on
-- C_Glue.IsOnGlueScreen() (login screens only) - so Nav.lua speaks through C_VoiceChat.SpeakText itself
-- (Blizzard_NarrationManager.lua:29 uses the same call). LOGIC test: ns.Speak is a plain function, no
-- frames involved; the fake world's unknown globals are stubs, so we REPLACE C_VoiceChat and GetCVar in
-- g.env with recorders. What the real voice actually says on the player's machine stays on the test list.

local function narrWorld(on)
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.spoken = {}
    g.env.GetCVar = function(name)
        if name == "accessibilityScreenNarrationEnabled" then return on and "1" or "0" end
        return nil
    end
    g.env.C_VoiceChat = { StopSpeakingText = function() g.interrupted = (g.interrupted or 0) + 1 end,
                          SpeakText = function(voice, text, rate, volume) g.spoken[#g.spoken + 1] = text end }
    return g
end

test("narration-off-silent", "R-2.5", "with the screen-reader setting OFF, nothing is ever spoken (the default must not chatter)", function()
    local g = narrWorld(false)
    g.login(true)
    g.ns.Speak("MerchantItem1")
    eq(#g.spoken, 0, "no SpeakText call while the setting is off")
end)

test("narration-on-speaks-name", "R-2.5", "with the setting ON, a control name is spoken through C_VoiceChat.SpeakText and the previous speech is interrupted first (Blizzard's own pattern, NarrationManager.lua:104)", function()
    local g = narrWorld(true)
    g.login(true)
    g.ns.Speak("Rugged Tunic")
    eq(#g.spoken, 1, "exactly one utterance")
    eq(g.spoken[1], "Rugged Tunic", "the highlighted control's own name is what is said")
    eq(g.interrupted or 0, 1, "StopSpeakingText before speaking (never queue a backlog)")
end)

test("narration-no-repeat", "R-2.5", "the same name twice in a row is NOT repeated (a held d-pad key must not stammer)", function()
    local g = narrWorld(true)
    g.login(true)
    g.ns.Speak("Trade Goods")
    g.ns.Speak("Trade Goods")
    eq(#g.spoken, 1, "one utterance only")
    g.ns.Speak("Close")
    eq(#g.spoken, 2, "a DIFFERENT name is spoken right away")
end)

test("narration-strips-colour-codes", "R-2.5", "colour codes are stripped so the voice never reads them (item names carry |c...|r)", function()
    local g = narrWorld(true)
    g.login(true)
    g.ns.Speak("|cff00ff00Worn Shortsword|r")
    eq(g.spoken[1], "Worn Shortsword", "only the plain words reach the voice")
end)

test("navdraw-speaks-focused-label", "R-2.5", "drawing the highlight speaks the FOCUSED control's label - merchant item names come from the map (Nav.lua merchantMap reads MerchantItem<N>Name)", function()
    local g = narrWorld(true)
    -- a vendor window with named items, opened through its real OnShow hook (same helper as R-2.3)
    local f = g.env.CreateFrame("Frame", "MerchantFrame")
    f.IsShown = function() return rawget(f, "__shown") and true or false end
    -- the item NAME fontstrings merchantMap reads for labels: give them real text (the fake world's stubs
    -- would return a stub table, not a string - this test must prove the label path carries TEXT).
    for i = 1, 12 do
        local n = g.env.CreateFrame("Frame", "MerchantItem" .. i .. "Name")
        n.SetText = function(self, t) rawset(n, "__text", t) end
        n.GetText = function(self) return rawget(n, "__text") end
        n:SetText("Item Number " .. i)
    end
    g.login(true)
    local shown = { MerchantItem1ItemButton = true, MerchantItem2ItemButton = true }
    g.env.UbermocForeverNavProbe = function(id) return shown[id] and true or false end
    g.show(g.env.MerchantFrame)   -- NavOpen -> NavDraw: the highlight lands on control 1
    eq(#g.spoken, 1, "opening a window speaks the first highlighted control")
    eq(g.spoken[1], "Item Number 1", "the item's own name from its Name fontstring is what is spoken")
end)
