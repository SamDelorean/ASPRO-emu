-- ASPRO-DIAG AP-04: eight distinct files, two phases separated by MAME restart.
-- Test-only keyboard input, all via existing MAME 0.289 ioport_field API.
-- Phase 'write': choose F1..F8, type 'a'..'h'; phase 'verify': reopen F1..F8.
local phase = assert(os.getenv("ASPRO_AP04_PHASE"), "ASPRO_AP04_PHASE missing")
assert(phase == "write" or phase == "verify", "invalid phase")
local machine = manager.machine
local screen = assert(machine.screens[":screen"], "LCD screen missing")
local ports = machine.ioport.ports
local files = {
    {"COL.13", 0x01}, -- F1
    {"COL.12", 0x01}, -- F2
    {"COL.12", 0x04}, -- F3
    {"COL.12", 0x02}, -- F4
    {"COL.11", 0x02}, -- F5
    {"COL.10", 0x02}, -- F6
    {"COL.0",  0x04}, -- F7
    {"COL.0",  0x01}, -- F8
}
local chars = {
    {"COL.14", 0x10}, -- a
    {"COL.1",  0x08}, -- b
    {"COL.12", 0x80}, -- c
    {"COL.12", 0x10}, -- d
    {"COL.12", 0x40}, -- e
    {"COL.1",  0x10}, -- f
    {"COL.1",  0x02}, -- g
    {"COL.2",  0x02}, -- h
}
local function field(spec)
    local p = assert(ports[":" .. spec[1]], "matrix port missing")
    for _, f in pairs(p.fields) do
        if f.mask == spec[2] then return f end
    end
    error("keyboard field not found " .. spec[1])
end
local fkeys, ckeys = {}, {}
for i=1,8 do
    fkeys[i] = field(files[i])
    ckeys[i] = field(chars[i])
end
local function event(t)
    local f = assert(io.open("observations.log", "a"))
    f:write("ASPRO_AP04_", phase, "_", t, "\n")
    f:close()
end
local frame, active, failed, shots = 0, nil, false, 0
local function release()
    if active then active:clear_value(); active = nil end
end
local function press(f, label)
    release()
    f:set_value(1)
    active=f
    event(label)
end
local function snapshot(i)
    local pix, width, height = screen:pixels()
    if not pix or width~=240 or height~=36 then error("invalid LCD geometry") end
    local name=string.format("f%d.png",i)
    local err=screen:snapshot(name)
    if err then error("snapshot failed " .. name) end
    shots=shots+1
    event(string.format("SNAPSHOT_F%d",i))
end
local function step()
    frame=frame+1
    if frame < 410 then return end
    for i=1,8 do
        local base=410+(i-1)*130
        if frame == base then press(fkeys[i],"KEY_F"..i.."_DOWN") end
        if frame == base+12 then release(); event("KEY_F"..i.."_UP") end
        if phase=="write" then
            if frame == base+30 then press(ckeys[i],"CHAR_"..string.char(96+i).."_DOWN") end
            if frame == base+42 then release(); event("CHAR_"..string.char(96+i).."_UP") end
        end
        if frame == base+75 then snapshot(i) end
    end
    if frame==1500 then
        release()
        if shots~=8 then error("missing file screenshots") end
        event("OBSERVATION_COMPLETE")
    end
end
emu.register_frame_done(function()
    if failed or frame>=1500 then return end
    local ok,err=pcall(step)
    if not ok then
        failed=true; pcall(release)
        event("OBSERVATION_FAILED")
    end
end)
event("LUA_ATTACHED")
