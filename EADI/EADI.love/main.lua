ver = "BENDIX/KING EFS50 EADI v1"
sky =  {0x2A/255.0, 0x6C/255.0, 0xA5/255.0} 
ground =  {0x78/255.0, 0x5C/255.0, 0x3D/255.0}
pilot_side_amber = {239/255.0, 151/255.0, 0/255.0}
green = {0/255.0, 158/255.0, 60/255.0}
white = {1, 1, 1, 1}
debug = false

local sim_data -- Our thread object.

if love.system.getOS() == "iOS" then
    resizable = true
    fullscreen = true
    SCREENWIDTH = 1024
    SCREENWIDTH = 1024
    SCREENHEIGHT = SCREENWIDTH 
else   
    resizable = true
    fullscreen = false
    SCREENHEIGHT = 1024
   
    if 0 < SCREENHEIGHT then
        SCREENHEIGHT = 800
    end
    SCREENWIDTH = SCREENHEIGHT 
end

local states = {COLD=1, NORM=2, APPROACH=3}
state = states.NORM
local ref_pointer, ref_pointer_internal

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

attitude = 0
bank=0

ap = {
    YD=false,
    AP=false,
    modes={lat_eng={m="HDG", c=green}, 
            lat_arm={m="LOC",c=white},
            vert_eng={m="ALT", c=green}, 
            vert_arm={m="GS", c=white}},
    marker = {o = false, m = false, i = false},
    DH = false,
    aux = {SR = dv.ap.sr, HB = dv.ap.hb, CWS = dv.ap.cws}
}

