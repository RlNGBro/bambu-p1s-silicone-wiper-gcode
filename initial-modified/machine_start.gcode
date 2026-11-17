;===== machine: P1S-0.4 ========================
;===== fused version: official safety + modified silicone wiper logic =====
;===== date: 20260618 =====================
;===== main purpose: keep modified rear silicone wiping, do NOT use original negative-Z hard wipe =====

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
    {if (bed_temperature[initial_extruder] >50)||(bed_temperature_initial_layer[initial_extruder] >50)}
    M106 P3 S255
    {elsif (bed_temperature[initial_extruder] >45)||(bed_temperature_initial_layer[initial_extruder] >45)}
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
    G1 X120 F12000

    G1 X20 Y50 F12000
    G1 Y-3
    T[initial_extruder]
    G1 X54 F12000
    G1 Y265
    M400
M621 S[initial_extruder]A

;===== keep modified M620.1 test logic =================
; Official uses flush_volumetric_speeds / flush_temperatures.
; This modified line uses filament max volumetric speed and high nozzle temperature range.
M620.1 E F{filament_max_volumetric_speed[initial_extruder]/2.4053*60} T{nozzle_temperature_range_high[initial_extruder]}


M412 S1 ; ===turn on filament runout detection===

M109 S250 ;set nozzle to common flush temp
M106 P1 S0
G92 E0
G1 E40 F200 ; modified: reduce first flush from E50 to E40
M400
M104 S[nozzle_temperature_initial_layer]
G92 E0
G1 E40 F200 ; modified: reduce second flush from E50 to E40
M400
M106 P1 S255
;G92 E0
;G1 E5 F300 ; modified: disabled extra E5 flush
M109 S{nozzle_temperature_initial_layer[initial_extruder]-25} ; drop nozzle temp, make filament shrink a bit
M104 S{nozzle_temperature_initial_layer[initial_extruder]-40} ; modified: continue cooling while wiping
G92 E0
G1 E-3 F300 ; modified: larger retract before silicone wiping

G1 X70 F9000 ;快速移动X轴到70mm的位置，速度为9000mm/min
G1 X76 F15000
G1 X65 F15000
G1 X76 F15000
G1 X65 F15000; shake to put down garbage
G1 X80 F6000
G1 X95 F15000
G1 X80 F15000
G1 X165 F15000; wipe and shake
M400
;M106 P1 S0 ; keep fan P1 on as modified version
;===== prepare print temperature and material end =====


;===== modified silicone nozzle wipe ===============================
; Keep the modified rear silicone wiping purpose.
; Do NOT restore the official negative-Z hard wipe here.

M104 S{nozzle_temperature_initial_layer[initial_extruder]-60} ; cool down more while wiping

G1 X60 Y265 ; move to modified rear silicone wiper area
G92 E0
G1 E-2 F300 ; retract more before wiping
G1 X100 F5000 ; second wipe mouth
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000

G4 S15 ; wait for pressure release, then wipe again
;G1 E-2 F300 ; optional extra retract, keep disabled
G1 X100 F5000 ; third wipe mouth
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000

G1 X90 F5000
G0 X128 Y261 ; modified: XY move only, no negative Z hard wipe
G1 X128 Y10 F20000
G92 E0
;G1 E-1 F300 ; optional extra retract, keep disabled
M104 S140 ; set temp down to heatbed acceptable
M106 S255 ; turn on fan to cool nozzle

;===== official hard wipe intentionally disabled for modified silicone wiper =====
;M1002 gcode_claim_action : 14
;M975 S1
;M106 S255
;G1 X65 Y230 F18000
;G1 Y264 F6000
;M109 S{nozzle_temperature_initial_layer[initial_extruder]-20}
;G1 X100 F18000 ; first wipe mouth
;G0 X135 Y253 F20000
;G28 Z P0 T300
;G29.2 S0
;G0 Z5 F20000
;M221 S
;M221 Z0
;G0 X125 Y259.5 Z-1.01
;G0 Z-1.01
;G0 X128 Y261 Z-1.5 F20000
;G2 I0.5 J0 F300

M109 S140 ; wait nozzle temp down to heatbed acceptable

;M221 R ; official pop softend status, not needed because M221 S/Z0 is disabled
;G29.2 S1 ; official ABL restore, not needed because G29.2 S0 is disabled
;G28 ; home again after hard wipe mouth
M106 S0 ; turn off fan , too noisy
;===== modified silicone nozzle wipe end ================================


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
    {if (bed_temperature[initial_extruder] >50)||(bed_temperature_initial_layer[initial_extruder] >50)}
    M106 P3 S255
    {elsif (bed_temperature[initial_extruder] >45)||(bed_temperature_initial_layer[initial_extruder] >45)}
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


;===== nozzle load line ===============================
M975 S1
G90
M83
T1000
G1 X18.0 Y1.0 Z0.8 F18000;Move to start position
M109 S{nozzle_temperature_initial_layer[initial_extruder]}
G1 Z0.2
G0 E2 F300
G0 X240 E15 F{outer_wall_volumetric_speed/(0.3*0.5)     * 60}
G0 Y11 E0.700 F{outer_wall_volumetric_speed/(0.3*0.5)/ 4 * 60}
G0 X239.5
G0 E0.2
G0 Y1.5 E0.700
G0 X18 E15 F{outer_wall_volumetric_speed/(0.3*0.5)     * 60}
M400

;===== for Textured PEI Plate , lower the nozzle as the nozzle was touching topmost of the texture when homing ==
;curr_bed_type={curr_bed_type}
{if curr_bed_type=="Textured PEI Plate"}
G29.1 Z{-0.04} ; for Textured PEI Plate
{endif}
;========turn off light and wait extrude temperature =============
M1002 gcode_claim_action : 0
M106 S0 ; turn off fan
M106 P2 S0 ; turn off big fan
M106 P3 S0 ; turn off chamber fan

M975 S1 ; turn on mech mode supression
