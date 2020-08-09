-- Receive values sent via thread:start

require 'love.event'
require 'love.keyboard'
require 'love.timer'
require 'love.system'
local socket = require "socket"

local dv = {
        src1_AHARS = {a=30, r=0, h=0, as=0}, -- AHARS 1 att, roll, heading (DG mag.), calibrated airspeed 
        hsi = {source='test', id='test', vdef = 0, hdef = 0},
        fd = {mode=0, r=0, a=0}, -- flight director roll and attitude
        ap = {mode=0, state=0, hb=0, sr=0, cws=0, yd=0},
        as_sel = 0,                -- airspeed bug selector
        hdg_sel = 0,               -- heading bug selector
        crs_sel = 0,               -- course bug selector
        ralt = 2450,               -- Radar altimeter
        dh = -1,                   -- DH debug
        marker = {o=0, m=0, i=0}}        

love.thread.getChannel('to_panel'):push(dv)
local last_frame = love.timer.getTime()
local address, port
-- the address and port of the server
if love.system.getOS() == "iOS" then
    address, port = "192.168.1.102", 49002
else
    address, port = "127.0.0.1", 49002
end

local debug = false
print("loaded")
udp = socket.udp()
udp:settimeout(0)
udp:setsockname(address, port)
local running = true

while running do
    data, msg_or_ip, port_or_nil = udp:receivefrom()
    if data then
        local index = string.byte(data, 6)
        if debug then
            print(index)
            print(string.byte(data, 10, 13))
            print(data)
        end
        if index == 17 then
            -- AHARS
            dv.src1_AHARS.a = love.data.unpack("f", string.sub(data, 10, 13))
            dv.src1_AHARS.r = - love.data.unpack("f", string.sub(data, 14, 17))
            dv.src1_AHARS.h = love.data.unpack("f", string.sub(data, 18, 21))
            dv.src1_AHARS.as = love.data.unpack("f", string.sub(data, 22, 25))
        elseif index == 18 then
            -- RALT
            dv.ralt = love.data.unpack("f", string.sub(data, 10, 13))
            dv.dh = love.data.unpack("f", string.sub(data, 14, 17))
        elseif index == 19 then
            -- Autopilot
            dv.ap.mode = love.data.unpack("f", string.sub(data, 10, 13))
            dv.ap.state = love.data.unpack("f", string.sub(data, 14, 17))
            dv.ap.hb = love.data.unpack("f", string.sub(data, 18, 21)) -- nb convert these to 1 byte
            dv.ap.sr = love.data.unpack("f", string.sub(data, 22, 25))
            dv.ap.cws = love.data.unpack("f", string.sub(data, 26, 29))
            dv.ap.yd = love.data.unpack("f", string.sub(data, 30, 33))
        elseif index == 20 then
            -- Flight Director
            dv.fd.mode = love.data.unpack("f", string.sub(data, 10, 13))
            dv.fd.a = - love.data.unpack("f", string.sub(data, 14, 17))
            dv.fd.r = love.data.unpack("f", string.sub(data, 18, 21))
            dv.as_sel = love.data.unpack("f", string.sub(data, 22, 25))
        elseif index == 21 then
            -- NAV SOURCES
            dv.hsi.source = string.sub(data, 10, 12)
            dv.hsi.id = string.sub(data, 13)
        elseif index == 22 then
            -- Markers
            dv.marker.o = love.data.unpack("f", string.sub(data, 10, 13))
            dv.marker.m = love.data.unpack("f", string.sub(data, 14, 17))
            dv.marker.i = love.data.unpack("f", string.sub(data, 18, 21))
            
        end
        
    end

    local dt = love.timer.getTime() - last_frame --distance between last frame
    if dt > love.timer.getAverageDelta()/3 then
        love.thread.getChannel('to_panel'):clear() -- garbage collect
        love.thread.getChannel('to_panel'):push(dv)
        last_frame = love.timer.getTime()
    end

    -- pull any changes from panel
    local from = love.thread.getChannel("from_panel"):pop()
    if from then
        -- if from == 'quit' then return end
        for k, v in pairs(from) do
            dv[k] = v
        end
    end

end 

