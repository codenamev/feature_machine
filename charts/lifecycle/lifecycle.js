/* feature_machine · Flowchart (built from the Tinycharts Pro flowchart template)
   One wish, from the form (or an agent over MCP) to a merged pull request. Tag names are WorkItem's real statuses.
   Statechart: lifecycle.mmd (its ids are the data-state groups in the drawing), checked by `node lifecycle.check.mjs`.
   Build: see charts/README.md */
const PHONE = matchMedia('(max-width:820px)').matches, sz = (d,p) => PHONE ? p : d;
function step(x,y,text){ const w = Math.max(92,text.length*14.6+30); tag(x-w/2,y,w,text,tagN++); return w; }
const words = (x,y,s,anchor = 'start') => out.push(`<text x="${x}" y="${y}" text-anchor="${anchor}" class="it" font-size="18.5" fill="${INK}" letter-spacing=".5">${s}</text>`);
const small = (x,y,s,anchor = 'start') => out.push(`<text x="${x}" y="${y}" text-anchor="${anchor}" class="it" font-size="15.5" fill="#5e4c3d">${s}</text>`);
function pl(sx,sy,w,d,h = 50){ const [x,y] = at(sx,sy); board(x-14,y-14,w+28,d+28,7,'#efe9da','#c8bfa9',12); cast(x,y,w,d,h); layShades(); }
/* thin dotted lines from each picture to the step it shows, drawn first so pictures and boxes sit on top */
const links = (...ps) => ps.forEach(p => out.push(`<path class="link" d="M${p.map(q => q.join(' ')).join('L')}" fill="none" stroke="#a89c8a" stroke-width="1.7" stroke-dasharray="0.1 5.6" stroke-linecap="round" stroke-linejoin="round"/>`));

/* ---- props: real furniture and paper ---- */
const LEG = '#8e6d4f';
function desk(x,y,w,d,h,col = '#c79a68'){ for (const [a,b] of [[1,1],[w-4,1],[1,d-4],[w-4,d-4]]) box(x+a,y+b,0,3,3,h-3,{left:LEG,marks:false,ink:.6}); box(x,y,h-3,w,d,3,{left:col,top:litOf(col),marks:false,ink:1}); }
/* a laptop: base at height z, the screen standing on its back edge, facing the viewer */
function laptop(x,y,z,w,d,h,screen,id){ box(x,y,z,w,d,1.6,{left:'#a6a4a4',top:'#dcd9d0',marks:false,ink:.8}); const f = [P(x,y,z+1.6),P(x+w,y,z+1.6),P(x+w,y,z+h),P(x,y,z+h)]; flat(f,'#6b6660'); rim(f,.9,INK);
  const g = [P(x+2,y+.2,z+3),P(x+w-2,y+.2,z+3),P(x+w-2,y+.2,z+h-2),P(x+2,y+.2,z+h-2)]; flat(g,screen); rim(g,.5,INK);
  if (id) group(`id="${id}" style="opacity:0;transition:opacity .5s"`,() => { flat(g,'#93d3b0'); rim(g,.5,INK); for (let i = 0; i < 3; i++) rule([[P(x+5,y+.3,z+h-6-i*3.4),P(x+w-8-i*3,y+.3,z+h-6-i*3.4)]],'#2f6b4f',.9); }); }
/* a sheet of paper lying flat, with ruled lines */
function sheet(x,y,z,w,d,lines = 3,col = '#fffdf6'){ const s = [P(x,y,z),P(x+w,y,z),P(x+w,y+d,z),P(x,y+d,z)]; flat(s,col); rim(s,.6,INK); const r = []; for (let i = 1; i <= lines; i++) r.push([P(x+3,y+i*d/(lines+1),z),P(x+w-4-(i%2)*3,y+i*d/(lines+1),z)]); rule(r,LEAD,.5); }
/* a pile of request slips: n sheets, a little askew */
function pile(x,y,z,n,w = 18,d = 13){ for (let i = 0; i < n; i++){ const j = ((i*7)%5-2)*.6; box(x+j,y-j,z+i*1.6,w,d,1.6,{left:'#efe7d8',top:i === n-1 ? '#fffdf6' : '#f6f0e4',marks:false,ink:.45}); } }
/* a rubber stamp on its foot, red ink pad beside it */
function stamp(x,y,z){ box(x+14,y-2,z,14,10,2,{left:'#3f3a39',top:'#c8372f',marks:false,ink:.6}); lifeTurn(x,y,z,[[6,0],[6,3],[2.4,5],[2.4,14],[5,16],[5,22],[2.6,25]],'#9c6b4e',{cap:'#7a5238',seam:false,ink:.8}); }
/* a brass balance on a post: two pans, the heavier pile on the left */
function balance(x,y,z){ const B = '#c4a25c'; lifeTurn(x,y,z,[[8,0],[8,2.5],[2,4],[2,42],[3.5,44]],B,{cap:'#d9b98c',seam:false,ink:.8});
  const L = P(x-22,y+4,z+38), R = P(x+22,y-4,z+44); pen([L,P(x,y,z+43),R],1.6);
  for (const [px,py,pz] of [[x-22,y+4,z+20],[x+22,y-4,z+26]]){ const top = P(px,py,pz+18); rule([[top,P(px-7,py,pz+3)],[top,P(px+7,py,pz+3)]],INK,.5); lifeTurn(px,py,pz,[[2,0],[9,3.5]],B,{cap:'#e4cf9a',seam:false,ink:.7}); }
  pile(x-27,y-1,z+24,4,10,8); pile(x+18,y-8,z+30,1,10,8); }
