// "Number 42, please" as the sequence diagram in src/queue.js: four parallel regions of queue.mmd (customer, ticket machine,
// number board, clerk) and seven messages that move them. The states and arrows come from queue.mmd itself, so the check can
// only ever test the drawn machine. A message moves every region that has an arrow with its name, and only when each of them
// can take it (that is what a message between two lifelines means). Arrows that are NOT in the chart live in MUTANTS: each one
// shows what a rule is there to stop. Checked by visiting every reachable state (plain breadth-first search, not TLC).
import { readFileSync, writeFileSync } from "node:fs";

const TITLE = "Four hands";
const MMD = readFileSync(new URL("./handoff.mmd", import.meta.url), "utf8");
// read the regions, states and arrows of the .mmd
function parse(src){
  const body = src.slice(src.indexOf("stateDiagram")), parent = {}, comp = new Set(), stack = ["root"], arrows = [], init = {}, final = new Set();
  for (const raw of body.split("\n")){ const l = raw.trim(); let m;
    if ((m = l.match(/^state\s+"[^"]*"\s+as\s+(\w+)\s*\{$/))){ parent[m[1]] = stack.at(-1); comp.add(m[1]); stack.push(m[1]); continue; }
    if (l === "}"){ stack.pop(); continue; }
    if ((m = l.match(/^(\w+|\[\*\])\s*-->\s*(\w+|\[\*\])(?::\s*(.+))?$/))){ const label = (m[3] || "").trim(), g = label.match(/\[(.*)\]/);
      if (m[1] === "[*]") init[stack.at(-1)] = m[2]; else if (m[2] === "[*]") final.add(m[1]);
      else arrows.push({ from: m[1], to: m[2], label, ev: label.replace(/\s*\[.*\]/, "").trim(), guard: g ? g[1] : null }); continue; }
    if ((m = l.match(/^(\w+):\s/))) parent[m[1]] = stack.at(-1); }
  const leaves = Object.keys(parent).filter(s => !comp.has(s)), regions = [...new Set(leaves.map(s => parent[s]))];
  return { parent, leaves, regions, arrows, init, final };
}
const C = parse(MMD);
const START = { at: Object.fromEntries(C.regions.map(r => [r, C.init[r]])), pr: false };

// what each guard means (each names a state of another region, and can be false where its arrow starts)
const GUARD = {
  "a request is in": s => s.at.engine === "requested",
  "a PR is attached": s => s.at.engine === "in_review",
  "an item is planned": s => s.at.engine === "planned",
  "the item shipped": s => s.at.engine === "shipped",
};
// what an arrow does to the data the rules read
const EFFECT = { "update to in_review with PR": { pr: true } };
for (const a of C.arrows) if (a.guard && !GUARD[a.guard]) throw new Error(`handoff.mmd guard "[${a.guard}]" has no meaning in the check`);
for (const g of Object.keys(GUARD)) if (!C.arrows.some(a => a.guard === g)) throw new Error(`the check has guard "${g}", which is not in handoff.mmd`);

// arrows the chart does not have: each is what a rule keeps shut
const MUTANTS = {
  // WorkItem::AGENT_TRANSITIONS has no draft -> planned: approving is triage, and triage is human
  "the agent plans it": [{ from: "requested", to: "planned", ev: "agent approves its own item", guard: null }],
  // shipping straight from in progress, with no pull request attached
  "a PR is attached": [{ from: "reviewing", to: "merged", ev: "merge and ship", guard: null, replaces: "a PR is attached" },
                       { from: "in_progress", to: "shipped", ev: "merge and ship", guard: null }],
};
const regionOf = s => C.parent[s];
function moves(s, mutant = ""){
  const extra = MUTANTS[mutant] || [], drop = new Set(extra.map(a => a.replaces).filter(Boolean));
  const arrows = [...C.arrows.filter(a => !drop.has(a.guard)), ...extra], out = [];
  for (const ev of new Set(arrows.map(a => a.ev))){
    const regs = new Set(arrows.filter(a => a.ev === ev).map(a => regionOf(a.from))), take = [];
    let ok = true;
    for (const r of regs){ const here = arrows.filter(a => a.ev === ev && a.from === s.at[r] && (!a.guard || GUARD[a.guard](s)));
      if (here.length > 1) throw new Error(`two arrows for "${ev}" in ${r} at once`);
      if (!here.length){ ok = false; break; } take.push(here[0]); }
    if (!ok) continue;
    const at = { ...s.at }; for (const a of take) at[regionOf(a.from)] = a.to;
    out.push([ev, { ...s, ...(EFFECT[ev] || {}), at }]); }
  return out;
}
const key = s => JSON.stringify(s);
function search(mutant, bad = () => false){
  const seen = new Map([[key(START), null]]), q = [START], all = [START]; let steps = 0, hit = null;
  while (q.length){ const s = q.shift(); if (!hit && bad(s)) hit = s;
    for (const [ev, n] of moves(s, mutant)){ steps++; if (!seen.has(key(n))){ seen.set(key(n), [s, ev]); q.push(n); all.push(n); } } }
  const trail = s => { const p = []; for (let c = s; seen.get(key(c)); c = seen.get(key(c))[0]) p.unshift(seen.get(key(c))[1]); return p; };
  return { states: seen.size, steps, all, hit: hit && trail(hit) };
}
const APPROVED = ["planned", "in_progress", "in_review", "shipped"];
const plannedByAgent = s => APPROVED.includes(s.at.engine) && s.at.you === "triaging";
const shippedNoPR = s => s.at.engine === "shipped" && !s.pr;
const ok = search("", s => plannedByAgent(s) || shippedNoPR(s));
if (ok.hit) throw new Error("a rule breaks as built: " + ok.hit.join(", "));
const selfPlan = search("the agent plans it", plannedByAgent).hit, noPR = search("a PR is attached", shippedNoPR).hit;
if (!selfPlan || !noPR) throw new Error("a mutant does not break its rule: the guard may not be needed");
const reached = new Set(ok.all.flatMap(s => Object.values(s.at)));
const missing = C.leaves.filter(s => !reached.has(s)); if (missing.length) throw new Error("never reached: " + missing.join(", "));
for (const a of C.arrows.filter(a => a.guard)) if (!ok.all.some(s => s.at[regionOf(a.from)] === a.from && !GUARD[a.guard](s))) throw new Error(`guard "[${a.guard}]" is never false at ${a.from}`);
const ends = s => C.final.has(s.at.asker) && C.final.has(s.at.engine) && s.at.you === "merged" && s.at.coder === "handed";
const oneOrder = ok.all.every(s => moves(s).length <= 1);
const finishes = ok.all.every(s => { const q = [s], v = new Set([key(s)]); while (q.length){ const u = q.shift(); if (ends(u)) return true; for (const [, n] of moves(u)) if (!v.has(key(n))){ v.add(key(n)); q.push(n); } } return false; });
let run = 0; for (let c = START, m; (m = moves(c)).length; c = m[0][1]) run++;
if (!oneOrder || !finishes || run !== 9) throw new Error(`model does not behave as expected: ${JSON.stringify({ oneOrder, finishes, run })}`);
const n = p => `${p.length} step${p.length === 1 ? "" : "s"}`;
const out = {
  title: TITLE,
  checked: `Every reachable state checked (${ok.states} states, ${ok.steps} steps). All three rules hold.`,
  rules: [
    { rule: "Only you plan work", says: "A coding agent can pick up planned work, but approving a request is triage, and triage is human (WorkItem::AGENT_TRANSITIONS).", path: `Let the agent approve its own item and it breaks in ${n(selfPlan)}: ${selfPlan.join(", ")}.` },
    { rule: "Nothing ships without a pull request", says: "In review needs a GitHub pull request URL, and you merge only what is in review.", path: `Take away the guard on "merge and ship" and it breaks in ${n(noPR)}: ${noPR.join(", ")}, with no PR attached.` },
    { rule: "One order, and it always finishes", says: "From any point there is only one next message, and every run ends shipped, with the asker told.", path: "Holds on every path: nine messages, top to bottom." }]
};
writeFileSync(new URL("./handoff.json", import.meta.url), JSON.stringify(out, null, 1));
console.log(JSON.stringify(out, null, 1));