function love.load()
    love.window.setMode(SCREENWIDTH, SCREENHEIGHT, {fullscreen=fullscreen, resizable=resizable})
    
    DEBUG_FONT = love.graphics.getFont()
    FONT = love.graphics.newFont("res/BebasNeue Book.otf", 80)
    SCALE_FONT = love.graphics.newFont("res/BebasNeue Regular.otf", 80) -- font for compass and attitude lines

    sim_data = love.thread.newThread( "xplane.lua" )
    sim_data:start()
  

    -- images
    ref_pointer = love.graphics.newImage("res/ref_pointer.png")
    ref_pointer_internal = love.graphics.newImage("res/ref_pointer_internal.png")
    
    glideslope = love.graphics.newImage("res/glideslope.png")
    gs_bug = love.graphics.newImage("res/gs_bug.png")
    
    AOA = love.graphics.newImage("res/AOA.png")
    as_bug = love.graphics.newImage("res/as_bug.png") 
    
    localiser = {norm=love.graphics.newImage("res/localiser.png"),
                apr = love.graphics.newImage("res/localiser_apr.png")}
    flight_director = love.graphics.newImage("res/flight_director.png")

    markers = {
        IM = love.graphics.newImage("res/IM.png"),
        MM = love.graphics.newImage("res/MM.png"),
        OM = love.graphics.newImage("res/OM.png")
    }

    runway = love.graphics.newImage("res/runway.png")

    -- attitude indicator lines
    att_lines = love.graphics.newCanvas(300, 2400)
    no_lines = 20*2 -- 100º with 5º increments
    love.graphics.setCanvas(att_lines)
        att_font = SCALE_FONT
        att_font:setFilter("nearest", "nearest", 0)
        size = att_font:getHeight()
        sx = 0.4
        sy = sx

        --  to prevent clipping
        -- ⌜ att_lines 0 =  100º  (not drawn)    ⌝
        -- ⌜ att_lines height/40 = 90º   drawn)  ⌝
        -- ⌞ att_lines 39*height/40 = -90º drawn)⌟
        -- ⌞ att_lines height =  -100º  (not drawn)    ⌟  
        

        for i=1,no_lines do 
            local number = math.abs(-100 + (5*i))
            if number ~= 85 and number <=90 then
                if i%2 == 0 then
                    if i ~= no_lines / 2 then
                        love.graphics.rectangle("fill", 0.1*att_lines:getWidth(), i*att_lines:getHeight()/no_lines, 0.8*att_lines:getWidth(), SCREENHEIGHT*0.004)
                        love.graphics.setBlendMode("alpha")
                        love.graphics.setColor(1, 1, 1, 0.5)
                        love.graphics.print(number, att_font, 0, (i*att_lines:getHeight()/no_lines), 0, sx, sy, 0, sx*size)
                        love.graphics.print(number, att_font, 0.92*att_lines:getWidth(), (i*att_lines:getHeight()/no_lines), 0, sx, sy, 0, sx*size)
                        love.graphics.setColor(1, 1, 1, 1)
                    else
                        love.graphics.rectangle("fill", 0, i*att_lines:getHeight()/no_lines, att_lines:getWidth(), SCREENHEIGHT*0.004)
                    end
                else
                    love.graphics.rectangle("fill", 0.25*att_lines:getWidth(), i*att_lines:getHeight()/no_lines, 0.5*att_lines:getWidth(), SCREENHEIGHT*0.004)
                end
            end
        end
    love.graphics.setCanvas()

    -- heading indicator lines
    hdg_lines = love.graphics.newCanvas(3000,50)
    no_lines = (36*2)+2 -- 1 line for every 5º + two extra "invisible" lines to prevent clipping
    love.graphics.setCanvas(hdg_lines)
        hdg_font = SCALE_FONT
        hdg_font:setFilter("nearest", "nearest", 0)
        size = hdg_font:getHeight()
        sx = 0.4
        sy = sx
        for i=0,no_lines do 
            local number = -10 + (5*i)
            if number >= 0 and number < 360 then
                if i%2 == 0 then
                    love.graphics.rectangle("fill", i*hdg_lines:getWidth()/no_lines, 0.5*hdg_lines:getHeight(), SCREENHEIGHT*0.004, 0.5*hdg_lines:getHeight())
                    love.graphics.setBlendMode("alpha")
                    if (i+1)%3 == 0 then
                        love.graphics.setColor(1, 1, 1, 0.5)
                        if number % 90 == 0 then
                            lut = {[0]="N", [90]="E", [180]="S", [270]="W"}
                            love.graphics.print(lut[number], att_font, i*hdg_lines:getWidth()/no_lines, 0, 0, sx, sy, 0.5*hdg_font:getWidth("0") - SCREENHEIGHT*0.002, 0)
                        elseif number > 99 then
                            love.graphics.print((number)/10, att_font, i*hdg_lines:getWidth()/no_lines, 0, 0, sx, sy, 0.5*hdg_font:getWidth("00") - SCREENHEIGHT*0.002, 0)
                        else
                            love.graphics.print((number)/10, att_font, i*hdg_lines:getWidth()/no_lines, 0, 0, sx, sy, 0.5*hdg_font:getWidth("0") - SCREENHEIGHT*0.002, 0)
                        end
                            -- love.graphics.print(number, att_font, i*hdg_lines:getWidth()/no_lines, 0, 0, sx, sy, sx*hdg_font:getWidth("000"), 0)
                        love.graphics.setColor(white)  
                    end
                else
                    love.graphics.rectangle("fill", i*hdg_lines:getWidth()/no_lines, 0.8*hdg_lines:getHeight(), SCREENHEIGHT*0.004, 0.2*hdg_lines:getHeight())
                end
            end
        end
        love.graphics.rectangle("fill", (2*hdg_lines:getWidth()/no_lines), hdg_lines:getHeight()-SCREENHEIGHT*0.004, hdg_lines:getWidth()-(2*hdg_lines:getWidth()/no_lines), SCREENHEIGHT*0.004)

    love.graphics.setCanvas() 

    -- width of the blue and brown rectangles
    skyWidth = math.min(100*SCREENWIDTH, 100*SCREENHEIGHT) 

end

