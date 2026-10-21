-- AP07 one bounded display and CPU-state observation on isolated ASPRO-DIAG.
local machine=manager.machine
local screen=assert(machine.screens[":screen"])
local ports=machine.ioport.ports
local expected=AP07_EXPECTED_HOLD
local do_boot=AP07_BOOT_MODE==1
local frame=0
-- MAME reloads the autoboot script after machine:soft_reset(). Persist
-- the one-time switch inside this campaign's unique private directory,
-- otherwise every reload resets again while only ~15 SCI bytes arrived.
local switch_file="ap07_bootstrap_soft_reset_once.flag"
local switched=false
if do_boot then
    local previous=io.open(switch_file,"rb")
    if previous then
        previous:close()
        switched=true
    end
end
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
            -- Write before resetting; a fresh Lua VM must observe this
            -- marker and must not schedule another soft reset.
            local once=assert(io.open(switch_file,"wb"))
            once:write("BOOTSTRAP_SELECTED_ONCE\n")
            assert(once:close())
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

    if not do_boot and frame==480 then
        local ok=pcall(function() screen:snapshot("normal_before.png") end)
        if ok then log("NORMAL_LCD_BEFORE") else log("NORMAL_LCD_BEFORE_FAILED") end
    end
    if not do_boot and frame==500 then
        local ok=pcall(function()
            local keyport=assert(ports[":COL.14"])
            for _,f in pairs(keyport.fields) do
                if f.mask==0x10 then f:set_value(1); return end
            end
            error("key A not found")
        end)
        if ok then log("NORMAL_KEY_A_DOWN") else log("NORMAL_KEY_A_FAILED") end
    end
    if not do_boot and frame==520 then
        local ok=pcall(function()
            local keyport=assert(ports[":COL.14"])
            for _,f in pairs(keyport.fields) do
                if f.mask==0x10 then f:clear_value(); return end
            end
        end)
        if ok then log("NORMAL_KEY_A_UP") end
    end
    if (do_boot and frame==150) or (not do_boot and frame==650) then
        local ok=pcall(function() screen:snapshot("bootstrap.png") end)
        if ok then log("LCD_SNAPSHOT") else log("LCD_SNAPSHOT_FAILED") end
    end
    if (do_boot and frame==160) or (not do_boot and frame==690) then
        log("OBSERVATION_COMPLETE")
    end
end)
log("LUA_ATTACHED")
