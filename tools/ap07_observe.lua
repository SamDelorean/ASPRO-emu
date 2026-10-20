-- AP07 one bounded display and CPU-state observation on isolated ASPRO-DIAG.
local machine=manager.machine
local screen=assert(machine.screens[":screen"])
local ports=machine.ioport.ports
local expected=AP07_EXPECTED_HOLD
local do_boot=AP07_BOOT_MODE==1
local frame=0
local switched=false
local function log(msg)
    local f=assert(io.open("observations.log","a"))
    f:write("AP07_"..msg.."\n")
    f:close()
end
local function modefield()
    local port=assert(ports[":BOOTSTRAP_MODE"])
    for _,f in pairs(port.fields) do
        if f.mask==1 then return f end
    end
    error("bootstrap mode field missing")
end
local field=modefield()
emu.register_frame_done(function()
    frame=frame+1
    if frame==2 and not switched then
        switched=true
        if do_boot then
            field:set_value(1)
            log("SELECT_BOOTSTRAP")
            machine:soft_reset()
        else log("NORMAL_DEFAULT") end
    end
    if frame==80 then
        local ok,pc=pcall(function()
            return machine.devices[":maincpu"].state["PC"].value
        end)
        if ok then
            log(string.format("PC_%04X",pc))
            if do_boot and pc==expected then log("PC_HOLD") end
        else log("PC_STATE_UNAVAILABLE") end
    end
    if frame==150 then
        local ok=pcall(function() screen:snapshot("bootstrap.png") end)
        if ok then log("LCD_SNAPSHOT") else log("LCD_SNAPSHOT_FAILED") end
        log("OBSERVATION_COMPLETE")
    end
end)
log("LUA_ATTACHED")