timers = {
    OM = 0,  
    MM = 50, -- MM is offset from OM by 50 update cycles
    IM = 100,-- MM is offset from OM by 100 update cycles
    APR = 0
}


function love.update(dt)
    if resizable then
        SCREENWIDTH, SCREENHEIGHT = love.graphics.getDimensions()-- love.window.getDesktopDimensions()
        skyWidth = math.min(100*SCREENWIDTH, 100*SCREENHEIGHT)
    end

    dv =  love.thread.getChannel("to_panel"):demand()

    -- get debug variables from other thread

    -- local dv = {
    --     src1_AHARS = {a=30, r=0, h=0, as=0}, -- AHARS 1 att, roll, heading (DG mag.), calibrated airspeed 
    --     hsi = {source='test', id='test', vdef = 0, nav_hdef = 0},
    --     fd = {mode=0, r=0, a=0}, -- flight director roll and attitude
    --     ap = {mode=0, state=0, hb=0, sr=0},
    --     as_sel = 0,                -- airspeed bug selector
    --     hdg_sel = 0,               -- heading bug selector
    --     crs_sel = 0,               -- course bug selector
    --     ralt = 2450,               -- Radar altimeter
    --     dh = -1,                   -- DH debug
    --     marker = {o=0, m=0, i=0}}    
    ----------------------------


    attitude = dv.src1_AHARS.a
    fd_attitude = dv.fd.a
    bank = (dv.src1_AHARS.r/180) * math.pi --radians
    fd_bank = (dv.fd.r / 180) * math.pi -- radians

    if dv.ap.mode > 1 then 
        ap.AP = true 
    else 
        ap.AP = false 
    end

    if dv.fd.mode > 0 then
         ap.FD = true
    else 
        ap.FD = false
    end

    if dv.ap.yd > 0 then ap.YD = true
    else ap.YD = false end

    for k, v in pairs(dv.marker) do
        if v > 0.5 then
            ap.marker[k] = true
        else
            ap.marker[k] = false
        end
    end

    if dv.dh > 0 then 
        ap.DH = true
    else 
        ap.DH = false 
    end

    -- engaged and armed modes -----------------------------
    ap_state = bitfieldint_to_bitstring(dv.ap.state) 

    -- determine lateral mode
    if getbit(ap_state, 2) == '1' then --HDG engaged
        ap.modes.lat_eng.m = 'HDG'
    elseif getbit(ap_state, 10) == '1' then --NAV engaged
        ap.modes.lat_eng.m = 'NAV'
    else 
        ap.modes.lat_eng.m = nil 
    end

    if getbit(ap_state, 9) == '1' then --NAV armed
        ap.modes.lat_arm.m = 'NAV'
    else 
        ap.modes.lat_arm.m = nil 
    end
    -- determine vertical mode
    if getbit(ap_state, 15) == '1' then --ALT engaged
        ap.modes.vert_eng.m = 'ALT'
    elseif getbit(ap_state, 4) == '1' then -- IAS engaged
        ap.modes.vert_eng.m = 'IAS'
    elseif getbit(ap_state, 5) == '1' then --VS engaged
        ap.modes.vert_eng.m = 'VS'
    elseif getbit(ap_state, 12) == '1' then --NAV engaged
        ap.modes.vert_eng.m = 'GS'
    elseif getbit(ap_state, 17) == '1' then --Go around engaged
        ap.modes.vert_eng.m = 'GA'
    else 
        ap.modes.vert_eng.m = nil 
    end

    if getbit(ap_state, 6) == '1' then --ALT armed
        ap.modes.vert_arm.m = 'ALT'
    elseif getbit(ap_state, 11) == '1' then --GS armed
        ap.modes.vert_arm.m = 'GS'
    else 
        ap.modes.vert_arm.m = nil 
    end    

    ap.aux = {SR = dv.ap.sr, HB = dv.ap.hb, CWS = dv.ap.cws}


    
    -- increment all timers
    -- for k, v in pairs(timers) do
    --     timers[k] = v + 1
    -- end

    -- if timers.IM > 1/dt then -- 1s timer
    --     ap.IM = not ap.IM
    --     timers.IM = 0
    -- end

    -- if timers.MM > 1/dt then -- 1s timer
    --     ap.MM = not ap.MM
    --     timers.MM = 10
    -- end

    -- if timers.OM > 1/dt then -- 1s timer
    --     ap.OM = not ap.OM
    --     timers.OM = 20
    -- end

    -- if timers.APR > 30/dt then -- 30s timer
    --     if state == states.APPROACH then
    --         state = states.NORM
    --     else
    --         state = states.APPROACH
    --     end
    --     timers.APR = 0
    -- end

    -- calculate state from dv


    -- if state == states.APPROACH then
    --     -- show smaller border
    --     -- show approach localiser
    --     -- if RA < 2500 show rising runway
    --     print()
    -- end


    -- if state == states.NORM then
    --     -- show normal border
    --     print()
    -- end

    -- from the AHARS source convert 

    -- push radar-alt to sim state
    -- love.thread.getChannel("from_panel"):push({["ra"]=dv.ra})

