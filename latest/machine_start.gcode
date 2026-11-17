;===== machine: P1S-0.4 ========================
;===== revised: 20261112 r7 / user baseline: 20251031 =====
; SLICER TEMPLATE: paste into Machine start G-code; do not send directly.
; P1S / 0.4 mm / PETG / BIQU Glacier, rear silicone wiper.
; At established Y265 exits, use the stock X165 then Y256 sequence.
; Screen/App pause and runout-refill recovery remain firmware-controlled and unmodified.
;===== turn on the HB fan & MC board fan =================
M104 S75 ;set extruder temp to turn on the HB fan and prevent filament oozing from nozzle
M710 A1 S255 ;turn on MC fan by default(P1S)
;===== reset machine status =================
M290 X40 Y40 Z2.6666666
G91
M17 Z0.4 ; lower the z-motor current
G380 S2 Z30 F300 ; G380 is same as G38; lower the hotbed , to prevent the nozzle is below the hotbed
G380 S2 Z-25 F300 ;
G1 Z5 F300;
G90
M17 X1.2 Y1.2 Z0.75 ; reset motor current to default
M960 S5 P1 ; turn on logo lamp
G90
M220 S100 ;Reset Feedrate
M221 S100 ;Reset Flowrate
M73.2   R1.0 ;Reset left time magnitude
M1002 set_gcode_claim_speed_level : 5
M221 X0 Y0 Z0 ; turn off soft endstop to prevent protential logic problem
G29.1 Z{+0.0} ; clear z-trim value first
M204 S10000 ; init ACC set to 10m/s^2

;===== heatbed preheat ====================
M1002 gcode_claim_action:54
M140 S[bed_temperature_initial_layer_single] ;set bed temp
M190 S[bed_temperature_initial_layer_single] ;wait for bed temp



;=============turn on fans to prevent PLA jamming=================
{if filament_type[initial_extruder]=="PLA"}
    {if (bed_temperature[initial_extruder] >45)||(bed_temperature_initial_layer[initial_extruder] >45)}
    M106 P3 S180
    {endif};Prevent PLA from jamming
{endif}
M106 P2 S100 ; turn on big fan ,to cool down toolhead

;===== prepare print temperature and material ==========
M104 S[nozzle_temperature_initial_layer] ;set extruder temp
G91
G0 Z10 F1200
G90
G28 X
M975 S1 ; turn on
G1 X60 F12000
G1 Y245
G1 Y265 F3000
M620 M
M620 S[initial_extruder]A   ; switch material if AMS exist
    M109 S[nozzle_temperature_initial_layer]
    G1 X165 F12000 ; stock lateral exit at Y265
    G1 Y256 F3000

    G1 Y50 F12000 ; forward first, away from rear motors
    G1 X20 F12000 ; move left only after reaching front Y50
    G1 Y-3
    T[initial_extruder]
    G1 X54 F12000
    G1 Y265 F3000 ; retain direct stock return; no added Y245 forward/back detour
    M400
M621 S[initial_extruder]A
M620.1 E F{flush_volumetric_speeds[initial_no_support_extruder]/2.4053*60} T{flush_temperatures[initial_no_support_extruder]}


M412 S1 ; ===turn on filament runout detection===

M83 ; explicit relative extrusion before purge/retraction
M109 S250 ;set nozzle to common flush temp
M106 P1 S0
G92 E0
G1 E40 F200 ; retain user purge amount
M400
M104 S[nozzle_temperature_initial_layer]
G92 E0
G1 E40 F200 ; retain user purge amount
M400
M106 P1 S255
; User extra E5 purge remains disabled.
M109 S{nozzle_temperature_initial_layer[initial_extruder]-20} ; drop nozzle temp, make filament shink a bit
G92 E0
G1 E-0.5 F300

G1 X70 F9000
G1 X76 F15000
G1 X65 F15000
G1 X76 F15000
G1 X65 F15000; shake to put down garbage
G1 X80 F6000
G1 X95 F15000
G1 X80 F15000
G1 X165 F15000; wipe and shake
M400
M106 P1 S0
G1 Y256 F3000 ; stock X165/Y265 lateral move above, then stock forward exit
;===== prepare print temperature and material end =====


;===== silicone wipe and Z reference =====================
M1002 gcode_claim_action : 14
M975 S1
M106 P1 S255
G1 X65 Y230 F18000
G1 Y264 F3000
M109 S{nozzle_temperature_initial_layer[initial_extruder]-20}
G1 X100 F5000
; Restore stock Z reference separately from the removed negative-Z hard wipe.
G0 X135 Y253 F12000 ; retain the stock Y264 exit; do not transplant a Y265 route
G28 Z P0 T300
G29.2 S0
G0 Z5 F1200

