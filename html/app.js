const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'uplay';
const $ = (id) => document.getElementById(id);

let state = { current: null, queue: [], history: [], paused: false, position: 0, volume: 50 };
let results = [];
let tab = 'results';
let receivedAt = Date.now();
let lastQuery = '';
let toastTimer = null;
let T = {};
const t = (k) => T[k] || k;

function applyLocale() {
  const canSearch = state.canSearch !== false;
  $('q').placeholder = canSearch ? t('ui_placeholder_search') : t('ui_placeholder_link');
  document.querySelector('[data-tab=results]').firstChild.textContent = t('ui_tab_results');
  document.querySelector('[data-tab=queue]').firstChild.textContent = t('ui_tab_queue') + ' ';
  document.querySelector('[data-tab=history]').firstChild.textContent = t('ui_tab_recent');
}

async function post(name, data) {
  try {
    const r = await fetch(`https://${RES}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    });
    return await r.json();
  } catch (e) {
    return null;
  }
}

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (s) => {
  s = Math.max(0, Math.floor(s || 0));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
};

function toast(msg) {
  const t = $('toast');
  t.textContent = msg;
  t.classList.add('on');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('on'), 3500);
}

// ---------- Íconos ----------
const icoPlus = '<svg viewBox="0 0 24 24" fill="none" stroke="#ededed" stroke-width="2.6"><path d="M12 5v14M5 12h14"/></svg>';
const icoPlay = '<svg viewBox="0 0 24 24" fill="#fff"><path d="M7 4l13 8-13 8z"/></svg>';
const icoX = '<svg viewBox="0 0 24 24" fill="none" stroke="#ededed" stroke-width="2.6"><path d="M6 6l12 12M18 6L6 18"/></svg>';

// ---------- Lista ----------
function rowHtml(item, buttons, extra = '') {
  const playing = state.current && state.current.id === item.id && tab !== 'queue';
  const right = playing
    ? `<div class="bars ${state.paused ? 'paused' : ''}"><i></i><i></i><i></i></div>`
    : `<div class="dur">${item.duration > 0 ? fmt(item.duration) : ''}</div><div class="btns">${buttons}</div>`;
  return `<div class="row ${playing ? 'playing' : ''}" ${extra}>
      <div class="cover" style="background-image:url('${esc(item.thumb)}')"></div>
      <div class="info"><div class="t">${esc(item.title)}</div><div class="a">${esc(item.artist)}${item.by && tab === 'queue' ? ' · ' + esc(item.by) : ''}</div></div>
      ${right}
    </div>`;
}

function renderList() {
  const list = $('list');
  let html = '';

  if (tab === 'results') {
    if (!results.length) {
      html = `<div class="empty">${lastQuery ? t('ui_empty_none') : (state.canSearch !== false ? t('ui_empty_start_search') : t('ui_empty_start_link'))}</div>`;
    } else {
      html = results.map((it, i) => rowHtml(it,
        `<div class="ib" data-act="queue" data-i="${i}" title="${t('ui_add')}">${icoPlus}</div>
         <div class="ib play" data-act="play" data-i="${i}" title="${t('ui_play')}">${icoPlay}</div>`)).join('');
    }
  } else if (tab === 'queue') {
    if (!state.queue.length) {
      html = `<div class="empty">${t('ui_empty_queue')}</div>`;
    } else {
      html = state.queue.map((it, i) => rowHtml(it,
        `<div class="ib" data-act="remove" data-i="${i}" title="${t('ui_remove')}">${icoX}</div>
         <div class="ib play" data-act="playQueued" data-i="${i}" title="${t('ui_play_now')}">${icoPlay}</div>`)).join('');
    }
  } else {
    if (!state.history.length) {
      html = `<div class="empty">${t('ui_empty_recent')}</div>`;
    } else {
      html = state.history.map((it, i) => rowHtml(it,
        `<div class="ib" data-act="hqueue" data-i="${i}" title="${t('ui_add')}">${icoPlus}</div>
         <div class="ib play" data-act="hplay" data-i="${i}" title="${t('ui_play')}">${icoPlay}</div>`)).join('');
    }
  }

  list.innerHTML = html;
  $('queueCount').textContent = state.queue.length ? `(${state.queue.length})` : '';
}

// ---------- Reproduciendo ----------
function currentPos() {
  if (!state.current) return 0;
  if (state.paused) return state.position;
  return state.position + (Date.now() - receivedAt) / 1000;
}

function renderNow() {
  const c = state.current;
  const on = !!c;
  $('bigCover').style.backgroundImage = on ? `url('${c.thumb}')` : '';
  $('bigCover').innerHTML = on ? '' : '<div class="nocover">♪</div>';
  $('nowTitle').textContent = on ? c.title : t('ui_nothing');
  $('nowArtist').textContent = on ? c.artist : t('ui_nothing_sub');
  $('who').innerHTML = on && c.by ? `${esc(t('ui_added_by'))} <b>${esc(c.by)}</b>` : '';
  $('icoPause').style.display = on && !state.paused ? '' : 'none';
  $('icoPlay').style.display = on && !state.paused ? 'none' : '';
  ['playBtn', 'nextBtn', 'prevBtn', 'seekBar'].forEach((id) => $(id).classList.toggle('disabled', !on));
  if (document.activeElement !== $('vol')) $('vol').value = state.volume ?? 50;
  tick();
}

function tick() {
  const c = state.current;
  const dur = c ? c.duration || 0 : 0;
  const pos = Math.min(currentPos(), dur);
  $('tCur').textContent = fmt(pos);
  $('tDur').textContent = dur > 0 ? fmt(dur) : '--:--';
  $('progFill').style.width = dur ? `${(pos / dur) * 100}%` : '0%';
}
setInterval(tick, 500);

function setState(s) {
  if (!s) return;
  state = Object.assign({ queue: [], history: [] }, s);
  receivedAt = Date.now();
  renderNow();
  renderList();
}

// ---------- Acciones ----------
async function action(name, data) {
  const res = await post('action', { action: name, data });
  if (res && res.error) { toast(res.error); return false; }
  if (res && (res.queue || res.current !== undefined)) setState(res);
  return true;
}

$('list').addEventListener('click', (e) => {
  const b = e.target.closest('[data-act]');
  if (!b) return;
  const i = Number(b.dataset.i);
  const act = b.dataset.act;
  if (act === 'play') action('play', { id: results[i].id });
  else if (act === 'queue') action('queue', { id: results[i].id }).then((ok) => ok && toast(t('ui_added')));
  else if (act === 'remove') action('remove', { index: i + 1 });
  else if (act === 'playQueued') action('playQueued', { index: i + 1 });
  else if (act === 'hplay') action('play', { id: state.history[i].id });
  else if (act === 'hqueue') action('queue', { id: state.history[i].id }).then((ok) => ok && toast(t('ui_added')));
});

document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => {
  tab = t.dataset.tab;
  document.querySelectorAll('.tab').forEach((x) => x.classList.toggle('on', x === t));
  renderList();
}));

$('searchForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const q = $('q').value.trim();
  if (q.length < 2) return;
  lastQuery = q;
  $('spinner').classList.add('on');
  const res = await post('search', { q });
  $('spinner').classList.remove('on');
  if (!res || res.error) {
    toast(res ? res.error : '...');
    return;
  }
  results = res.results || [];
  // Si pegaron un link, limpiar el buscador (los nombres se dejan para seguir buscando)
  if (/youtu\.?be|^[\w-]{11}$/i.test(q)) {
    $('q').value = '';
    lastQuery = '';
  }
  tab = 'results';
  document.querySelectorAll('.tab').forEach((x) => x.classList.toggle('on', x.dataset.tab === 'results'));
  renderList();
});

$('playBtn').addEventListener('click', () => action('toggle'));
$('nextBtn').addEventListener('click', () => action('next'));
$('prevBtn').addEventListener('click', () => action('prev'));
$('seekBar').addEventListener('click', (e) => {
  if (!state.current) return;
  const r = e.currentTarget.getBoundingClientRect();
  const pct = Math.min(1, Math.max(0, (e.clientX - r.left) / r.width));
  action('seek', { position: pct * (state.current.duration || 0) });
});
$('vol').addEventListener('change', (e) => action('volume', { volume: Number(e.target.value) }));

function close() { post('close'); }
$('closeBtn').addEventListener('click', close);
document.addEventListener('keyup', (e) => { if (e.key === 'Escape') close(); });

// ---------- Mensajes del juego ----------
window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.action === 'open') {
    if (d.locale) T = d.locale;
    $('app').style.display = '';
    setState(d.state || { queue: [], history: [] });
    applyLocale();
    setTimeout(() => $('q').focus(), 50);
  } else if (d.action === 'close') {
    $('app').style.display = 'none';
    $('q').blur();
  } else if (d.action === 'state') {
    setState(d.state);
  }
});