/* an envelope lying flat with PR on it */
function envelope(x,y,z,w = 26,d = 16){ const e = [P(x,y,z),P(x+w,y,z),P(x+w,y+d,z),P(x,y+d,z)]; flat(e,'#ecc98e'); rim(e,.7,INK); pen([P(x,y,z),P(x+w/2,y+d*.55,z),P(x+w,y,z)],.7); floorText(x+w*.62,y+d*.82,z,'PR',{size:7,col:RED,anchor:'middle',cls:'tt',track:.4}); }
/* a parcel with tape */
function parcel(x,y,z,w,d,h,col = '#c9a27c'){ box(x,y,z,w,d,h,{left:col,top:litOf(col),marks:false,ink:.8}); rule([[P(x+w/2,y,z+h),P(x+w/2,y+d,z+h)],[P(x+w/2,y+d,z+h),P(x+w/2,y+d,z+h*.5)]],'#e9dcc4',1.6); }

/* the chain: tag x, y per state */
const X = 620, YS = [110,256,402,548,694,840,986,1132], DX = 930;
const AT = {filed:[X,YS[0]],grouped:[X,YS[1]],judged:[X,YS[2]],draft:[X,YS[3]],planned:[X,YS[4]],declined:[DX,YS[4]],in_progress:[X,YS[5]],in_review:[X,YS[6]],shipped:[X,YS[7]]};