G1 X60 Y245 F12000
G1 Y265 F3000
M83
G92 E0
G1 E-0.5 F300 ; total explicit pre-line retraction = 1.0 mm
M106 P1 S255 ; Z homing may have stopped this fan
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
M400 ; finish the first silicone wipe before the cooling wait
G1 X54 F5000 ; return to the stock initial purge position, not the wipe edge
M400
M104 S190 ; PETG silicone-wipe TRIAL target, not a validated no-ooze threshold
M106 P1 S255
M109 S190 ; wait at the stock purge position X54/Y265
G4 S15 ; keep the existing dwell, now AFTER reaching the cooling target
; Split the existing four round trips: one warm, three AFTER cooling to 140 C.
; No extra round trips or E moves are added.
G1 X70 F5000 ; approach the wipe start only after the temperature wait
G1 X100 F5000
G1 X70 F15000
M400 ; finish the single warm round trip before cooling further
G1 X54 F5000 ; collect any continued ooze at the stock purge position
M400
M104 S140 ; separate stock pre-leveling target from the silicone-wipe target
M109 S140 ; stay at X54/Y265 until the leveling target is reached
; Final residue cleanup after the interval in which the user observed new ooze.
; Three X70 -> X100 -> X70 round trips; effectiveness at 140 C is not guaranteed.
G1 X70 F5000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
M400
G1 X100 F5000
G1 X165 F12000 ; stock lateral sweep at established Y265
G1 Y256 F3000 ; stock forward exit, no Y10 detour
; Keep the 140 C target through the following leveling/homing branch.
G1 Z10 F1200
M400
G1 X230 Y15 F12000
G29.2 S1
M106 P1 S0
;===== silicone wipe and Z reference end =================


;===== bed leveling ==================================
M1002 judge_flag g29_before_print_flag
M622 J1

    M1002 gcode_claim_action : 1
    G29 A X{first_layer_print_min[0]} Y{first_layer_print_min[1]} I{first_layer_print_size[0]} J{first_layer_print_size[1]}
    M400
    M500 ; save cali data

M623
;===== bed leveling end ================================

;===== home after wipe mouth============================
M1002 judge_flag g29_before_print_flag
M622 J0

    M1002 gcode_claim_action : 13
    G28

M623
;===== home after wipe mouth end =======================

M975 S1 ; turn on vibration supression


;=============turn on fans to prevent PLA jamming=================
{if filament_type[initial_extruder]=="PLA"}
    {if (bed_temperature[initial_extruder] >45)||(bed_temperature_initial_layer[initial_extruder] >45)}
    M106 P3 S180
    {endif};Prevent PLA from jamming
{endif}
M106 P2 S100 ; turn on big fan ,to cool down toolhead


M104 S{nozzle_temperature_initial_layer[initial_extruder]} ; set extrude temp earlier, to reduce wait time

;===== mech mode fast check============================
G1 X128 Y128 Z10 F20000
M400 P200
M970.3 Q1 A7 B30 C80  H15 K0
M974 Q1 S2 P0

G1 X128 Y128 Z10 F20000
M400 P200
M970.3 Q0 A7 B30 C90 Q0 H15 K0
M974 Q0 S2 P0

M975 S1
G1 F30000
G1 X230 Y15
G28 X ; re-home XY
;===== fmech mode fast check============================


;===== nozzle load line: PETG slow lead-in =================
M975 S1
G90
M83
T1000
; BIQU Glacier: select Smooth PEI / High Temp Plate in the slicer.
; Keep stock textured-PEI correction conditional; it does not apply to Smooth PEI.
;curr_bed_type={curr_bed_type}
{if curr_bed_type=="Textured PEI Plate"}
G29.1 Z{-0.04}
{endif}
M106 P1 S0 ; stop part cooling before laying the line
M106 P2 S0 ; stop auxiliary cooling before laying the line
G1 X18.0 Y1.0 F18000
G1 Z0.8 F1200
M109 S{nozzle_temperature_initial_layer[initial_extruder]}
G1 Z0.2 F600
G92 E0
G1 E2 F300 ; stock prime, now exceeds total explicit retraction (1.0 mm)
G1 X38 E1.35135 F900 ; first 20 mm at 15 mm/s
G1 X240 E13.64865 F1800 ; remaining 202 mm at 30 mm/s; total E15
G1 Y11 E0.700 F1200
G1 X239.5 F1200
G1 E0.2 F300
G1 Y1.5 E0.700 F1200
G1 X18 E15 F1800
M400

;========turn off light and wait extrude temperature =============
M1002 gcode_claim_action : 0
M106 S0 ; turn off fan
M106 P2 S0 ; turn off big fan
M106 P3 S0 ; turn off chamber fan

M975 S1 ; turn on mech mode supression