end

-- function love.threaderror(thread, errorstr)
--     print("Thread error!\n"..errorstr)
--     -- thread:getError() will return the same error string now.
--   end


function love.draw()

    -- AH ----------------------------------------------------------------------------------------
    sx, sy = scale_factor(att_lines, 2.0)
    sy_rot = (sy*att_lines:getHeight())/200 -- how much to scale the attitiude image (180º + 10º each side)
    rotOrigin = {x=(0.5*SCREENWIDTH)+(sy_rot*attitude*math.sin(-bank)), 
                 y=(0.5*SCREENHEIGHT)+(sy_rot*attitude*math.cos(-bank))}
    love.graphics.push() -- push the frame buffer out of the main canvas (makes a reference frame for the rotation+translation of shapes for attiude+roll)
    love.graphics.translate(rotOrigin.x, rotOrigin.y)
    love.graphics.rotate(bank)
    love.graphics.translate(-rotOrigin.x, -rotOrigin.y)
    -- -- sky
    love.graphics.setColor(sky)
    love.graphics.rectangle("fill", rotOrigin.x-(0.5*skyWidth), rotOrigin.y-skyWidth, skyWidth, skyWidth)
    -- ground
    love.graphics.setColor(ground)
    love.graphics.rectangle("fill", rotOrigin.x-(0.5*skyWidth), rotOrigin.y, skyWidth, skyWidth)
    
    love.graphics.pop() -- collapse back to default reference frame

    love.graphics.setColor(white)
    love.graphics.stencil(function()  love.graphics.circle("fill", 0.5*SCREENWIDTH, 0.5*SCREENHEIGHT, 0.3*SCREENHEIGHT) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
        love.graphics.setBlendMode("alpha", "premultiplied")
        sx_att, sy_att = scale_factor(att_lines, 2.0)

        -- to make grid lines further apart increase att_lines height and modify scale factor to suit
        love.graphics.draw(att_lines, rotOrigin.x, rotOrigin.y, bank, sx_att, sy_att, att_lines:getWidth()/2, att_lines:getHeight()/2)

        -- heading card(s) lines
        sx_hdg, sy_hdg = scale_factor(hdg_lines, 1/40)
        love.graphics.setColor(white)
        -- center
        hdg_offset = (hdg_lines:getWidth()/36)+(hdg_lines:getWidth()*(35/36)*(dv.src1_AHARS.h)/360)
        love.graphics.draw(hdg_lines, rotOrigin.x, rotOrigin.y, bank, sx_hdg, sy_hdg, 
        hdg_offset, hdg_lines:getHeight())
        
        -- left edge
        love.graphics.draw(hdg_lines, rotOrigin.x, rotOrigin.y, bank, sx_hdg, sy_hdg, 
        (35/36)*hdg_lines:getWidth()+hdg_offset, hdg_lines:getHeight())

        -- edge2
        love.graphics.draw(hdg_lines, rotOrigin.x, rotOrigin.y, bank, sx_hdg, sy_hdg, 
        hdg_offset-(35/36)*hdg_lines:getWidth(), hdg_lines:getHeight())

        love.graphics.setBlendMode("alpha")     

        -- flight director
        if ap.FD then
            sx, sy = scale_factor(flight_director, 1/17)
            love.graphics.draw(flight_director, 
                                rotOrigin.x+(sy_rot*fd_attitude*math.sin(-bank)), 
                                rotOrigin.y+(sy_rot*fd_attitude*math.cos(-bank)), bank+fd_bank, sx, sy,
                                flight_director:getWidth()/2)
        end


    love.graphics.setStencilTest()

    -- ref_pointers ----------------------------------------------------------------------------------------
    sx, sy = scale_factor(ref_pointer, 0.4)
    love.graphics.setColor(white)
    love.graphics.draw(ref_pointer, 0.5*SCREENWIDTH, 0.5*SCREENHEIGHT, 0, 
                        sx, sy, 
                        ref_pointer:getWidth()/2,  ref_pointer:getHeight()-90)
    love.graphics.draw(ref_pointer_internal, 0.5*SCREENWIDTH, 0.5*SCREENHEIGHT, bank,
                        sx, sy, 
                        ref_pointer_internal:getWidth()/2,  ref_pointer_internal:getHeight()-90)

    -- black border box ----------------------------------------------------------------------------------------
    borderWidth = {x=0.1835, y=0.16}
    mask = function() love.graphics.rectangle("fill", borderWidth.x*SCREENWIDTH, borderWidth.y*SCREENHEIGHT, 
        (1 - 2*borderWidth.x)*SCREENWIDTH, (1 - 2*borderWidth.y)*SCREENHEIGHT) end
    love.graphics.stencil(mask,"replace", 1 )
    love.graphics.setStencilTest("less", 1)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, SCREENWIDTH, SCREENHEIGHT)
    love.graphics.setStencilTest()

    -- nav crosshairs --------------------------------------------------------------------------------------
    love.graphics.setColor(white)
    -- glideslope--------
    if ap.modes.vert_eng.m == 'GS' or ap.modes.vert_arm.m == 'GS' then
        bug_dimmensions = {x=0.01*SCREENWIDTH, y=0.03*SCREENHEIGHT}
        sx_GS, sy_GS = scale_factor(glideslope, 0.4)
        love.graphics.draw(glideslope, 0.85*SCREENWIDTH, 0.5*SCREENHEIGHT, 0,
                            sx_GS, sy_GS, 
                            glideslope:getWidth()/2,  glideslope:getHeight()/2)
        sx, sy = scale_factor(gs_bug, 0.06)
        love.graphics.setColor(pilot_side_amber)
        draw_gs_bug(0.85*SCREENWIDTH, 0.5*SCREENHEIGHT+(0.93*dv.hsi.vdef*sy_GS*glideslope:getHeight()/10), sx, sy)
    end
    
    -- AS---------------
    diff = dv.src1_AHARS.as - dv.as_sel
    if ap.modes.vert_eng.m == 'IAS' and math.abs(diff) < 13 then
        sx_AS, sy_AS = scale_factor(AOA, 0.3)
        sx, sy = scale_factor(as_bug, 0.06)
        love.graphics.draw(AOA, 0.155*SCREENWIDTH, 0.5*SCREENHEIGHT, 0,
                            sx_AS, sy_AS, 
                            AOA:getWidth()/2,  (AOA:getHeight()/2))
        love.graphics.setColor(green)
        if math.abs(diff) <= 10 then 
            draw_as_bug(0.155*SCREENWIDTH, 0.5*SCREENHEIGHT+(0.68*(-diff)*sy_AS*(AOA:getHeight())/20), sx, sy)
        else 
            if diff < 0 then
                draw_as_bug(0.155*SCREENWIDTH, 0.5*SCREENHEIGHT+(0.68*(13)*sy_AS*(AOA:getHeight())/20), sx, sy)
            else
                draw_as_bug(0.155*SCREENWIDTH, 0.5*SCREENHEIGHT+(0.68*(-13)*sy_AS*(AOA:getHeight())/20), sx, sy)
            end
        end
    end
    -- localiser---------
    bug_dimmensions = {x=0.01*SCREENWIDTH, y=0.03*SCREENHEIGHT}
    sx_loc, sy_loc = scale_factor(localiser.norm, 1/38)

    bank_limit = 60
    att_limit = 15
    
    if state == states.APPROACH then
        loc = localiser.apr
    elseif state == states.NORM then 
        loc = localiser.norm 
    end

    love.graphics.setColor(white)
    love.graphics.draw(loc, 0.5*SCREENWIDTH, 0.82*SCREENHEIGHT, 0,
    sx_loc, sy_loc, 
    localiser.norm:getWidth()/2 - 1,  (localiser.norm:getHeight()/2))

    if state == states.APPROACH then -- and 
        if math.abs(bank) < bank_limit and attitude < att_limit then
            love.graphics.stencil(mask,"replace", 1 ) -- mask is the black border 
            love.graphics.setStencilTest("greater", 0)
            -- rising runway
            love.graphics.setColor(white)
            if dv.ralt < 200 then
                sx, sy = scale_factor(runway, ((200-dv.ralt)/200)*(1/3) + (1/8))
            else
                sx, sy = scale_factor(runway, 1/8)
            end
            love.graphics.draw(runway, 
            0.5*SCREENWIDTH+(dv.hsi.hdef*sx_loc*localiser.norm:getWidth()/10), 
            0.7*SCREENHEIGHT, 0, sx, sy,
            runway:getWidth()/2, 0.3*runway:getHeight())  
            love.graphics.setStencilTest()
        else
            love.graphics.setColor(green)
            love.graphics.rectangle("fill", 0.5*SCREENWIDTH+(dv.hsi.hdef*sx_loc*localiser.norm:getWidth()/10)-(bug_dimmensions.x/2), 
                            0.82*SCREENHEIGHT-(bug_dimmensions.y/2), 
                            bug_dimmensions.x, bug_dimmensions.y)
        end
        loc = localiser.apr
    
    elseif state == states.NORM then
        love.graphics.setColor(green)
            love.graphics.rectangle("fill", 0.5*SCREENWIDTH+(dv.hsi.hdef*sx_loc*localiser.norm:getWidth()/10)-(bug_dimmensions.x/2), 
                            0.82*SCREENHEIGHT-(bug_dimmensions.y/2), 
                            bug_dimmensions.x, bug_dimmensions.y)
    end
