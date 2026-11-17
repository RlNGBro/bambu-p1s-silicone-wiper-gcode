import fs from 'node:fs';
import assert from 'node:assert/strict';
const files = ['latest/machine_start.gcode', 'latest/machine_end.gcode'];
const texts = files.map(f => fs.readFileSync(f, 'utf8'));
const commands = s => s.split(/\r?\n/).map(l => l.split(';')[0].trim()).filter(Boolean);
const [start, end] = texts.map(commands);
const results = [];
for (let i = 0; i < files.length; i++) {
  let conditional = 0, firmware = 0;
  for (const l of commands(texts[i])) {
    assert(!/\*\*|&#x|\\/.test(l), 'Pasted markup remains');
    if (/^\{if\b/.test(l)) conditional++;
    if (/^\{(?:else|elsif)\b/.test(l)) assert(conditional > 0);
    if (/^\{endif\}/.test(l)) assert(--conditional >= 0);
    if (/^M622\s/.test(l)) firmware++;
    if (/^M623\b/.test(l)) assert(--firmware >= 0);
    assert(!/^G[01]\s.*\bZ-/.test(l), 'Negative-Z hard wipe remains');
  }
  assert.equal(conditional, 0);
  assert.equal(firmware, 0);
  results.push({file: files[i], conditional_blocks: 'balanced', pasted_markup: 'none', negative_Z_G0_G1: 'none'});
}
assert(start.indexOf('G28 Z P0 T300') < start.findIndex(l => l.startsWith('G29 A ')));
assert(start.indexOf('G29.2 S0') < start.indexOf('G29.2 S1'));
const initialTool = start.indexOf('T[initial_extruder]');
const initialLoadComplete = start.indexOf('M621 S[initial_extruder]A');
assert(initialTool>=0&&initialLoadComplete>initialTool);
assert.deepEqual(start.slice(initialTool+1,initialLoadComplete),['G1 X54 F12000','G1 Y265 F3000','M400'],'Do not introduce a forward Y detour after initial AMS tool selection');
results.push({initial_AMS_post_T_moves:['X54','Y265'],added_Y245_detour:false,firmware_internal_motion:'not simulated'});
const primeIndex = start.indexOf('G1 E2 F300');
const retractions = start.slice(0, primeIndex).filter(l => /^G[01]\s+E-/.test(l));
const debt = -retractions.reduce((s,l) => s + Number(l.match(/E(-?[\d.]+)/)[1]), 0);
assert.equal(debt, 1);
for (const p of [1, 2]) {
  const fanCommands = start.slice(0, primeIndex).filter(l => l.startsWith(`M106 P${p} `));
  assert.equal(fanCommands.at(-1), `M106 P${p} S0`);
}
const segments = start.slice(primeIndex + 1, primeIndex + 3).map(l => ({
  x: Number(l.match(/\bX([\d.]+)/)[1]), e: Number(l.match(/\bE([\d.]+)/)[1]), f: Number(l.match(/\bF([\d.]+)/)[1])
}));
assert.equal(segments[0].x - 18, 20);
assert.equal(segments[1].x - segments[0].x, 202);
assert.equal(segments[0].e + segments[1].e, 15);
assert.deepEqual(segments.map(s => s.f / 60), [15, 30]);
results.push({pre_line_explicit_retraction_mm: debt, prime_mm: 2, first_line_E_mm: 15, speeds_mm_per_s: [15, 30]});
// Regression: retain four second-stage round trips, split 1 at 190 C + 3 after 140 C.
const lastWipeRetraction = start.lastIndexOf('G1 E-0.5 F300',primeIndex);
const coolingSet = start.indexOf('M104 S190');
const coolingWait = start.indexOf('M109 S190');
const settlingWait = start.indexOf('G4 S15');
const levelingSet = start.indexOf('M104 S140');
const levelingWait = start.indexOf('M109 S140');
const secondWipeExit = start.findIndex((l,i)=>i>settlingWait&&l==='G1 X165 F12000');
const leveling = start.findIndex(l=>l.startsWith('G29 A '));
assert(lastWipeRetraction<coolingSet&&coolingSet<coolingWait&&coolingWait<settlingWait&&settlingWait<levelingSet&&levelingSet<levelingWait&&levelingWait<secondWipeExit&&secondWipeExit<leveling);
const firstWipe = start.slice(lastWipeRetraction+1,coolingSet);
assert.equal(firstWipe.filter(l=>l==='G1 X100 F5000').length,4);
assert.equal(firstWipe.filter(l=>l==='G1 X70 F15000').length,4);
assert.deepEqual(firstWipe.slice(-3),['M400','G1 X54 F5000','M400']);
assert(!start.slice(coolingSet,settlingWait+1).some(l=>/^G[01]\s/.test(l)),'Movement during cooling/settling wait');
const secondWipe = start.slice(settlingWait+1,levelingSet);
assert.deepEqual(secondWipe,['G1 X70 F5000','G1 X100 F5000','G1 X70 F15000','M400','G1 X54 F5000','M400']);
assert.deepEqual(start.slice(levelingSet,levelingWait+1),['M104 S140','M109 S140']);
const finalStartWipe = start.slice(levelingWait+1,secondWipeExit);
assert.deepEqual(finalStartWipe,[
  'G1 X70 F5000',
  'G1 X100 F5000','G1 X70 F15000',
  'G1 X100 F5000','G1 X70 F15000',
  'G1 X100 F5000','G1 X70 F15000',
  'M400','G1 X100 F5000'
],'Final three cleanup trips must follow the 140 C wait and precede exit');
const combinedSecondStage = start.slice(settlingWait+1,secondWipeExit);
assert.equal(combinedSecondStage.filter(l=>l==='G1 X70 F15000').length,4,'Do not add extra complete round trips');
const reheat = start.findIndex((l,i)=>i>coolingWait&&/^M104 S\{nozzle_temperature_initial_layer/.test(l));
assert(reheat>leveling);
assert(!start.slice(coolingSet,reheat).some(l=>/^G[01]\s.*\bE/.test(l)),'Cold E move introduced');
assert.deepEqual(start.slice(coolingWait+1,reheat).filter(l=>/^M10[49]\b/.test(l)),['M104 S140','M109 S140'],'Unexpected temperature change before leveling/homing');
// Verify the new waits use exactly the same explicit XY as the stock initial purge.
const stockStart = commands(fs.readFileSync('original/machine_start.gcode','utf8'));
function lastExplicitXY(lines,until) {
  let x,y;
  for(const l of lines.slice(0,until)) {
    if(/^T/.test(l)){x=undefined;y=undefined;}
    if(!/^G[01]\s/.test(l))continue;
    const mx=l.match(/\bX(-?[\d.]+)/),my=l.match(/\bY(-?[\d.]+)/);
    if(mx)x=Number(mx[1]);if(my)y=Number(my[1]);
  }
  return [x,y];
}
const stockPurgeXY=lastExplicitXY(stockStart,stockStart.indexOf('G1 E50 F200'));
assert.deepEqual(stockPurgeXY,[54,265]);
assert.deepEqual(lastExplicitXY(start,coolingWait),stockPurgeXY);
assert.deepEqual(lastExplicitXY(start,levelingWait),stockPurgeXY);
results.push({second_stage_round_trips_at_190:1,second_stage_round_trips_after_140:3,second_stage_total_round_trips:4,cooling_wait_position:stockPurgeXY,waiting_position_source:'stock initial purge explicit XY',cold_E_moves:0,retraction_mm:debt});
assert(end.indexOf('M621 S255') < end.indexOf('M109 S190'));
assert(!end.slice(end.indexOf('T255') + 1).some(l => /^G[01]\s.*\bE/.test(l)));
assert.equal(end.filter(l => l === 'G4 S35').length, 1);
assert(!end.includes('G4 S60'));
assert.equal(end.filter(l=>l==='G4 S15').length,1);
assert.equal(end[end.indexOf('M621 S255')+1],'M400');
const wipeStart = end.indexOf('M109 S190');
const unloadEnd = end.indexOf('M621 S255');
const endTempSet = end.indexOf('M104 S190');
const unloadReturn = end.slice(end.indexOf('T255')+1,unloadEnd);
assert.deepEqual(unloadReturn,['G1 X65 F12000','G1 Y245 F12000','G1 Y265 F3000'],'Premature post-unload outer sweep was reintroduced');
assert.deepEqual(end.slice(unloadEnd+1,endTempSet),['M400','G90','M83','G1 X54 F5000','G1 Y265 F3000','M400'],'Stock purge waiting point must be set after the macro');
assert.deepEqual(lastExplicitXY(end,endTempSet),stockPurgeXY);
assert.deepEqual(end.slice(endTempSet,wipeStart+2),['M104 S190','M106 P1 S255','M109 S190','G4 S15'],'Movement or macro inserted during inner-endpoint cooling');
assert.equal(end[wipeStart+1],'G4 S15');
const finalWipe = end.slice(wipeStart + 2, end.indexOf('M104 S0'));
assert.equal(finalWipe.filter(l => l==='G1 X70 F15000').length, 3);
assert.equal(finalWipe.filter(l => l==='G1 X70 F5000').length, 1);
assert.equal(finalWipe.filter(l => /^G1 X100\b/.test(l)).length, 4);
assert(!finalWipe.some(l => /^G[01]\s.*\b[YZ]/.test(l)));
assert.deepEqual(finalWipe,['G1 X70 F5000','G1 X100 F5000','G1 X70 F15000','G1 X100 F5000','G1 X70 F15000','G1 X100 F5000','G1 X70 F15000','G1 X100 F5000','M400']);
assert(!end.slice(end.indexOf('M104 S0')+1).some(l => /^G[01]\s.*\b[XY]/.test(l)));
results.push({waiting_xy:stockPurgeXY,approach:'X54 -> X70 after cooling',first_wipe:'X70 -> X100',final_wipe_round_trips:3,separate_outward_parking_passes:1,final_explicit_park:[100,265],stock_end_park_retained:true});
for(const [name,lines] of [['start',start],['end',end]]) {
  const cutter=lines.indexOf('G1 Y-3');
  assert(cutter>0);
  const moves=lines.slice(0,cutter+1).filter(l=>/^G[01]\s/.test(l)).slice(-5);
  assert.deepEqual(moves,['G1 X165 F12000','G1 Y256 F3000','G1 Y50 F12000','G1 X20 F12000','G1 Y-3'],`${name}: cutter route must move forward before left`);
  results.push({template:name,cutter_route:'X165 at Y265 -> Y256 -> Y50 -> X20 -> Y-3',axis_separated:true});
}

// Evaluate only numeric height conditionals from the actual end template.
// This is a static branch check, not a Bambu slicer or firmware emulator.
function endAtHeight(height) {
  const stack = [], emitted = [];
  const active = () => stack.every(s => s.active);
  const evaluate = expr => {
    const replaced = expr.replaceAll('max_layer_z', String(height));
    assert(/^[\d.\s()+\-<>=*/]+$/.test(replaced));
    return Function(`"use strict";return (${replaced});`)();
  };
  for (const l of end) {
    if (l.startsWith('{if ')) { const match = Boolean(evaluate(l.slice(4, -1))); stack.push({match, active:match}); continue; }
    if (l.startsWith('{elsif ')) {
      const branch = stack.at(-1), match = Boolean(evaluate(l.slice(7, -1)));
      branch.active = !branch.match && match;
      branch.match ||= match;
      continue;
    }
    if (l === '{else}') { stack.at(-1).active = !stack.at(-1).match; continue; }
    if (l === '{endif}') { stack.pop(); continue; }
    if (active()) emitted.push(l.replace(/\{([^}]+)\}/g, (_, expr) => evaluate(expr)));
  }
  return emitted;
}
const heights = [0.2, 149.9, 150, 247.5, 248, 249.5, 250];
for (const h of heights) {
  const z = endAtHeight(h).filter(l => /^G1 Z/.test(l)).map(l => Number(l.match(/Z([\d.]+)/)[1]));
  assert(z.every(v => v <= 250 && v >= Math.min(h + 0.5, 250)), `Z clearance/limit at ${h}: ${z}`);
  const expanded = endAtHeight(h);
  const on = expanded.indexOf('M106 P2 S255');
  const off = expanded.indexOf('M106 P2 S0', on + 1);
  assert.equal(expanded[on + 1], 'M106 P3 S255');
  assert.equal(expanded[off + 1], 'M106 P3 S0');
  const fanWindow = expanded.slice(on, off);
  assert(!fanWindow.includes('M106 P2 S0') && !fanWindow.includes('M106 P3 S0'));
  assert(fanWindow.indexOf('G4 S35') < fanWindow.findIndex(l => /^G1 Z/.test(l)));
  assert(fanWindow.indexOf('M220 S100') < fanWindow.findIndex(l => /^G1 Z/.test(l)));
  assert(fanWindow.indexOf('M17 R') < fanWindow.findIndex(l => /^G4 P/.test(l)));
  let currentZ = z[0], seconds = 0;
  for (const l of fanWindow) {
    if (/^G1 Z/.test(l)) {
      const nextZ = Number(l.match(/Z([\d.]+)/)[1]);
      const feed = Number(l.match(/F([\d.]+)/)[1]);
      seconds += Math.abs(nextZ - currentZ) / (feed / 60);
      currentZ = nextZ;
    } else if (/^G4 [SP]/.test(l)) {
      const [, unit, value] = l.match(/^G4 ([SP])([\d.]+)/);
      assert(Number(value) >= 0);
      seconds += Number(value) / (unit === 'P' ? 1000 : 1);
    } else if (l === 'M400 P100') seconds += 0.1;
  }
  assert(Math.abs(seconds - 60) < 1e-8, `Fan nominal duration at ${h}: ${seconds}`);
  results.push({max_layer_z:h, commanded_Z:z, both_fans_nominal_seconds:Number(seconds.toFixed(6)), bed_hold_seconds:35});
}
// Match explicit added exits to the official Y265 -> X165 -> Y256 sequence.
// The retained stock Y264 Z-reference diagonal is outside the cutter route.
// These are last-explicit-coordinate checks, not firmware or geometry simulation.
for (const [name, lines] of [['start',start], ['end',endAtHeight(20)]]) {
  let x, y; let exits = 0;
  for (const l of lines) {
    if (!/^G[01]\s/.test(l)) continue;
    const mx = l.match(/\bX(-?[\d.]+)/), my = l.match(/\bY(-?[\d.]+)/);
    if (my && y > 260 && Number(my[1]) < y) {
      const stockZReferenceTravel = name === 'start' && x === 100 && y === 264 && l === 'G0 X135 Y253 F12000';
      assert(stockZReferenceTravel || (x === 165 && y === 265 && !mx && Number(my[1]) === 256), `${name} unexpected rear departure: ${l}`);
      exits++;
    }
    if (mx) x = Number(mx[1]);
    if (my) y = Number(my[1]);
  }
  results.push({template:name, explicit_rear_departures_checked:exits});
}
fs.mkdirSync('work',{recursive:true});
fs.writeFileSync('work/check-results.json', JSON.stringify({status:'PASS', type:'static command/order checks only',geometry_validation:'NOT_PERFORMED', results}, null, 2));
console.log(JSON.stringify({status:'PASS', start_lines:start.length, end_lines:end.length, height_cases:heights.length, results}, null, 2));
