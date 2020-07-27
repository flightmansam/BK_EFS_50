-- instructions
-- scroll is attitude
-- "r" + scroll = roll
-- "h" + scroll = heading + FD roll
-- "l" + scroll = localiser
-- "g" + scroll = glide slope
-- "a" + scroll = airspeed



ver = "BENDIX/KING EFS50 EADI v1"
sky =  {0x2A/255.0, 0x6C/255.0, 0xA5/255.0} 
ground =  {0x78/255.0, 0x5C/255.0, 0x3D/255.0}
pilot_side_amber = {239/255.0, 151/255.0, 0/255.0}
green = {0/255.0, 158/255.0, 60/255.0}
white = {1, 1, 1, 1}
debug = false

if love.system.getOS() == "iOS" then
    resizable = true
    fullscreen = true
else   
    resizable = false
    fullscreen = false
    SCREENWIDTH = 1024
    if love.graphics.getDimensions() < SCREENWIDTH then
        SCREENWIDTH = 800
    end
    SCREENHEIGHT = SCREENWIDTH 
end

local states = {COLD=1, NORM=2, APPROACH=3}
state = states.APPROACH
local ref_pointer, ref_pointer_internal

dv = {a = 0, --att debug
    r = 0, --roll debug
    h = 0, --heading debug
    g = 0, --glideslope debug
    l = 0, --localiser debug
    fd = {r=0, a=0}, -- flight director roll and attitude
    aa = 0,--AS debug
    ra = 2450,
    dh = 180} --DH debug}

attitude = 0
bank=0

ap = {
    YD=true,
    AP=true,
    RA=true,
    modes={lat_eng={m="HDG", c=green}, 
            lat_arm={m="LOC",c=white},
            vert_eng={m="ALT", c=green}, 
            vert_arm={m="GS", c=white}},
    OM = true,
    MM = false,
    IM = false,
    DH = true,
    aux = {SR = true, HB = true, CWS = true}
}

function love.load()
    
    love.window.setMode(SCREENWIDTH, SCREENHEIGHT, {fullscreen=fullscreen, resizable=resizable})

    DEBUG_FONT = love.graphics.getFont()
    FONT = love.graphics.newFont("res/BebasNeue Book.otf", 80)
    SCALE_FONT = love.graphics.newFont("res/BebasNeue Regular.otf", 80) -- font for compass and attitude lines
  

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

    -- test data
    if love.system.getOS() == "iOS" then
        dv.l = 5 * math.sin(dv.r)
        dv.g = 5 * math.cos(dv.a)
        dv.aa = 5 * math.sin((-dv.g))
        dh.h = math.sin(dv.aa)
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
    elseif dv.a <= -math.pi/2 then
        dv.a = -math.pi/2
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
    ----------------------------

    attitude = 90*math.sin(dv.a)
    fd_attitude = 90*math.sin(dv.fd.a)
    bank = 180/math.pi*dv.r

    -- increment all timers
    for k, v in pairs(timers) do
        timers[k] = v + 1
    end

    if timers.IM > 1/dt then -- 1s timer
        ap.IM = not ap.IM
        timers.IM = 0
    end

    if timers.MM > 1/dt then -- 1s timer
        ap.MM = not ap.MM
        timers.MM = 10
    end

    if timers.OM > 1/dt then -- 1s timer
        ap.OM = not ap.OM
        timers.OM = 20
    end

    if timers.APR > 30/dt then -- 30s timer
        if state == states.APPROACH then
            state = states.NORM
        else
            state = states.APPROACH
        end
        timers.APR = 0
    end

    if state == states.APPROACH then
        ap.modes.lat_eng.m = 'APR'
        ap.modes.lat_arm.m = 'LOC'
        ap.modes.vert_eng.m = 'GS'
        ap.modes.vert_arm.m = nil
        dv.ra = dv.ra - 2
        if dv.ra < 0 then dv.ra = 0 end
    end


    if state == states.NORM then
        ap.modes.lat_eng.m = 'HDG'
        ap.modes.lat_arm.m = 'LOC'
        ap.modes.vert_eng.m = 'ALT'
        ap.modes.vert_arm.m = 'GS'
        dv.ra = 2450
    end




