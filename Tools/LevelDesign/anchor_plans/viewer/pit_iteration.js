/* HTML-only assembly study. All dimensions and sightlines are proposals. */
(()=>{'use strict';
const data=JSON.parse(document.getElementById('data').textContent),p=structuredClone(data.proposal),$=id=>document.getElementById(id),NS='http://www.w3.org/2000/svg';
const C={stone:'#817a68',mineral:'#497a80',metal:'#58747b',wood:'#775135',bone:'#b4a68b',root:'#66734e',orange:'#df8b3f',teal:'#86d3c6',amber:'#f6b35e',rose:'#df9ca1'};
const state={view:'plan',selected:'PitHub',bounds:false,sightlines:false,shortcuts:false,route:'none',isolate:false,checkpoint:'overview'};
let view=[-58,-52,116,106],renderer,scene,camera,group,drag=null;
const orbit={x:0,y:0,z:0,r:140,theta:-1.2,phi:.95};
const esc=v=>String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const mod=id=>p.modules.find(m=>m.id===id),selected=()=>mod(state.selected);
function position(m){return [...m.at];}
function port(id,key){const m=mod(id),a=position(m),b=m.ports[key];return a.map((v,i)=>v+b[i]);}
function points(e){const a=port(e.a,e.ap),b=port(e.b,e.bp),vs=e.via.map(v=>[...v]);if(e.kind==='ladder'){const q=vs[0];return[a,q,[q[0],q[1],b[2]],b];}return[a,...vs,b];}
const length=pts=>pts.slice(1).reduce((n,b,i)=>n+Math.hypot(b[0]-pts[i][0],b[1]-pts[i][1]),0);

function node(tag,attrs={},text){const n=document.createElementNS(NS,tag);for(const[k,v]of Object.entries(attrs))n.setAttribute(k,v);if(text!==undefined)n.textContent=text;return n;}
function line(parent,pts,attrs={}){parent.append(node('polyline',{points:pts.map(v=>`${v[0]},${-v[1]}`).join(' '),fill:'none',stroke:C.teal,'stroke-width':.3,...attrs}));}
function unit(svg=$('plan')){if(svg.tagName?.toLowerCase()!=='svg')svg=$('plan');return Math.max(view[2]/(svg.clientWidth||$('scene').clientWidth||1000),view[3]/(svg.clientHeight||760));}
function label(parent,at,text,size=12,color='#e8e9df',attrs={}){const u=unit(parent.ownerSVGElement||parent);parent.append(node('text',{x:at[0],y:-at[1],fill:color,'font-size':size*u,style:`stroke-width:${2*u}`,'text-anchor':'middle',...attrs},text));}
function rect(parent,x,y,w,h,attrs={}){parent.append(node('rect',{x,y:-y-h,width:w,height:h,...attrs}));}


function poly(parent,pts,attrs={}){parent.append(node('polygon',{points:pts.map(v=>`${v[0]},${-v[1]}`).join(' '),...attrs}));}
function worldPoly(m){return m.poly.map(v=>[v[0]+m.at[0],v[1]+m.at[1]]);}
function planDetail(g,m){const a=m.at,id=m.id;
if(id==='Court'){rect(g,-37,7,7,5,{fill:'#b2a285',stroke:'#e0cfad','stroke-width':.2});for(const y of [-10,0,12])rect(g,-18.7,y-.7,1.4,1.4,{fill:'#d5c3a1'});line(g,[[-43,-5],[-40,-5],[-40,-11]],{stroke:'#b2a285','stroke-width':1.2});}
if(id==='Arrival')rect(g,-9,20,5,1.3,{fill:'#b2a285'});
if(id==='Waterworks'){rect(g,18,4,24,18,{fill:'#0a191e',stroke:'#658890','stroke-width':.25});line(g,[[36,4],[36,12],[28,18],[11,18],[11,8]],{stroke:'#9c7650','stroke-width':2.2,'stroke-dasharray':'.8 .7'});for(const y of [-6,1])line(g,[[23,y],[43,y]],{stroke:'#93b3b6','stroke-width':.65});label(g,[32,12],'OPEN DOWN',9,C.teal);label(g,[32,8],'quarry terraces',9,C.teal);}
if(id==='Belfry'){rect(g,18,-40,6,28,{fill:'#ac7d4b','fill-opacity':.7});rect(g,24,-40,22,6,{fill:'#ac7d4b','fill-opacity':.7});rect(g,24,-25,7,6,{fill:'#ac7d4b','fill-opacity':.7});for(let k=0;k<8;k++)line(g,[[25,-34+k*1.5],[31,-34+k*1.5]],{stroke:C.orange,'stroke-width':.3});rect(g,34,-29,4,4,{fill:'#c0b19a',stroke:'#e8d5ad','stroke-width':.2});label(g,[21,-17],'0 m',9,C.amber);label(g,[39,-33],'−3 m',9);}
if(id==='Ossuary'){for(const x of [-11,11])for(const y of [-35,-29,-23])rect(g,x-1.8,y-1,3.6,2,{fill:'#d0c4ab','fill-opacity':.8});for(const y of [-36,-31,-26,-21]){line(g,[[-7,y],[-4,y]],{stroke:'#d2c3a5','stroke-width':.7});line(g,[[4,y],[7,y]],{stroke:'#d2c3a5','stroke-width':.7});}}
if(id==='Grotto'){line(g,[[-42,-17],[-36,-20],[-31,-27],[-25,-29]],{stroke:'#a0a76b','stroke-width':2.2});for(const v of [[-41,-29],[-38,-34],[-23,-35]])g.append(node('circle',{cx:v[0],cy:-v[1],r:1.3,fill:'#b5b66e'}));}
}
function renderPlan(){
const svg=$('plan');svg.replaceChildren();svg.setAttribute('viewBox',view.join(' '));
const defs=node('defs'),pat=node('pattern',{id:'grid',width:10,height:10,patternUnits:'userSpaceOnUse'});pat.append(node('path',{d:'M10 0H0V10',fill:'none',stroke:'#2c3f44','stroke-width':.12}));defs.append(pat);svg.append(defs);svg.append(node('rect',{x:-250,y:-250,width:500,height:500,fill:'url(#grid)'}));
for(const m of [...p.modules].sort((a,b)=>a.at[2]-b.at[2])){if(state.isolate&&m.id!==state.selected)continue;const a=m.at,g=node('g',{class:'pick',role:'button',tabindex:0,'aria-label':'Inspect '+m.name});
if(m.id==='PitDepths'){if(state.selected===m.id||state.route==='lower'){rect(g,-12,-12,24,24,{fill:'#24474b','fill-opacity':.5});rect(g,24,-10,12,12,{fill:C.mineral,stroke:C.amber,'stroke-width':.3});label(g,[30,-3],'Vault −8 m',10);}svg.append(g);continue;}
poly(g,worldPoly(m),{fill:C[m.theme],'fill-opacity':.66,stroke:state.selected===m.id?C.amber:'#bac2b7','stroke-width':state.selected===m.id?.6:.2});
planDetail(g,m);
if(m.id==='PitHub'){rect(g,-12,-12,24,24,{rx:1,fill:'#071013',stroke:C.teal,'stroke-width':.3});line(g,[[-9,3],[5,3]],{stroke:'#b7976a','stroke-width':1.1});rect(g,-10,1.8,2,2.4,{fill:'#b7976a'});label(g,[0,-2],'THE PIT',16,C.teal);label(g,[0,-6],'same shaft / quarry below',9,C.teal);for(let k=0;k<8;k++)line(g,[[12+k*.75,0],[12+k*.75,8]],{stroke:C.orange,'stroke-width':.2});}
else{const shifts={Court:[-3,-1],Waterworks:[0,-12],Belfry:[3,-5],Grotto:[-2,-10],Ossuary:[0,-2],Arrival:[0,1]},q=shifts[m.id]||[0,0];label(g,[a[0]+q[0],a[1]+q[1]],m.name,m.id==='Belfry'?11:12);if(!['Waterworks','Belfry'].includes(m.id))label(g,[a[0]+q[0],a[1]+q[1]-3],`${a[2]>0?'+':''}${a[2]} m`,9);}
if(state.bounds){poly(g,worldPoly(m),{fill:'none',stroke:C.teal,'stroke-width':.5,'stroke-dasharray':'1 .65'});for(const key of Object.keys(m.ports)){const v=port(m.id,key);g.append(node('circle',{cx:v[0],cy:-v[1],r:.6,fill:C.teal,stroke:'#071013','stroke-width':.16}));}}
g.onclick=()=>choose(m.id);g.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();choose(m.id);}};svg.append(g);}
// Route traces run through the spaces; seams themselves are not corridor floors.
for(const e of p.links){if(state.isolate&&e.a!==state.selected&&e.b!==state.selected)continue;const pts=points(e),col=e.shortcut?C.rose:C.teal;if(e.id==='QuarryDescent')continue;if(length(pts)>.1)line(svg,pts,{stroke:col,'stroke-width':e.width,'stroke-opacity':.45,'stroke-dasharray':e.shortcut&&!state.shortcuts?'1 .7':'none'});if(state.bounds){const a=pts[0];svg.append(node('circle',{cx:a[0],cy:-a[1],r:1,fill:col}));}}
if(state.route!=='none'&&!state.isolate){const trace=p.routes[state.route];line(svg,trace,{stroke:'#111b20','stroke-width':1.8,'stroke-linejoin':'round'});line(svg,trace,{stroke:C.amber,'stroke-width':.65,'stroke-dasharray':state.route==='lower'?'1 .6':'none','stroke-linejoin':'round'});for(let i=1;i<trace.length-1;i+=3)svg.append(node('circle',{cx:trace[i][0],cy:-trace[i][1],r:.8,fill:C.amber}));}
const camp=port('Arrival','camp');line(svg,[camp,[camp[0],camp[1]+8]],{stroke:C.amber,'stroke-width':.6,'stroke-dasharray':'1 .7'});label(svg,[camp[0],camp[1]+11],'BASE CAMP · kitchen / cooking',11,C.amber);
if(state.sightlines)for(const cp of p.checkpoints){line(svg,[cp.eye,cp.target],{stroke:C.amber,'stroke-width':.2,'stroke-dasharray':'.6 .6'});svg.append(node('circle',{cx:cp.eye[0],cy:-cp.eye[1],r:.6,fill:C.amber}));}
}
function renderBaseline(){const svg=$('baseline');svg.replaceChildren();svg.setAttribute('viewBox',view.join(' '));const d=data.previous,mp=id=>d.modules.find(m=>m.id===id),pt=(id,key)=>mp(id).at.map((v,i)=>v+mp(id).ports[key][i]);for(const e of d.links){line(svg,[pt(e.a,e.ap),...e.via,pt(e.b,e.bp)],{stroke:'#52666a','stroke-width':e.width,opacity:.8});}for(const m of d.modules){if(m.id==='PitDepths')continue;rect(svg,m.at[0]-m.size[0]/2,m.at[1]-m.size[1]/2,...m.size,{fill:C[m.theme],'fill-opacity':.55,stroke:'#9caaa4','stroke-width':.15});if(m.id==='PitHub')rect(svg,-12,-12,24,24,{fill:'#071013'});label(svg,m.at,m.id==='PitHub'?'Pit / Well':m.name,10);}}
function inspection(){const m=selected();$('module').value=m.id;$('inspection').innerHTML=`<div class="eyebrow">${esc(m.asset)}</div><h3>${esc(m.name)}</h3><p>${esc(m.landmark)}</p><p class="fine">${esc(m.intent)}</p><p class="fine" style="margin-top:10px">${esc(m.setup)}</p><p class="fine">Pivot: ${m.at.join(', ')} m · bounding extent ${m.size.join(' × ')} m · height ${m.height} m. Bounds describe authoring ownership, not isolated room boxes.</p>`;}