function draw(seed){
  begin(seed); OX = 700; OY = 300;
  out.push(`<style>#art .fs .hl{opacity:0;transition:opacity .35s}#art .fs.lit .hl{opacity:1}</style>`);
  title('','One wish');
  out.push(`<text x="72" y="236" class="it" font-size="${sz(21,28)}" fill="${INK}" letter-spacing=".6">a request, stop by stop</text>`);
  /* the readout: where the request is, in words */
  out.push(`<text x="1330" y="${sz(104,108)}" text-anchor="end" class="it" font-size="${sz(17,20)}" fill="${LEAD}">the request is</text><text id="fcS" x="1330" y="148" text-anchor="end" class="tt" font-size="${sz(38,44)}" fill="${INK}">filed</text><text id="fcD" x="1330" y="180" text-anchor="end" class="it" font-size="${sz(19,24)}" fill="${INK}">stop 1 of 8</text>`);
  const O = k => `class="spring obj" data-k="${k}"`;
  const edge = (id,side) => { const [x,y] = AT[id], w = Math.max(92,id.length*14.6+30); return [x+side*(w/2+4),y+28]; };
  links([edge('filed',-1),[300,440]],[edge('grouped',1),[1010,350]],[edge('judged',1),[1120,530]],[edge('draft',-1),[300,670]],[edge('planned',-1),[300,900]],[edge('declined',1),[1170,850]],[edge('in_progress',-1),[300,1140]],[edge('in_review',1),[1000,1000]],[edge('shipped',1),[1090,1166]]);

  /* filed: a user at home, the wish on a sticky note, their agent open on the laptop */
  group(O(0)+' data-state="filed"',() => { const [x,y] = at(240,470); pl(240,470,92,56,40);
    person(...P(x+20,y-22),{hair:'wavy',shirt:PAL.rose,arm:'front',look:1,say:'dark mode, please'});
    desk(x,y,80,48,30); laptop(x+30,y+10,30,30,20,22,'#a9c8ee'); const n = [P(x+10,y+30,30.2),P(x+22,y+30,30.2),P(x+22,y+20,30.2),P(x+10,y+20,30.2)]; flat(n,'#f4b829'); rim(n,.5,INK);
    lifeCup(x+66,y+34,30,4,'#7a5233'); });
  small(110,580,'a form, or over MCP');
  /* grouped: the sorting table, five slips about dark mode in one pile */
  group(O(1)+' data-state="grouped"',() => { const [x,y] = at(1050,350); pl(1050,350,130,64,34);
    person(...P(x+74,y-20),{hair:'short',shirt:PAL.sky,arm:'front',look:-1,say:'five asks, one pile'});
    desk(x,y,124,60,28,'#b39b78'); pile(x+12,y+22,28,7); pile(x+52,y+24,28,3); pile(x+90,y+20,28,1); });
  small(870,470,'five asks, one pile');
  /* judged: the bench and its balance */
  group(O(2)+' data-state="judged"',() => { const [x,y] = at(1180,530); pl(1180,530,120,58,44);
    person(...P(x+70,y-18),{hair:'bun',shirt:'#5d6c9c',arm:'front',look:-1,say:'paraphrases don’t move me'});
    box(x,y,0,120,44,34,{left:'#9c6b4e',top:'#c79a68',marks:false,ink:1.1}); rule([[P(x,y+44,17),P(x+120,y+44,17)]],'#7a5238',.6); balance(x+36,y+22,34); });
  small(1330,704,'ranked by a judge','end');
  /* draft: the drafting desk, a spec being written */
  group(O(3)+' data-state="draft"',() => { const [x,y] = at(240,700); pl(240,700,96,56,40);
    person(...P(x+20,y-20),{hair:'bob',shirt:PAL.gold,arm:'front',look:1,say:'problem, scope, criteria'});
    desk(x,y,86,50,30,'#d9b98c'); sheet(x+18,y+10,30.2,30,36,5); lifePipe([P(x+54,y+30,31),P(x+66,y+20,31)],1.6,'#f4b829'); sheet(x+56,y+28,30.2,22,16,2,'#f6f0e4'); });
  small(110,810,'a drafted spec');
  /* planned: you, a stamp, and the yes on paper */
  group(O(4)+' data-state="planned"',() => { const [x,y] = at(240,930); pl(240,930,90,52,40);
    person(...P(x+22,y-20),{hair:'short',shirt:'#7f9db3',arm:'front',look:1,say:'yes, this one'});
    desk(x,y,80,46,30); sheet(x+12,y+12,30.2,30,24,0); floorText(x+27,y+28,30.2,'PLANNED',{size:6.4,col:RED,anchor:'middle',cls:'tt',track:.6}); stamp(x+56,y+20,30); });
  small(110,1036,'only a person approves');
  /* declined: the paper bin */
  group(O(5)+' data-state="declined"',() => { const [x,y] = at(1190,860); pl(1190,860,44,44,22); cyl(x+22,y+22,0,13,20,'#a6a4a4',{ink:1,cap:'#7d8b96'}); for (const [a,b,z] of [[6,40,0],[38,8,0],[44,30,0]]){ const c = P(x+a,y+b,z+3); dot(c[0],c[1],4.5,'#fffdf6',.7); } });
  small(1124,960,'not this time');
  /* in_progress: your coding agent at the bench; the screen goes green when tests pass */
  group(O(6)+' data-state="in_progress"',() => { const [x,y] = at(250,1170); pl(250,1170,92,52,40);
    person(...P(x+20,y-20),{hair:'cap',cap:PAL.blue,shirt:PAL.sage,arm:'front',look:1,say:'running your tests'});
    desk(x,y,84,48,30,'#9c6b4e'); laptop(x+28,y+10,30,30,20,22,'#3f3a39','green'); sheet(x+62,y+24,30.2,18,14,2); });
  small(110,1278,'your coding agent');
  /* in_review: the pull request waiting in your tray */
  group(O(7)+' data-state="in_review"',() => { const [x,y] = at(1020,1010); pl(1020,1010,86,50,34);
    person(...P(x+60,y-18),{hair:'short',shirt:'#7f9db3',arm:'front',look:-1,say:'reading the diff'});
    desk(x,y,80,46,28,'#c79a68'); box(x+12,y+10,28,34,26,3,{left:'#5d6c9c',top:'#76a0e2',marks:false,ink:.7}); envelope(x+16,y+14,31.2); });
  small(940,1112,'a PR link, required');
  /* shipped: a parcel out of the door */
  group(O(8)+' data-state="shipped"',() => { const [x,y] = at(1120,1176); pl(1120,1176,70,50,30); lifePallet(x+4,y+4,0,60,40); parcel(x+10,y+10,7,26,22,20); parcel(x+38,y+12,7,18,16,14,'#ecc98e');
    person(...P(x+80,y+20),{hair:'wavy',shirt:PAL.rose,arm:'wave',look:-1,say:'it shipped!'}); });
  small(1040,1284,'on the roadmap');

  /* the chain: arrows with event words */
  route([X,YS[0]+58],[X,YS[1]-9]); words(X+16,YS[0]+104,'embeddings cluster it');
  route([X,YS[1]+58],[X,YS[2]-9]); words(X+16,YS[1]+104,'the judge ranks piles');
  route([X,YS[2]+58],[X,YS[3]-9]); words(X+16,YS[2]+104,'triage drafts a spec');
  route([X,YS[3]+58],[X,YS[4]-9]); words(X+16,YS[3]+104,'[you approve]');
  route([X+60,YS[3]+28],[DX,YS[4]-9],true); words(DX+16,YS[3]+104,'[you decline]');
  route([X,YS[4]+58],[X,YS[5]-9]); words(X+16,YS[4]+104,'an agent picks it up');
  route([X,YS[5]+58],[X,YS[6]-9]); words(X+16,YS[5]+104,'hands back a PR');
  route([X,YS[6]+58],[X,YS[7]-9]); words(X+16,YS[6]+104,'you merge');
  out.push(`<path id="trail" fill="none" stroke="${RED}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" opacity=".6"/>`);
  /* the wrong turn the guard keeps shut: shipping straight from in progress with no pull request. Drawn faint, to the side */
  group('opacity=".5"',() => { const L = 468, a = edge('in_progress',-1)[0], b = edge('shipped',-1)[0]; out.push(`<path d="M${a} ${YS[5]+28}H${L}V${YS[7]+28}H${b-6}" fill="none" stroke="#8d8478" stroke-width="1.6" stroke-dasharray="7 6"/>`); out.push(`<path d="M${b-6} ${YS[7]+21}l10 7l-10 7z" fill="#8d8478"/>`);
    out.push(`<text x="${L-10}" y="${YS[6]+86}" transform="rotate(-90 ${L-10} ${YS[6]+86})" class="it" font-size="17" fill="${INK}">[merged, no PR]</text>`);
    out.push(`<path d="M${L-9} ${YS[6]-40}l18 18M${L+9} ${YS[6]-40}l-18 18" stroke="${RED}" stroke-width="2.4" stroke-linecap="round"/>`); });
  for (const id of Object.keys(AT)){ const [x,y] = AT[id];
    group(`id="fs_${id}" class="fs" data-state="${id}"`,() => { const w = step(x,y,id); group('class="hl"',() => line([[x-w/2-7,y-3],[x+w/2+7,y-3],[x+w/2+7,y+57],[x-w/2-7,y+57],[x-w/2-7,y-3],[x-w/2+4,y-3]],{w:4.4,col:RED,amp:.2,over:0})); }); }
  /* the request itself: a red slip of paper */
  group('id="token"',() => { out.push(`<g transform="rotate(-8)"><rect x="-13" y="-10" width="26" height="20" rx="2" fill="#d8554f" stroke="${INK}" stroke-width="1.2"/><path d="M-8 -4h14M-8 1h16M-8 6h9" stroke="#fffdf6" stroke-width="1.4" stroke-linecap="round"/></g>`); });
  out.push(`<text x="72" y="1330" class="it" font-size="${sz(20,26)}" fill="${LEAD}">${PHONE ? 'Simplified.' : 'From draft on, WorkItem’s own statuses. Simplified.'}</text>`);
  finish();
}
const STOPS = {
  filed:{k:0,say:'Filed: from the form, or request_feature over MCP. The person who asked can follow it.'},
  grouped:{k:1,say:'Grouped: embeddings put the five dark-mode asks in one pile. No embedding model? It still files, just ungrouped.'},
  judged:{k:2,say:'Judged: a structured-judgment model ranks the piles, so the most-asked work rises.'},
  draft:{k:3,say:'Draft: triage forms a work item with a drafted spec. Now you choose: approve or decline.'},
  planned:{k:4,say:'Planned: you approved it, and it is on the roadmap. Only a person can make this move.'},
  declined:{k:5,say:'Declined: it stops here, and every request in its pile shows declined.'},
  in_progress:{k:6,say:'In progress: your coding agent picked it up over MCP and is running your tests.'},
  in_review:{k:7,say:'In review: the agent handed back with a GitHub pull request attached.'},
  shipped:{k:8,say:'Shipped: you merged it. The roadmap says so, and so does every request in the pile.'}
};
const NEXT = {filed:'grouped',grouped:'judged',judged:'draft',planned:'in_progress',in_progress:'in_review',in_review:'shipped'};
const DETAIL = {filed:'stop 1 of 8 · asked',grouped:'stop 2 of 8 · one pile',judged:'stop 3 of 8 · ranked',draft:'stop 4 of 8 · approve or decline?',planned:'stop 5 of 8 · on the roadmap',declined:'the end · not this time',in_progress:'stop 6 of 8 · being built',in_review:'stop 7 of 8 · PR attached',shipped:'stop 8 of 8 · merged'};
function init(ctx){
  const $ = id => document.getElementById(id), trail = $('trail'), token = $('token'), objs = [...document.querySelectorAll('.obj')], tags = [...document.querySelectorAll('.fs')], green = $('green');
  const DECIDED = new Set(['planned','declined','in_progress','in_review','shipped']);
  let name = 'filed', path = [], d = 0, moving = false, auto = false, autoT = 0, inked = [];
  const top = id => AT[id];
  const seat = p0 => { const p = onRoute(p0); token.setAttribute('transform',`translate(${p[0]} ${p[1]})`); if (inked.length){ inked.push(p); trail.setAttribute('d','M'+inked.map(q => `${q[0].toFixed(1)} ${q[1].toFixed(1)}`).join('L')); } };
  const finale = () => { [...document.querySelectorAll('#art .who')].sort((a,b) => a.getBBox().y-b.getBBox().y).forEach((w,i) => setTimeout(() => ctx.hop(w),i*130)); };
  const paint = () => { objs.forEach(o => o.classList.toggle('on',+o.dataset.k === STOPS[name].k)); tags.forEach(t => t.classList.toggle('lit',t.id === 'fs_'+name)); green.style.opacity = ['in_progress','in_review','shipped'].includes(name) ? 1 : 0; $('fcS').textContent = name; $('fcD').textContent = DETAIL[name]; };
  function go(next,via){ path = [top(name),...(via || []),top(next)]; d = 0; name = next; moving = true; }
  const busy = () => { if (!moving) return false; ctx.say('Wait: the request is still on its way to the next stop.'); return true; };
  function next(){ if (name === 'draft'){ ctx.say('Not yet: a draft waits for you. Press approve or decline.'); auto = false; return false; }
    if (name === 'shipped' || name === 'declined'){ ctx.say(`That was the end: it is ${name}. Press Play all to follow another request.`); return false; }
    go(NEXT[name]); return true; }
  function decide(to){ if (name === 'draft'){ go(to,to === 'declined' ? [[X+60,YS[3]+28],[DX,YS[3]+28]] : null); return true; }
    ctx.say(DECIDED.has(name) ? `Already decided: this request is ${name.replace('_',' ')}.` : `Not yet: it is only ${name}. Only a draft can be approved or declined, and only by you.`); return false; }
  function reset(){ name = 'filed'; inked = []; trail.removeAttribute('d'); seat(top('filed')); inked = [top('filed')]; paint(); }
  ctx.button('play it in order',() => { if (auto){ ctx.say('Already playing: watch the red slip go down the chart.'); return; } if (moving) return busy(); reset(); ctx.say('Playing: the request goes stop by stop, and you approve it at the draft.'); auto = true; autoT = 1; });
  ctx.button('next stop',() => { auto = false; if (!busy()) next(); });
  ctx.button('approve',() => { auto = false; if (!busy()) decide('planned'); });
  ctx.button('decline',() => { auto = false; if (!busy()) decide('declined'); });
  ctx.hint('tap people too'); reset();
  ctx.say(PHONE ? 'Press Play all, or Next step.' : 'Press Play all, or Next step to move the request one stop. At the draft, you approve or decline.');
  return { tick(t,dt){
    if (auto && !moving){ autoT -= dt; if (autoT <= 0){ autoT = 1.1; if (name === 'draft') decide('planned'); else if (name === 'shipped') auto = false; else next(); } }
    if (!moving) return; d = Math.min(1,d+dt*1.5); const n = path.length-1, u = d*n, i = Math.min(n-1,Math.floor(u)), f = u-i, e = f*f*(3-2*f), here = [lerp(path[i][0],path[i+1][0],e),lerp(path[i][1],path[i+1][1],e)]; seat(here); ctx.focus(here[0],here[1],1.6);
    if (d >= 1){ moving = false; paint(); ctx.say(STOPS[name].say); const e2 = top(name);
      if (name === 'shipped'){ auto = false; finale(); ctx.focus(700,700,1.001,.05); }
      else ctx.focus(e2[0],e2[1],1.6,auto ? 0 : 2.4); } } };
}