-- AP modes --------------------------------------------------------------------------------------

-- LARGE FONTS: AP, YD, DH value, RA value
sx, sy = scale_factor(FONT, 1/10)
love.graphics.setColor(white)

if ap.AP then love.graphics.print("AP", FONT, 0.1*SCREENWIDTH, 0.05*SCREENHEIGHT, 0, sx, sy) end
if ap.YD then love.graphics.print("YD", FONT, 0.1*SCREENWIDTH, 0.16*SCREENHEIGHT, 0, sx, sy) end

if dv.ralt > 100 and dv.ralt<2500 then love.graphics.print(string.format("%d0", dv.ralt/10), FONT, 0.90*SCREENWIDTH, 0.05*SCREENHEIGHT, 0, sx, sy, FONT:getWidth(string.format("%d0", dv.ralt/10)))
elseif dv.ralt<2500 then love.graphics.print(string.format("%d", dv.ralt), FONT, 0.90*SCREENWIDTH, 0.05*SCREENHEIGHT, 0, sx, sy, FONT:getWidth(string.format("%d", dv.ralt))) 
else love.graphics.print("- - -", FONT, 0.90*SCREENWIDTH, 0.05*SCREENHEIGHT, 0, sx, sy, FONT:getWidth("- - -")) end

if ap.DH then love.graphics.print(dv.dh, FONT, 0.90*SCREENWIDTH, 0.85*SCREENHEIGHT, 0, sx, sy, FONT:getWidth(string.format("%d", dv.dh))) end