function polygonsOverlap(a,b){const cross=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
const inside=(q,poly)=>{let hit=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[j],b=poly[i];if(Math.abs(cross(a,b,q))<1e-7&&q[0]>=Math.min(a[0],b[0])-1e-7&&q[0]<=Math.max(a[0],b[0])+1e-7&&q[1]>=Math.min(a[1],b[1])-1e-7&&q[1]<=Math.max(a[1],b[1])+1e-7)return false;if((a[1]>q[1])!==(b[1]>q[1])&&q[0]<(b[0]-a[0])*(q[1]-a[1])/(b[1]-a[1])+a[0])hit=!hit;}return hit;};
if(a.some(v=>inside(v,b))||b.some(v=>inside(v,a)))return true;
for(let i=0;i<a.length;i++)for(let j=0;j<b.length;j++){const x=a[i],y=a[(i+1)%a.length],u=b[j],v=b[(j+1)%b.length];if(cross(x,y,u)*cross(x,y,v)<-1e-7&&cross(u,v,x)*cross(u,v,y)<-1e-7)return true;}
// Edge midpoints also catch aligned overlapping rectangles whose vertices lie on edges.
return a.some((v,i)=>inside([(v[0]+a[(i+1)%a.length][0])/2,(v[1]+a[(i+1)%a.length][1])/2],b))||b.some((v,i)=>inside([(v[0]+b[(i+1)%b.length][0])/2,(v[1]+b[(i+1)%b.length][1])/2],a));}
function validate(){const errors=[],ordinary=p.links.filter(e=>!e.shortcut||state.shortcuts),seen=new Set(['Arrival']);let change=true;while(change){change=false;for(const e of ordinary)if(seen.has(e.a)&&!seen.has(e.b)){seen.add(e.b);change=true;}else if(seen.has(e.b)&&!seen.has(e.a)){seen.add(e.a);change=true;}}
if(seen.size!==p.modules.length)errors.push('Disconnected area');
for(let i=0;i<p.modules.length;i++)for(let j=i+1;j<p.modules.length;j++){const a=p.modules[i],b=p.modules[j];if(a.id==='PitDepths'||b.id==='PitDepths')continue;if(polygonsOverlap(worldPoly(a),worldPoly(b)))errors.push(`${a.name} overlaps ${b.name}`);}
const spans=p.links.filter(e=>!e.shortcut).map(e=>length(points(e)));const result={graphConnected:seen.size===p.modules.length,modules:p.modules.length,ordinaryLinks:p.links.filter(e=>!e.shortcut).length,shortcuts:2,errors,directJoins:p.links.filter(e=>!e.shortcut&&e.id!=='QuarryDescent'&&length(points(e))<=3.1).length,transitionMin:Math.min(...spans),transitionMax:Math.max(...spans)};
$('validation').className='status'+(errors.length?' warning':'');$('validation').textContent=errors.length?errors.join('; '):`Concept graph connected · ${result.directJoins} direct / thick-wall joins; quarry descent is inside the pump void. No physics / visibility proof.`;return result;}
function choose(id){state.selected=id;inspection();draw();}

