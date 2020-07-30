-- Receive values sent via thread:start

require 'love.event'
require 'love.keyboard'
require 'love.timer'

local dv = {a = 0,       -- att debug
        r = 0,           -- roll debug
        h = 0,           -- heading debug
        g = 0,           -- glideslope debug
        l = 0,           -- localiser debug
        fd = {r=0, a=0}, -- flight director roll and attitude
        aa = 0,          -- AS debug
        ra = 2450,       -- Radar altimeter
        dh = 180}        -- DH debug

love.thread.getChannel('to_panel'):push(dv)
local last_frame = love.timer.getTime()
da = 0.01

while true do
    local dt = love.timer.getTime() - last_frame --distance between last frame
    if dt > love.timer.getAverageDelta()/3 then
        love.thread.getChannel('to_panel'):clear() -- garbage collect
        love.thread.getChannel('to_panel'):push(dv)
        last_frame = love.timer.getTime()
    end

    for n, a, b, c, d, e, f in love.event.poll() do
        if n == 'quit' then
            love.event.quit()
        elseif n == "wheelmoved" then
            y = b
            if love.keyboard.isDown("r") then
                if y > 0 then
                    dv.r = dv.r + 0.1
                elseif y < 0 then
                    dv.r = dv.r - 0.1
                end
            elseif love.keyboard.isDown("l") then
                if y > 0 then
                    dv.l = dv.l + 0.1
                elseif y < 0 then
                    dv.l = dv.l - 0.1
                end
            elseif love.keyboard.isDown("g") then
                if y > 0 then
                    dv.g = dv.g + 0.1
                elseif y < 0 then
                    dv.g = dv.g - 0.1
                end
            elseif love.keyboard.isDown("h") then
                if y > 0 then
                    dv.h = dv.h + 0.1
                elseif y < 0 then
                    dv.h = dv.h - 0.1
                end
            elseif love.keyboard.isDown("f") then
                if y > 0 then
                    dv.fd.a = dv.fd.a + 0.03
                elseif y < 0 then
                    dv.fd.a = dv.fd.a - 0.035
                end
            elseif love.keyboard.isDown("a") then
                if y > 0 then
                    dv.aa = dv.aa + 0.1
                elseif y < 0 then
                    dv.aa = dv.aa - 0.1
                end
            else
                if y > 0 then
                    dv.a = dv.a + 0.03
                elseif y < 0 then
                    dv.a = dv.a - 0.035
                end
            end
        elseif n == "touchmoved" then
            dx = d
            dy = e
            if dx > 0 then
                dv.r = dv.r + 0.01
            elseif dx < 0 then
                dv.r = dv.r - 0.01
            end

            if dy > 0 then
                dv.a = dv.a + 0.01
            elseif dy < 0 then
                dv.a = dv.a - 0.01
            end           
        end	
    end

    -- pull any changes from panel
    local from = love.thread.getChannel("from_panel"):pop()
    if from then
        for k, v in pairs(from) do
            dv[k] = v
        end
    end

    -- clamping test data to appropriate sizes
    if dv.r >= 2*math.pi then
        dv.r = 0
    elseif dv.r <= -2*math.pi then
        dv.r = 0
    end

    if dv.fd.r >= 2*math.pi then
        dv.fd.r = 0
    elseif dv.fd.r <= -2*math.pi then
        dv.fd.r = 0
    end

    if dv.h >= 2*math.pi then
        dv.h = 0
    end
    if dv.h < 0 then
        dv.h = 0
    end

    if dv.a >= math.pi/2 then
        dv.a = math.pi/2
        da = da * -1
    elseif dv.a <= -math.pi/2 then
        dv.a = -math.pi/2
        da = da * -1
    end

    if dv.fd.a >= math.pi/2 then
        dv.fd.a = math.pi/2
    elseif dv.fd.a <= -math.pi/2 then
        dv.fd.a = -math.pi/2
    end

    if dv.l >= 5 then
        dv.l = 5
    elseif dv.l <= -5 then
        dv.l = -5
    end

    if dv.g >= 5 then
        dv.g = 5
    elseif dv.g <= -5 then
        dv.g = -5
    end

    if dv.aa >= 5 then
        dv.aa = 5
    elseif dv.aa <= -5 then
        dv.aa = -5
    end

end 