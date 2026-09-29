// vale studio page. Plain ES module, no dependencies. Neovim does the theme
// work (applying edits, computing preview colours); this page only edits
// values and displays what Neovim sends back.

const TOKEN = document.querySelector('meta[name="vale-token"]').content;
const $app = document.getElementById("app");
const $crumbs = document.getElementById("crumbs");
const $actions = document.getElementById("bar-actions");
const VARIANTS = ["night", "day"];
const GROUPS = [
  ["foundation", "Foundation"],
  ["syntax", "Syntax"],
  ["signals", "Signals"],
  ["ui", "UI"],
  ["ansi", "Terminal (ANSI)"],
];

// ---------------------------------------------------------------- helpers

const h = (tag, attrs = {}, ...children) => {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (k === "style" && typeof v === "object") Object.assign(el.style, v);
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
};

// Lua sends empty tables as [] — treat them as objects.
const obj = (v) => (v && typeof v === "object" && !Array.isArray(v) ? v : {});

async function api(method, path, body) {
  const res = await fetch(path, {
    method,
    headers: { "X-Vale-Token": TOKEN, ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `${res.status}`);
  return data;
}

let toastTimer;
function toast(msg, bad = false) {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.className = "show" + (bad ? " bad" : "");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.className = ""), 2600);
}

// ---------------------------------------------------------------- colour maths

const isHex = (s) => /^#[0-9a-fA-F]{6}$/.test(s);
const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
const toHex = (c) => "#" + c.map((v) => Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, "0")).join("").toUpperCase();
const lin = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const delin = (c) => (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055);