function addBox(list,id,at,size,theme='stone',yaw=0,pitch=0,tag='shell'){list.push({id,at,size,theme,yaw,pitch,tag});}
function slab(list,id,poly,z,theme,holes=[]){list.push({id,poly,z,theme,holes,tag:'floor'});}
function beam(list,id,a,b,width=.5,height=4,theme='stone',tag='shell'){const run=Math.hypot(b[0]-a[0],b[1]-a[1]);if(run<.01)return;addBox(list,id,[(a[0]+b[0])/2,(a[1]+b[1])/2,(a[2]+b[2])/2],[Math.hypot(run,b[2]-a[2]),width,height],theme,Math.atan2(b[1]-a[1],b[0]-a[0])*180/Math.PI,-Math.atan2(b[2]-a[2],run)*180/Math.PI,tag);}
function ramp(list,id,a,b,width,theme='orange'){const run=Math.hypot(b[0]-a[0],b[1]-a[1]),dz=b[2]-a[2];if(run<.01)return;addBox(list,id,[(a[0]+b[0])/2,(a[1]+b[1])/2,(a[2]+b[2])/2-.2],[Math.hypot(run,dz)+.12,width,.4],theme,Math.atan2(b[1]-a[1],b[0]-a[0])*180/Math.PI,-Math.atan2(dz,run)*180/Math.PI,'internal-route');}
function shellWalls(bs,m){const verts=worldPoly(m),a=m.at;
for(let i=0;i<verts.length;i++){const v=verts[i],w=verts[(i+1)%verts.length],dx=w[0]-v[0],dy=w[1]-v[1],len=Math.hypot(dx,dy),cuts=[];
if(m.openEdges?.includes(i)){for(let t=0;t<len;t+=9){const x=v[0]+dx*t/len,y=v[1]+dy*t/len;addBox(bs,m.id,[x,y,a[2]+m.height/2],[.9,.9,m.height],m.theme);}beam(bs,m.id,[v[0],v[1],a[2]+m.height-.4],[w[0],w[1],a[2]+m.height-.4],.7,.8,m.theme);continue;}
for(const q of Object.values(m.ports)){const x=q[0]+a[0],y=q[1]+a[1],t=((x-v[0])*dx+(y-v[1])*dy)/len;if(t>=-.01&&t<=len+.01&&Math.abs((x-v[0])*dy-(y-v[1])*dx)/len<.02){const width=m.id==='Belfry'?7:6;cuts.push([Math.max(0,t-width/2),Math.min(len,t+width/2)]);}}
cuts.sort((x,y)=>x[0]-y[0]);let last=0;for(const [lo,hi] of [...cuts,[len,len]]){if(lo>last+.01)beam(bs,m.id,[v[0]+dx*last/len,v[1]+dy*last/len,a[2]+m.height/2],[v[0]+dx*lo/len,v[1]+dy*lo/len,a[2]+m.height/2],.45,m.height,m.theme);last=Math.max(last,hi);}
}}
function geometry(){const bs=[];
for(const m of p.modules){const a=m.at,id=m.id;
if(id==='PitHub'){
for(const q of [[0,15,36,6],[0,-15,36,6],[-15,0,6,24],[15,-6,6,12],[15,10,6,4]])addBox(bs,id,[q[0],q[1],-.25],[q[2],q[3],.5],'mineral');
ramp(bs,id,[12,4,0],[18,4,-3],8); // The pump stair is cut into the rim, not a spoke.
for(const q of [[0,12,24,.16],[0,-12,24,.16],[-12,0,.16,24],[12,-6,.16,12],[12,10,.16,4]])addBox(bs,id,[q[0],q[1],.55],[q[2],q[3],1.1],'metal');
addBox(bs,id,[-9,3,5],[1.2,1.2,10],'wood');addBox(bs,id,[-2,3,9.5],[15,1,1],'wood');addBox(bs,id,[5,3,5.7],[.16,.16,7],'metal');
for(const x of [-4,4])addBox(bs,id,[x,18,2.2],[.8,.8,4.4],'stone');addBox(bs,id,[-2.3,18,4.5],[3.4,.9,.6],'stone');
for(const y of [-10,0,12])addBox(bs,id,[-18,y,4.5],[.9,.9,9],'stone');
for(const y of [-.5,8.5])addBox(bs,id,[18,y,.2],[.5,.5,5.6],'metal');addBox(bs,id,[18,4,3.1],[.6,9.5,.6],'metal');
for(let k=0;k<3;k++){const y=-18-k*2;for(const x of [-3.3,3.3])addBox(bs,id,[x,y,2],[.4,.6,4],'bone');addBox(bs,id,[0,y,4.1],[7,.6,.4],'bone');}
for(const x of [16,20])addBox(bs,id,[x,-11,2.5],[.5,.5,5],'wood');addBox(bs,id,[18,-11,5.1],[4.5,.6,.5],'wood');continue;}
if(id==='PitDepths'){addBox(bs,id,[0,0,-8.3],[24,24,.6],'mineral');addBox(bs,id,[30,-4,-8.3],[12,12,.6],'mineral');addBox(bs,id,[18,-4,-8.3],[12,4,.6],'mineral');for(const x of [-12,12]){addBox(bs,id,[x,-8,-4.5],[.5,8,7],'mineral');if(x<0)addBox(bs,id,[x,11,-4.5],[.5,2,7],'mineral');}continue;}
// One floor is deliberately absent: Waterworks opens to the descending terraces.
if(id==='Waterworks'){
slab(bs,id,[[18,-12],[46,-12],[46,22],[42,22],[42,4],[18,4]],-3,'metal');
for(const y of [-6,1]){addBox(bs,id,[32,y,1.8],[21,.6,.6],'metal');for(const x of [23,43])addBox(bs,id,[x,y,-.8],[.5,.5,4.4],'metal');}
addBox(bs,id,[44,12,-.5],[.6,16,.6],'metal');
}else slab(bs,id,worldPoly(m),a[2],m.theme);
shellWalls(bs,m);
if(id==='Arrival'){addBox(bs,id,[-6,20,1.6],[5,1,3.2],'stone');for(const x of [-6,6])addBox(bs,id,[x,28,.5],[2,4,1],'wood');}
if(id==='Court'){addBox(bs,id,[-33.5,9.5,.5],[7,5,1],'stone');addBox(bs,id,[-35,9.5,3.5],[2.6,2,6],'stone',-12);addBox(bs,id,[-31.7,10,2.8],[2.2,2,4.6],'stone',18);beam(bs,id,[-43,-5,1.6],[-40,-5,1.6],1,3.2);beam(bs,id,[-40,-5,1.6],[-40,-11,1.6],1,3.2);}
if(id==='Ossuary'){for(const x of [-11,11])for(const y of [-35,-29,-23])addBox(bs,id,[x,y,1.4],[3.6,2,2.8],'bone');for(const y of [-36,-31,-26])for(const x of [-6,6])addBox(bs,id,[x,y,2],[.5,.7,4],'bone');addBox(bs,id,[-5,-19,1.5],[4,1,3],'bone');}
if(id==='Belfry'){
// Low service floor and raised reader gallery share one tall chamber.
addBox(bs,id,[21,-26,-.2],[6,28,.4],'wood');addBox(bs,id,[35,-37,-.2],[22,6,.4],'wood');addBox(bs,id,[27,-22,-.2],[8,6,.4],'wood');
ramp(bs,id,[28,-34,-3],[28,-22,0],6);
for(const x of [33,39])addBox(bs,id,[x,-27,2],[.6,.6,10],'wood');addBox(bs,id,[36,-27,7],[7,.8,.7],'wood');addBox(bs,id,[36,-27,5.2],[2,2,2.8],'metal');
for(const y of [-32,-23,-14])addBox(bs,id,[24,y,-1.5],[.45,.45,3],'wood');beam(bs,id,[24,-31,.6],[24,-26,.6],.12,1.2,'metal');
}
if(id==='Grotto'){for(const [x,y,yaw] of [[-40,-18,20],[-35,-23,-15],[-29,-27,30]]){addBox(bs,id,[x,y,1.5],[1.5,2,3],'root',yaw);addBox(bs,id,[x+1,y,3.5],[7,1.2,1.2],'root',yaw);}for(const [x,y] of [[-41,-29],[-38,-34],[-23,-35]])addBox(bs,id,[x,y,.35],[2.6,2.6,.7],'root');}
}
for(const e of p.links){const pts=points(e);for(let i=1;i<pts.length;i++){const a=pts[i-1],b=pts[i],run=Math.hypot(b[0]-a[0],b[1]-a[1]),dz=b[2]-a[2];if(run<.01){if(!dz)continue;for(let z=Math.min(a[2],b[2]);z<Math.max(a[2],b[2]);z+=.4)addBox(bs,e.id,[a[0],a[1],z],[1.2,.2,.1],'orange');for(const x of [-.65,.65])addBox(bs,e.id,[a[0]+x,a[1],(a[2]+b[2])/2],[.1,.15,Math.abs(dz)],'metal');continue;}
ramp(bs,e.id,a,b,e.width,dz?'orange':e.shortcut?'wood':'stone');
if(e.id==='QuarryDescent'){// Broad supported landings make a winding room, not an unsupported line.
addBox(bs,e.id,[b[0],b[1],b[2]-.25],[e.width,e.width,.5],'mineral');for(const side of [-1,1]){const nx=-(b[1]-a[1])/run*side*e.width/2,ny=(b[0]-a[0])/run*side*e.width/2;beam(bs,e.id,[a[0]+nx,a[1]+ny,a[2]+.6],[b[0]+nx,b[1]+ny,b[2]+.6],.13,1.2,'metal','guard');}addBox(bs,e.id,[b[0],b[1],-9],[.6,.6,Math.max(.5,(b[2]+9)*2)],'metal');}
}}
return bs;}

