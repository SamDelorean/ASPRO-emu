-- AP-06: genuine Pro firmware PC Send, decoded from physical PD0/PD1.
-- Always run only in ASPRO-DIAG with ASPro private NVRAM.
local machine = manager.machine
local screen = assert(machine.screens[":screen"], "Pro LCD required")
local ports = machine.ioport.ports
local function field(port,mask)
    local p=assert(ports[":"..port],"missing keyboard matrix "..port)
    for _, f in pairs(p.fields) do
        if f.mask==mask then return f end
    end
    error("missing field "..port)
end
local attached = field("PC_CONNECTED",0x01)
local keys = {
    a=field("COL.14",0x10),
    b=field("COL.1",0x08),
    c=field("COL.12",0x80),
    send=field("COL.7",0x01), -- AlphaSmart Pro, NOT AS2K COL.7 0x10
}
local frame,held,failed=0,nil,false
local function log(s)
    local f=assert(io.open("observations.log","a"))
    f:write("ASPRO_AP06_"..s.."\n")
    f:close()
end
local function release()
    if held then held:clear_value(); held=nil end
end
local function press(name)
    release()
    held=keys[name]
    held:set_value(1)
    log("KEY_"..name.."_DOWN")
end
local function snapshot(name)
    local pix,w,h=screen:pixels()
    if not pix or w~=240 or h~=36 then error("invalid Pro LCD") end
    local err=screen:snapshot(name..".png")
    if err then error("MAME snapshot failed") end
    log("SNAPSHOT_"..name)
end
local function tick()
    frame=frame+1
    -- Already validated editor starts by emulated second 8.
    if frame==400 then snapshot("ready") end
    if frame==440 then press("a") end
    if frame==454 then release() end
    if frame==480 then press("b") end
    if frame==494 then release() end
    if frame==520 then press("c") end
    if frame==534 then release() end
    if frame==595 then snapshot("typed_abc") end
    if frame==650 then
        attached:set_value(1)
        log("PC_ATTACHED")
    end
    if frame==880 then snapshot("host_attached") end
    if frame==1020 then press("send") end
    if frame==1036 then release(); log("SEND_KEY_RELEASED") end
    if frame==1360 then press("send"); log("SEND_SECOND_TRIGGER") end
    if frame==1376 then release(); log("SECOND_SEND_KEY_RELEASED") end
    if frame==1450 then snapshot("after_send") end
    if frame==1550 then
        -- PC_CONNECTED is a PORT_TOGGLE field: explicitly force LOW rather
        -- than clear the Lua override and inherit a potentially latched state.
        attached:set_value(0)
        log("PC_DETACHED")
    end
    if frame==1560 then
        -- Diagnostic readback only; a missing Lua read interface cannot
        -- turn this into a false functional PASS.
        local ok,value=pcall(function() return ports[":PC_CONNECTED"]:read() end)
        if ok then log("PC_PORT_READBACK_"..tostring(value & 0x01)) end
    end
    if frame==1650 then
        release()
        snapshot("after_disconnect")
        log("OBSERVATION_COMPLETE")
    end
end
emu.register_frame_done(function()
    if failed or frame>=1650 then return end
    local ok=pcall(tick)
    if not ok then
        failed=true
        pcall(release)
        pcall(function() attached:clear_value() end)
        log("OBSERVATION_FAILED")
    end
end)
log("LUA_ATTACHED")