function luminance(hex) {
  const [r, g, b] = rgb(hex).map(lin);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
function contrast(a, b) {
  const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}

function toOklch(hex) {
  const [r, g, b] = rgb(hex).map(lin);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  const L = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s;
  const A = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  const B = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
  return [L, Math.hypot(A, B), Math.atan2(B, A)];
}
function fromOklch([L, C, H]) {
  const A = C * Math.cos(H), B = C * Math.sin(H);
  const l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3;
  const m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3;
  const s = (L - 0.0894841775 * A - 1.291485548 * B) ** 3;
  return [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
}
// Nearest in-gamut colour: keep L and H, reduce chroma until sRGB fits.
function oklchToHex(L, C, H) {
  L = Math.min(1, Math.max(0, L));
  let lo = 0, hi = Math.max(0, C);
  const fits = (c) => fromOklch([L, c, H]).every((v) => v >= -1e-4 && v <= 1 + 1e-4);
  if (!fits(hi)) {
    for (let i = 0; i < 20; i++) {
      const mid = (lo + hi) / 2;
      if (fits(mid)) lo = mid; else hi = mid;
    }
    hi = lo;
  }
  return toHex(fromOklch([L, hi, H]).map(delin));
}
function variations(hex) {
  const [L, C, H] = toOklch(hex);
  return [
    ["darker", oklchToHex(L - 0.1, C, H)],
    ["a bit darker", oklchToHex(L - 0.05, C, H)],
    ["a bit lighter", oklchToHex(L + 0.05, C, H)],
    ["lighter", oklchToHex(L + 0.1, C, H)],
    ["less saturated", oklchToHex(L, C * 0.7, H)],
    ["more saturated", oklchToHex(L, C * 1.3 + 0.01, H)],
  ].filter(([, v]) => v.toUpperCase() !== hex.toUpperCase());
}

// ---------------------------------------------------------------- live events

let events;
function connectEvents() {
  if (events) return;
  events = new EventSource(`/api/events?t=${TOKEN}`);
  events.addEventListener("changed", (e) => {
    const { name } = JSON.parse(e.data);
    if (editor && editor.name === name) editor.reloadFromDisk();
  });
  events.addEventListener("bye", () => {
    events.close();
    document.body.append(h("div", { class: "overlay" },
      h("div", {}, h("h2", {}, "Studio stopped"), h("p", {}, "Run :Vale in Neovim to open it again."))));
  });
}

// ---------------------------------------------------------------- router

let editor = null;

async function route() {
  const hash = location.hash || "#/";
  $actions.replaceChildren();
  if (editor && !hash.startsWith(`#/edit/${editor.name}`)) {
    if (!(await editor.leave())) {
      history.replaceState(null, "", `#/edit/${editor.name}`);
      return;
    }
    editor = null;
  }
  const edit = hash.match(/^#\/edit\/([a-z0-9-]+)/);
  const create = hash.match(/^#\/new(?:\/([a-z0-9-]*))?/);
  try {
    if (edit) await showEditor(edit[1]);
    else if (create) await showNew(create[1] || "");
    else await showList();
  } catch (err) {
    $app.replaceChildren(h("div", { class: "page" }, h("h1", {}, "Something went wrong"), h("p", { class: "lead" }, err.message)));
  }
}
window.addEventListener("hashchange", route);

// ---------------------------------------------------------------- list

async function showList() {
  $crumbs.replaceChildren(h("b", {}, "Themes"));
  const { themes } = await api("GET", "/api/themes");
  const cards = [];
  for (const t of themes) {
    const data = await api("GET", `/api/theme/${t.name}`);
    const v = t.variants[0];
    const r = data.resolved[v];
    const strip = ["base.bg", "base.fg", "accent.blue", "accent.purple", "accent.yellow", "accent.orange", "accent.teal", "accent.green"]
      .map((s) => h("i", { style: { background: r[s] } }));
    cards.push(h("div", { class: "card" },
      h("h2", {}, t.name),
      h("div", { class: "meta" }, t.variants.map((x) => `${t.name}-${x}`).join(" · ")),
      h("div", { class: "strip" }, strip),
      h("div", {}, h("a", { class: "btn primary", href: `#/edit/${t.name}` }, "Edit"))));
  }
  cards.push(h("div", { class: "card new" },
    h("h2", {}, "New theme"),
    h("div", { class: "meta" }, "Start from VS Code Modern or copy a theme."),
    h("a", { class: "btn", href: "#/new" }, "Create…")));
  $app.replaceChildren(h("div", { class: "page" },
    h("h1", {}, "Your themes"),
    h("p", { class: "lead" }, "Each theme has a night (dark) and/or day (light) variant, loadable as :colorscheme name-variant."),
    h("div", { class: "cards" }, cards)));
}

// ---------------------------------------------------------------- new theme

async function showNew(prefill) {
  $crumbs.replaceChildren(h("a", { href: "#/" }, "Themes"), "›", h("b", {}, "New theme"));
  const { themes } = await api("GET", "/api/themes");
  const name = h("input", { type: "text", value: prefill, placeholder: "ocean", autocomplete: "off", spellcheck: "false" });
  const night = h("input", { type: "checkbox", checked: true });
  const day = h("input", { type: "checkbox", checked: true });
  const from = h("select", {},
    h("option", { value: "vscode" }, "VS Code Modern (default colours)"),
    themes.map((t) => h("option", { value: t.name }, `Copy of ${t.name}`)));
  const error = h("div", { class: "error" });
  const submit = h("button", { class: "btn primary", type: "submit" }, "Create theme");
  const form = h("form", { class: "form", onsubmit: async (e) => {
    e.preventDefault();
    const variants = [night.checked && "night", day.checked && "day"].filter(Boolean);
    error.textContent = "";
    submit.disabled = true;
    try {
      await api("POST", "/api/create", { name: name.value.trim(), variants, from: from.value });
      location.hash = `#/edit/${name.value.trim()}`;
    } catch (err) {
      error.textContent = err.message;
    } finally {
      submit.disabled = false;
    }
  } },
    h("label", { class: "field" }, "Name", h("span", { class: "hint" }, "lowercase letters, digits and hyphens — becomes :colorscheme name-night / name-day"), name),
    h("div", { class: "field" }, h("b", {}, "Variants"),
      h("div", { class: "row" },
        h("label", {}, night, " night (dark)"),
        h("label", {}, day, " day (light)"))),
    h("label", { class: "field" }, "Start from", from),
    error,
    h("div", {}, submit));
  $app.replaceChildren(h("div", { class: "page" }, h("h1", {}, "New theme"), form));
  name.focus();
}

// ---------------------------------------------------------------- editor

async function showEditor(name) {
  $crumbs.replaceChildren(h("a", { href: "#/" }, "Themes"), "›", h("b", {}, name));
  const data = await api("GET", `/api/theme/${name}`);
  editor = new Editor(data);
  await editor.start();
}

class Editor {
  constructor(data) {
    this.name = data.name;
    this.data = data;
    this.variant = data.variants.includes("night") ? "night" : data.variants[0];
    this.edits = { night: {}, day: {} };
    this.semantics = this.normSemantics(data.semantics);
    this.sample = null;
    this.tab = "colours";
    this.pending = false;
    this.inflight = false;
    this.timer = null;
  }

  normSemantics(sem) {
    const out = {};
    for (const [k, v] of Object.entries(obj(sem))) out[k] = typeof v === "object" ? { ...obj(v) } : v;
    return out;
  }

  // ---- state
  saved(slot, variant = this.variant) { return this.data.resolved[variant][slot]; }
  value(slot, variant = this.variant) { return this.edits[variant][slot] || this.saved(slot, variant); }
  roleValue(role) {
    const d = this.data.roles.find((r) => r.role === role);
    return obj(this.semantics[this.variant])[role] ?? this.semantics[role] ?? d.default;
  }
  hexOfName(name) {
    if (name.startsWith("ui.")) return this.value(name);
    for (const b of ["base", "accent", "signal"]) {
      const s = `${b}.${name}`;
      if (s in this.data.resolved[this.variant]) return this.value(s);
    }
    return null;
  }
  dirty() {
    if (VARIANTS.some((v) => Object.keys(this.edits[v]).length)) return true;
    return JSON.stringify(this.normSemantics(this.data.semantics)) !== JSON.stringify(this.semantics);
  }

  // ---- lifecycle
  async start() {
    connectEvents();
    const res = await api("POST", "/api/session", { name: this.name, variant: this.variant, sample: this.sample });
    this.sample = res.sample.file;
    this.preview = res;
    this.render();
    window.onbeforeunload = () => (this.dirty() ? "unsaved" : undefined);
    window.onpagehide = () => {
      fetch("/api/close", { method: "POST", keepalive: true, headers: { "X-Vale-Token": TOKEN, "Content-Type": "application/json" }, body: "{}" });
    };
  }

  async leave() {
    if (this.dirty() && !confirm("Discard unsaved changes to this theme?")) return false;
    await api("POST", "/api/close", {}).catch(() => {});
    window.onbeforeunload = null;
    window.onpagehide = null;
    return true;
  }

  async reloadFromDisk() {
    this.data = await api("GET", `/api/theme/${this.name}`);
    if (!this.dirty()) this.semantics = this.normSemantics(this.data.semantics);
    toast("Theme changed on disk — reloaded");
    this.push();
  }

  // Send the unsaved state to Neovim; it repaints and returns the preview.
  push() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.flush(), 60);
    this.renderStatus();
  }
  async flush() {
    if (this.inflight) { this.pending = true; return; }
    this.inflight = true;
    try {
      this.preview = await api("POST", "/api/preview", {
        name: this.name, variant: this.variant, sample: this.sample,
        palette: this.edits, semantics: this.semantics,
      });
      this.renderPreview();
    } catch (err) {
      toast(err.message, true);
    } finally {
      this.inflight = false;
      if (this.pending) { this.pending = false; this.flush(); }
    }
  }

  async save() {
    try {
      await this.flush();
      await api("POST", "/api/save", { name: this.name });
      this.data = await api("GET", `/api/theme/${this.name}`);
      this.edits = { night: {}, day: {} };
      this.semantics = this.normSemantics(this.data.semantics);
      toast("Saved");
      this.render();
      this.push();
    } catch (err) {
      toast(err.message, true);
    }
  }

  async discard() {
    if (!this.dirty() || confirm("Discard all unsaved changes?")) {
      this.edits = { night: {}, day: {} };
      this.semantics = this.normSemantics(this.data.semantics);
      this.render();
      this.push();
    }
  }

  // ---- edits
  setColour(slot, hex) {
    hex = hex.toUpperCase();
    if (hex === this.saved(slot).toUpperCase()) delete this.edits[this.variant][slot];
    else this.edits[this.variant][slot] = hex;
    this.renderSlot(slot);
    if (this.tab === "roles") this.renderSide();
    this.push();
  }
  setRole(role, name) {
    // Role changes apply to the whole theme; a per-variant override of the
    // same role on the current variant is removed so the change shows.
    this.semantics[role] = name;
    if (this.semantics[this.variant]) delete this.semantics[this.variant][role];
    this.renderSide();
    this.push();
  }

  // ---- rendering
  render() {
    $actions.replaceChildren(
      this.data.variants.length > 1
        ? h("div", { class: "seg", role: "group", "aria-label": "Variant" },
          this.data.variants.map((v) => h("button", {
            "aria-pressed": String(v === this.variant),
            onclick: () => { this.variant = v; this.render(); this.push(); },
          }, v === "night" ? "night (dark)" : "day (light)")))
        : h("span", { class: "meta" }, `${this.variant} only`),
      (this.$discard = h("button", { class: "btn", onclick: () => this.discard() }, "Discard")),
      (this.$save = h("button", { class: "btn primary", onclick: () => this.save() }, "Save")));
    this.$side = h("section", { class: "side" });
    this.$code = h("pre", { class: "code" });
    this.$tabs = h("div", { class: "tabs", role: "tablist" });
    this.$status = h("div", { class: "status" });
    $app.replaceChildren(h("div", { class: "editor" },
      this.$side,
      h("section", { class: "preview" }, this.$tabs, this.$code, this.$status)));
    this.renderSide();
    this.renderPreview();
    this.renderStatus();
  }

  renderStatus() {
    const n = VARIANTS.reduce((a, v) => a + Object.keys(this.edits[v]).length, 0);
    const dirty = this.dirty();
    this.$save.disabled = !dirty;
    this.$discard.disabled = !dirty;
    this.$status.textContent = dirty
      ? `${n} colour${n === 1 ? "" : "s"} changed${JSON.stringify(this.normSemantics(this.data.semantics)) !== JSON.stringify(this.semantics) ? " · roles changed" : ""} — unsaved, previewing live in Neovim (${this.preview?.colors_name ?? ""})`
      : `Saved · previewing in Neovim as ${this.preview?.colors_name ?? ""}`;
  }

  renderSide() {
    const tabs = h("div", { class: "tabs", role: "tablist" },
      [["colours", "Colours"], ["roles", "Roles"]].map(([id, label]) => h("button", {
        role: "tab", "aria-selected": String(this.tab === id),
        onclick: () => { this.tab = id; this.renderSide(); },
      }, label)));
    this.slotEls = {};
    const body = this.tab === "colours" ? this.renderColours() : this.renderRoles();
    this.$side.replaceChildren(tabs, ...body);
  }

  renderColours() {
    return GROUPS.map(([id, title]) => h("div", { class: "group" },
      h("h3", {}, title),
      this.data.slots.filter((s) => s.group === id).map((s) => {
        const el = h("div", { class: "slot" });
        this.slotEls[s.slot] = el;
        this.fillSlot(el, s);
        return el;
      })));
  }

  renderSlot(slot) {
    const el = this.slotEls[slot];
    if (el) this.fillSlot(el, this.data.slots.find((s) => s.slot === slot));
    // colours used as another slot's contrast partner change those too
    for (const s of this.data.slots) if (s.on === slot && this.slotEls[s.slot]) this.fillSlot(this.slotEls[s.slot], s);
    this.renderStatus();
  }

  fillSlot(el, s) {
    const value = this.value(s.slot);
    const edited = s.slot in this.edits[this.variant];
    const on = this.value(s.on);
    const ratio = contrast(value, on);
    const low = s.text && ratio < 4.5;
    const picker = h("input", { type: "color", value: value.toLowerCase(), "aria-label": `Pick ${s.label}`,
      oninput: (e) => this.setColour(s.slot, e.target.value) });
    const hex = h("input", { class: "hex", value, spellcheck: "false", "aria-label": `${s.label} hex`,
      oninput: (e) => {
        const v = e.target.value.trim();
        const ok = isHex(v.startsWith("#") ? v : "#" + v);
        e.target.classList.toggle("invalid", !ok);
        if (ok) this.setColourQuiet(s.slot, v.startsWith("#") ? v : "#" + v, e.target);
      } });
    const raw = this.data.palettes[this.variant][s.slot.split(".")[0]][s.slot.split(".")[1]];
    el.className = "slot" + (edited ? " edited" : "");
    el.replaceChildren(
      h("div", { class: "sw", style: { background: value }, title: "Open colour picker" }, picker),
      h("div", { class: "label" },
        h("b", { title: s.label }, s.label),
        h("code", {}, s.slot), !raw.startsWith("#") && !edited ? h("span", { class: "alias" }, ` → ${raw}`) : null),
      hex,
      h("div", { class: "cr" + (low ? " low" : ""), title: `Contrast against ${s.on} (${on})${low ? " — below 4.5:1 for text" : ""}` },
        `${ratio.toFixed(1)}:1${low ? " ⚠" : ""}`),
      h("div", { class: "vars" }, variations(value).map(([label, v]) =>
        h("button", { title: `${label} ${v}`, style: { background: v }, onclick: () => this.setColour(s.slot, v) }))),
      edited ? h("button", { class: "btn small reset", title: `Back to saved ${this.saved(s.slot)}`, onclick: () => this.setColour(s.slot, this.saved(s.slot)) }, "reset") : h("span"));
  }

  // Typing in the hex box: update everything except the input being typed in.
  setColourQuiet(slot, hex, input) {
    hex = hex.toUpperCase();
    if (hex === this.saved(slot).toUpperCase()) delete this.edits[this.variant][slot];
    else this.edits[this.variant][slot] = hex;
    const el = this.slotEls[slot];
    const s = this.data.slots.find((x) => x.slot === slot);
    this.fillSlot(el, s);
    const again = el.querySelector("input.hex");
    again.value = input.value;
    again.focus();
    again.setSelectionRange(again.value.length, again.value.length);
    for (const o of this.data.slots) if (o.on === slot && this.slotEls[o.slot]) this.fillSlot(this.slotEls[o.slot], o);
    this.push();
  }

  paletteNames() {
    const names = [];
    const p = this.data.palettes[this.variant];
    for (const b of ["base", "accent", "signal"]) for (const k of Object.keys(p[b]).sort()) names.push(k);
    for (const k of Object.keys(p.ui).sort()) names.push(`ui.${k}`);
    return names;
  }

  renderRoles() {
    const names = this.paletteNames();
    const sections = [];
    for (const r of this.data.roles) {
      let sec = sections.find((x) => x.name === r.section);
      if (!sec) sections.push((sec = { name: r.section, roles: [] }));
      sec.roles.push(r);
    }
    return sections.map((sec) => h("div", { class: "group" },
      h("h3", {}, sec.name || "Roles"),
      sec.roles.map((r) => {
        const current = this.roleValue(r.role);
        const changed = current !== r.default;
        const sel = h("select", { "aria-label": r.role, onchange: (e) => this.setRole(r.role, e.target.value) },
          names.map((n) => h("option", { value: n, selected: n === current },
            n === "fg" ? "fg — plain text" : n, n === r.default ? " (default)" : "")));
        return h("div", { class: "role" + (changed ? " changed" : "") },
          h("div", {}, h("b", {}, r.role.replace(/_/g, " ")), changed ? h("span", { class: "tag" }, "changed") : null,
            h("small", {}, r.note || `default: ${r.default}`)),
          sel,
          h("i", { style: { background: this.hexOfName(current) || "transparent" }, title: this.hexOfName(current) || "" }));
      })));
  }

  renderPreview() {
    const p = this.preview;
    if (!p) return;
    this.$tabs.replaceChildren(...p.samples.map((s) => h("button", {
      role: "tab", "aria-selected": String(s.file === this.sample),
      onclick: async () => { this.sample = s.file; this.flush(); },
    }, s.label)));
    const { sample, ui } = p;
    this.$code.style.background = ui.bg;
    this.$code.style.color = ui.fg;
    const byRow = new Map();
    for (const r of sample.runs) {
      if (!byRow.has(r.row)) byRow.set(r.row, []);
      byRow.get(r.row).push(r);
    }
    const rows = sample.lines.map((line, i) => {
      const runs = (byRow.get(i) || []).sort((a, b) => a.s - b.s);
      const parts = [];
      let pos = 0;
      for (const r of runs) {
        if (r.s > pos) parts.push(line.slice(pos, r.s));
        const style = {};
        if (r.fg) style.color = r.fg;
        if (r.bg) style.background = r.bg;
        if (r.b) style.fontWeight = "700";
        if (r.i) style.fontStyle = "italic";
        const deco = [r.u && "underline", r.st && "line-through"].filter(Boolean).join(" ");
        if (deco) style.textDecoration = deco;
        parts.push(h("span", { style }, line.slice(r.s, r.e)));
        pos = r.e;
      }
      if (pos < line.length) parts.push(line.slice(pos));
      return h("div", { class: "ln-row" }, h("span", { class: "ln", style: { color: ui.linenr } }, i + 1), h("span", {}, ...parts, "\n"));
    });
    this.$code.replaceChildren(...rows);
    this.renderStatus();
  }
}

route();
