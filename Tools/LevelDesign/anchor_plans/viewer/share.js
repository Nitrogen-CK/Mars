/* Offline review only: current builder geometry, not Unreal gameplay simulation. */
(() => {
  'use strict';
  const payload = JSON.parse(document.getElementById('warrens-data').textContent);
  const {source: d, manifest: m} = payload;
  const $ = id => document.getElementById(id);
  const svgNS = 'http://www.w3.org/2000/svg';
  const esc = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const materials = new Map(d.presentation.materials.map(v => [v.path, v]));
  const groups = d.twoPlayer.structuralGroups;
  const state = {tab:'plan', floor:'all', labels:true, staging:true, walls:false, area:null, mechanism:null, closed:new Set(), route:[], routeNodes:[]};
  const coords = m.boxes.map(v => v.centre);
  const initial = [Math.min(...coords.map(v=>v[0]))-7, Math.min(...coords.map(v=>v[1]))-7, 0, 0];
  initial[2] = Math.max(...coords.map(v=>v[0]))+7-initial[0]; initial[3] = Math.max(...coords.map(v=>v[1]))+7-initial[1];
  let view = initial.slice(), drag = null, renderer, scene3, camera, meshGroups = [], overlay3, activeTab = 'plan';
  const orbit = {x:initial[0]+initial[2]/2, y:initial[1]+initial[3]/2, z:0, radius:180, theta:-1.3, phi:0.95};
  const mechInfo = {
    PK:['Kitchen shutters','Hold the exterior crank for 2 seconds. Both shutters latch open: east cargo entry and optional west packless service opening.','One opens while the other stages cargo, then both reunite. No maintained holder.'],
    P1:['Vault key door','Bring the gallery RedKey to the Vault lock. Two fixed tallow rewards make this optional detour useful.','One scouts the key while the other plans the loaded return.'],
    P2:['Drowned Gallery sluice','The Sluice hand-wheel latches the remote bars open. Water remains cosmetic.','One operates; the other observes the destination or stages cargo. Both can leave.'],
    P3:['Mourner plate','One chef or pack occupancy latches access. One fixed fuel reward and the optional cache remain.','Single-person occupancy; stepping off does not strand the operator.'],
    P4:['Bellkeeper','Set three dials to '+d.bellkeeper.phrase.join(' → ')+', then pull the chain. The optional latch reveals the remaining Cleaver, Tenderizer and Ration rewards.','Voluntary clue reader / operator split, with shared staging and a reserved vent landing. Sequential solo access remains possible.'],
    P5:['Chime ladder release','The gallery-side release opens the barred ladder foot.','Loaded vertical return, with separate waiting and landing space.'],
    P6:['SC2 closet return','Climb out of the Pit into the closet, then open the closet-side release.','Learned loaded return to Chapel. Players regroup outside the ladder mount.']
  };
  const puzzles = d.puzzles.map(p => ({...p, control:p.id==='P4'?d.bellkeeper.panel.at:p.needsAt, info:mechInfo[p.id]}));
  function node(name, attrs={}, text) {const n=document.createElementNS(svgNS,name); for(const [k,v]of Object.entries(attrs))n.setAttribute(k,v);if(text!==undefined)n.textContent=text;return n;}
  function centre(room) {if(room.rect)return[(room.rect[0]+room.rect[2])/2,(room.rect[1]+room.rect[3])/2,room.z];const n=room.poly.length;return[room.poly.reduce((s,v)=>s+v[0],0)/n,room.poly.reduce((s,v)=>s+v[1],0)/n,room.z];}
  function level(z) {return z < -3.8 ? -5 : z < -1.8 ? -2.5 : z < -0.6 ? -1.5 : z < 1.8 ? 0 : z < 3.8 ? 2.5 : 5;}
  function visible(z) {return state.floor==='all'||level(z)===+state.floor;}
  function palette(box) {const def=materials.get(box.material);return def?.vectors.PrimaryColor || (box.kind==='ramp'?[.42,.14,.03]:box.kind==='water'?[.06,.19,.23]:[.2,.23,.24]);}
  const channel = v=>Math.round(255*(v<=.0031308?12.92*v:1.055*Math.pow(v,1/2.4)-.055));
  const color = b=>'#'+palette(b).map(v=>channel(v).toString(16).padStart(2,'0')).join('');
  function corners(b) {const a=b.yaw*Math.PI/180,p=b.pitch*Math.PI/180;const out=[];for(const [u,v]of[[-1,-1],[1,-1],[1,1],[-1,1]]){const x=u*b.size[0]/2,y=v*b.size[1]/2,z=b.size[2]/2;const xx=x*Math.cos(p)-z*Math.sin(p);out.push([b.centre[0]+xx*Math.cos(a)-y*Math.sin(a),b.centre[1]+xx*Math.sin(a)+y*Math.cos(a)]);}return out;}
  function poly(parent,points,attrs) {parent.append(node('polygon',{points:points.map(v=>v.slice(0,2).join(',')).join(' '),...attrs}));}
  function line(parent,points,attrs={}) {parent.append(node('polyline',{points:points.map(v=>v.slice(0,2).join(',')).join(' '),fill:'none',stroke:'#72d4d0','stroke-width':.38,...attrs}));}
  function text(parent,at,value,attrs={}) {const scale=Math.min(1,view[2]/70);const options={x:at[0],y:at[1],fill:'#eff0e8','font-size':1.45,'text-anchor':'middle',...attrs};options['font-size']*=scale;options.style=`stroke-width:${.35*scale}`;parent.append(node('text',options,value));}
  function rect(parent,r,z,label,stroke='#72d4d0') {if(!visible(z))return;parent.append(node('rect',{x:r[0],y:r[1],width:r[2]-r[0],height:r[3]-r[1],fill:stroke,'fill-opacity':.13,stroke,'stroke-width':.14,'stroke-dasharray':'.4 .25'}));if(state.labels&&label)text(parent,[(r[0]+r[2])/2,r[1]-.3],label,{'font-size':.65,fill:stroke});}
  function routePoints(link) {return[d.nodes[link.a],...link.via,d.nodes[link.b]];}
  function route3(link) {const points=routePoints(link),a=d.nodes[link.a],b=d.nodes[link.b];return points.map((v,i)=>[v[0],v[1],(v[2]??(a[2]+(b[2]-a[2])*i/(points.length-1)))+.14]);}
  function renderPlan() {
    const svg=$('plan');svg.replaceChildren();svg.setAttribute('viewBox',view.join(' '));
    const defs=node('defs'),pattern=node('pattern',{id:'grid',width:10,height:10,patternUnits:'userSpaceOnUse'});pattern.append(node('path',{d:'M 10 0 H 0 V 10',fill:'none',stroke:'#26333b','stroke-width':.1}));defs.append(pattern);svg.append(defs);
    svg.append(node('rect',{x:initial[0]-200,y:initial[1]-200,width:initial[2]+400,height:initial[3]+400,fill:'url(#grid)'}));
    const floors=m.boxes.filter(b=>['floor','ramp','gallery','water','grate'].includes(b.kind)&&visible(b.centre[2]+b.size[2]/2)).sort((a,b)=>a.centre[2]-b.centre[2]);
    for(const b of floors)poly(svg,corners(b),{fill:color(b),stroke:'#142128','stroke-width':.04,'fill-opacity':b.kind==='water'?.6:.83});
    for(const link of d.links){if(!visible(d.nodes[link.a][2])&&!visible(d.nodes[link.b][2]))continue;line(svg,routePoints(link),{stroke:state.closed.has(link.closedBy)?'#db6f6f':'#dbe8e0','stroke-width':.13,'stroke-opacity':.4,'stroke-dasharray':state.closed.has(link.closedBy)?'.6 .4':'none'});}
    for(const c of d.crawls)if(visible(c.z||0))line(svg,[c.a,c.b],{stroke:'#d17fb8','stroke-width':.27,'stroke-dasharray':'.5 .35'});
    for(const l of d.ladders)if(visible(l.baseZ)||visible(l.baseZ+l.height)){const at=l.at;svg.append(node('rect',{x:at[0]-.4,y:at[1]-.4,width:.8,height:.8,fill:'#80cce8'}));if(state.labels)text(svg,[at[0],at[1]-1],l.id,{'font-size':.8,fill:'#80cce8'});}
    for(const room of d.rooms)if(room.label&&visible(room.z)&&state.labels){const at=centre(room);const g=node('g',{class:'pick',role:'button',tabindex:0,'aria-label':'Inspect '+room.label});const target=()=>selectRoom(room);g.addEventListener('click',target);g.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();target();}});text(g,at,room.label);svg.append(g);}
    if(state.staging){for(const r of d.twoPlayer.clearRectangles)rect(svg,r.rectPlanM,r.floorZ,r.id);for(const s of d.twoPlayer.stationReservations)rect(svg,s.transverseWorkRectPlanM,s.positionPlanM[2],s.id+' work');rect(svg,d.twoPlayer.kitchenTransit.rectPlanM,0,'kitchen transit');for(const r of d.twoPlayer.drops)rect(svg,r.landingRectPlanM,r.floorZ,'↓ '+r.id);rect(svg,d.bellkeeper.partnerStageRectPlanM,0,'P4 partner');}
    for(const l of state.route)if(visible(d.nodes[l.a][2])||visible(d.nodes[l.b][2]))line(svg,routePoints(l),{stroke:'#72ffed','stroke-width':.5});
    for(const p of puzzles){if(!visible(p.at[2])&&!visible(p.control[2]||0))continue;const active=state.mechanism?.id===p.id;if(active){line(svg,[p.control,p.at],{stroke:'#ffd282','stroke-width':.36,'stroke-dasharray':'1 .6'});svg.append(node('circle',{cx:p.control[0],cy:p.control[1],r:.6,fill:'#ffd282'}));text(svg,[p.control[0],p.control[1]-1.3],'CONTROL',{'font-size':.9,fill:'#ffd282'});}
      const g=node('g',{class:'pick',role:'button',tabindex:0,'aria-label':'Inspect '+p.info[0]});g.append(node('circle',{cx:p.at[0],cy:p.at[1],r:active?.95:.65,fill:'#f3bd63',stroke:'#27221a','stroke-width':.15}));if(state.labels)text(g,[p.at[0],p.at[1]-1.35],p.id==='P6'?'SC2':p.id,{'font-size':.85,fill:'#ffd282'});g.addEventListener('click',()=>selectMechanism(p.id));g.addEventListener('keydown',e=>{if(e.key==='Enter'){selectMechanism(p.id);}});svg.append(g);}
    if(state.mechanism?.id==='P4'){rect(svg,d.bellkeeper.vent.landingRectPlanM,0,'P4 vent landing','#ed8980');if(visible(2.5)){const r=d.bellkeeper.clue.readerAt;line(svg,[r,d.bellkeeper.operatorAt],{stroke:'#d17fb8','stroke-width':.25,'stroke-dasharray':'.5 .6'});svg.append(node('circle',{cx:r[0],cy:r[1],r:.65,fill:'#ffd282'}));text(svg,[r[0],r[1]-1.2],'CLUE READER',{'font-size':1.1,fill:'#ffd282'});}}
  }
  function computeRoute() {
    const from=$('from').value,to=$('to').value,dist=new Map([[from,0]]),prev=new Map(),done=new Set();
    while(true){let u=null,best=Infinity;for(const [k,v]of dist)if(!done.has(k)&&v<best){u=k;best=v;}if(u===null||u===to)break;done.add(u);for(const l of d.links){if(state.closed.has(l.closedBy))continue;const v=l.a===u?l.b:l.b===u?l.a:null;if(!v)continue;const nd=best+l.costCm/100;if(nd<(dist.get(v)??Infinity)){dist.set(v,nd);prev.set(v,[u,l]);}}}
    state.route=[];state.routeNodes=[];if(dist.has(to)){let at=to;state.routeNodes=[at];while(at!==from){const [u,l]=prev.get(at);state.route.unshift(l);state.routeNodes.unshift(u);at=u;}$('route-result').textContent=`${from} → ${to}: ${dist.get(to).toFixed(1)} m authored graph cost · ${state.route.length} links`;}else $('route-result').textContent='No graph route under these closures.';
    redraw();
  }
  function areaForRoom(room) {return groups.find(g=>g.label.toLowerCase().includes(room.id.split('-')[0])) || groups.find(g=>g.geometryIds.some(id=>id.startsWith('C10'))&&room.id==='spiral-well');}
  function selectRoom(room) {const g=areaForRoom(room);if(g){$('area').value=g.areaId;selectArea(g.areaId);}else{const at=centre(room);focus(at,28);$('inspector').innerHTML=`<h2>${esc(room.label||room.id)}</h2><p>Authored floor elevation: ${room.z} m.</p><p class="hint">Inspect nearby mechanisms and reserved staging spaces using the controls.</p>`;}}
  function focus(at,span=30) {view=[at[0]-span/2,at[1]-span/2,span,span];orbit.x=at[0];orbit.y=at[1];orbit.z=at[2]||0;orbit.radius=span*1.4;redraw();}
  function defaultInspector() {$('inspector').innerHTML='<h2>The Well remains the hub</h2><p>Choose an area to inspect its two-player intention, or a mechanism to connect its control to the affected destination.</p><p class="hint">Drag to pan / orbit · scroll or +/− to zoom. Arrow keys pan the focused plan. Double-click the plan to inspect the nearest room.</p>';}
  function selectArea(id) {const g=groups.find(g=>g.areaId===+id);state.area=g||null;state.mechanism=null;$('mechanism').value='';if(!g){defaultInspector();reset();return;}const cp=g.checkpoint;focus(cp.targetPlanM,35);$('inspector').innerHTML=`<h2>${esc(g.label)}</h2><p>${esc(g.intention)}</p><p class="hint">Structural setup: batch ${g.batch}. Phase 5 art presentation is accepted only for Batch A; B/C presentation remains open.</p>`;}
  function selectMechanism(id) {const p=puzzles.find(p=>p.id===id);state.mechanism=p||null;state.area=null;$('area').value='';$('mechanism').value=id;if(!p){defaultInspector();redraw();return;}const points=[p.at,p.control,...(id==='P4'?[d.bellkeeper.clue.readerAt]:[])],xs=points.map(v=>v[0]),ys=points.map(v=>v[1]),x0=Math.min(...xs),x1=Math.max(...xs),y0=Math.min(...ys),y1=Math.max(...ys);const mid=[(x0+x1)/2,(y0+y1)/2,0],span=Math.max(22,x1-x0+12,y1-y0+12);focus(mid,span);$('inspector').innerHTML=`<h2>${esc(p.info[0])}</h2><p>${esc(p.info[1])}</p><p><strong>Two players:</strong> ${esc(p.info[2])}</p><p class="hint">Control ${p.control.map(v=>v.toFixed(1)).join(', ')} m → destination ${p.at.join(', ')} m. The line shows causality, not a walkable corridor.${id==='P4'?' Pink line: clue reader to operator.':''}</p>`;}
  function reset() {view=initial.slice();orbit.x=initial[0]+initial[2]/2;orbit.y=initial[1]+initial[3]/2;orbit.z=0;orbit.radius=180;redraw();}
  function redraw(){renderPlan();if(renderer){refresh3();draw3();}}
  function init3() {
    if(renderer)return;try{
      renderer=new THREE.WebGLRenderer({canvas:$('three'),antialias:true,preserveDrawingBuffer:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));
      scene3=new THREE.Scene();scene3.background=new THREE.Color('#0b1115');camera=new THREE.PerspectiveCamera(48,1,.05,600);camera.up.set(0,0,1);
      scene3.add(new THREE.AmbientLight(0xffffff,1.6));const sun=new THREE.DirectionalLight(0xffeccb,2.2);sun.position.set(-30,-50,120);scene3.add(sun);
      const buckets=new Map();for(const b of m.boxes){const z=b.centre[2]+b.size[2]/2;const category=['wall','roof'].includes(b.kind)?'walls':'floor';const key=[b.material||b.kind,level(z),category].join('|');if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(b);}
      const geo=new THREE.BoxGeometry(1,1,1),dummy=new THREE.Object3D();for(const bs of buckets.values()){const b=bs[0],c=palette(b);const material=new THREE.MeshLambertMaterial({color:new THREE.Color().setRGB(...c),transparent:['wall','roof','water'].includes(b.kind),opacity:['wall','roof'].includes(b.kind)?.35:b.kind==='water'?.55:1});const mesh=new THREE.InstancedMesh(geo,material,bs.length);bs.forEach((b,i)=>{dummy.position.set(...b.centre);dummy.scale.set(...b.size);dummy.rotation.set(0,-b.pitch*Math.PI/180,b.yaw*Math.PI/180,'ZYX');dummy.updateMatrix();mesh.setMatrixAt(i,dummy.matrix);});mesh.userData={level:level(b.centre[2]+b.size[2]/2),wall:['wall','roof'].includes(b.kind),count:bs.length};scene3.add(mesh);meshGroups.push(mesh);}
      const grid=new THREE.GridHelper(160,16,0x425059,0x26333b);grid.rotation.x=Math.PI/2;grid.position.set(45,40,-6);scene3.add(grid);overlay3=new THREE.Group();scene3.add(overlay3);refresh3();draw3();
    }catch(error){$('scene-note').textContent='3D rendering unavailable in this browser. Plan, routes, inspection and embedded PIE comparisons remain available.';console.error(error);}
  }
  function refresh3() {
    for(const mesh of meshGroups)mesh.visible=(state.floor==='all'||mesh.userData.level===+state.floor)&&(!mesh.userData.wall||state.walls);
    while(overlay3.children.length){const obj=overlay3.children.pop();obj.traverse(child=>{child.geometry?.dispose();if(Array.isArray(child.material))child.material.forEach(v=>v.dispose());else child.material?.dispose();});obj.parent=null;}
    function path(points,col){const geo=new THREE.BufferGeometry().setFromPoints(points.map(p=>new THREE.Vector3(...p)));overlay3.add(new THREE.Line(geo,new THREE.LineBasicMaterial({color:col,depthTest:false})));}
    for(const l of state.route)if(visible(d.nodes[l.a][2])||visible(d.nodes[l.b][2]))path(route3(l),0x72ffed);
    if(state.staging)for(const r of d.twoPlayer.clearRectangles)if(visible(r.floorZ)){const a=r.rectPlanM;path([[a[0],a[1],r.floorZ+.1],[a[2],a[1],r.floorZ+.1],[a[2],a[3],r.floorZ+.1],[a[0],a[3],r.floorZ+.1],[a[0],a[1],r.floorZ+.1]],0x72d4d0);}
    const p=state.mechanism;if(p)path([[p.control[0],p.control[1],p.control[2]||0],p.at],0xffd282);
  }
  function draw3() {if(!renderer||activeTab!=='three')return;const stage=$('scene'),w=stage.clientWidth,h=stage.clientHeight;renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();camera.position.set(orbit.x+orbit.radius*Math.cos(orbit.theta)*Math.cos(orbit.phi),orbit.y+orbit.radius*Math.sin(orbit.theta)*Math.cos(orbit.phi),orbit.z+orbit.radius*Math.sin(orbit.phi));camera.lookAt(orbit.x,orbit.y,orbit.z);renderer.render(scene3,camera);}
  function tab(name){activeTab=name;for(const v of ['plan','three','changes'])$('tab-'+v).setAttribute('aria-pressed',String(v===name));$('layout').hidden=name==='changes';$('legend').hidden=name==='changes';$('changes').hidden=name!=='changes';$('plan').toggleAttribute('hidden',name!=='plan');$('three').hidden=name!=='three';$('floor').disabled=name==='changes';$('scene-note').textContent=name==='three'?'3D cutaway: current builder primitive transforms, approximate family colours. Roofs / walls hidden by default. Drag to orbit; right-drag to pan. Shader detail, live entities and Unreal lighting are not reproduced.':'Plan: current builder floor geometry. Route and mechanism lines are explanatory overlays.';if(name==='three'){init3();draw3();}}
  for(const name of ['plan','three','changes'])$('tab-'+name).onclick=()=>tab(name);
  for(const g of groups){const o=document.createElement('option');o.value=g.areaId;o.textContent=g.areaId+' · '+g.label;$('area').append(o);}
  for(const p of puzzles){const o=document.createElement('option');o.value=p.id;o.textContent=(p.id==='P6'?'SC2':p.id)+' · '+p.info[0];$('mechanism').append(o);}
  const nodeNames={K:'Kitchen / hearth',H1:'Charnel Court',H2:'Pit',CI:'Cistern',CH:'Chime Hall',O:'Ossuary',BR:'Bridge',RQ:'Reliquary',PU:'Pump Room',SL:'Sluice',CE:'Salt Cellar',gE:'Grotto east',gN:'Grotto north',sp0:'Spiral lower',sp1:'Spiral upper'};
  for(const id of ['from','to']){for(const [k,v]of Object.entries(d.nodes)){const o=document.createElement('option');o.value=k;o.textContent=`${nodeNames[k]||k} · ${v[2]} m` ;$(id).append(o);}$(id).onchange=computeRoute;}$('from').value='S1';$('to').value='K';
  for(let i=1;i<=7;i++){const lab=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.value='R'+i;input.onchange=()=>{if(input.checked&&state.closed.size>=3){input.checked=false;$('route-result').textContent='Closure cap is three R gates. Reopen one first.';return;}input.checked?state.closed.add(input.value):state.closed.delete(input.value);computeRoute();};lab.append(input,'R'+i+' closed');$('gates').append(lab);}
  $('area').onchange=()=>selectArea($('area').value);$('mechanism').onchange=()=>selectMechanism($('mechanism').value);$('floor').onchange=()=>{state.floor=$('floor').value;redraw();};
  for(const id of ['labels','staging','walls'])$(id).onchange=()=>{state[id]=$(id).checked;redraw();};$('reset').onclick=reset;
  function zoom(factor){const cx=view[0]+view[2]/2,cy=view[1]+view[3]/2;view[2]=Math.max(8,Math.min(350,view[2]*factor));view[3]=Math.max(8,Math.min(350,view[3]*factor));view[0]=cx-view[2]/2;view[1]=cy-view[3]/2;orbit.radius=Math.max(8,Math.min(250,orbit.radius*factor));renderPlan();draw3();}
  $('zoom-in').onclick=()=>zoom(.8);$('zoom-out').onclick=()=>zoom(1.25);
  $('scene').onwheel=e=>{e.preventDefault();zoom(Math.exp(e.deltaY*.001));};
  for(const id of ['plan','three']){const el=$(id);el.oncontextmenu=e=>e.preventDefault();el.onpointerdown=e=>{if(e.target.closest?.('.pick'))return;drag={id,x:e.clientX,y:e.clientY,button:e.button};el.setPointerCapture(e.pointerId);};el.onpointerup=el.onpointercancel=()=>drag=null;el.onpointermove=e=>{if(!drag||drag.id!==id)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;drag.x=e.clientX;drag.y=e.clientY;if(id==='plan'){const scale=Math.max(view[2]/el.clientWidth,view[3]/el.clientHeight);view[0]-=dx*scale;view[1]-=dy*scale;renderPlan();}else if(drag.button===2){orbit.x-=dx*.06;orbit.y+=dy*.06;draw3();}else{orbit.theta-=dx*.008;orbit.phi=Math.max(.12,Math.min(1.5,orbit.phi+dy*.006));draw3();}};}
  $('scene').onkeydown=e=>{const deltas={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]};if(!deltas[e.key]||activeTab!=='plan')return;e.preventDefault();view[0]+=deltas[e.key][0]*view[2]*.07;view[1]+=deltas[e.key][1]*view[3]*.07;renderPlan();};
  $('plan').ondblclick=e=>{const svg=$('plan'),point=new DOMPoint(e.clientX,e.clientY).matrixTransform(svg.getScreenCTM().inverse());const room=d.rooms.filter(r=>visible(r.z)).sort((a,b)=>Math.hypot(centre(a)[0]-point.x,centre(a)[1]-point.y)-Math.hypot(centre(b)[0]-point.x,centre(b)[1]-point.y))[0];if(room)selectRoom(room);};
  new ResizeObserver(()=>draw3()).observe($('scene'));
  const cards=[
    ['Layout for two','Separate waiting, receiving, work and recovery space. Cistern crossing preserves both routes; spiral / Grotto approaches, ladder exits and loaded returns remain authored.','Phases 1–2: static contracts and local physical evidence.'],
    ['Mechanisms with a payoff','Kitchen shutters, sluice bars, one-person Mourner latch, Vault fuel, Chime ladder and SC2 returns. Short splits are voluntary and lead to reunion.','Phase 3: local mechanism and reward evidence.'],
    ['Bellkeeper cause and effect','Three-dial phrase, Bridge clue, partner staging, vent landing and cost lettering. The clue is now '+d.bellkeeper.phrase.join(' → ')+'.','Phase 4: physical / visual checks; normal heard audio pending.'],
    ['Distinct material families','Stone joints, timber plank bands, fine ivory bone and steel plate grids, all using CkUSF. Orange marks 18 spiral treads and 13 ramp segments.','Material repair: 16 matched PIE pairs. Orange follow-up: 4 matched PIE pairs.'],
    ['Area identities','Supported pipes and drying racks, ceremonial Court forms, inward Ossuary niches, mineral Cistern ribs and root silhouettes break up the rooms.','Structural setups authored. Phase 5 art presentation accepted only for Batch A.'],
    ['Still open','Phase 5 environmental sound deliveries and B/C presentation, normal heard Bellkeeper audio and an unfamiliar human-pair playtest. Session / authority / replication work is out of scope.','No two-human, complete Phase 5 or full-regression claim.']
  ];$('change-cards').innerHTML=cards.map(([title,body,proof])=>`<article class="card"><h3>${esc(title)}</h3><p>${esc(body)}</p><div class="proof">${esc(proof)}</div></article>`).join('');
  payload.comparisons.forEach(c=>{const h=document.createElement('h3');h.textContent=c.title;const image=document.createElement('img');image.src=c.image;image.alt=c.title+' — matched actual Unreal PIE views';image.className='comparison';image.loading='lazy';$('comparisons').append(h,image);});
  $('counts').textContent=`Accepted snapshot: ${m.boxes.length.toLocaleString()} geometry boxes, ${m.lights.length} authored lights, ${d.twoPlayer.clearRectangles.length} clear rectangles. Static acceptance: ${payload.static.checks.length} checks, 320 graph cases and 5 rejected negative fixtures. Native audit: ${payload.audit.samples} support samples, ${payload.audit.missing} missing, ${payload.audit.startsClear} clear starts, ${payload.audit.crawlsOk} valid crawls; Jolt valid. These are saved scoped results, not newly run gameplay tests.`;
  $('provenance').textContent=`Committed snapshot ${payload.commit.slice(0,7)} · source SHA-256 ${payload.sourceHash.slice(0,16)}… · all data, images and renderer embedded.`;
  computeRoute();
  // Inspection hook for local browser acceptance; no file/network access.
  window.WarrensReview={payload,state,get scene(){return scene3;},get meshes(){return meshGroups;},get renderer(){return renderer;}};
})();
