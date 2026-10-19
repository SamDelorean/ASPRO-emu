-- Host-only observation using the pinned MAME Lua interfaces, not a CPU/LCD model.
local machine = manager.machine
local screen = machine.screens[":screen"]
local port = machine.ioport.ports[":COL.14"]
local key = nil
if port then
    for _, field in pairs(port.fields) do
        if field.mask == 0x10 then key = field; break end
    end
end
local frame, before, pressed = 0, nil, false
local capture = os.getenv("ASPRO_CAPTURE") == "1"
local failed = false
local function event(tag)
    local f = assert(io.open("observations.log", "a"))
    f:write("ASPRO_", tag, "\n"); f:close()
end
local function snapshot(name)
    if not capture then event("SNAPSHOT_PENDING"); return end
    local err = screen:snapshot(name .. ".png")
    if err then error("snapshot interface failed") end
    event("SNAPSHOT_" .. name)
end
local function observe()
    frame = frame + 1
    if frame == 150 then
        if not screen or not key then error("screen or COL.14/A field absent") end
        local w, h
        before, w, h = screen:pixels()
        if w ~= 240 or h ~= 36 then error("unexpected LCD dimensions") end
        local first = before:sub(1,4)
        local varied = false
        for i=5,#before,4 do
            if before:sub(i,i+3) ~= first then varied = true; break end
        end
        event(varied and "LCD_NONUNIFORM" or "LCD_UNIFORM")
        snapshot("before")
    elseif frame == 180 then
        key:set_value(1); pressed = true; event("KEY_DOWN_A")
    elseif frame == 190 then
        key:clear_value(); pressed = false; event("KEY_UP_A")
    elseif frame == 240 then
        local after = screen:pixels()
        event(after ~= before and "LCD_CHANGED_AFTER_KEY" or "LCD_UNCHANGED_AFTER_KEY")
        snapshot("after")
        -- A changed frame may also be a cursor/startup update. No functional
        -- keyboard PASS or interpreted text is inferred from this comparison.
        event("OBSERVATION_COMPLETE")
    end
end
emu.register_frame_done(function()
    if failed or frame >= 240 then return end
    local ok = pcall(observe)
    if not ok then
        failed = true
        if pressed and key then pcall(function() key:clear_value() end) end
        event("LUA_OBSERVATION_FAILED")
    end
end)
event("LUA_ATTACHED")