function init3(){if(renderer)return;renderer=new THREE.WebGLRenderer({canvas:$('three'),antialias:true,preserveDrawingBuffer:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));scene=new THREE.Scene();scene.background=new THREE.Color('#0b1215');camera=new THREE.PerspectiveCamera(50,1,.05,800);camera.up.set(0,0,1);scene.add(new THREE.AmbientLight(0xffffff,1.8));const light=new THREE.DirectionalLight(0xffe6c7,2);light.position.set(-60,-80,140);scene.add(light);const grid=new THREE.GridHelper(130,13,0x415b60,0x24383e);grid.rotation.x=Math.PI/2;grid.position.z=-12;scene.add(grid);group=new THREE.Group();scene.add(group);}

function build3(){if(!renderer)return;for(const obj of [...group.children]){group.remove(obj);obj.geometry?.dispose();obj.material?.dispose();}
for(const b of geometry()){if(state.isolate&&b.id!==state.selected&&!p.links.some(e=>e.id===b.id&&(e.a===state.selected||e.b===state.selected)))continue;
let geo;if(b.poly){const shape=new THREE.Shape();shape.moveTo(...b.poly[0]);for(const v of b.poly.slice(1))shape.lineTo(...v);shape.closePath();geo=new THREE.ExtrudeGeometry(shape,{depth:.5,bevelEnabled:false});}else geo=new THREE.BoxGeometry(1,1,1);
const mesh=new THREE.Mesh(geo,new THREE.MeshLambertMaterial({color:C[b.theme]}));if(b.poly)mesh.position.z=b.z-.5;else{mesh.position.set(...b.at);mesh.scale.set(...b.size);mesh.rotation.set(0,b.pitch*Math.PI/180,b.yaw*Math.PI/180,'ZYX');}group.add(mesh);}
const paths=state.sightlines?p.checkpoints.map(cp=>({points:[cp.eye,cp.target],dashed:true})):[];if(state.route!=='none')paths.push({points:p.routes[state.route].map(v=>[v[0],v[1],v[2]+.2]),dashed:state.route==='lower'});
for(const path of paths){const g=new THREE.BufferGeometry().setFromPoints(path.points.map(v=>new THREE.Vector3(...v))),material=path.dashed?new THREE.LineDashedMaterial({color:C.amber,dashSize:.8,gapSize:.6,depthTest:false}):new THREE.LineBasicMaterial({color:C.amber,depthTest:false});const line=new THREE.Line(g,material);line.computeLineDistances();line.renderOrder=5;group.add(line);}
}

