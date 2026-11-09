// kit: diaKit
/* feature_machine · Sequence diagram (built from the Tinycharts Pro sequence template)
   Who says what to whom, from a user's wish to a shipped pull request, over feature_machine's MCP tools.
   Statechart: handoff.mmd (its ids are the data-state groups in the drawing), checked by `node handoff.check.mjs`.
   Build: see charts/README.md */
/* four parties: a user's own agent, the engine in your app, you, and your coding agent. Tool names are the real MCP tools; item 7 is made up */
const QX = [196,478,906,1196], QN = ["user's agent",'the engine','coding agent','you'], QNP = ['asker','engine','coder','you'], QK = ['asker','engine','coder','you'], QBG = ['#f6e6d2','#dfeae0','#e3e6ea','#f3ddd6'];
const HY = 304, HH = 206, LY0 = HY+HH, LY1 = 1278, RY = k => 590+k*80, BAR = 9, HW = 266, NM = 9;
/* each head's prop: scale, and where its origin sits in the card */
const HK = [[1.8,-4,168],[1.9,-28,162],[1.7,4,180],[1.42,-18,204]];
/* the seven messages: from, to, words, kind (call: solid with a filled head; ret: a dashed reply; async: an open head; self: a loop back), where the label sits */
const MSG = [
  {f:0,t:1,s:'request_feature',kind:'call',lx:337},
  {f:3,t:1,s:'approve as planned',kind:'call',lx:1052},
  {f:2,t:1,s:'list_work_items',kind:'call',lx:690},
  {f:1,t:2,s:'item 7, planned',kind:'ret',lx:690},
  {f:2,t:1,s:'update_work_item',kind:'call',lx:660},
  {f:2,t:2,s:'code, run tests',kind:'self'},
  {f:2,t:1,s:'update_work_item + PR',kind:'call',lx:652},
  {f:3,t:1,s:'merge and ship',kind:'call',lx:1082},
  {f:1,t:0,s:'it shipped',kind:'async',lx:300}];
/* the state boxes on the lifelines: participant, state id in handoff.mmd, words, and how many messages have been sent when it starts */
const PILLS = [[0,'asking','has a wish',0],[1,'none','nothing yet',0],[3,'triaging','triaging',0],[2,'idle','idle',0],
  [0,'waiting','waiting',1],[1,'requested','requested',1],[1,'planned','planned',2],[3,'reviewing','awaits a PR',2],
  [2,'asked','asked',3],[2,'assigned','has item 7',4],[1,'in_progress','in progress',5],[2,'working','working',5],[2,'tested','green',6],
  [1,'in_review','in review',7],[2,'handed','PR open',7],[1,'shipped','shipped',8],[3,'merged','merged',8],[0,'told','told it shipped',9]];
/* activation bars: participant, first and last message row it is busy for */
const ACTS = [[0,0,8],[1,0,1],[1,2,4],[1,6,8],[3,1,1],[3,7,7],[2,2,6]];
const pillY = k => k === 0 ? 536 : RY(k-1)+40;
const msgPts = m => { const y = RY(MSG.indexOf(m)); if (m.kind === 'self'){ const x = QX[m.f]+BAR; return [[x,y-16],[x+64,y-16],[x+64,y+16],[x,y+16]]; } const d = Math.sign(QX[m.t]-QX[m.f]); return [[QX[m.f]+d*BAR,y],[QX[m.t]-d*BAR,y]]; };

/* lettering laid on an isometric face that looks along +y */
const onY = (x,y,z,s,size,col,o = {}) => { const p = P(x,y,z); out.push(`<text ${o.id ? `id="${o.id}" ` : ''}transform="matrix(.866 .5 0 1 ${n1(p[0])} ${n1(p[1])})" x="0" y="0" text-anchor="${o.a || 'start'}" class="${o.cls || 'tt'}" font-size="${size}" fill="${col}">${s}</text>`); };
/* a parcel: brown card with tape along the top and down one side */
function parcel(x,y,z,w,d,h,col = '#c9a27c'){ box(x,y,z,w,d,h,{left:col,top:litOf(col),marks:false,ink:.8}); rule([[P(x+w/2,y,z+h),P(x+w/2,y+d,z+h)],[P(x+w/2,y+d,z+h),P(x+w/2,y+d,z+h*.5)]],'#e9dcc4',1.6); }
function pillar(x,y){ ground(blob(...P(x+4,y+4),16,6)); lifeTurn(x,y,0,[[10,0],[10,3],[9,4],[9,40],[10,42],[10,46],[7,50],[3,53]],'#c8372f',{cap:'#b0302a'}); const a = P(x+6.6,y+6.6,36), b = P(x+2,y+9.2,36); out.push(`<path d="M${n1(a[0])} ${n1(a[1])}L${n1(b[0])} ${n1(b[1])}" stroke="${INK}" stroke-width="2.2" stroke-linecap="round"/>`); const c = P(x+5,y+8,24); out.push(`<rect x="${n1(c[0]-3)}" y="${n1(c[1]-3)}" width="7" height="5" fill="#fffdf6" stroke="${INK}" stroke-width=".5"/>`); }

