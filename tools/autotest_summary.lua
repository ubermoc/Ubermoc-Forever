-- Prints a short pass/fail summary of the auto test results in a saved variables file.
-- Usage: lua tools/autotest_summary.lua <SavedVariables/UbermocForever.lua> [label] [installed toc] [--all]
-- Exit code: 0 ok, 1 something got worse (new failure or Lua error), 2 no results yet.
local path, label, toc = arg[1], arg[2] or "", arg[3]
local all = false
for i = 1, #arg do
    if arg[i] == "--all" then all = true end
end

local function readFile(p)
    local f = p and io.open(p, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local text = readFile(path)
if not text then
    print(("%s: no saved variables file yet (%s)"):format(label, tostring(path)))
    os.exit(2)
end

-- The file is plain Lua assignments; run it in an empty environment so it can touch nothing.
local env = {}
local chunk, err
if setfenv then
    chunk, err = loadstring(text, "=savedvariables")
    if chunk then setfenv(chunk, env) end
else
    chunk, err = load(text, "=savedvariables", "t", env)
end
if not chunk then
    print(("%s: could not read the file: %s"):format(label, tostring(err)))
    os.exit(2)
end
local ok, runErr = pcall(chunk)
if not ok then
    print(("%s: could not read the file: %s"):format(label, tostring(runErr)))
    os.exit(2)
end

local db = env.UbermocForeverDB or {}
local r = db.autotestResult
if not r then
    print(("%s: no auto test results yet. In the game: /ubf autotest on, then /reload twice."):format(label))
    os.exit(2)
end

local installed
local tocText = readFile(toc)
if tocText then
    installed = tocText:match("## Version:%s*([^\r\n]+)")
end

local verdict = r.ok and "OK" or "WORSE"
print(("%s: %s  %s %s (game %s build %s), run #%d after %s at %s"):format(label, verdict, r.game or "?",
    tostring(r.version), tostring(r.gameVersion), tostring(r.build), r.seq or 0, tostring(r.trigger), tostring(r.time)))
print(("  %d passed, %d failed (%d new, %d fixed since the run before), %d Lua errors"):format(r.passed or 0,
    r.failed or 0, #(r.newFailures or {}), #(r.fixed or {}), #(r.errors or {})))
if installed and installed ~= r.version then
    print(("  NOTE: these results are from %s but %s is installed. /reload once more to get results for %s."):format(
        tostring(r.version), installed, installed))
end
local details = {}
for _, f in ipairs(r.failures or {}) do
    details[f.name] = f.detail
end
for _, name in ipairs(r.newFailures or {}) do
    local d = details[name]
    print("  NEW FAILURE: " .. name .. ((d and d ~= "") and (" (" .. d .. ")") or ""))
end
for _, name in ipairs(r.fixed or {}) do
    print("  fixed: " .. name)
end
for _, e in ipairs(r.errors or {}) do
    print("  LUA ERROR: " .. tostring(e):gsub("\n.*", ""))
end
if all then
    for _, f in ipairs(r.failures or {}) do
        print("  failing: " .. f.name .. ((f.detail ~= "") and (" (" .. f.detail .. ")") or ""))
    end
elseif (r.failed or 0) > #(r.newFailures or {}) then
    print(("  %d failures were already there last run (--all lists them)"):format(r.failed - #(r.newFailures or {})))
end
os.exit(r.ok and 0 or 1)
