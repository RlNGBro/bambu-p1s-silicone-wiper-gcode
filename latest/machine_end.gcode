;===== revised: 20261112 r7 / user baseline: 20230428 =====
; SLICER TEMPLATE: paste into Machine end G-code; do not send directly.
; P1S / 0.4 mm / rear silicone wiper. No negative-Z hard wipe.
; At established Y265, use the stock X165 then Y256 exit before travelling to the cutter.
; Screen/App pause and runout-refill recovery remain firmware-controlled and unmodified.
M400
G90
M83
G92 E0
G1 E-0.8 F1800
; Respect the stock 250 mm configured printable height.
{if max_layer_z < 249.5}
    G1 Z{max_layer_z + 0.5} F900
{else}
    G1 Z250 F900
{endif}

M140 S0
M106 P1 S0
M106 P2 S0
M106 P3 S0
G1 X65 Y245 F12000
G1 Y265 F3000
G1 X100 F5000
G1 X165 F12000 ; stock lateral sweep at established Y265
G1 Y256 F3000 ; stock forward exit, then proceed to the cutter

; Unload before cooling/wiping; retain the stock M620/T255/M621 sequence.
M620 S255
G1 Y50 F12000 ; forward first, away from rear motors
G1 X20 F12000 ; move left only after reaching front Y50
G1 Y-3
T255
G1 X65 F12000
G1 Y245 F12000
G1 Y265 F3000
M621 S255
M400 ; finish the unload/return sequence before the temperature wait

; Establish the stock initial purge position AFTER the unload sequence, before cooling.
G90
M83
G1 X54 F5000
G1 Y265 F3000
M400 ; complete purge-position positioning before the temperature wait
; User observed no further ooze at 190 C for this setup; drop direction is still to test.
M104 S190
M106 P1 S255
M109 S190 ; wait at the stock initial purge position X54/Y265
G4 S15 ; settle over the purge position before the final three round trips
G1 X70 F5000 ; approach the wipe start only AFTER cooling/settling
; Three full round trips: X70 -> X100 (outward) -> X70 (return).
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
G1 X100 F5000
G1 X70 F15000
; Separate outward parking pass; not a fourth complete round trip.
G1 X100 F5000
; Stay at the stock end-code park X100/Y265; no additional XY exit is needed.
M400
M104 S0
M106 P1 S0

M622.1 S1
M1002 judge_flag timelapse_record_flag
M622 J1
    M400
    M991 S0 P-1
    M400 S3
M623

M400
; Both fans share one nominal 60 s window. Hold the bed for the first 35 s.
; Air purification here means running the existing P3 chamber exhaust fan.
M106 P2 S255
M106 P3 S255
G4 S35

; Lower the bed during the remaining 25 s, with both fans still running.
; Normalize motion scaling so the F600 timing calculation remains consistent.
M220 S100
M201.2 K1.0
M17 S
M17 Z0.4
{if (max_layer_z + 100.0) < 250}
    G1 Z{max_layer_z + 100.0} F600
    G1 Z{max_layer_z + 98.0} F600
{else}
    G1 Z250 F600
    ; Skip the stock Z248 rebound when it would consume the last 0.5 mm of clearance.
    {if max_layer_z <= 247.5}
        G1 Z248 F600
    {endif}
{endif}
M400 P100
M17 R ; restore Z current before the remaining fan dwell
; F600 = 10 mm/s. Deduct nominal Z travel and the 100 ms M400 delay.
; Acceleration and command overhead are not measurable here: total is ABOUT 60 s.
{if (max_layer_z + 100.0) < 250}
    G4 P14750 ; 25 s - (99.5 + 2)/10 s - 0.1 s
{elsif max_layer_z <= 247.5}
    G4 P{24900 - (251.5 - max_layer_z) * 100}
{elsif max_layer_z < 249.5}
    G4 P{24900 - (249.5 - max_layer_z) * 100}
{else}
    G4 P24900 ; bed is already at the capped Z250 position
{endif}
M106 P2 S0
M106 P3 S0
M400

M220 S100
M201.2 K1.0
M73.2 R1.0
M1002 set_gcode_claim_speed_level : 0
M17 X0.8 Y0.8 Z0.5