/* the four participants, each drawn as the real thing */
const HEADS = [
  /* a user at home: a desk, a laptop with their agent open, a mug, and the wish itself on a sticky note */
  () => { ground(blob(...P(4,10),66,22)); box(-34,-20,0,62,30,28,{left:'#c79a68',top:'#d9b98c',marks:false,ink:1}); for (const [u,v] of [[-32,8],[24,8]]) box(u,v,-1,3,3,1,{left:'#8e6d4f',marks:false,ink:.5});
    laptop(-22,-12,28,26,16,18,'#a9c8ee'); onY(-19,-11.8,40,'agent',4.4,INK); onY(-19,-11.8,34,'request_feature',2.6,'#2b2930');
    lifeCup(14,2,28,3.6,'#7a5233'); const n = [P(4,8,28.2),P(14,8,28.2),P(14,0,28.2),P(4,0,28.2)]; flat(n,'#f4b829'); rim(n,.5,INK);
    const q = P(36,10); who2(q[0],q[1],{hair:'wavy',shirt:PAL.rose,arm:'front',look:-1,size:.8,say:'dark mode, please'}); },
  /* feature_machine: a cabinet in your app with a screen, a slot that takes requests, and a slip curling out */
  () => { ground(blob(...P(12,10),40,14)); box(2,2,0,20,12,4,{left:'#6b6660',marks:false,ink:.8}); box(0,0,4,24,14,48,{left:'#5f9e7f',top:'#86bfa1',marks:false,ink:1.2});
    const s = [P(3,14,34),P(21,14,34),P(21,14,46),P(3,14,46)]; flat(s,'#2f2a2a'); rim(s,.7,INK); onY(4.5,14.2,41.5,'NEW',3.6,'#f4b829'); onY(4.5,14.2,37,'REQUEST',3.2,'#f4b829');
    const c = P(12,14,26); out.push(`<ellipse cx="${n1(c[0])}" cy="${n1(c[1])}" rx="5" ry="3.6" fill="#f4b829" stroke="${INK}" stroke-width=".9"/><ellipse cx="${n1(c[0]-.8)}" cy="${n1(c[1]-1)}" rx="2.4" ry="1.4" fill="#fbe2a0"/>`);
    rule([[P(5,14,15),P(19,14,15)]],INK,1.8); box(-3,-2,52,30,18,4,{left:'#3f3a39',top:'#6b6660',marks:false,ink:.9}); const f = [P(-2,16,53),P(26,16,53),P(26,16,66),P(-2,16,66)]; flat(f,'#fffdf6'); rim(f,.8,INK); onY(1,16.2,57,'FEATURES',4.4,INK);
    lifePipe([P(12,-2,56),P(12,-2,72)],1.4,'#8f8a86');
    group('id="hSlip" style="opacity:0;transition:opacity .3s"',() => { const t = [P(8,14,15),P(16,14,15),P(16,24,9),P(8,24,9)]; flat(t,'#fffdf6'); rim(t,.7,INK); const m = P(12,20,12); tx(m[0]+1,m[1]+2.5,'#12',5,{cls:'tt',col:RED}); });
    const w = P(44,4); who2(w[0],w[1],{hair:'cap',shirt:PAL.gold,arm:'front',look:-1,size:.5,say:'mine is next'}); lifeBag(-30,22,0,16,10,9,'#c9a27c'); },
  /* your coding agent at its bench: a laptop gone green, the spec it was handed, and the pull request in an envelope */
  () => { ground(blob(...P(0,10),70,22)); box(-38,-20,0,72,30,28,{left:'#9c6b4e',top:'#c79a68',marks:false,ink:1}); rule([[P(-38,-5,28),P(34,-5,28)]],'#7a5238',.5);
    laptop(-26,-12,28,26,16,18,'#3f3a39'); group('id="hGreen" style="opacity:0;transition:opacity .4s"',() => { const g = [P(-24,-11.8,31),P(-2,-11.8,31),P(-2,-11.8,44),P(-24,-11.8,44)]; flat(g,'#93d3b0'); rim(g,.5,INK); onY(-21,-11.6,38,'tests: green',3,INK); });
    for (let i = 0; i < 3; i++){ const z = 28+i*1.2, d = [P(6,-14+i,z),P(22,-14+i,z),P(22,-2+i,z),P(6,-2+i,z)]; flat(d,'#fffdf6'); rim(d,.5,INK); } rule([[P(8,-11,31.6),P(20,-11,31.6)],[P(8,-8,31.6),P(18,-8,31.6)],[P(8,-5,31.6),P(19,-5,31.6)]],LEAD,.5);
    group('id="hEnv" style="opacity:0;transition:opacity .4s"',() => { const e = [P(10,4,28.4),P(26,4,28.4),P(26,14,28.4),P(10,14,28.4)]; flat(e,'#ecc98e'); rim(e,.6,INK); pen([P(10,4,28.4),P(18,9,28.4),P(26,4,28.4)],.6); });
    const q = P(-44,14); who2(q[0],q[1],{hair:'cap',cap:PAL.blue,shirt:PAL.sage,arm:'front',look:1,size:.78,say:'tests are green'}); },
  /* you at the triage desk: work items in pigeonholes behind, the glass, the tray, the PLANNED stamp and its pad */
  () => { ground(blob(...P(0,12),74,24)); box(-44,-48,0,92,10,62,{left:'#c79a68',top:'#d9b98c',marks:false,ink:1}); { const Q = (u,z) => P(-44+u,-38,z), r = []; for (let z = 10; z <= 58; z += 12) r.push([Q(0,z),Q(92,z)]); for (let u = 0; u <= 92; u += 13) r.push([Q(u,10),Q(u,58)]); rule(r,'#8e6d4f',.8);
      const L = []; for (let i = 0; i < 7; i++) for (let j = 0; j < 4; j++) if ((i*3+j*5)%4){ const c = Q(3+i*13,12+j*12); L.push(`M${n1(c[0])} ${n1(c[1])}l${n1(6*.866)} ${n1(6*.5)}v-6l${n1(-6*.866)} ${n1(-6*.5)}z`); } out.push(`<path d="${L.join('')}" fill="#fffdf6" stroke="${INK}" stroke-width=".5"/>`); }
    const q = P(-6,-16); who2(q[0],q[1],{hair:'bun',shirt:'#7f9db3',arm:'front',look:-1,size:.78,say:'this one is planned'});
    lifeCounter(-46,0,96,24,30,'#9c6b4e','#e9dcc4',{n:14});
    const g = [P(-46,2,30),P(50,2,30),P(50,2,62),P(-46,2,62)]; out.push(`<path d="${pathOf(g)}Z" fill="#c5d1d4" opacity=".36"/>`); rim(g,.9,INK); out.push(`<path d="${pathOf([P(-30,2,34),P(-22,2,34),P(-10,2,58),P(-18,2,58)])}Z" fill="#fffdf6" opacity=".5"/>`);
    box(14,8,30,26,16,3,{left:'#a6a4a4',top:'#dcd9d0',marks:false,ink:.9}); box(16,22,30,8,3,7,{left:'#3f3a39',top:'#6b6660',marks:false,ink:.6});
    group('id="hPR" style="opacity:0;transition:opacity .4s"',() => { const e = [P(16,9,33.2),P(38,9,33.2),P(38,22,33.2),P(16,22,33.2)]; flat(e,'#ecc98e'); rim(e,.7,INK); pen([P(16,9,33.2),P(27,15,33.2),P(38,9,33.2)],.7); });
    box(-30,10,30,10,12,2,{left:'#3f3a39',top:'#6b6660',marks:false,ink:.6}); lifeTurn(-12,14,30,[[3,0],[3,4],[5,6],[5,12]],'#8e6d4f',{cap:'#c8372f',seam:false,ink:.6});
    box(-24,-6,68,52,3,13,{left:'#3f3a39',top:'#6b6660',marks:false,ink:.9}); const s = [P(-22,-3,70),P(26,-3,70),P(26,-3,79),P(-22,-3,79)]; flat(s,'#e9dcc4'); rim(s,.7,INK); onY(-18,-2.8,72,'TRIAGE',6,INK); for (const u of [-14,18]) lifePipe([P(u,-4,81),P(u,-4,96)],1,'#8f8a86'); }
];
/* a laptop on a desk: base at height z, the screen standing on its back edge, facing the viewer */
function laptop(x,y,z,w,d,h,screen){ box(x,y,z,w,d,1.6,{left:'#a6a4a4',top:'#dcd9d0',marks:false,ink:.8}); const f = [P(x,y,z+1.6),P(x+w,y,z+1.6),P(x+w,y,z+h),P(x,y,z+h)]; flat(f,'#6b6660'); rim(f,.9,INK); const g = [P(x+2,y+.2,z+3),P(x+w-2,y+.2,z+3),P(x+w-2,y+.2,z+h-2),P(x+2,y+.2,z+h-2)]; flat(g,screen); rim(g,.5,INK); }

