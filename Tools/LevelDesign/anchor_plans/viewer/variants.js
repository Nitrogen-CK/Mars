// Warrens v8 layout variants: the viewer (viewer.js) plus a tab per layout and a Compare table, for export_variants.py.
// window.MARS_VARIANTS = {layouts, meta}; every number in Compare comes from MarsViewer.metrics / rasterize, as in the panel.
// ?tab=compare | <layout tab name> picks the opening tab (headless screenshots).
(function () {
  'use strict';
  const V = window.MARS_VARIANTS, L = V.layouts, el = id => document.getElementById(id);
  const esc = t => String(t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  window.MarsViewer.start(THREE);
  const tabs = el('vtabs'), sel = el('layout'), buttons = [];
  const show = which => {
    el('app').hidden = which === 'compare'; el('compare').hidden = which !== 'compare';
    buttons.forEach(b => b.setAttribute('aria-pressed', String(b.dataset.tab === String(which))));
    if (which === 'compare') { if (!el('compare').innerHTML) el('compare').innerHTML = compareTable(); return; }
    if (sel.value !== String(which)) { sel.value = String(which); sel.dispatchEvent(new Event('change')); }
  };
  const tab = (text, key, title) => { const b = document.createElement('button'); b.textContent = text; b.dataset.tab = key; b.title = title || ''; b.addEventListener('click', () => show(key)); tabs.appendChild(b); buttons.push(b); };
  L.forEach((d, i) => tab(d._tab || d.revision, String(i), d._file));
  tab('Compare', 'compare', 'one column per layout');
  sel.addEventListener('change', () => buttons.forEach(b => b.setAttribute('aria-pressed', String(b.dataset.tab === sel.value))));
  el('vstamp').textContent = `${L.length} layouts · exported ${V.meta.generated} · ${V.meta.commit ? 'commit ' + V.meta.commit.slice(0, 9) : ''}`;

  function compareTable() {
    const cols = L.map(d => { const m = window.MarsViewer.metrics(d); let warnings; try { warnings = window.MarsViewer.rasterize(d).warnings; } catch (e) { warnings = ['rasterize failed: ' + e.message]; } return { d, m, v: m.v8, warnings }; });
    const row = (name, f, cls) => `<tr${cls ? ` class="${cls}"` : ''}><td>${name}</td>` + cols.map(c => `<td>${f(c)}</td>`).join('') + '</tr>';
    const list = xs => (xs.length ? xs.map(esc).join(', ') : '<span class="muted">none</span>');
    return `<p class="muted">One column per layout, computed in this page from each layout's data with the viewer's metrics (the same numbers as the side panel). Plan walked and corridor share count only floor links; ladder / lift / drop links count in the graph (closure sets, dead ends) but not as walked floor. Transition lengths: for each plan link whose ends sit in two different rooms, the metres outside any room.</p>` +
      `<table><tr><th></th>${cols.map(c => `<th>${esc(c.d._tab || c.d.revision)}</th>`).join('')}</tr>` +
      row('Revision', c => `${esc(c.d.revision)} <span class="muted">(${esc(c.d._file)})</span>`) +
      row('Footprint', c => `${c.m.footprint[0]} × ${c.m.footprint[1]} m, ${c.m.rooms} rooms`) +
      row('Floor heights', c => c.m.heights.map(h => h.toFixed(1)).join(' / ')) +
      row('Plan walked / corridor share', c => `${Math.round(c.m.walked)} m / ${Math.round(c.m.share * 100)} %`) +
      row('Transition lengths', c => (c.v.span ? `mean ${c.v.span.mean.toFixed(1)} m, min ${c.v.span.min.m.toFixed(1)} m (${esc(c.v.span.min.link)}), ${c.v.span.n} links` : '<span class="muted">no link joins two rooms</span>')) +
      row('Well-facing rooms', c => (c.v.facing.length ? `${c.v.facing.length}: ` : '') + list(c.v.facing)) +
      row('Transition beats', c => { const e = Object.entries(c.v.beats); return e.length ? `${e.reduce((s, [, n]) => s + n, 0)}: ` + e.map(([k, n]) => `${esc(k)}×${n}`).join(' ') : '<span class="muted">none</span>'; }) +
      row('Shortcuts one-way / two-way', c => `${c.v.ways.one} / ${c.v.ways.two}`) +
      row('Instances (ports)', c => `${c.v.instances} (${c.v.ports})`) +
      row('Closure sets valid / total', c => `${c.m.valid} / ${c.m.combos}`) +
      row('Dead ends', c => list(c.m.deadEnds)) +
      row('Cannot render', c => (c.warnings.length ? `<span class="warn">${c.warnings.map(esc).join('<br>')}</span>` : '<span class="muted">none</span>')) +
      row('Thesis', c => (c.d.notes && c.d.notes.thesis ? esc(c.d.notes.thesis) : '<span class="muted">no notes</span>'), 'thesis') +
      `</table><p class="muted">Sources: ${V.meta.files.map(f => `${esc(f.file)} sha256 ${f.sha256.slice(0, 12)}`).join(' · ')}</p>`;
  }

  const params = new URLSearchParams(location.search), want = params.get('tab');
  const start = want === 'compare' ? 'compare' : (want != null ? String(Math.max(0, L.findIndex(d => (d._tab || d.revision) === want || d._file.includes(want)))) : sel.value);
  show(start);
  if (params.get('goview') && start !== 'compare') window.MarsViewerDebug.gotoView(params.get('goview')); // the viewer ran its own ?goview on the first layout
})();
