import fs from 'node:fs';
import assert from 'node:assert/strict';
const original = fs.readFileSync('original/change_filament.gcode','utf8');
const revised = fs.readFileSync('latest/change_filament.gcode','utf8');
const originalTime = fs.readFileSync('original/timelapse.gcode','utf8');
const revisedTime = fs.readFileSync('latest/timelapse.gcode','utf8');
const cmds = s => s.split(/\r?\n/).map(l=>l.split(';')[0].trim()).filter(Boolean);
const materialCommands = s => cmds(s).filter(l => /^G[01]\s+E|^G92\b|^M(?:104|109|106|620(?:\.\d+)?|621|628|629)\b|^T/.test(l));
assert.deepEqual(materialCommands(revised),materialCommands(original),'Material / AMS / fan commands changed');
assert.deepEqual(cmds(originalTime).filter(l=>/^M/.test(l)),cmds(revisedTime).filter(l=>/^M/.test(l)),'Timelapse control commands changed');
// Confirm the official lateral span at Y265 before reusing it.
const officialCommands = cmds(original);
const officialExit = officialCommands.indexOf('G1 X165 F15000');
assert(officialExit > 0);
assert.equal(officialCommands[officialExit+1], 'G1 Y256');
assert.equal(officialCommands.slice(0,officialExit).filter(l=>/^G[01]\s.*\bY/.test(l)).at(-1), 'G1 Y265 F5000');
function stockWipeCommands(text) {
  const lines=cmds(text), from=lines.indexOf('M400 S3'),to=lines.findIndex((l,i)=>i>from&&l==='G1 X165 F15000');
  assert(from>=0&&to>from);
  return lines.slice(from,to+1);
}
assert.deepEqual(stockWipeCommands(revised),stockWipeCommands(original),'Official post-flush wiping was changed');
const revisedCommands=cmds(revised);
const cutter=revisedCommands.indexOf('G1 Y-3');
assert(cutter>0);
assert.deepEqual(revisedCommands.slice(0,cutter+1).filter(l=>/^G[01]\s/.test(l)).slice(-5),[
  'G1 X165 F12000','G1 Y256 F3000','G1 Y50 F21000','G1 X20 F21000','G1 Y-3'
],'AMS cutter route must move forward before left, one axis per move');
for(const text of [revised,revisedTime]) {
  let depth=0,firmware=0;
  for(const l of cmds(text)) {
    if(l.startsWith('{if ')) depth++;
    if(/^\{(?:else|elsif)\b/.test(l)) assert(depth>0);
    if(l==='{endif}') assert(--depth>=0);
    if(/^M622\s/.test(l)) firmware++;
    if(/^M623\b/.test(l)) assert(--firmware>=0);
  }
  assert.equal(depth,0);assert.equal(firmware,0);
}

// Numeric/string sample expansion for STATIC branch checks only.
// This does not execute Bambu's template engine or any printer macro.
function expand(text,vars) {
  const scope=Object.keys(vars), values=Object.values(vars), stack=[], result=[];
  const evaluate = expr => Function(...scope,`"use strict"; return (${expr});`)(...values);
  for(const line of cmds(text)) {
    if(line.startsWith('{if ')) { const yes=Boolean(evaluate(line.slice(4,-1)));stack.push({taken:yes,active:yes});continue; }
    if(line.startsWith('{elsif ')) { const top=stack.at(-1),yes=Boolean(evaluate(line.slice(7,-1)));top.active=!top.taken&&yes;top.taken ||= yes;continue; }
    if(line==='{else}') {stack.at(-1).active=!stack.at(-1).taken;continue;}
    if(line==='{endif}') {stack.pop();continue;}
    if(stack.every(s=>s.active)) result.push(line.replace(/\{([^{}]+)\}/g,(_,s)=>evaluate(s)).replace(/\[([a-zA-Z_]\w*)\]/g,(_,s)=>evaluate(s)));
  }
  return result;
}
const base = {
  previous_extruder:0,next_extruder:1,max_layer_z:20,old_filament_temp:250,new_filament_temp:250,
  long_retractions_when_cut:[0,0],retraction_distances_when_cut:[18,18],flush_volumetric_speeds:[8,8],flush_temperatures:[250,250],
  filament_type:['PETG','PETG'],toolchange_count:2,travel_point_1_x:100,travel_point_1_y:200,travel_point_2_x:80,travel_point_2_y:180,travel_point_3_x:70,travel_point_3_y:160,
  flush_length_1:50,flush_length_2:20,flush_length_3:10,flush_length_4:5,old_retract_length_toolchange:2,new_retract_length_toolchange:2,
  layer_z:20,initial_layer_print_height:0.2,initial_layer_acceleration:500,default_acceleration:10000,x_after_toolchange:128,y_after_toolchange:128,z_after_toolchange:20,
};
const scenarios=[
  ['PETG all flush stages',{}],
  ['PVA long retract',{filament_type:['PETG','PVA'],long_retractions_when_cut:[1,0]}],
  ['PLA short flush first layer',{filament_type:['PETG','PLA'],flush_length_1:23.7,flush_length_2:0,flush_length_3:0,flush_length_4:0,layer_z:0.2}],
  ['zero flush',{flush_length_1:0,flush_length_2:0,flush_length_3:0,flush_length_4:0}],
  ['height 246.9',{max_layer_z:246.9}],
  ['height 247',{max_layer_z:247}],
  ['height 249.5',{max_layer_z:249.5}],
  ['height 250',{max_layer_z:250}],
  ['unload only',{next_extruder:255}],
  ['unload only high',{next_extruder:255,max_layer_z:249.5,z_after_toolchange:249.5}],
];
const results=[];
for(const [name,override] of scenarios) {
  const vars={...base,...override};
  if(vars.next_extruder===255) {
    vars.flush_volumetric_speeds=[...vars.flush_volumetric_speeds];vars.flush_volumetric_speeds[255]=8;
    vars.flush_temperatures=[...vars.flush_temperatures];vars.flush_temperatures[255]=250;
  }
  const old=expand(original,vars), lines=expand(revised,vars);
  assert.deepEqual(materialCommands(lines.join('\n')),materialCommands(old.join('\n')));
  let x=128,y=128,z=vars.max_layer_z,relative=false,exits=0;
  for(const l of lines) {
    if(l==='G90') relative=false;
    if(l==='G91') relative=true;
    // Do not invent a post-T macro XY position. It is not supplied by this template.
    if(/^T\d+/.test(l)){x=undefined;y=undefined;}
    if(!/^G[01]\s/.test(l)) continue;
    const mx=l.match(/\bX(-?[\d.]+)/),my=l.match(/\bY(-?[\d.]+)/),mz=l.match(/\bZ(-?[\d.]+)/);
    const ny=my?(relative?y+Number(my[1]):Number(my[1])):y;
    if(Number.isFinite(y)&&y>260&&ny<y) {assert(x===165&&y===265&&ny===256&&!mx,`${name}: differs from stock Y265/X165/Y256 exit ${l}`);exits++;}
    if(mx)x=relative?x+Number(mx[1]):Number(mx[1]);
    if(my)y=ny;
    if(mz){z=relative?z+Number(mz[1]):Number(mz[1]);assert(z<=250,`${name}: Z exceeded 250`);}
  }
  if(vars.next_extruder<255) {assert.equal(x,165);assert.equal(y,256);assert.equal(z,Math.min(vars.max_layer_z+3,250));}
  else {assert.equal(x,vars.x_after_toolchange);assert.equal(y,vars.y_after_toolchange);assert.equal(z,vars.z_after_toolchange);}
  results.push({scenario:name,stock_matched_exits:exits,material_commands:'unchanged',post_flush_wipe:'stock',final_xyz:[x,y,z],macro_internal_path:'UNMODIFIED_NOT_SIMULATED'});
}
for(const type of [0,1]) {
  const vars={timelapse_type:type,layer_z:20},old=expand(originalTime,vars),lines=expand(revisedTime,vars);
  if(type===0)assert.deepEqual(lines,old,'Traditional timelapse was changed');
  else {
    let x,y,f,exits=0;
    for(const l of lines){if(!/^G1\s/.test(l))continue;const mx=l.match(/\bX([\d.]+)/),my=l.match(/\bY([\d.]+)/),mf=l.match(/\bF([\d.]+)/);if(my&&y>260&&Number(my[1])<y){assert(x===165&&y===265&&Number(my[1])===256&&!mx);exits++;}if(mx)x=Number(mx[1]);if(my)y=Number(my[1]);if(mf)f=Number(mf[1]);}
    assert.deepEqual([x,y,f],[100,255,20000]);results.push({scenario:'smooth timelapse',stock_matched_exits:exits,final_xy_feed:[x,y,f]});
  }
}
fs.mkdirSync('work',{recursive:true});
fs.writeFileSync('work/ams-timelapse-check-results.json',JSON.stringify({status:'PASS',scope:'static; post-T macro XY is unknown and not simulated',geometry_validation:'NOT_PERFORMED',results},null,2));
console.log(JSON.stringify({status:'PASS',ams_scenarios:scenarios.length,timelapse_modes:2,results},null,2));
