;========Date 20250206 / silicone exit revision r4 20261111========
; Based on the installed Bambu Studio 2.8.2.61 P1S 0.4 template.
; SLICER TEMPLATE: paste into Time lapse G-code; do not send directly.
; At established Y265, reuse the stock X165 then Y256 exit.
; Screen/App pause and runout-refill recovery are unmodified.
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firmware, default turned on
M1002 judge_flag timelapse_record_flag
M622 J1
{if timelapse_type == 0} ; timelapse without wipe tower
M971 S11 C10 O0
M1004 S5 P1  ; external shutter
{elsif timelapse_type == 1} ; timelapse with wipe tower
G92 E0
G1 X65 Y245 F20000 ; move to safe pos
G17
G2 Z{layer_z} I0.86 J0.86 P1 F20000
G1 Y265 F3000
M400
M1004 S5 P1  ; external shutter
M400 P300
M971 S11 C11 O0
G92 E0
G1 X100 F5000
G1 X165 F12000 ; stock lateral sweep at established Y265
G1 Y256 F3000 ; stock forward exit
G1 Y255 F3000
G1 X100 F20000 ; retain the stock final XY position and modal feedrate
{endif}
M623
; SKIPPABLE_END