function draw(seed){ begin(seed); OX = 700; OY = 700;
  out.push(`<style>.msg{opacity:.3;transition:opacity .4s}.msg.sent,.msg.go{opacity:1}.msg .hl,.pil .hl,.act .hl{opacity:0;transition:opacity .35s}.msg.lit .hl,.pil.lit .hl,.act.lit .hl{opacity:1}.pil{transition:opacity .4s}.pil.fut{opacity:.32}.pil.past{opacity:.62}#qTok{transition:opacity .25s}</style>`);
  head('','Four hands','who calls what over MCP, from a wish to a merge');
  /* the frame round the whole interaction, with its name tab, as UML draws it */
  group('data-state="app"',() => { const f = rrect(40,252,1320,1040,6); out.push(`<path d="${pathOf(f)}Z" fill="#fffdf6" opacity=".45"/>`); line(loopOf(f),{w:1.4,col:LEAD,over:0});
    const t = [[40,252],[318,252],[318,276],[302,292],[40,292]]; fill(t,'#efe6d6',{dx:0,dy:0,amp:0}); line([[318,252],[318,276],[302,292],[40,292]],{w:1.4,col:LEAD,over:0}); tx(56,280,'sd',sz(20,24),{a:'start',cls:'tt',col:LEAD}); tx(92,280,'one wish',sz(21,25),{a:'start',col:INK}); });
  /* time runs down the page */
  arr([[72,560],[72,1246]],{w:1.4,col:LEAD,hd:12}); tx(62,900,'time',sz(19,24),{rot:-90,col:LEAD});
  /* the participant heads, then their lifelines */
  for (let i = 0; i < 4; i++){ const x = QX[i];
    group(`data-state="${QK[i]}"`,() => { card(x-HW/2,HY,HW,HH,QBG[i]); clipped(rrect(x-HW/2+2,HY+2,HW-4,HH-50,9),() => isoK(x+HK[i][1],HY+HK[i][2],HK[i][0],HEADS[i])); line([[x-HW/2+12,HY+HH-46],[x+HW/2-12,HY+HH-46]],{w:.9,col:LEAD,over:0}); tx(x,HY+HH-14,PHONE ? QNP[i] : QN[i],sz(22,27));
      out.push(`<path d="M${x} ${LY0}V${LY1}" stroke="${LEAD}" stroke-width="1.4" stroke-dasharray="9 7"/>`); }); }
  /* activation bars: who is busy, row by row */
  ACTS.forEach(([w,a,b],i) => { const x = QX[w], y0 = RY(a)-(a === b ? 22 : 14), y1 = RY(b)+(a === b ? 22 : 16);
    group(`id="ac${i}" class="act" data-state="${QK[w]}"`,() => { const p = [[x-BAR,y0],[x+BAR,y0],[x+BAR,y1],[x-BAR,y1]]; fill(p,'#fffdf6',{dx:0,dy:0,amp:0}); line(loopOf(p),{w:1.2,over:0}); group('class="hl"',() => { out.push(`<path d="${pathOf(p)}Z" fill="#f2c6b8"/>`); line(loopOf(p),{w:1.6,col:RED,over:0}); }); }); });
  /* the messages, numbered, in time order */
  MSG.forEach((m,i) => { const pts = msgPts(m), y = RY(i), dash = m.kind === 'ret', open = m.kind !== 'call', sz0 = sz(17,25);
    group(`id="m${i}" class="msg"`,() => {
      const drawArrow = (col,w,hd) => { if (dash){ const [a,b] = pts, L = Math.abs(b[0]-a[0]), d = Math.sign(b[0]-a[0]), segs = []; for (let u = 0; u < L-16; u += 18) segs.push([[a[0]+d*u,y],[a[0]+d*Math.min(u+10,L-16),y]]); rule(segs,col,w); arr([[b[0]-d*20,y],b],{col,w,hd,open:true}); } else arr(pts,{col,w,hd,open}); };
      drawArrow(INK,1.6,15); group('class="hl"',() => drawArrow(RED,4,19));
      const w = m.s.length*sz0*.78+sz0*1.6, x0 = m.kind === 'self' ? QX[m.f]+BAR+78 : m.lx-w/2, ly = m.kind === 'self' ? y+8 : y-14;
      out.push(`<path d="${pathOf(rrect(x0-6,ly-sz0-3,w+12,sz0+13,(sz0+13)/2-1))}Z" fill="#fbf6ec" opacity=".92"/>`);
      out.push(`<circle cx="${n1(x0+sz0*.55)}" cy="${n1(ly-sz0*.32)}" r="${n1(sz0*.58)}" fill="${INK}"/>`); tx(x0+sz0*.55,ly-sz0*.32+sz0*.3,String(i+1),sz(15,19),{cls:'tt',col:'#fffdf6'}); tx(x0+sz0*1.45,ly,m.s,sz0,{a:'start'}); }); });
  /* the state boxes on the lifelines: what each part is in, between messages */
  PILLS.forEach(([w,id,s,k],i) => { const x = QX[w], y = pillY(k), size = sz(17,21), wd = Math.max(84,s.length*size*.78+30), h = size+16;
    out.push(`<path d="${pathOf(rrect(x-wd/2,y-h/2,wd,h,h/2-1))}Z" fill="#fcf7ee"/>`); /* a solid backing, so a faded pill never shows the activation bar through it */
    group(`id="pl${i}" class="pil" data-state="${id}"`,() => { const p = rrect(x-wd/2,y-h/2,wd,h,h/2-1); fill(p,'#fffdf6',{dx:0,dy:0,amp:0}); line(loopOf(p),{w:1.2,over:0}); group('class="hl"',() => { out.push(`<path d="${pathOf(p)}Z" fill="#fbe3d6"/>`); line(loopOf(rrect(x-wd/2-4,y-h/2-4,wd+8,h+8,h/2+3)),{w:3.4,col:RED,over:0}); }); tx(x,y+size*.36,s,size); }); });
  /* the message on its way */
  group(`id="qTok" style="opacity:0;pointer-events:none" transform="translate(${QX[0]} ${RY(0)})"`,() => { out.push(`<circle cx="0" cy="0" r="21" fill="${RED}" stroke="${INK}" stroke-width="1.2"/>`); tx(0,8,'1',22,{id:'qTokN',cls:'tt',col:'#fffdf6'}); });
  /* where the story is */
  tx(1330,148,'0 of 9',sz(38,42),{id:'qA',a:'end',cls:'tt'}); tx(1330,180,'nothing sent yet',sz(19,22),{id:'qB',a:'end',col:INK});
  foot('Real tool names and statuses; item 7 is made up.','Item 7 is made up.');
  finish(); }

