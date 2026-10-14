/* ============================================================================
   app.js — the whole frontend, explained for a 13-year-old (and for Riccardo 😄).

   What happens when the page loads:
     1. We download index.json (one file with every skill in it).
     2. We look at the URL after the "#": either a search (#/?q=audio) or a
        skill id (#/s/palladius-public-goodies/nano-banana-ricc).
     3. We draw the cards that match, or the detail page for one skill.
     4. Every time you type, we redraw. Every time the "#" changes, we redraw.

   There is NO framework, NO build step. Just functions that make HTML strings.
   ========================================================================== */

"use strict";

// ---- 1. State: the few things the page needs to remember ---------------------
const state = {
  skills: [],            // every skill from index.json
  sources: [],           // every source (repo) from index.json
  query: "",             // what's in the search box
  activeSources: new Set(),  // source ids currently toggled ON (empty = all)
  activeTiers: new Set(),    // tiers currently toggled ON (empty = all)
  cursor: -1,            // which card is highlighted by the keyboard (↑/↓)
};

// Short helpers so the code below reads like English.
const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"}[c]));
const TIER_LABEL = {public: "public", ricc: "💛 ricc", google: "🔵 google"};

// ---- 2. Boot: download the index, then listen for typing and URL changes -----
async function boot() {
  const res = await fetch("index.json", {cache: "no-cache"});
  const index = await res.json();
  state.skills = index.skills;
  state.sources = index.sources;
  $("#generated").textContent = `generated ${index.generated_at?.slice(0, 16).replace("T", " ")} UTC`;

  renderFilters();
  readUrl();                   // URL → state (so a shared link opens the right view)
  render();

  // Typing while a skill detail is open? Leave the detail: the results list must follow the search.
  $("#q").addEventListener("input", (e) => {
    state.query = e.target.value; state.cursor = -1;
    if (state.detailId) { state.detailId = null; $("#detail").hidden = true; }
    writeUrl(); render();
  });
  window.addEventListener("hashchange", () => { readUrl(); render(); });
  document.addEventListener("keydown", onKey);
}

