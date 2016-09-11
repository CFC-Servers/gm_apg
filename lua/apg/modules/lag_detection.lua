--[[------------------------------------------

    A.P.G. - a lightweight Anti Prop Griefing solution (v{{ script_version_name }})
    Made by :
    - While True (http://steamcommunity.com/id/76561197972967270)
    - LuaTenshi (http://steamcommunity.com/id/76561198096713277)

    Licensed to : http://steamcommunity.com/id/{{ user_id }}


    ============================
        LAG DETECTION MODULE
    ============================

    Developper informations :
    ---------------------------------
    Used variables :
        lagTrigger = { value = 75, desc = "% difference between current lag and average lag."}
        lagsCount = { value = 8, desc = "Number of consectuives laggy frames in order to run a cleanup."}
        bigLag = { value = 2, desc = "Time (seconds) between 2 frames to trigger a cleanup"}
        lagFunc = { value = "cleanUp_unfrozen", desc = "Function ran on lag detected" }
        lagFuncTime = { value = 20, desc = "Time (seconds) between 2 cleanup (avoid spam)"}

    Ready to hook :
        APG_lagDetected = Ran on lag detected by the server.
        Example : hook.Add( "APG_lagDetected", "myLagDetectHook", function() print("[APG] Lag detected (printed from my very own hook)")  end)

]]--------------------------------------------
local mod = "lag_detection"

--[[--------------------
    Lag fixing functions
]]----------------------
-- cleanup_all
-- cleanup_unfrozen
-- ghost_unfrozen
-- freeze_unfrozen
-- custom_function
local lagFix = {}
lagFix.cleanup_all = function( notify ) APG.cleanUp( "all", notify ) end
lagFix.cleanup_unfrozen = function( notify ) APG.cleanUp( "unfrozen", notify ) end
lagFix.ghost_unfrozen = APG.ghostThemAll
lagFix.freeze_unfrozen = APG.freezeProps
lagFix.custom_function = APG.customFunc

--[[--------------------
        Utils
]]----------------------
function APG.process( tab )
    local sum = 0
    local max = 0
    for k, v in pairs( tab ) do
        sum = sum + v
        if v > max then
            max = v
        end
    end
    return sum / (#tab) , max
end
local trigValue = 10
local tickTable = {}
local delta, curAvg, lagCount = 0, 0, 0

APG.timerCreate("lag_detection", "APG_process", 5, 0, function()
    if not APG.modules[ mod ] then return end

    if #tickTable < 60 or delta < trigValue then
        table.insert(tickTable, delta)
        if #tickTable > 60 then
            table.remove(tickTable, 1) -- it will take 300 seconds to fullfill the table.
        end

        curAvg = APG.process( tickTable )
        trigValue = curAvg * (100 + APG.cfg["lagTrigger"].value)/100
    end
end)

APG.hookAdd( "lag_detection", "APG_lagDetected", "APG_lagDetected_id", function()
    if not APG then return end -- This will stop error spam.
    local func = APG.cfg["lagFunc"].value
    local notify = APG.cfg["lagFuncNotify"].value
    if not lagFix[ func ] then return end
    lagFix[ func ]( notify )
end)


local pause = false
local lastThink = SysTime()
APG.hookAdd( "lag_detection", "Think", "APG_detectLag", function()
    if not APG.modules[ mod ] then return end

    local curTime = SysTime()
    delta = curTime - lastThink
    if delta >= trigValue then
        lagCount = lagCount + 1
        if (lagCount >= APG.cfg["lagsCount"].value) or ( delta > APG.cfg["bigLag"].value ) then
            lagCount = 0
            if not pause then
                pause = true
                timer.Simple( APG.cfg["lagFuncTime"].value, function() pause = false end)
                APG.log( "[APG] WARNING LAG DETECTED : Running lag fix function")
                hook.Run( "APG_lagDetected" )
            end
        end
    else
        lagCount = lagCount > 0 and (lagCount - 0.5) or 0
    end
    lastThink = curTime
end)

--[[--------------------
        To replace in UI
]]----------------------
concommand.Add( "APG_showLag", function(ply, cmd, arg)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local lastShow = SysTime()
    local values = {}
    local time = arg[1] or 30
    APG.log("[APG] Processing : please wait " .. time .. " seconds", ply )
    hook.Add("Think","APG_showLag",function()
        local curTime = SysTime()
        local diff = curTime - lastShow
        table.insert(values, diff)
        lastShow = curTime
    end)
    timer.Simple( time , function()
        hook.Remove("Think","APG_showLag")
        local avg, max = APG.process( values )
        values = {}
        APG.log("[APG] Avg : " .. avg .. " | Max : " .. max, ply )
    end)
end)
