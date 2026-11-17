;===== date: 20230428 =====================
M400 ; wait for buffer to clear
G92 E0 ; zero the extruder
G1 E-0.8 F1800 ; retract
G1 Z{max_layer_z + 0.5} F900 ; lower z a little

;===== modified silicone nozzle wipe ===============================
; Move to the modified rear silicone wiper, cool with the part fan, then wipe.
G1 X60 Y265 F12000 ; move to the modified waste/wiper area
M104 S190 ; set the cooling target
M106 S255 ; nozzle part-cooling fan 100%
M109 S190 ; wait until the nozzle is at 190C or below

G92 E0
G1 E-2 F300 ; retract before wiping
G1 X100 F5000 ; second wipe mouth
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000

G4 S15 ; wait for pressure release, then wipe again
G1 X100 F5000 ; third wipe mouth
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000

G1 X90 F5000
G0 X128 Y261 ; leave the modified wiper without a negative-Z wipe
G1 X128 Y10 F20000
M106 S0 ; part-cooling fan off after wiping
;===== modified silicone nozzle wipe end ================================

M140 S0 ; turn off bed
M106 P2 S0 ; turn off remote part cooling fan
M106 P3 S0 ; turn off chamber cooling fan

; pull back filament to AMS
M620 S255
G1 X20 Y50 F12000
G1 Y-3
T255
G1 X65 F12000
G1 Y265
G1 X100 F12000 ; retain the AMS unload alignment move
M621 S255
M104 S0 ; turn off hotend

M622.1 S1 ; for prev firware, default turned on
M1002 judge_flag timelapse_record_flag
M622 J1
    M400 ; wait all motion done
    M991 S0 P-1 ;end smooth timelapse at safe pos
    M400 S3 ;wait for last picture to be taken
M623; end of "timelapse_record_flag"

M400 ; wait all motion done
M17 S
M17 Z0.4 ; lower z motor current to reduce impact if there is something in the bottom

;===== auxiliary and chamber fans during bed lowering =================
M106 P2 S255 ; auxiliary fan 100%
M106 P3 S255 ; chamber fan 100%
{if (max_layer_z + 100.0) < 250}
    G1 Z{max_layer_z + 100.0} F600
    G1 Z{max_layer_z +98.0}
{else}
    G1 Z250 F600
    G1 Z248
{endif}
M400 P100
G4 S60 ; keep both fans on for one minute from bed lowering start
M106 P2 S0 ; auxiliary fan off
M106 P3 S0 ; chamber fan off
M400
M17 R ; restore z current

M220 S100  ; Reset feedrate magnitude
M201.2 K1.0 ; Reset acc magnitude
M73.2   R1.0 ;Reset left time magnitude
M1002 set_gcode_claim_speed_level : 0

M17 X0.8 Y0.8 Z0.5 ; lower motor current to 45% power
