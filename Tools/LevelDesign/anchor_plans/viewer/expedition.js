/* Offline design atlas. Geometry is current; expedition assignments are proposed. */
(() => {
  'use strict';
  const payload = JSON.parse(document.getElementById('warrens-data').textContent);
  const {source:d,manifest:m,proposal:p} = payload;
  const $ = id => document.getElementById(id);
  const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const ns='http://www.w3.org/2000/svg';
  const C={amber:'#f2b45f',teal:'#85d1c6',rose:'#d7a1af',orange:'#e18d43',ink:'#e9e8dd',muted:'#a9b8b7',rule:'#354447'};
  const state={view:'world',district:'warrens',scenario:p.scenarios[0].id,phase:0,reveal:false,geometry:'plan',floor:'all',staging:false,walls:false,cooking:'camp',mechanism:''};
  const scenarios=p.scenarios, districts=p.world.districts;
  const scenario=()=>scenarios.find(s=>s.id===state.scenario)||scenarios[0];
  const phase=()=>scenario().stages[state.phase]||scenario().stages[0];
  const titleOf=s=>s.title||s.label||s.id;
  const descriptionOf=s=>s.description||s.note||'';
  const coords=m.boxes.map(b=>b.centre);
  const minx=Math.min(...coords.map(v=>v[0]))-8,miny=Math.min(...coords.map(v=>v[1]))-8;
  const initial=[minx,miny,Math.max(...coords.map(v=>v[0]))+8-minx,Math.max(...coords.map(v=>v[1]))+8-miny];
  let view=initial.slice(),drag=null,renderer,scene3,camera,overlay3;
  const meshes=[], orbit={x:minx+initial[2]/2,y:miny+initial[3]/2,z:0,radius:180,theta:-1.3,phi:1.05};
  const materials=new Map((d.presentation?.materials||[]).map(v=>[v.path,v]));
  const mechanisms={
    PK:['Kitchen shutters','Exterior crank latches both shutters open. One chef works while the other stages cargo; both can leave afterward.'],
    P1:['Optional Vault','Gallery RedKey opens the Vault. This optional detour is never a required target or recipe gate.'],
    P2:['Sluice','The hand-wheel latches remote bars open. One operates while the other reads the destination or stages cargo.'],
    P3:['Mourner plate','Single chef or pack occupancy latches access. Stepping off does not strand the operator.'],
    P4:['Bellkeeper',`Three dials, then the chain. Existing phrase: ${(d.bellkeeper?.phrase||[]).join(' → ')}. Voluntary clue-reader / operator split with a partner staging reservation.`],
    P5:['Chime ladder','Gallery-side release opens the ladder foot. Loaded return has separate waiting and landing space; ladders are outside the generic route graph.'],
    P6:['SC2 closet return','Climb from the Pit to the closet, then open the closet-side release. This local ladder return is supported physical content outside the generic route graph.']
  };
  const selectedMechanism=()=>d.puzzles.find(v=>v.id===state.mechanism);
  const roomCentre=r=>r.rect?[(r.rect[0]+r.rect[2])/2,(r.rect[1]+r.rect[3])/2,r.z]:[r.poly.reduce((s,v)=>s+v[0],0)/r.poly.length,r.poly.reduce((s,v)=>s+v[1],0)/r.poly.length,r.z];
  const level=z=>z < -3.8?-5:z < -1.8?-2.5:z < -.6?-1.5:z < 1.8?0:z < 3.8?2.5:5;
  const visible=z=>state.floor==='all'||level(z)===+state.floor;
  const palette=b=>materials.get(b.material)?.vectors.PrimaryColor||(b.kind==='ramp'?[.42,.14,.03]:b.kind==='water'?[.06,.19,.23]:[.2,.23,.24]);
  const channel=v=>Math.round(255*(v<=.0031308?12.92*v:1.055*Math.pow(v,1/2.4)-.055));
  const color=b=>'#'+palette(b).map(v=>channel(v).toString(16).padStart(2,'0')).join('');
  function node(name,attrs={},content){const el=document.createElementNS(ns,name);for(const[k,v]of Object.entries(attrs))el.setAttribute(k,v);if(content!==undefined)el.textContent=content;return el;}
  function label(parent,x,y,text,size=12,color=C.ink,attrs={}){const el=node('text',{x,y,'font-size':size,fill:color,...attrs},text);parent.append(el);return el;}
  function path(parent,points,attrs={}){if(!points?.length)return;parent.append(node('polyline',{points:points.map(v=>v.slice(0,2).join(',')).join(' '),fill:'none',stroke:C.teal,'stroke-width':.4,...attrs}));}
  function polygon(parent,points,attrs={}){parent.append(node('polygon',{points:points.map(v=>v.slice(0,2).join(',')).join(' '),...attrs}));}
  function lines(parent,x,y,items,opts={}){items.forEach((s,i)=>label(parent,x,y+i*(opts.lineHeight||17),s,opts.size||12,opts.color||C.muted,opts.attrs||{}));}
  function wrap(str,len=33){const result=[];let line='';for(const word of String(str).split(' ')){if((line+' '+word).trim().length>len&&line){result.push(line);line=word;}else line=(line+' '+word).trim();}if(line)result.push(line);return result;}
  function corners(b){const a=b.yaw*Math.PI/180,pitch=b.pitch*Math.PI/180;return[[-1,-1],[1,-1],[1,1],[-1,1]].map(([u,v])=>{const x=u*b.size[0]/2,y=v*b.size[1]/2,z=b.size[2]/2,xx=x*Math.cos(pitch)-z*Math.sin(pitch);return[b.centre[0]+xx*Math.cos(a)-y*Math.sin(a),b.centre[1]+xx*Math.sin(a)+y*Math.cos(a)];});}
  function setView(name){state.view=name;render();$('announcement').textContent=name==='local'?'Warrens expedition. Current geometry, proposed authored assignments.':name==='world'?'Conceptual spire atlas.':'Reuse and implementation scope.';}
  function chooseDistrict(id){state.district=id;renderWorld();renderWorldInspector();}
  function openLocal(){state.district='warrens';setView('local');}
  function renderWorld(){
    const svg=$('world-map');svg.replaceChildren();
    const defs=node('defs');const grid=node('pattern',{id:'world-grid',width:40,height:40,patternUnits:'userSpaceOnUse'});grid.append(node('path',{d:'M40 0H0V40',fill:'none',stroke:'#243033','stroke-width':.55}));defs.append(grid);
    const hatch=node('pattern',{id:'spire-hatch',width:9,height:9,patternUnits:'userSpaceOnUse',patternTransform:'rotate(30)'});hatch.append(node('path',{d:'M0 0V9',stroke:'#304043','stroke-width':1}));defs.append(hatch);svg.append(defs);
    svg.append(node('rect',{width:1100,height:850,fill:'url(#world-grid)'}));
    // Section silhouette is an illustration of the proposal, not a dungeon layout.
    const spine=[[526,160],[548,208],[541,247],[563,284],[552,331],[576,377],[568,427],[585,473],[576,534],[600,584],[586,625],[602,668],[579,725],[551,789],[529,750],[517,706],[499,673],[508,629],[488,585],[501,539],[480,494],[495,447],[479,402],[496,356],[486,311],[505,270],[499,224]];
    polygon(svg,spine,{fill:'#192426',stroke:'#425457','stroke-width':1.2});polygon(svg,spine,{fill:'url(#spire-hatch)',opacity:.7});
    path(svg,[[543,230],[543,744]],{stroke:'#53686a','stroke-width':1,'stroke-dasharray':'3 9'});
    label(svg,620,765,'THE SPIRE',11,'#627c7e',{'letter-spacing':4});
    label(svg,620,785,'Section / illustrative depth',10,C.muted);
    // Camp is deliberately outside all existing Warrens geometry.
    svg.append(node('path',{d:'M480 160L516 141L526 119L539 143L554 125L568 147L608 163Z',fill:'#2e342b',stroke:C.amber,'stroke-width':1.4}));
    svg.append(node('path',{d:'M491 165H599M501 171H589M519 177H570',stroke:'#686348','stroke-width':2}));
    label(svg,548,94,'BASE CAMP',18,C.ink,{'text-anchor':'middle','letter-spacing':2});
    label(svg,548,112,'Proposed arrival + short physical cook',10,C.amber,{'text-anchor':'middle'});
    const campFire=node('path',{d:'M545 149Q538 144 547 134Q553 141 550 147Q558 145 554 153Z',fill:C.amber});svg.append(campFire);
    const positions=[{x:95,y:275,side:-1,col:C.amber},{x:690,y:430,side:1,col:C.teal},{x:95,y:590,side:-1,col:C.rose}];
    districts.slice(0,3).forEach((district,i)=>{
      const pos=positions[i],active=state.district===district.id,centreY=pos.y+65;
      const dockX=pos.side<0?493:578,edgeX=pos.side<0?pos.x+320:pos.x;
      path(svg,[[548,181],[548,centreY],[dockX,centreY],[edgeX,centreY]],{stroke:active?pos.col:'#4c6567','stroke-width':active?1.9:1.2,'stroke-dasharray':'6 6'});
      svg.append(node('rect',{x:dockX-5,y:centreY-5,width:10,height:10,fill:'#162325',stroke:pos.col,'stroke-width':1}));
      if(i===0){label(svg,429,centreY-15,'ARRIVAL',8,C.muted,{'text-anchor':'end'});label(svg,429,centreY-3,'DOCK',8,C.muted,{'text-anchor':'end'});}
      const g=node('g',{class:'world-pick',tabindex:0,role:'button','aria-label':'Inspect '+district.title,'aria-pressed':String(active)});
      const shell=i===0?[[0,12],[34,0],[104,5],[132,0],[183,11],[220,4],[278,15],[315,37],[324,88],[301,116],[257,127],[193,118],[159,128],[114,117],[58,124],[18,103],[-6,61]]:i===1?[[0,29],[28,14],[86,18],[115,0],[162,11],[201,3],[239,28],[284,15],[324,39],[314,91],[280,117],[236,106],[198,129],[148,113],[98,124],[55,110],[14,115],[-7,73]]:[[0,22],[32,22],[32,0],[83,0],[83,17],[130,17],[130,2],[184,2],[184,19],[234,19],[234,5],[282,5],[282,27],[322,27],[322,111],[280,111],[280,130],[235,130],[235,112],[184,112],[184,129],[131,129],[131,110],[82,110],[82,128],[30,128],[30,108],[0,108]];
      polygon(g,shell.map(v=>[v[0]+pos.x,v[1]+pos.y]),{class:'district-shell',fill:active?'#243031':'#172224',stroke:active?pos.col:'#526669','stroke-width':active?1.8:1});
      const detail=node('g',{transform:`translate(${pos.x} ${pos.y})`,opacity:active?.7:.4});
      if(i===0){for(let j=0;j<5;j++){detail.append(node('path',{d:`M${28+j*58} 36h31v53h-31z`,fill:'none',stroke:'#6f7e67','stroke-width':1}));}path(detail,[[27,69],[81,69],[99,47],[155,47],[181,83],[293,83]],{stroke:pos.col,'stroke-width':3});detail.append(node('circle',{cx:163,cy:67,r:26,fill:'#172325',stroke:pos.col,'stroke-width':1}));detail.append(node('path',{d:'M145 67a18 18 0 1 1 18 18a9 9 0 1 1 9-9',fill:'none',stroke:pos.col,'stroke-width':2}));}
      else if(i===1){for(let j=0;j<5;j++)detail.append(node('path',{d:`M14 ${39+j*15}Q60 ${18+j*15} 100 ${39+j*15}T188 ${39+j*15}T306 ${39+j*15}`,fill:'none',stroke:pos.col,'stroke-width':1}));for(const x of [53,142,235])detail.append(node('path',{d:`M${x} 95v-48q12-23 24 0v48`,fill:'#172325',stroke:'#7caaa5','stroke-width':2}));}
      else{for(let j=0;j<6;j++){const x=28+j*48;detail.append(node('path',{d:`M${x} 97V49q13-35 26 0v48M${x+6} 95V54q7-24 14 0v41`,fill:'none',stroke:pos.col,'stroke-width':1.5}));}path(detail,[[15,105],[307,105]],{stroke:pos.col,'stroke-width':2});}
      g.append(detail);svg.append(g);
      const labelY=pos.y-22;
      label(svg,pos.x,labelY-20,`0${i+1} / ${district.status||'FUTURE CONCEPT'}`,9,pos.col,{'letter-spacing':1.4});
      label(svg,pos.x,labelY,district.title,22,C.ink);
      label(svg,pos.x,pos.y+153,wrap(district.habitat||'',49)[0],11,C.muted);
      label(svg,pos.x,pos.y+170,i===0?'Current shell · proposed expedition':'Future district · no implemented geometry',9,pos.col);
      g.onclick=()=>chooseDistrict(district.id);g.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();chooseDistrict(district.id);}};
    });
    // The optional cross-district link is explicitly a later concept.
    path(svg,[[417,653],[449,653],[449,495],[690,495]],{stroke:'#748484','stroke-width':1,'stroke-dasharray':'2 7'});
    label(svg,665,658,'ADJACENT DISTRICT',9,C.muted,{'letter-spacing':1});label(svg,665,674,'Optional later contracts',10,C.muted);
    label(svg,30,795,'NOT A VERTICAL TRANSIT PLAN',9,'#718c8d',{'letter-spacing':1.5});
    label(svg,30,813,'Docks, lifts and district positions are proposed topology.',10,C.muted);
  }
  function districtButton(district){return`<button data-district="${esc(district.id)}" aria-pressed="${state.district===district.id}"><span>${esc(district.title)}<small>${esc(district.status||'Future concept')}</small></span><span class="arrow" aria-hidden="true">↗</span></button>`;}
  function renderWorldInspector(){
    const district=districts.find(v=>v.id===state.district)||districts[0],isWarrens=district.id==='warrens';
    $('inspector').innerHTML=`<div class="inspector-top"><div class="eyebrow">Field atlas / district ${districts.indexOf(district)+1}</div><h2>${esc(district.title)}</h2><p>${esc(district.habitat)}</p><div class="district-list">${districts.map(districtButton).join('')}</div>${isWarrens?'<button class="action" id="enter-warrens">Open the Warrens expedition →</button>':'<div class="state-note">Future concept. This atlas contains no authored geometry or playable content for this district.</div>'}</div><section class="panel-section"><span class="line-label">Recognise the place</span><p>${esc(district.identity)}</p><div class="pill-list" style="margin-top:13px">${(district.resources||[]).map(v=>`<span class="pill">${esc(v)}</span>`).join('')}</div></section><section class="panel-section"><span class="line-label">Inside one run</span><div class="fact-list"><div class="fact"><strong>Habitat stays dependable</strong><p>The district retains its ingredient identity. Revisit the same setup within a run; harvested opportunities do not refill.</p></div><div class="fact amber"><strong>Approach can change</strong><p>${esc((district.variations||[]).join(' · '))}</p></div></div></section><section class="panel-section"><span class="line-label">Progression proposal</span><p>Arrival-dock eligibility persists. Local shortcuts and lifts reset each run, then stay open once earned. Camp connections and lifts remain future scope.</p></section>`;
    document.querySelectorAll('[data-district]').forEach(b=>b.onclick=()=>chooseDistrict(b.dataset.district));if($('enter-warrens'))$('enter-warrens').onclick=openLocal;
  }
  function roleText(stage,role){const value=stage.roles?.[role];if(value)return value;const roles={brief:['Read habitat and part requirements.','Plan cargo space and the loaded return.'],approach:['Read landmarks and controls.','Stage cargo clear of the working player.'],hunt:['Identify the needed part before striking.','Receive the harvest; protect its condition.'],optional:['Decide whether the detour is worth it.','Keep required cargo safe; the bonus is optional.'],return:['Read the earned return route.','Carry the same ingredient cargo out.'],cook:['Read the one-course recipe at camp.','Prepare the returned ingredients.']};return(roles[stage.id]||roles.approach)[role==='reader'?0:1];}
  function renderLocalInspector(){
    const s=scenario(),stage=phase(),recipe=p.contract;
    $('inspector').innerHTML=`<div class="inspector-top"><div class="eyebrow">One district / one supper / two chefs</div><label class="line-label" for="scenario">Authored setup</label><select class="scenario-select" id="scenario">${scenarios.map(v=>`<option value="${esc(v.id)}" ${v.id===s.id?'selected':''}>${esc(v.title)}</option>`).join('')}</select><div class="seed-meta"><span class="seed-dot"></span>${esc(s.seedLabel||s.seed||s.id)} · SAME GEOMETRY</div><label class="reveal"><input id="design-reveal" type="checkbox" ${state.reveal?'checked':''}><span>Design reveal<small>Expose proposed sites, numbered markers and route overlays.</small></span></label><div class="state-note">${state.reveal?'Designer view: planned opportunities visible. No physical spawn or path validation is implied.':'Cookbook view: habitat clues, no exact ingredient GPS. Use the six steps below to inspect the loop.'}</div></div><section class="panel-section phase-list-wrap"><span class="line-label">Trace the expedition</span><div class="phase-list">${s.stages.map((v,i)=>`<button class="phase-button" data-phase="${i}" aria-pressed="${state.phase===i}"><span class="number">${i+1}</span><span><strong>${esc(titleOf(v))}</strong><small>${esc(v.status||((v.id==='cook')?'Future camp proposal':'Proposed expedition step'))}</small></span><span aria-hidden="true">›</span></button>`).join('')}</div></section><section class="phase-copy" aria-live="polite"><span class="line-label">Step ${state.phase+1} / ${s.stages.length}</span><h3>${esc(titleOf(stage))}</h3><p>${esc(descriptionOf(stage))}</p><div class="role-grid"><div class="role"><b>READER</b>${esc(roleText(stage,'reader'))}</div><div class="role"><b>CARRIER</b>${esc(roleText(stage,'carrier'))}</div></div>${stage.id==='cook'?cookingMarkup():''}</section><section class="panel-section"><span class="line-label">Course 1 / illustrative contract</span><p class="recipe-title">${esc(recipe.title)}</p><div class="ingredient"><i>01</i><span>Preserved Pickle Mimic part<small>Required · ${esc(s.hunt?.habitat||'the Warrens habitat')} · keep the part intact.</small></span></div><div class="ingredient"><i>02</i><span>Common seasoning<small>Required · multiple planned common sources; never a secret-only gate.</small></span></div><div class="ingredient"><i>+</i><span>Grotto mushroom<small>Optional garnish · existing Grotto forage geometry; the recipe remains solvable without it.</small></span></div><p class="fine" style="margin-top:13px">Opportunity guaranteed by the proposed authored setup at departure. The player can still damage the part. Quality follows condition, with no rarity tiers.</p></section>`;
    const clue=document.createElement('p');clue.className='fine';clue.style.marginBottom='14px';clue.textContent=s.summary||s.habitat||'';document.querySelector('.inspector-top .reveal').before(clue);
    $('scenario').onchange=e=>{state.scenario=e.target.value;state.phase=Math.min(state.phase,scenario().stages.length-1);renderLocal();$('scenario').focus();$('announcement').textContent='Setup changed. Same Warrens geometry, different proposed assignments.';};
    $('design-reveal').onchange=e=>{state.reveal=e.target.checked;renderLocal();$('design-reveal').focus();};
    document.querySelectorAll('[data-phase]').forEach(b=>b.onclick=()=>{state.phase=+b.dataset.phase;renderLocal();document.querySelector(`[data-phase="${state.phase}"]`).focus();});
    bindCooking();
    if(state.mechanism&&mechanisms[state.mechanism]){const info=mechanisms[state.mechanism];const section=document.createElement('section');section.className='panel-section';section.innerHTML=`<span class="line-label">Current mechanism / ${esc(state.mechanism)}</span><h3>${esc(info[0])}</h3><p>${esc(info[1])}</p><p class="fine" style="margin-top:10px">Amber connector shows control → destination causality, not a walking route. Cyan rectangles show authored staging reservations when enabled.</p>`;$('inspector').append(section);}
  }
  function cookingMarkup(){return`<div class="cooking-switch" role="group" aria-label="Cooking proposal"><button data-cooking="camp" aria-pressed="${state.cooking==='camp'}">Camp return</button><button data-cooking="field" aria-pressed="${state.cooking==='field'}">Field shelter</button></div><div class="state-note" id="cooking-note">${cookingCopy()}</div>`;}
  function cookingCopy(){return state.cooking==='camp'?'MVP proposal: leave at the existing district boundary, carry the same cargo to camp, then do a short physical cook. The camp and its transit connection have no geometry here.':'Existing map: kitchen / hearth K. Proposed tradeoff: cook locally to extend exposure or recover, versus returning cargo to camp. The field shelter loop is optional and deferred; its geometry stays in place.';}
  function bindCooking(){document.querySelectorAll('[data-cooking]').forEach(b=>b.onclick=()=>{state.cooking=b.dataset.cooking;document.querySelectorAll('[data-cooking]').forEach(el=>el.setAttribute('aria-pressed',String(el.dataset.cooking===state.cooking)));$('cooking-note').textContent=cookingCopy();});}
  function graphPoints(ids){const result=[];for(let i=0;i<ids.length-1;i++){const a=ids[i],b=ids[i+1],link=d.links.find(l=>(l.a===a&&l.b===b)||(l.b===a&&l.a===b));if(!link)return[];const points=[d.nodes[link.a],...(link.via||[]),d.nodes[link.b]];if(link.a!==a)points.reverse();result.push(...(i?points.slice(1):points));}return result;}
  function stagePaths(){const stage=phase();if(stage.paths?.length)return stage.paths.map(v=>({...v,points:v.points?.length?v.points:graphPoints(v.nodeIds||[])}));if(stage.routeNodeIds?.length)return[{kind:'graph',points:graphPoints(stage.routeNodeIds),label:'Authored route graph'}];return[];}
  function sitePoint(site){if(Array.isArray(site.at))return site.at;if(Array.isArray(site.position))return site.position;if(site.nodeId&&d.nodes[site.nodeId])return d.nodes[site.nodeId];const r=d.rooms.find(r=>r.id===site.roomId);return r?roomCentre(r):null;}
  function screenUnit(){const el=$('map-viewport');return Math.max(view[2]/Math.max(1,el.clientWidth),view[3]/Math.max(1,el.clientHeight));}
  function marker(parent,at,number,text,col=C.teal){if(!at||!visible(at[2]||0))return;const scale=screenUnit(),r=9*scale;parent.append(node('circle',{cx:at[0],cy:at[1],r,fill:'#0c1517',stroke:col,'stroke-width':1.4*scale}));label(parent,at[0],at[1]+3.6*scale,String(number),10*scale,col,{'text-anchor':'middle','font-weight':700});if(text){const right=at[0]>view[0]+view[2]*.72;const textNode=label(parent,at[0]+(right?-1:1)*(r+5*scale),at[1]+3.6*scale,text.length>25?text.slice(0,23)+'…':text,11*scale,col,{'font-weight':500,'text-anchor':right?'end':'start'});textNode.append(node('title',{},text));}}
  function reservation(parent,r,z){if(!r||!visible(z))return;parent.append(node('rect',{x:r[0],y:r[1],width:r[2]-r[0],height:r[3]-r[1],fill:C.teal,'fill-opacity':.11,stroke:C.teal,'stroke-width':.12,'stroke-dasharray':'.5 .3'}));}
  function renderPlan(){
    const svg=$('local-map');svg.replaceChildren();svg.setAttribute('viewBox',view.join(' '));
    const defs=node('defs'),grid=node('pattern',{id:'local-grid',width:10,height:10,patternUnits:'userSpaceOnUse'});grid.append(node('path',{d:'M10 0H0V10',stroke:'#2c393d','stroke-width':.1,fill:'none'}));defs.append(grid);svg.append(defs);svg.append(node('rect',{x:minx-400,y:miny-400,width:1000,height:1000,fill:'url(#local-grid)'}));
    const floors=m.boxes.filter(b=>['floor','ramp','gallery','water','grate'].includes(b.kind)&&visible(b.centre[2]+b.size[2]/2)).sort((a,b)=>a.centre[2]-b.centre[2]);
    for(const b of floors)polygon(svg,corners(b),{fill:color(b),stroke:'#101b1e','stroke-width':.055,'fill-opacity':b.kind==='water'?.65:.8});
    // Existing routes remain subordinate to the expedition overlay; no invented links.
    for(const l of d.ladders||[]){if(!visible(l.baseZ)&&!visible(l.baseZ+l.height))continue;svg.append(node('rect',{x:l.at[0]-.35,y:l.at[1]-.35,width:.7,height:.7,fill:C.orange,stroke:'#111','stroke-width':.1}));}
    if(state.staging){for(const r of d.twoPlayer.clearRectangles||[])reservation(svg,r.rectPlanM,r.floorZ);for(const s of d.twoPlayer.stationReservations||[])reservation(svg,s.transverseWorkRectPlanM,s.positionPlanM[2]);reservation(svg,d.bellkeeper.partnerStageRectPlanM,0);}
    const labelScale=view[2]/145;
    for(const r of d.rooms){if(!r.label||!visible(r.z))continue;const at=roomCentre(r);label(svg,at[0],at[1],r.label,11*screenUnit(),'#e1e2d4',{'text-anchor':'middle',class:'map-label'});}
    const entry=d.nodes[scenario().entryNode],exit=d.nodes[scenario().returnNode||scenario().entryNode];if(entry){marker(svg,entry,'A','ARRIVAL '+scenario().entryNode,C.ink);}if(exit&&scenario().returnNode!==scenario().entryNode){marker(svg,exit,'R','RETURN '+scenario().returnNode,C.ink);}
    for(const id of scenario().closedGates||[]){const anchor=d.anchors.find(v=>v.id===id);if(anchor){const at=[...anchor.at,d.nodes[anchor.node]?.[2]||0];marker(svg,at,'×',id+' · setup closed',C.rose);}}
    const kitchen=d.nodes.K;if(kitchen&&visible(kitchen[2])){label(svg,kitchen[0],kitchen[1]+2.6*labelScale,'K · existing field kitchen',1.05*labelScale,C.amber,{'text-anchor':'middle'});}
    if(state.reveal){
      for(const route of stagePaths()){if(!route.points?.length)continue;const schematic=route.kind!=='graph';path(svg,route.points,{stroke:schematic?C.amber:C.teal,'stroke-width':.48*labelScale,'stroke-dasharray':schematic?`${1*labelScale} ${.65*labelScale}`:'none','stroke-linecap':'round','stroke-linejoin':'round'});}
      const hunt=scenario().hunt;if(hunt)marker(svg,sitePoint(hunt),'3','Pickle Mimic · proposed',C.rose);
      const forage=scenario().forage||[];forage.forEach((s,i)=>{const at=sitePoint(s);if(at&&visible(at[2]||0)){svg.append(node('path',{d:`M${at[0]} ${at[1]-1*labelScale}l${1*labelScale} ${1*labelScale}l${-1*labelScale} ${1*labelScale}l${-1*labelScale} ${-1*labelScale}Z`,fill:C.amber,stroke:'#121a1b','stroke-width':.15}));if(state.phase===1||state.phase===2)label(svg,at[0]+1.7*labelScale,at[1],`Seasoning ${i+1}`,11*screenUnit(),C.amber);}});
      if(scenario().bonus)marker(svg,sitePoint(scenario().bonus),'+','Optional garnish',C.rose);
      for(const item of phase().markers||[]){const at=sitePoint(item);if(!at)continue;if((phase().id==='hunt')&&hunt&&Math.hypot(at[0]-sitePoint(hunt)[0],at[1]-sitePoint(hunt)[1])<1)continue;if(item.kind==='arrival'||item.kind==='return'||item.id==='entry'||item.id==='exit')continue;const short=item.kind==='seasoning'?'Common seasoning':item.kind==='bonus'?'Optional mushroom':phase().id==='cook'?'Camp beyond boundary':item.label||'';marker(svg,at,state.phase+1,short,item.kind==='optional'?C.rose:C.teal);}
    }
    const mechanism=selectedMechanism();if(mechanism){const control=mechanism.id==='P4'?d.bellkeeper.panel.at:mechanism.needsAt;if(control){path(svg,[control,mechanism.at],{stroke:C.amber,'stroke-width':.3*labelScale,'stroke-dasharray':`${.7*labelScale} ${.6*labelScale}`});marker(svg,control,'C','CONTROL',C.amber);}marker(svg,mechanism.at,mechanism.id==='P6'?'SC2':mechanism.id,'DESTINATION',C.amber);if(mechanism.id==='P4'){marker(svg,d.bellkeeper.clue.readerAt,'R','CLUE READER',C.rose);reservation(svg,d.bellkeeper.partnerStageRectPlanM,0);}}
  }
  function localCaption(){if(state.geometry==='three')return'CURRENT BUILDER CUTAWAY · approximate material colours; no Unreal lighting, live entities, physics or audio.';if(!state.reveal)return'CURRENT FLOOR GEOMETRY · orange traversal landmarks · habitat clues only · ingredient sites hidden.';const schematic=stagePaths().some(v=>v.kind!=='graph');return schematic?'DESIGN REVEAL · solid = authored graph segments; dashed = schematic physical connector, outside generic graph.':'DESIGN REVEAL · proposed assignments on current geometry · route graph does not simulate locks, cargo or physical movement.';}
  function renderLocal(){renderLocalInspector();renderPlan();$('map-caption').textContent=localCaption();if(renderer){refresh3();draw3();}}
  function renderScope(){
    const scope=p.scope;
    const columns=[['existing','Current systems / geometry','teal','Use what is already here'],['proposed','Proposed reuse / data / config','amber','The bounded expedition slice'],['deferred','Deferred new scope','','Deliberately later']];
    $('scope-view').innerHTML=`<div class="scope-intro"><div class="eyebrow">Build the loop before the world</div><h2>One authored district first.</h2><p>Course 1 is the MVP. Courses 2 and 3 expand later recipe pools; they are not difficulty tiers. This mockup compares three authored setups and changes no gameplay systems.</p></div><div class="scope-columns">${columns.map(([key,title,colour,sub])=>`<article class="scope-column"><span class="tag ${colour}">${esc(sub)}</span><h3>${esc(title)}</h3><ul>${(scope[key]||[]).map(v=>`<li>${esc(typeof v==='string'?v:v.title||v.label)}</li>`).join('')}</ul></article>`).join('')}</div><div class="milestones"><div class="milestone"><span class="eyebrow">01 / MVP</span><strong>Authored Warrens</strong><small>One monster, one recipe, three setups. Camp return + short cook proposed.</small></div><div class="milestone"><span class="eyebrow">02 / LATER</span><strong>Population variation</strong><small>Vary authored encounter and resource sockets after the loop is proven.</small></div><div class="milestone"><span class="eyebrow">03 / LATER</span><strong>District generation</strong><small>Preserve habitat identity, required opportunities and cargo routes.</small></div><div class="milestone"><span class="eyebrow">04 / LATER</span><strong>Neighboring district + lifts</strong><small>Adjacent optional and advanced multi-district contracts. No network work in this scope.</small></div></div><div class="strategy-grid" style="margin-top:32px"><article><span class="index">SOLVABILITY</span><h3>Guarantee the opportunity at run start.</h3><p>Design checks must guarantee reachable required sites before departure. Never rely on random spawn luck, an optional vault or a secret. Damage to the part remains a player consequence.</p></article><article><span class="index">PERSISTENCE</span><h3>Stable within the run.</h3><p>Return to the same setup and earned local shortcuts. No ingredient farming by revisiting. Only district arrival eligibility persists between runs.</p></article><article><span class="index">WORLD IDENTITY</span><h3>Read silhouettes and materials.</h3><p>Bone ribs, root thresholds, water galleries and orange circulation make places legible through geometry and material, beyond a palette change.</p></article></div>`;
  }
  function render(){
    const local=state.view==='local',world=state.view==='world';
    for(const key of ['world','local','scope'])$('nav-'+key).setAttribute('aria-pressed',String(key===state.view));
    $('atlas-layout').hidden=state.view==='scope';$('scope-view').hidden=state.view!=='scope';$('principles').hidden=state.view==='scope';
    $('world-map').toggleAttribute('hidden',!world);$('local-map').toggleAttribute('hidden',!local||state.geometry!=='plan');$('three-map').hidden=!local||state.geometry!=='three';$('local-controls').hidden=!local;$('local-tools').hidden=!local;
    $('map-eyebrow').textContent=local?'Current shell / proposed expedition':'Permanent habitats / variable expeditions';
    $('map-title').textContent=local?'The Warrens, a supper below.':'A camp above the dark.';
    $('map-description').textContent=local?'Fixed current geometry. Switch authored setups to compare the proposed hunt, forage and loaded return.':'Three illustrative districts. One normal contract stays within one district; the wider spire is a future horizon.';
    $('map-code').innerHTML=local?'PLATE 02<br>WARRENS / PLAN<br>'+m.boxes.length.toLocaleString()+' PRIMITIVES':'PLATE 01<br>SPIRE / SECTION<br>CONCEPTUAL TOPOLOGY';
    $('view-status').textContent=local?'CURRENT GEOMETRY / PROPOSED ASSIGNMENTS':world?'WORLD SCHEMATIC · NOT TO SCALE':'BOUNDED MVP / REUSE FIRST';
    $('map-legend').innerHTML=local?'<span><i class="swatch" style="--c:var(--orange)"></i>Existing traversal</span><span><i class="swatch" style="--c:var(--teal)"></i>Graph overlay</span><span><i class="swatch dashed" style="--c:var(--amber)"></i>Schematic connector</span>':'<span><i class="swatch" style="--c:var(--amber)"></i>Habitat / district</span><span><i class="swatch dashed" style="--c:var(--teal)"></i>Proposed connection</span>';
    if(world){renderWorld();renderWorldInspector();$('map-caption').textContent='ILLUSTRATIVE SPIRE · district silhouettes and transit links are conceptual, not authored geometry.';}else if(local){renderLocal();if(state.geometry==='three'){init3();draw3();}}else renderScope();
    if(state.view!=='scope')sizeInspector();
  }
  function init3(){
    if(renderer)return;
    try{
      renderer=new THREE.WebGLRenderer({canvas:$('three-map'),antialias:true,preserveDrawingBuffer:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));scene3=new THREE.Scene();scene3.background=new THREE.Color('#0b1113');camera=new THREE.PerspectiveCamera(48,1,.05,700);camera.up.set(0,0,1);
      scene3.add(new THREE.AmbientLight(0xffffff,1.6));const sun=new THREE.DirectionalLight(0xffeccb,2.2);sun.position.set(-30,-50,120);scene3.add(sun);
      const buckets=new Map();for(const b of m.boxes){const wall=['wall','roof'].includes(b.kind),key=[b.material||b.kind,level(b.centre[2]+b.size[2]/2),wall].join('|');if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(b);}
      const geo=new THREE.BoxGeometry(1,1,1),dummy=new THREE.Object3D();for(const boxes of buckets.values()){const b=boxes[0],wall=['wall','roof'].includes(b.kind),material=new THREE.MeshLambertMaterial({color:new THREE.Color().setRGB(...palette(b)),transparent:wall||b.kind==='water',opacity:wall?.28:b.kind==='water'?.55:1});const mesh=new THREE.InstancedMesh(geo,material,boxes.length);boxes.forEach((box,i)=>{dummy.position.set(...box.centre);dummy.scale.set(...box.size);dummy.rotation.set(0,-box.pitch*Math.PI/180,box.yaw*Math.PI/180,'ZYX');dummy.updateMatrix();mesh.setMatrixAt(i,dummy.matrix);});mesh.userData={level:level(b.centre[2]+b.size[2]/2),wall};scene3.add(mesh);meshes.push(mesh);}
      const grid=new THREE.GridHelper(170,17,0x425059,0x26333b);grid.rotation.x=Math.PI/2;grid.position.set(40,40,-6);scene3.add(grid);overlay3=new THREE.Group();scene3.add(overlay3);refresh3();
    }catch(error){$('map-caption').textContent='3D unavailable in this browser. The current floor plan and all design controls remain available.';$('geometry-view').value='plan';state.geometry='plan';$('three-map').hidden=true;$('local-map').removeAttribute('hidden');console.warn('3D cutaway unavailable:',error);}
  }
  function refresh3(){if(!overlay3)return;for(const mesh of meshes)mesh.visible=(state.floor==='all'||mesh.userData.level===+state.floor)&&(!mesh.userData.wall||state.walls);for(const child of [...overlay3.children]){overlay3.remove(child);child.traverse(v=>{v.geometry?.dispose();v.material?.dispose();});}
    function route(points,col,dashed){if(!points?.length)return;const geometry=new THREE.BufferGeometry().setFromPoints(points.map(v=>new THREE.Vector3(v[0],v[1],(v[2]||0)+.25)));const material=dashed?new THREE.LineDashedMaterial({color:col,dashSize:1,gapSize:.6,depthTest:false}):new THREE.LineBasicMaterial({color:col,depthTest:false});const line=new THREE.Line(geometry,material);if(dashed)line.computeLineDistances();overlay3.add(line);}
    if(state.reveal)for(const r of stagePaths())route(r.points,r.kind==='graph'?C.teal:C.amber,r.kind!=='graph');
    const mechanism=selectedMechanism();if(mechanism){const control=mechanism.id==='P4'?d.bellkeeper.panel.at:mechanism.needsAt;if(control)route([control,mechanism.at],C.amber,true);}
    if(state.staging)for(const r of d.twoPlayer.clearRectangles||[])if(visible(r.floorZ)){const a=r.rectPlanM;route([[a[0],a[1],r.floorZ],[a[2],a[1],r.floorZ],[a[2],a[3],r.floorZ],[a[0],a[3],r.floorZ],[a[0],a[1],r.floorZ]],C.teal,false);}
  }
  function draw3(){if(!renderer||state.view!=='local'||state.geometry!=='three')return;const stage=$('map-viewport'),w=stage.clientWidth,h=stage.clientHeight;renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();camera.position.set(orbit.x+orbit.radius*Math.cos(orbit.theta)*Math.cos(orbit.phi),orbit.y+orbit.radius*Math.sin(orbit.theta)*Math.cos(orbit.phi),orbit.z+orbit.radius*Math.sin(orbit.phi));camera.lookAt(orbit.x,orbit.y,orbit.z);renderer.render(scene3,camera);}
  function reset(){view=initial.slice();orbit.x=minx+initial[2]/2;orbit.y=miny+initial[3]/2;orbit.radius=180;orbit.theta=-1.3;orbit.phi=1.05;renderPlan();draw3();}
  function zoom(factor){const cx=view[0]+view[2]/2,cy=view[1]+view[3]/2;view[2]=Math.max(10,Math.min(350,view[2]*factor));view[3]=Math.max(10,Math.min(350,view[3]*factor));view[0]=cx-view[2]/2;view[1]=cy-view[3]/2;orbit.radius=Math.max(12,Math.min(300,orbit.radius*factor));renderPlan();draw3();}
  for(const name of ['world','local','scope'])$('nav-'+name).onclick=()=>setView(name);
  $('geometry-view').onchange=e=>{state.geometry=e.target.value;render();};$('floor').onchange=e=>{state.floor=e.target.value;renderPlan();if(renderer){refresh3();draw3();}};
  $('show-staging').onchange=e=>{state.staging=e.target.checked;renderPlan();if(renderer){refresh3();draw3();}};$('show-walls').onchange=e=>{state.walls=e.target.checked;if(renderer){refresh3();draw3();}};
  $('mechanism').onchange=e=>{state.mechanism=e.target.value;renderLocal();};
  $('fit-map').onclick=reset;$('zoom-in').onclick=()=>zoom(.8);$('zoom-out').onclick=()=>zoom(1.25);
  $('map-viewport').onwheel=e=>{if(state.view!=='local')return;e.preventDefault();zoom(Math.exp(e.deltaY*.001));};
  for(const id of ['local-map','three-map']){const el=$(id);el.oncontextmenu=e=>e.preventDefault();el.onpointerdown=e=>{drag={id,x:e.clientX,y:e.clientY,button:e.button};el.setPointerCapture(e.pointerId);};el.onpointerup=el.onpointercancel=()=>drag=null;el.onpointermove=e=>{if(!drag||drag.id!==id)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;drag.x=e.clientX;drag.y=e.clientY;if(id==='local-map'){const scale=Math.max(view[2]/el.clientWidth,view[3]/el.clientHeight);view[0]-=dx*scale;view[1]-=dy*scale;renderPlan();}else if(drag.button===2){orbit.x-=dx*.08;orbit.y+=dy*.08;draw3();}else{orbit.theta-=dx*.008;orbit.phi=Math.max(.15,Math.min(1.5,orbit.phi+dy*.006));draw3();}};}
  $('map-viewport').onkeydown=e=>{if(state.view!=='local')return;if(e.key==='+'||e.key==='='){e.preventDefault();zoom(.8);return;}if(e.key==='-'){e.preventDefault();zoom(1.25);return;}if(e.key==='Home'){e.preventDefault();reset();return;}const deltas={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]};if(!deltas[e.key])return;e.preventDefault();if(state.geometry==='three'){orbit.theta+=deltas[e.key][0]*.12;orbit.phi=Math.max(.15,Math.min(1.5,orbit.phi-deltas[e.key][1]*.08));draw3();}else{view[0]+=deltas[e.key][0]*view[2]*.07;view[1]+=deltas[e.key][1]*view[3]*.07;renderPlan();}};
  function sizeInspector(){const inspector=$('inspector');if(window.innerWidth>760)inspector.style.maxHeight=document.querySelector('.cartography').offsetHeight+'px';else inspector.style.removeProperty('max-height');}
  new ResizeObserver(()=>{draw3();if(state.view==='local')renderPlan();sizeInspector();}).observe($('map-viewport'));
  window.addEventListener('resize',sizeInspector);
  $('snapshot').textContent=`${d.revision||'Current'} · ${m.boxes.length.toLocaleString()} embedded primitives · offline`;
  $('provenance').innerHTML=`SOURCE SNAPSHOT ${esc((payload.commit||'uncommitted').slice(0,12))}<br>SHA-256 ${esc((payload.sourceHash||'').slice(0,20))}…<br>Self-contained HTML · no network required`;
  render();
  window.WarrensExpedition={payload,state,setView,openLocal,chooseDistrict,render,scenario,phase,graphPoints,stagePaths,get scene(){return scene3;},get meshes(){return meshes;},get renderer(){return renderer;},get viewBox(){return view.slice();}};
})();