function draw3(){if(state.view!=='three'||!renderer)return;const s=$('scene');renderer.setSize(s.clientWidth,s.clientHeight,false);camera.aspect=s.clientWidth/s.clientHeight;camera.updateProjectionMatrix();const cp=p.checkpoints.find(v=>v.id===state.checkpoint);if(cp){camera.position.set(...cp.eye);camera.lookAt(...cp.target);}else{camera.position.set(orbit.x+orbit.r*Math.cos(orbit.theta)*Math.cos(orbit.phi),orbit.y+orbit.r*Math.sin(orbit.theta)*Math.cos(orbit.phi),orbit.z+orbit.r*Math.sin(orbit.phi));camera.lookAt(orbit.x,orbit.y,orbit.z);}renderer.render(scene,camera);}
function draw(){renderPlan();if(state.view==='compare')renderBaseline();validate();if(renderer){build3();draw3();}}
function research(){ $('research').innerHTML='<h2>Research → layout decisions</h2><p class="muted">Primary developer commentary informs these proposals; it does not validate this layout.</p><div class="cards">'+p.research.map(r=>`<article class="card"><h3><a href="${r.url}" target="_blank" rel="noopener">${esc(r.title)} ↗</a></h3><p>${esc(r.finding)}</p><p><strong>Apply:</strong> ${esc(r.application)}</p><p class="fine">${esc(r.limit)}</p></article>`).join('')+'</div>';}
function contracts(){ $('details').innerHTML='<h2>One complex, eight authoring areas</h2><p class="muted">Proposed ownership seams follow the architecture. They do not require eight independent rooms or corridor instances.</p><div style="overflow:auto"><table><thead><tr><th>Level Instance</th><th>Pivot / floor</th><th>Footprint</th><th>Local ports (x, y, z m)</th></tr></thead><tbody>'+p.modules.map(m=>`<tr><td>${esc(m.asset)}<br><small>${esc(m.name)}</small></td><td>${position(m).join(', ')}</td><td>${m.size.join(' × ')} m</td><td>${Object.entries(m.ports).map(([k,v])=>`${k}: ${v.join(', ')}`).join('<br>')}</td></tr>`).join('')+'</tbody></table></div><h3 style="margin-top:24px">Existing mechanisms: proposed disposition</h3><table><tr><th>Mechanism</th><th>Location / intent</th></tr><tr><td>PK kitchen shutters</td><td>Retire from the expedition. Cooking is at camp; the arrival gallery is not a repeated kitchen-unlock objective.</td></tr><tr><td>P1 / Vault</td><td>Lower Pit side annex; optional key reward, outside the required hunt route.</td></tr><tr><td>P2 / Sluice</td><td>Waterworks service bay; local control opens optional remote bars. No water simulation and no required loaded-descent gate.</td></tr><tr><td>P3 / Mourner</td><td>Ossuary / Reliquary; retain single-person occupancy and latching access.</td></tr><tr><td>P4 / Bellkeeper</td><td>Belfry; retain dials, chain, stakes and optional reward. Reader gallery and safe partner staging are placement contracts pending a later physical pass.</td></tr><tr><td>P5 / Chime ladder</td><td>Local Belfry reader-gallery access / return; exact placement pending. No compulsory two-person hold.</td></tr><tr><td>SC2 / closet ladder</td><td>Earned Lower Pit to hub-west return. Separate waiting space at both ends; remains latched during the expedition.</td></tr><tr><td>R-route variations</td><td>Park random closures for this navigation prototype. First validate the ordinary loops; introduce route variants later without invalidating required access.</td></tr></table><div class="cards" style="margin-top:22px">'+p.scope.map((s,i)=>`<article class="card"><div class="eyebrow">Contract ${i+1}</div><p>${esc(s)}</p></article>`).join('')+'</div><p class="fine" style="margin-top:20px">Shared seam contracts: '+p.links.map(e=>e.id).join(', ')+'. Direct joins use shared walls or open edges. Local stairs belong to their area; the assembly owns alignment and bindings.</p>';}
function setView(name){if(name==='compare'&&state.view!=='compare')view=[-83,-78,166,156];else if(state.view==='compare'&&name!=='compare')view=[-58,-52,116,106];state.view=name;for(const n of ['plan','compare','three','research','modules'])$('view-'+n).setAttribute('aria-pressed',String(name===n));$('layout').hidden=['research','modules'].includes(name);$('research').hidden=name!=='research';$('details').hidden=name!=='modules';$('scene').classList.toggle('compare',name==='compare');$('baseline').toggleAttribute('hidden',name!=='compare');$('plan').toggleAttribute('hidden',!['plan','compare'].includes(name));$('three').hidden=name!=='three';$('head-current').hidden=name!=='compare';$('head-proposal').classList.toggle('right',name==='compare');$('head-proposal').hidden=name==='three';$('caption').textContent=name==='compare'?'Same scale: previous corridor draft / revised interlocking complex. Both are HTML proposals; the live map is unchanged.':name==='three'?'PROPOSED BLOCKOUT · shared walls / open void / internal gallery and terraces · orbit drag, right-drag pan · intended sightlines are not occlusion-verified.':'PROPOSED · one continuous complex · inspect an area; trace routes through its interior · 10 m grid.';if(name==='three'){init3();build3();draw3();}if(name==='research')research();if(name==='modules')contracts();draw();}
for(const m of p.modules){const o=document.createElement('option');o.value=m.id;o.textContent=m.name;$('module').append(o);}for(const cp of p.checkpoints){const o=document.createElement('option');o.value=cp.id;o.textContent=cp.label;$('checkpoint').append(o);}
$('module').onchange=e=>choose(e.target.value);