-- MEDIUM FONTS: DH, RA, lon, vert
-- modes={lat_eng="HDG", lat_arm="LOC", vert_eng="ALT", vert_arm="GS"},
sx, sy = scale_factor(FONT, 1/15)

love.graphics.print("RA", FONT, 0.90*SCREENWIDTH, 0.128*SCREENHEIGHT, 0, sx, sy, FONT:getWidth("RA"))
if ap.DH then love.graphics.print("DH", FONT, 0.90*SCREENWIDTH, 0.797*SCREENHEIGHT, 0, sx, sy, FONT:getWidth("DH")) end

love.graphics.setColor(ap.modes.lat_eng.c)
if ap.modes.lat_eng.m then love.graphics.print(ap.modes.lat_eng.m, FONT, 0.3*SCREENWIDTH, 0.055*SCREENHEIGHT, 0, sx, sy) end

love.graphics.setColor(ap.modes.lat_arm.c)
if ap.modes.lat_arm.m then love.graphics.print(ap.modes.lat_arm.m, FONT, 0.3*SCREENWIDTH, 0.11*SCREENHEIGHT, 0, sx, sy) end

love.graphics.setColor(ap.modes.vert_eng.c)
if ap.modes.vert_eng.m then love.graphics.print(ap.modes.vert_eng.m, FONT, 0.6*SCREENWIDTH, 0.055*SCREENHEIGHT, 0, sx, sy) end

