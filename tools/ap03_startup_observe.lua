-- AP-03: observe Pro boot progression 8/16/24/27 seconds and inject A at 27.6s.
-- Uses existing MAME 0.289 Lua surfaces, no hardware model or firmware edits.
-- This script is selected only for --seconds >=20, using ASPRO-DIAG.
local machine = manager.machine
local screen = machine.screens[":screen"]
local port = machine.ioport.ports[":COL.14"]
local key
if port then
    for _, field in pairs(port.fields) do
        if field.mask == 0x10 then key = field; break end
    end
end
local frame, previous, before, pressed, failed = 0, nil, nil, false, false

local function event(tag)
    local f = assert(io.open("observations.log", "a"))
    f:write("ASPRO_", tag, "\n")
    f:close()
end

local function capture(label)
    if not screen then error("no screen device") end
    local pix, width, height = screen:pixels()
    if width ~= 240 or height ~= 36 then error("screen geometry mismatch") end
    if previous then
        event(pix == previous and "SCREEN_SAME_" .. label or "SCREEN_CHANGED_" .. label)
    end
    previous = pix
    if os.getenv("ASPRO_CAPTURE") == "1" then
        local err = screen:snapshot(label .. ".png")
        if err then error("MAME internal screenshot failed") end
        event("SNAPSHOT_" .. label)
    else
        event("SNAPSHOT_PENDING_" .. label)
    end
    event("CHECKPOINT_" .. label)
    return pix
end

local function diff_pixels(a, b)
    local count, minx, miny, maxx, maxy = 0, 240, 36, -1, -1
    for y=0,35 do
        for x=0,239 do
            local i = (y*240+x)*4+1
            if a:sub(i,i+3) ~= b:sub(i,i+3) then
                count = count+1
                if x < minx then minx=x end
                if x > maxx then maxx=x end
                if y < miny then miny=y end
                if y > maxy then maxy=y end
            end
        end
    end
    event(string.format("DIFF_PIXELS=%d_BBOX=%d,%d,%d,%d", count,minx,miny,maxx,maxy))
    return count
end

local function observe()
    frame = frame+1
    if frame==400 then
        if not key then error("COL.14/A not available") end
        capture("t08")
    elseif frame==800 then
        capture("t16")
    elseif frame==1200 then
        capture("t24")
    elseif frame==1350 then
        before=capture("before")
    elseif frame==1380 then
        key:set_value(1)
        pressed=true
        event("KEY_DOWN_A")
    elseif frame==1400 then
        key:clear_value()
        pressed=false
        event("KEY_UP_A")
    elseif frame==1450 then
        local after=capture("after")
        local changed=diff_pixels(before,after)
        event(changed>0 and "LCD_CHANGED_AFTER_KEY" or "LCD_UNCHANGED_AFTER_KEY")
        event("OBSERVATION_COMPLETE")
    end
end

emu.register_frame_done(function()
    if failed or frame>=1450 then return end
    local ok = pcall(observe)
    if not ok then
        failed=true
        if pressed and key then pcall(function() key:clear_value() end) end
        event("LUA_OBSERVATION_FAILED")
    end
end)
event("LUA_ATTACHED_AP03")