// ---- 3. URL ↔ state -------------------------------------------------------------
// We use the part after "#" so this works on GitHub Pages (no server rewrites).
//   #/?q=audio&src=google-skills&tier=public   → list view
//   #/s/<skill id>                              → detail view
function readUrl() {
  const hash = location.hash.replace(/^#\/?/, "");
  if (hash.startsWith("s/")) { state.detailId = decodeURIComponent(hash.slice(2)); return; }
  state.detailId = null;
  const params = new URLSearchParams(hash.replace(/^\?/, ""));
  state.query = params.get("q") ?? "";
  state.activeSources = new Set((params.get("src") ?? "").split(",").filter(Boolean));
  state.activeTiers = new Set((params.get("tier") ?? "").split(",").filter(Boolean));
  $("#q").value = state.query;
}

function writeUrl() {
  const p = new URLSearchParams();
  if (state.query) p.set("q", state.query);
  if (state.activeSources.size) p.set("src", [...state.activeSources].join(","));
  if (state.activeTiers.size) p.set("tier", [...state.activeTiers].join(","));
  const next = p.toString() ? `#/?${p}` : "#/";
  // replaceState = don't spam the browser history with every keystroke.
  history.replaceState(null, "", next);
}

// ---- 4. Search: which skills match, and in what order? ---------------------------
// Every word you type must appear somewhere (name, title, description, category, source).
// Matches in the NAME count more than matches in the description → better ones float up.
function score(skill, words) {
  const name = skill.name.toLowerCase();
  const hay = `${skill.title} ${skill.description} ${skill.category ?? ""} ${skill.source}`.toLowerCase();
  let total = 0;
  for (const w of words) {
    if (name === w) total += 100;
    else if (name.startsWith(w)) total += 50;
    else if (name.includes(w)) total += 25;
    else if (hay.includes(w)) total += 5;
    else return 0;                  // one word missing → not a match at all
  }
  return total;
}

// Order: best text match first, then higher quality (0–5 stars, computed by the indexer),
// then newest, then alphabetical. With an empty search it's simply quality → date → name.
function matches() {
  const words = state.query.toLowerCase().split(/\s+/).filter(Boolean);
  return state.skills
    .filter((s) => !state.activeSources.size || state.activeSources.has(s.source))
    .filter((s) => !state.activeTiers.size || state.activeTiers.has(s.tier))
    .map((s) => [score(s, words) || (words.length ? 0 : 1), s])
    .filter(([sc]) => sc > 0)
    .sort((a, b) => b[0] - a[0]
      || (b[1].quality ?? 0) - (a[1].quality ?? 0)
      || b[1].updated_at.localeCompare(a[1].updated_at)
      || a[1].name.localeCompare(b[1].name))
    .map(([, s]) => s);
}

// ---- 5. Rendering: turn data into HTML ---------------------------------------------
function render() {
  if (state.detailId) return renderDetail(state.skills.find((s) => s.id === state.detailId));
  $("#detail").hidden = true;
  const list = matches();
  $("#count").textContent = `${list.length} / ${state.skills.length}`;
  $("#results").hidden = false;
  $("#results").innerHTML = list.length
    ? list.map((s, i) => card(s, i === state.cursor)).join("")
    : `<p class="empty">Nothing matches <b>${esc(state.query)}</b>. Try fewer words.</p>`;
  document.title = state.query ? `🧭 ${state.query} — skills` : "🧭 Skills";
}

// One result card, built for a 2–4 column grid:
//   row 1: emoji + name + stars        row 2: description (3 lines max)
//   row 3: version · lines · date · scripts        source badge
const stars = (q) => `<span class="stars" title="quality ${q}/5 (version, scripts, recent, size, description)">${"★".repeat(q)}${"☆".repeat(5 - q)}</span>`;
function card(s, active) {
  const meta = [
    s.version && `<span class="v">v${esc(s.version)}</span>`,
    `<span class="l">${s.lines}L</span>`,
    `<span class="d">${esc(s.updated_at)}</span>`,
    s.has_scripts && `<span class="scripts" title="${esc(s.languages.join(", "))}">⚙️ ${esc(s.languages.join(" "))}</span>`,
  ].filter(Boolean).join(" ");
  return `
  <a class="card ${active ? "active" : ""}" data-tier="${s.tier}" href="#/s/${encodeURIComponent(s.id)}">
    <div class="row1">
      <span class="emoji">${s.emoji ?? "📄"}</span>
      <span class="name" title="${esc(s.name)}">${esc(s.name)}</span>
      ${stars(s.quality ?? 0)}
    </div>
    <p class="desc">${esc(s.description.replace(/^\s*[(\[]?\s*\p{Extended_Pictographic}\uFE0F?\s*[)\]]?\s*/u, ""))}</p>
    <div class="row3">
      <span class="meta">${meta}</span>
      <span class="src" data-tier="${s.tier}" title="${esc(s.category ?? "")}">${esc(s.source)}</span>
    </div>
  </a>`;
}

// The detail page: header + metadata + the SKILL.md rendered as HTML.
async function renderDetail(s) {
  $("#results").hidden = true;
  const box = $("#detail");
  box.hidden = false;
  if (!s) { box.innerHTML = `<p class="empty">Unknown skill <code>${esc(state.detailId)}</code>. <a href="#/">← back</a></p>`; return; }
  document.title = `${s.emoji ?? "🧭"} ${s.name} — skills`;
  box.dataset.tier = s.tier;
  box.innerHTML = `
    <p class="crumbs"><a href="#/">← all skills</a> · <a href="#/?src=${esc(s.source)}">${esc(s.source)}</a>${s.category ? ` · ${esc(s.category)}` : ""}</p>
    <h1>${s.emoji ?? ""} ${esc(s.title)}</h1>
    <p class="lead">${esc(s.description)}</p>
    <dl class="facts">
      <dt>name</dt><dd><code>${esc(s.name)}</code></dd>
      <dt>quality</dt><dd>${stars(s.quality ?? 0)} <small>${s.quality ?? 0}/5 — version, scripts, recent, size, description</small></dd>
      ${s.version ? `<dt>version</dt><dd>v${esc(s.version)}</dd>` : ""}
      <dt>size</dt><dd>${s.lines} lines · ${(s.size_bytes / 1024).toFixed(1)} KB</dd>
      <dt>updated</dt><dd>${esc(s.updated_at)}</dd>
      ${s.compatibility ? `<dt>compat</dt><dd>${esc(s.compatibility)}</dd>` : ""}
      ${s.languages.length ? `<dt>scripts</dt><dd>${esc(s.languages.join(", "))}</dd>` : ""}
      <dt>tier</dt><dd><span class="src" data-tier="${s.tier}">${TIER_LABEL[s.tier] ?? s.tier}</span></dd>
      <dt>upstream</dt><dd><a href="${esc(s.upstream_url)}" target="_blank" rel="noopener">${esc(s.path)}</a></dd>
      <dt>raw</dt><dd><a href="${esc(s.entrypoint)}" target="_blank" rel="noopener">entrypoint</a></dd>
      <dt>install</dt><dd><code class="install">${esc(s.install)}</code> <button class="copy" data-copy="${esc(s.install)}">copy</button></dd>
      <dt>permalink</dt><dd><code>${esc(location.href)}</code> <button class="copy" data-copy="${esc(location.href)}">copy</button></dd>
    </dl>
    <div class="md"><p class="dim">loading SKILL.md…</p></div>`;
  box.querySelectorAll(".copy").forEach((b) => b.addEventListener("click", () => {
    navigator.clipboard.writeText(b.dataset.copy); b.textContent = "copied!"; setTimeout(() => (b.textContent = "copy"), 1200);
  }));
  // Fetch the copy of SKILL.md that the indexer placed under content/, render it safely.
  try {
    const md = await (await fetch(s.content_url)).text();
    const body = md
      .replace(/^---[\s\S]*?\n---\s*\n/, "")   // hide the YAML frontmatter, it's already shown above
      .replace(/^\s*#\s+.+\n/, "");           // hide the first H1 too, it's our page title
    box.querySelector(".md").innerHTML = DOMPurify.sanitize(marked.parse(body));
  } catch (e) {
    box.querySelector(".md").innerHTML = `<p class="dim">Could not load content (${esc(e.message)}). <a href="${esc(s.upstream_url)}">Open upstream →</a></p>`;
  }
}

// Filter chips: one per source and one per tier (tiers only shown if there's more than one).
function renderFilters() {
  const tiers = [...new Set(state.skills.map((s) => s.tier))];
  const chips = [
    ...state.sources.map((src) => chip("src", src.id, `${esc(src.name)} <small>${src.skills_count}</small>`, src.tier)),
    ...(tiers.length > 1 ? tiers.map((t) => chip("tier", t, TIER_LABEL[t] ?? t, t)) : []),
  ];
  $("#filters").innerHTML = chips.join("");
  $("#filters").addEventListener("click", (e) => {
    const b = e.target.closest("button"); if (!b) return;
    const set = b.dataset.kind === "src" ? state.activeSources : state.activeTiers;
    set.has(b.dataset.value) ? set.delete(b.dataset.value) : set.add(b.dataset.value);
    b.classList.toggle("on");
    state.cursor = -1; writeUrl(); render();
  });
}
const chip = (kind, value, label, tier) =>
  `<button class="chip" data-kind="${kind}" data-value="${esc(value)}" data-tier="${tier}">${label}</button>`;

// ---- 6. Keyboard: "/" focuses search, ↑/↓ move, Enter opens, Esc goes back -----------
function onKey(e) {
  const typing = e.target === $("#q");
  if (e.key === "/" && !typing) { e.preventDefault(); $("#q").focus(); $("#q").select(); return; }
  if (e.key === "Escape") { if (state.detailId) location.hash = "#/"; else { $("#q").value = ""; state.query = ""; writeUrl(); render(); } return; }
  if (state.detailId) return;
  const cards = [...document.querySelectorAll(".card")];
  if (!cards.length) return;
  if (e.key === "ArrowDown") { e.preventDefault(); state.cursor = Math.min(state.cursor + 1, cards.length - 1); }
  else if (e.key === "ArrowUp") { e.preventDefault(); state.cursor = Math.max(state.cursor - 1, 0); }
  else if (e.key === "Enter" && state.cursor >= 0) { cards[state.cursor].click(); return; }
  else return;
  cards.forEach((c, i) => c.classList.toggle("active", i === state.cursor));
  cards[state.cursor]?.scrollIntoView({block: "nearest"});
}

boot();