love.graphics.setColor(ap.modes.vert_arm.c)
if ap.modes.vert_arm.m then love.graphics.print(ap.modes.vert_arm.m, FONT, 0.6*SCREENWIDTH, 0.11*SCREENHEIGHT, 0, sx, sy) end

-- SMALL FONTS: SR, HB, CWS
sx, sy = scale_factor(FONT, 1/20)
love.graphics.setColor(white)
if ap.aux.SR == 1 then love.graphics.print("SR", FONT, 0.2*SCREENWIDTH, 0.06*SCREENHEIGHT, 0, sx, sy) end
if ap.aux.HB == 1 then love.graphics.print("HB", FONT, 0.2*SCREENWIDTH, 0.11*SCREENHEIGHT, 0, sx, sy) end
if ap.aux.CWS == 1 then love.graphics.print("CWS", FONT, 0.2*SCREENWIDTH, 0.16*SCREENHEIGHT, 0, sx, sy) end
love.graphics.print(dv.hsi.source, FONT, 0.7*SCREENWIDTH, 0.78*SCREENHEIGHT, 0, sx, sy)

-- markers
sx, sy = scale_factor(markers.IM, 1/25)
if ap.marker.i then love.graphics.draw(markers.IM, 0.12*SCREENWIDTH, 0.8*SCREENHEIGHT, 0, sx, sy) end
if ap.marker.m then love.graphics.draw(markers.MM, 0.12*SCREENWIDTH, 0.82*SCREENHEIGHT, 0, sx, sy) end
if ap.marker.o then love.graphics.draw(markers.OM, 0.12*SCREENWIDTH, 0.84*SCREENHEIGHT, 0, sx, sy) end

    if debug then
        -- debug crosshairs
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.line(0.5*SCREENWIDTH, 0, 0.5*SCREENWIDTH, SCREENHEIGHT)
        love.graphics.line(0.1*SCREENWIDTH, 0, 0.1*SCREENWIDTH, SCREENHEIGHT)
        love.graphics.line(0.9*SCREENWIDTH, 0, 0.9*SCREENWIDTH, SCREENHEIGHT)
        love.graphics.line(0, 0.5*SCREENHEIGHT, SCREENWIDTH, 0.5*SCREENHEIGHT)
        
        -- ver no
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.print(ver, 0.1*SCREENWIDTH, 0.95*SCREENHEIGHT)
        
        -- r
        love.graphics.setColor(0, 1, 1, 1)
        love.graphics.print(string.format("%.1f", math.abs(bank)), 0.5*SCREENWIDTH, 0.95*SCREENHEIGHT)

        -- att
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print(string.format("%.1f", attitude), 0.85*SCREENWIDTH, 0.52*SCREENHEIGHT)
        
        -- a
        love.graphics.setColor(1, 0, 1, 1)
        love.graphics.print(string.format("a = %.1f", dv.src1_AHARS.a), 0.85*SCREENWIDTH, 0.55*SCREENHEIGHT)

        -- l 
        love.graphics.setColor(0, 0, 1, 1)
        love.graphics.print(string.format("l = %.4f", dv.hsi.hdef), 0.5*SCREENWIDTH, 0.8*SCREENHEIGHT)

        -- diff
        love.graphics.setColor(0, 0, 1, 1)
        love.graphics.print(string.format("as = %.4f", diff), 0.3*SCREENWIDTH, 0.5*SCREENHEIGHT)

        -- h
        love.graphics.setColor(0, 0.5, 0.5, 1)
        love.graphics.print(string.format("h = %.1f", dv.src1_AHARS.h), 0.7*SCREENWIDTH, 0.8*SCREENHEIGHT)

        -- thread
        love.graphics.setColor(0.5, 0.5, 0, 1)
        love.graphics.print(tostring(dv), 0.3*SCREENWIDTH, 0.8*SCREENHEIGHT)

        -- ap_state
        love.graphics.setColor(0.5, 0.5, 0.2, 1)
        love.graphics.print(bitfieldint_to_bitstring(dv.ap.state), 0.3*SCREENWIDTH, 0.1*SCREENHEIGHT)

    end

    