for(const id of ['bounds','sightlines','shortcuts'])$(id).onchange=e=>{state[id]=e.target.checked;draw();};$('route').onchange=e=>{state.route=e.target.value;draw();};$('isolate').onclick=()=>{state.isolate=!state.isolate;$('isolate').setAttribute('aria-pressed',String(state.isolate));draw();};$('checkpoint').onchange=e=>{state.checkpoint=e.target.value;const area={arrival:'Arrival',court:'Court',water:'Waterworks',belfry:'Belfry',bone:'Ossuary',lower:'PitDepths'}[state.checkpoint];if(area){state.selected=area;inspection();}setView('three');};
function fit(){view=state.view==='compare'?[-83,-78,166,156]:[-58,-52,116,106];orbit.r=140;state.checkpoint='overview';$('checkpoint').value='overview';draw();}function zoom(f){const cx=view[0]+view[2]/2,cy=view[1]+view[3]/2;view[2]=Math.max(35,Math.min(350,view[2]*f));view[3]=Math.max(35,Math.min(350,view[3]*f));view[0]=cx-view[2]/2;view[1]=cy-view[3]/2;orbit.r=Math.max(30,Math.min(350,orbit.r*f));draw();}
$('fit').onclick=fit;$('zoom-in').onclick=()=>zoom(.8);$('zoom-out').onclick=()=>zoom(1.25);$('reset').onclick=()=>{state.isolate=false;state.shortcuts=false;state.route='none';$('route').value='none';$('shortcuts').checked=false;$('isolate').setAttribute('aria-pressed','false');inspection();fit();};