end



function love.draw()

    -- AH ----------------------------------------------------------------------------------------
    sx, sy = scale_factor(att_lines, 2.0)
    sy = (sy*att_lines:getHeight())/200 -- how much to scale the attitiude image (180º + 10º each side)
    rotOrigin = {x=(0.5*SCREENWIDTH)+(sy*attitude*math.sin(-dv.r)), 
                 y=(0.5*SCREENHEIGHT)+(sy*attitude*math.cos(-dv.r))}
    love.graphics.push() -- push the frame buffer out of the main canvas (makes a reference frame for the rotation+translation of shapes for attiude+roll)
    love.graphics.translate(rotOrigin.x, rotOrigin.y)
    love.graphics.rotate(dv.r)
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
        love.graphics.draw(att_lines, rotOrigin.x, rotOrigin.y, dv.r, sx_att, sy_att, att_lines:getWidth()/2, att_lines:getHeight()/2)

        -- heading card(s) lines
        sx_hdg, sy_hdg = scale_factor(hdg_lines, 1/40)
        love.graphics.setColor(white)
        -- center
        hdg_offset = (hdg_lines:getWidth()/36)+(hdg_lines:getWidth()*(35/36)*math.sin(dv.h))
        love.graphics.draw(hdg_lines, rotOrigin.x, rotOrigin.y, dv.r, sx_hdg, sy_hdg, 
        hdg_offset, hdg_lines:getHeight())
        
        -- left edge
        love.graphics.draw(hdg_lines, rotOrigin.x, rotOrigin.y, dv.r, sx_hdg, sy_hdg, 
        (35/36)*hdg_lines:getWidth()+hdg_offset, hdg_lines:getHeight())

        -- edge2
        love.graphics.draw(hdg_lines, rotOrigin.x, rotOrigin.y, dv.r, sx_hdg, sy_hdg, 
        hdg_offset-(35/36)*hdg_lines:getWidth(), hdg_lines:getHeight())

        love.graphics.setBlendMode("alpha")     

        -- flight director
        sx, sy = scale_factor(flight_director, 1/17)
        love.graphics.draw(flight_director, 
                            rotOrigin.x+(sy*fd_attitude*math.sin(-dv.r)), 
                            rotOrigin.y+(sy*fd_attitude*math.cos(-dv.r)), dv.h+dv.r, sx, sy,
                            flight_director:getWidth()/2)

    love.graphics.setStencilTest()

    -- ref_pointers ----------------------------------------------------------------------------------------
    sx, sy = scale_factor(ref_pointer, 0.4)
    love.graphics.setColor(white)
    love.graphics.draw(ref_pointer, 0.5*SCREENWIDTH, 0.5*SCREENHEIGHT, 0, 
                        sx, sy, 
                        ref_pointer:getWidth()/2,  ref_pointer:getHeight()-90)
    love.graphics.draw(ref_pointer_internal, 0.5*SCREENWIDTH, 0.5*SCREENHEIGHT, dv.r,
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
    bug_dimmensions = {x=0.01*SCREENWIDTH, y=0.03*SCREENHEIGHT}
    sx_GS, sy_GS = scale_factor(glideslope, 0.4)
    love.graphics.draw(glideslope, 0.85*SCREENWIDTH, 0.5*SCREENHEIGHT, 0,
                        sx_GS, sy_GS, 
                        glideslope:getWidth()/2,  glideslope:getHeight()/2)
    sx, sy = scale_factor(gs_bug, 0.06)
    love.graphics.setColor(pilot_side_amber)
    draw_gs_bug(0.85*SCREENWIDTH, 0.5*SCREENHEIGHT+(0.93*dv.g*sy_GS*glideslope:getHeight()/10), sx, sy)
    
    -- AS---------------
    sx_AS, sy_AS = scale_factor(AOA, 0.3)
    sx, sy = scale_factor(as_bug, 0.06)
    love.graphics.draw(AOA, 0.155*SCREENWIDTH, 0.5*SCREENHEIGHT, 0,
                        sx_AS, sy_AS, 
                        AOA:getWidth()/2,  (AOA:getHeight()/2))
    love.graphics.setColor(green)
    draw_as_bug(0.155*SCREENWIDTH, 0.5*SCREENHEIGHT+(0.68*dv.aa*sy_AS*(AOA:getHeight())/10), sx, sy)

    -- localiser---------
    bug_dimmensions = {x=0.01*SCREENWIDTH, y=0.03*SCREENHEIGHT}
    sx_loc, sy_loc = scale_factor(localiser.norm, 1/38)

    loc = localiser.norm
    if state == states.APPROACH then
        love.graphics.stencil(mask,"replace", 1 ) -- mask is the black border 
        love.graphics.setStencilTest("greater", 0)
        -- rising runway
        love.graphics.setColor(white)
        if dv.ra < 200 then
            sx, sy = scale_factor(runway, ((200-dv.ra)/200)*(1/3) + (1/8))
        else
            sx, sy = scale_factor(runway, 1/8)
        end
        love.graphics.draw(runway, 
        0.5*SCREENWIDTH+(dv.l*sx_loc*localiser.norm:getWidth()/10), 
        0.7*SCREENHEIGHT, 0, sx, sy,
        runway:getWidth()/2, 0.3*runway:getHeight())  
        love.graphics.setStencilTest()

        loc = localiser.apr
    end
        

    love.graphics.draw(loc, 0.5*SCREENWIDTH, 0.82*SCREENHEIGHT, 0,
                        sx_loc, sy_loc, 
                        localiser.norm:getWidth()/2 - 1,  (localiser.norm:getHeight()/2))

    if state == states.NORM then
        love.graphics.setColor(green)
        love.graphics.rectangle("fill", 0.5*SCREENWIDTH+(dv.l*sx_loc*localiser.norm:getWidth()/10)-(bug_dimmensions.x/2), 
                            0.82*SCREENHEIGHT-(bug_dimmensions.y/2), 
                            bug_dimmensions.x, bug_dimmensions.y) 
    end


-- AP modes --------------------------------------------------------------------------------------

-- LARGE FONTS: AP, YD, DH value, RA value
sx= 0.8
sy = sx
love.graphics.setColor(white)

if ap.AP then love.graphics.print("AP", FONT, 0.1*SCREENWIDTH, 0.05*SCREENHEIGHT, 0, sx, sy) end
if ap.YD then love.graphics.print("YD", FONT, 0.1*SCREENWIDTH, 0.16*SCREENHEIGHT, 0, sx, sy) end
if ap.RA then love.graphics.print(string.format("%d0", dv.ra/10), FONT, 0.90*SCREENWIDTH, 0.05*SCREENHEIGHT, 0, sx, sy, FONT:getWidth(string.format("%d0", dv.ra/10))) end
if ap.DH then love.graphics.print(dv.dh, FONT, 0.90*SCREENWIDTH, 0.85*SCREENHEIGHT, 0, sx, sy, FONT:getWidth(string.format("%d", dv.dh))) end

-- MEDIUM FONTS: DH, RA, lon, vert
-- modes={lat_eng="HDG", lat_arm="LOC", vert_eng="ALT", vert_arm="GS"},
sx= 0.6
sy = sx

if ap.RA then love.graphics.print("RA", FONT, 0.90*SCREENWIDTH, 0.12*SCREENHEIGHT, 0, sx, sy, FONT:getWidth("DH")) end
if ap.DH then love.graphics.print("DH", FONT, 0.90*SCREENWIDTH, 0.8*SCREENHEIGHT, 0, sx, sy, FONT:getWidth("DH")) end

love.graphics.setColor(ap.modes.lat_eng.c)
if ap.modes.lat_eng.m then love.graphics.print(ap.modes.lat_eng.m, FONT, 0.3*SCREENWIDTH, 0.06*SCREENHEIGHT, 0, sx, sy) end

love.graphics.setColor(ap.modes.lat_arm.c)
if ap.modes.lat_arm.m then love.graphics.print(ap.modes.lat_arm.m, FONT, 0.3*SCREENWIDTH, 0.11*SCREENHEIGHT, 0, sx, sy) end

love.graphics.setColor(ap.modes.vert_eng.c)
if ap.modes.vert_eng.m then love.graphics.print(ap.modes.vert_eng.m, FONT, 0.6*SCREENWIDTH, 0.06*SCREENHEIGHT, 0, sx, sy) end

love.graphics.setColor(ap.modes.vert_arm.c)
if ap.modes.vert_arm.m then love.graphics.print(ap.modes.vert_arm.m, FONT, 0.6*SCREENWIDTH, 0.11*SCREENHEIGHT, 0, sx, sy) end

-- SMALL FONTS: SR, HB, CWS
sx= 0.5
sy = sx
love.graphics.setColor(white)
if ap.aux.SR then love.graphics.print("SR", FONT, 0.2*SCREENWIDTH, 0.06*SCREENHEIGHT, 0, sx, sy) end
if ap.aux.HB then love.graphics.print("HB", FONT, 0.2*SCREENWIDTH, 0.11*SCREENHEIGHT, 0, sx, sy) end
if ap.aux.CWS then love.graphics.print("CWS", FONT, 0.2*SCREENWIDTH, 0.16*SCREENHEIGHT, 0, sx, sy) end
if true then love.graphics.print("LOC", FONT, 0.7*SCREENWIDTH, 0.78*SCREENHEIGHT, 0, sx, sy) end

-- markers
sx, sy = scale_factor(markers.IM, 1/25)
if ap.IM then love.graphics.draw(markers.IM, 0.12*SCREENWIDTH, 0.8*SCREENHEIGHT, 0, sx, sy) end
if ap.MM then love.graphics.draw(markers.MM, 0.12*SCREENWIDTH, 0.82*SCREENHEIGHT, 0, sx, sy) end
if ap.OM then love.graphics.draw(markers.OM, 0.12*SCREENWIDTH, 0.84*SCREENHEIGHT, 0, sx, sy) end

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
        love.graphics.print(string.format("a = %.1f", dv.a), 0.85*SCREENWIDTH, 0.55*SCREENHEIGHT)

        -- l 
        love.graphics.setColor(0, 0, 1, 1)
        love.graphics.print(string.format("l = %.4f", dv.l), 0.5*SCREENWIDTH, 0.8*SCREENHEIGHT)

        -- h
        love.graphics.setColor(0, 0.5, 0.5, 1)
        love.graphics.print(string.format("h = %.1f", 360*math.sin(dv.h)), 0.7*SCREENWIDTH, 0.8*SCREENHEIGHT)

    end

    
end

function scale_factor(img, sf)
    -- compare image size to screen size
    -- aspectRatio = SCREENWIDTH / SCREENHEIGHT
    local sy =  sf * SCREENHEIGHT / img:getHeight()
    return sy, sy
end

function love.wheelmoved(x, y)
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
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    if id == 1 then
        if dx > 0 then
            dv.l = dv.l + 0.1
        elseif dx < 0 then
            dv.l = dv.l - 0.1
        end

        if dy > 0 then
            dv.a = dv.a + 0.01
        elseif dy < 0 then
            dv.a = dv.a - 0.01
        end
    else
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

    