end

function scale_factor(img, sf)
    -- compare image size to screen size
    -- aspectRatio = SCREENWIDTH / SCREENHEIGHT
    local sy =  sf * SCREENHEIGHT / img:getHeight()
    return sy, sy
end

function draw_gs_bug(x, y, sx, sy)
    love.graphics.push()
    love.graphics.translate(x, y-(sy*gs_bug:getHeight()/2))
    love.graphics.scale(sx, sy)
    love.graphics.draw(gs_bug)
    love.graphics.stencil(function()  love.graphics.rectangle("fill", 60, 3, 32, 75) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(gs_bug) -- white text stenciled out
    love.graphics.setStencilTest()
    love.graphics.pop()

end

function draw_as_bug(x, y, sx, sy)
    love.graphics.push()
    love.graphics.translate(x-(sx*as_bug:getWidth()), y-(sy*as_bug:getHeight()/2))
    love.graphics.scale(sx, sy)
    love.graphics.draw(as_bug)
    love.graphics.stencil(function()  love.graphics.rectangle("fill", 5, 5, 33, 75) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(as_bug) -- white text stenciled out
    
    love.graphics.setStencilTest()
    love.graphics.pop()

end

function love.quit()
    print("quiting thread")
    love.thread.getChannel("from_panel"):push("quit")
    sim_data:wait()
    print("quited thread")
    return false
end

function bitfieldint_to_bitstring(num)
    local t={}
    while num>0 do
        rest=num%2
        t[#t+1]=rest
        num=(num-rest)/2
    end
    return string.reverse(table.concat(t))
end

function getbit(str, idx)
    local str_len = string.len(str) + 1
    if idx > str_len then return '0' end
    return string.sub(str, str_len - idx, str_len - idx)
end

    