for(const name of ['plan','compare','three','research','modules'])$('view-'+name).onclick=()=>setView(name);
for(const id of ['plan','three']){const el=$(id);el.oncontextmenu=e=>e.preventDefault();el.onpointerdown=e=>{if(e.target.closest?.('.pick'))return;drag={id,x:e.clientX,y:e.clientY,button:e.button};el.setPointerCapture(e.pointerId);};el.onpointerup=el.onpointercancel=()=>drag=null;el.onpointermove=e=>{if(!drag)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;drag.x=e.clientX;drag.y=e.clientY;if(id==='three'){state.checkpoint='overview';$('checkpoint').value='overview';if(drag.button===2){orbit.x-=dx*.1;orbit.y+=dy*.1;}else{orbit.theta-=dx*.007;orbit.phi=Math.max(.1,Math.min(1.5,orbit.phi+dy*.006));}draw3();}else{const u=unit();view[0]-=dx*u;view[1]-=dy*u;renderPlan();if(state.view==='compare')renderBaseline();}};}
$('scene').onwheel=e=>{e.preventDefault();zoom(Math.exp(e.deltaY*.001));};$('scene').onkeydown=e=>{if(e.key==='+'||e.key==='='){e.preventDefault();zoom(.8);}else if(e.key==='-'){e.preventDefault();zoom(1.25);}else if(e.key.startsWith('Arrow')){e.preventDefault();const q={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]}[e.key];view[0]+=q[0]*view[2]*.07;view[1]+=q[1]*view[3]*.07;draw();}};
$('download').onclick=()=>{const output={...p,modules:p.modules.map(m=>({...m,at:position(m)})),links:p.links.map(e=>({...e,via:points(e).slice(1,-1)})),validation:validate(),boundary:'HTML proposal only; shared-edge placements and internal circulation traces; no automatic corridor generation. No Unreal asset changes.'};const blob=new Blob([JSON.stringify(output,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='Warrens-Pit-Layout-Proposal.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
new ResizeObserver(()=>{renderPlan();if(state.view==='compare')renderBaseline();draw3();}).observe($('scene'));
$('provenance').textContent=`Interlocked HTML revision 03 · ${p.date} · baseline ${data.commit.slice(0,7)} / SHA-256 ${data.sourceHash.slice(0,16)}… · no live asset or MP changes.`;
inspection();setView('plan');window.WarrensPitIteration={data,proposal:p,state,port,points,position,validate,geometry,setView,get renderer(){return renderer;},get scene(){return scene;}};
})();