function init(ctx){
  const $ = id => document.getElementById(id), tok = $('qTok'), WHO = ["user's agent",'engine','coding agent','you'];
  const SAY = ['1 · A user’s agent files a feature request over MCP.',
    '2 · You approve it in triage: the work item is planned.',
    '3 · Your coding agent asks for planned work.',
    '4 · feature_machine hands back item 7, with its spec.',
    '5 · The agent picks it up: in progress.',
    '6 · It writes the code and runs your tests.',
    '7 · It hands back for review, with the pull request attached.',
    '8 · You merge and mark it shipped.',
    '9 · The person who asked hears it shipped.'];
  let k = 0, anim = null, auto = false, wait = 0;
  function show(){ const now = anim ? anim.i : k-1;
    MSG.forEach((m,i) => { const g = $('m'+i); g.classList.toggle('sent',i < k); g.classList.toggle('go',!!anim && anim.i === i); g.classList.toggle('lit',i === now); });
    PILLS.forEach((p,i) => { const g = $('pl'+i), live = p[3] <= k, cur = live && !PILLS.some(q => q[0] === p[0] && q[3] <= k && q[3] > p[3]); g.classList.toggle('fut',!live); g.classList.toggle('past',live && !cur); g.classList.toggle('lit',cur); });
    ACTS.forEach(([,a,b],i) => $('ac'+i).classList.toggle('lit',now >= a && now <= b));
    $('hSlip').style.opacity = k >= 1 && k < 3 ? 1 : 0; $('hGreen').style.opacity = k >= 6 ? 1 : 0; $('hEnv').style.opacity = k === 6 ? 1 : 0; $('hPR').style.opacity = k === 7 ? 1 : 0;
    $('qA').textContent = `${k} of ${NM}`; const L = MSG[k-1];
    $('qB').textContent = L ? `${WHO[L.f]}: ${L.s}` : 'nothing sent yet'; }
  function place(p){ tok.setAttribute('transform',`translate(${n1(p[0])} ${n1(p[1])})`); }
  function send(i){ const pts = msgPts(MSG[i]), L = pts.slice(1).reduce((a,q,j) => a+Math.hypot(q[0]-pts[j][0],q[1]-pts[j][1]),0); anim = {i,pts,p:0,dur:.55+L/1600}; $('qTokN').textContent = i+1; place(pts[0]); tok.style.opacity = 1; show(); }
  function arrive(){ const i = anim.i; anim = null; tok.style.opacity = 0; k = i+1; show(); ctx.say(SAY[i]); if (k === NM) auto = false; }
  const settle = () => { if (anim) arrive(); };
  function reset(){ anim = null; tok.style.opacity = 0; k = 0; show(); }
  function next(){ settle(); if (k === NM){ reset(); ctx.say('A new wish: back to the top.'); return; } send(k); }
  const STATUS = ['nothing','requested','planned','planned','planned','in progress','in progress','in review','shipped','shipped'];
  function approve(){ settle(); auto = false;
    if (k === 1){ send(1); return; }
    if (k === 0) ctx.say('Refused: nothing has been filed yet.');
    else if (k < NM) ctx.say(`Already approved: item 7 is ${STATUS[k]}.`);
    else ctx.say('It has shipped: press Next message to start again.'); }
  function ship(){ settle(); auto = false;
    if (k === 7){ send(7); return; }
    if (k < 2) ctx.say('Refused: there is no planned work item yet.');
    else if (k < 7) ctx.say(`Refused: no pull request is attached yet. Item 7 is ${STATUS[k]}.`);
    else ctx.say('Already merged and shipped.'); }
  ctx.button('play it in order',() => { if (auto){ ctx.say('Already playing.'); return; } settle(); if (k === NM) reset(); auto = true; wait = 0; });
  ctx.button('next message',() => { auto = false; next(); });
  ctx.button('approve it',approve);
  ctx.button('merge and ship',ship);
  reset(); ctx.say(PHONE ? 'Press Play all, or Next message.' : 'Press Play all, or Next message. Try merging before there is a PR.');
  return { tick(t,dt){
    if (anim){ const a = anim; a.p = Math.min(1,a.p+dt/a.dur); const e = a.p*a.p*(3-2*a.p), P2 = a.pts, Ls = P2.slice(1).map((q,j) => Math.hypot(q[0]-P2[j][0],q[1]-P2[j][1])); let d = e*Ls.reduce((s,v) => s+v,0), j = 0; while (j < Ls.length-1 && d > Ls[j]){ d -= Ls[j]; j++; }
      const u = Math.min(1,d/(Ls[j] || 1)); place([lerp(P2[j][0],P2[j+1][0],u),lerp(P2[j][1],P2[j+1][1],u)]); if (a.p >= 1) arrive(); return; }
    if (auto){ wait -= dt; if (wait <= 0){ if (k < NM) send(k); wait = .6; } } } };
}
