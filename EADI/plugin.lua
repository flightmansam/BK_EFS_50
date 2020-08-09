local run_plugin = true 

local socket = require "socket"
local ffi = require "ffi"
address, port = "127.0.0.1", 49002
udp = socket.udp()
udp:settimeout(0)
udp:setpeername(address, port)

DataRef("AHARS1_pitch", "sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", "readonly")
DataRef("AHARS1_roll",  "sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", "readonly")
DataRef("AHARS1_hdg",   "sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot", "readonly")
DataRef("AHARS1_cas",   "sim/cockpit2/gauges/indicators/calibrated_airspeed_kts_pilot", "readonly")

DataRef("ap_mode",  "sim/cockpit/autopilot/autopilot_mode", "readonly")
DataRef("ap_state", "sim/cockpit/autopilot/autopilot_state", "readonly")
DataRef("ap_sr",    "sim/cockpit2/annunciators/autopilot_soft_ride", "readonly")
DataRef("ap_hb",    "sim/cockpit/warnings/annunciators/autopilot_bank_limit", "readonly")
DataRef("ap_servos",    "sim/cockpit2/autopilot/servos_on", "readonly")
DataRef("ap_yd",    "sim/cockpit/switches/yaw_damper_on", "readonly")



DataRef("fd_pitch", "sim/cockpit/autopilot/flight_director_pitch", "readonly")
DataRef("fd_roll",  "sim/cockpit/autopilot/flight_director_roll", "readonly")
DataRef("fd_mode",  "sim/cockpit2/autopilot/flight_director_mode", "readonly")
DataRef("fd_as", "sim/cockpit2/autopilot/airspeed_dial_kts", "readonly")

DataRef("ralt", "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", "readonly")
DataRef("dh",   "sim/cockpit/misc/radio_altimeter_minimum", "readonly")

DataRef("xp_hsi_selector", "sim/cockpit2/radios/actuators/HSI_source_select_pilot", "readonly")
DataRef("nav1_nav_id", "sim/cockpit2/radios/indicators/nav1_nav_id", "readonly")
DataRef("nav2_nav_id", "sim/cockpit2/radios/indicators/nav2_nav_id", "readonly")
DataRef("gps_nav_id", "sim/cockpit2/radios/indicators/gps_nav_id", "readonly")

DataRef("om", "sim/cockpit2/radios/indicators/outer_marker_signal_ratio", "readonly")
DataRef("mm", "sim/cockpit2/radios/indicators/middle_marker_signal_ratio", "readonly")
DataRef("im", "sim/cockpit2/radios/indicators/inner_marker_signal_ratio", "readonly")

function send_packets()
	
	-- local info_to_print = string.format("%f, %f, %f, %f", pitch, roll, hdg_t, hdg_m)

	-- AHARS1
	local t = {AHARS1_pitch, AHARS1_roll, AHARS1_hdg, AHARS1_cas}  -- array of floating point numbers
	local str = "DATA "..ffi.string(ffi.new("int[1]", 17), 1).."000"..ffi.string(ffi.new("float[?]", #t, t), 4 * #t)
	udp:send(str)

	-- AUTOPILOT
	if ap_mode > 1 then
		if ap_servos == 1 then ap_cws = 0 
		else ap_cws = 1 end
	
	else ap_cws = 0 end
	t = {ap_mode, ap_state, ap_hb/1.0, ap_sr/1.0, ap_cws/1, ap_yd/1}
	str = "DATA "..ffi.string(ffi.new("int[1]", 19), 1).."000"..ffi.string(ffi.new("float[?]", #t, t), 4 * #t)
	udp:send(str)

	-- RALT, DH, 
	t = {ralt, dh}
	str = "DATA "..ffi.string(ffi.new("int[1]", 18), 1).."000"..ffi.string(ffi.new("float[?]", #t, t), 4 * #t)
	udp:send(str)

	-- FLIGHT DIRECTOR
	t = {fd_mode, fd_pitch, fd_roll, fd_as}
	str = "DATA "..ffi.string(ffi.new("int[1]", 20), 1).."000"..ffi.string(ffi.new("float[?]", #t, t), 4 * #t)
	udp:send(str)
	
	-- SELECTED NAV RADIO (this will have to change for EHSI version...)
	t= {}
	-- Handle trigger for EFIS APR mode
	if xp_hsi_selector == 0 then
		if string.sub(nav1_nav_id, 0, 1) == 'I' then
			t.source = "LOC"
		else
			t.source = "VOR"
		end
		t.id = nav1_nav_id
	elseif xp_hsi_selector == 1 then
		if string.sub(nav2_nav_id, 0, 1) == 'I' then
			t.source = "LOC"
		else
			t.source = "VOR"
		end
		t.id = nav2_nav_id
	elseif xp_hsi_selector ==2 then
		t.source = "GPS"
		t.id = gps_nav_id
	else
		-- ADF
		t.source = "ADF"
		t.id = nil
	end
	str = "DATA "..ffi.string(ffi.new("int[1]", 21), 1).."000"..string.format("%3s%s", t.source, t.id)
	udp:send(str)

	-- NAV markers
	t = {om, mm, im}
	str = "DATA "..ffi.string(ffi.new("int[1]", 22), 1).."000"..ffi.string(ffi.new("float[?]", #t, t), 4 * #t)
	udp:send(str)


end

do_every_frame("send_packets()")
add_macro("Enable BK EFS50 UDP", "run_plugin = true", "run_plugin = false", "deactivate")