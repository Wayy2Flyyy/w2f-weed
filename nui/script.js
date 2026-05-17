/* ============================================================
   WEED ROLLING MINIGAME — v2 (Overhaul)
   Phases: 0 Strain → 1 Grind → 2 Roll → 3 Smoke
   ============================================================ */

/* ---- DATA ------------------------------------------------- */
const ALL_STRAINS = [
  {
    id: 'purple_runtz',
    name: 'Purple Runtz',
    img: 'assets/purple_runtz_bud.svg',
    joint: 'assets/purple_runtz.svg',
    thc: 28,
    flavor: 'Sweet, fruity, candy-like',
    rarity: 'Rare',
    rarityClass: 'rarity-rare',
  },
  {
    id: 'exotic',
    name: 'Exotic',
    img: 'assets/exotic_bud.svg',
    joint: 'assets/exotic.svg',
    thc: 32,
    flavor: 'Earthy, pungent, deep',
    rarity: 'Exotic',
    rarityClass: 'rarity-exotic',
  },
  {
    id: 'hybrid',
    name: 'Hybrid',
    img: 'assets/hybrid_bud.svg',
    joint: 'assets/hybrid.svg',
    thc: 24,
    flavor: 'Citrus, pine, balanced',
    rarity: 'Common',
    rarityClass: 'rarity-common',
  },
  {
    id: 'purple_palm_tree_delight',
    name: 'Purple Palm Tree Delight',
    img: 'assets/purple_palm_tree_delight_bud.svg',
    joint: 'assets/purple_palm_tree_delight.svg',
    thc: 26,
    flavor: 'Berry, floral, tropical',
    rarity: 'Uncommon',
    rarityClass: 'rarity-uncommon',
  },
  {
    id: 'skunk',
    name: 'Skunk',
    img: 'assets/skunk_bud.svg',
    joint: 'assets/skunk.svg',
    thc: 22,
    flavor: 'Pungent, diesel, classic',
    rarity: 'Common',
    rarityClass: 'rarity-common',
  },
];

const ROLL_STEPS = [
  { title: 'Open the Booklet',  desc: 'Tap the rolling-papers booklet on the tray.' },
  { title: 'Distribute the Greens', desc: 'Drag the grinded weed onto the paper.' },
  { title: 'Roll It Up', desc: 'Drag the green slider upward to roll the joint.' },
  { title: 'Lick & Seal', desc: 'Click the button to seal it shut.' },
];

const SESSION_KEY = 'lsSmokeSession';

let gameMode = 'practice'; // practice | craft
/** @type {typeof ALL_STRAINS | null} */
let filteredStrains = null;
/** @type {Record<string, { id: string; budCount: number; selectable: boolean; blockedHint?: string }> | null} */
let craftAvailById = null;
/** @type {{ budsPer: number; hasPaper: boolean; openHintNoPaper: string } | null} */
let craftMeta = null;

function readPayloadHasPaper(payload) {
  if (!payload) return true;
  if (payload.hasRollingPaperFlag === 1) return true;
  if (payload.hasRollingPaperFlag === 0) return false;
  const v = payload.hasRollingPaper;
  if (v === true || v === 1) return true;
  if (v === false || v === 0) return false;
  return v !== false;
}

/** Strain row from server — robust against boolean serialization quirks in NUI. */
function strainRowSelectable(row, budsPer) {
  if (!row) return false;
  const need = Number(budsPer) > 0 ? Number(budsPer) : 3;
  if (row.selectableFlag === 1) return true;
  if (row.selectableFlag === 0) return false;
  if (row.selectable === true || row.selectable === 1) return true;
  if (row.selectable === false || row.selectable === 0) return false;
  const n = Number(row.budCount);
  return Number.isFinite(n) && n >= need;
}

function getParentResourceNameSafe() {
  try {
    if (typeof window.GetParentResourceName === 'function')
      return window.GetParentResourceName();
  } catch (_) {}
  return 'w2f-weed';
}

/** FiveM Chromium resolves bundled NUI files at `https://cfx-nui-<resource>/<path-from-resource-root>`. */
function nuiAssetUrl(pathUnderNuiPage) {
  const rel = String(pathUnderNuiPage || '').trim();
  if (!rel || /^https?:\/\//i.test(rel)) return rel;
  const res = String(getParentResourceNameSafe() || '').trim() || 'w2f-weed';
  const clean = rel.replace(/^\/+/, '').replace(/^nui\//, '');
  return `https://cfx-nui-${res}/nui/${clean}`;
}

/** index.html uses relative `assets/…` paths — rewrite so they load in the NUI frame. */
function remapStaticAssets() {
  document.querySelectorAll('img[src^="assets/"]').forEach((el) => {
    const raw = el.getAttribute('src');
    if (raw) el.src = nuiAssetUrl(raw);
  });
}

function postNui(name, data) {
  const body = JSON.stringify(data || {});
  return fetch(`https://${getParentResourceNameSafe()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body,
  })
    .then((r) => r.json())
    .catch(() => ({}));
}

function openRollingUi(payload) {
  gameMode = payload && payload.mode === 'craft' ? 'craft' : 'practice';

  filteredStrains = null;
  craftAvailById = null;
  craftMeta = null;

  if (gameMode === 'craft' && payload) {
    craftAvailById = {};
    craftMeta = {
      budsPer: Number(payload.budsPerJoint) > 0 ? Number(payload.budsPerJoint) : 3,
      hasPaper: readPayloadHasPaper(payload),
      openHintNoPaper: payload.openHintNoPaper || '',
    };
    if (Array.isArray(payload.strains)) {
      payload.strains.forEach((row) => {
        craftAvailById[row.id] = row;
      });
    }
  }

  document.getElementById('app').classList.remove('is-hidden');

  resetGame(false);
  buildStrainGrid();

  if (
    gameMode === 'craft' &&
    craftMeta &&
    craftMeta.openHintNoPaper &&
    craftMeta.hasPaper === false
  ) {
    toast(craftMeta.openHintNoPaper);
  }

  if (gameMode === 'craft' && craftAvailById) {
    const ok = ALL_STRAINS.filter((s) =>
      strainRowSelectable(craftAvailById[s.id], craftMeta.budsPer)
    );
    if (ok.length === 1) selectStrain(ok[0]);
  }
}

function closeRollingUi() {
  document.getElementById('app').classList.add('is-hidden');
  gameMode = 'practice';
  filteredStrains = null;
  craftAvailById = null;
  craftMeta = null;
  resetGame(false);
}

window.addEventListener('message', (event) => {
  const msg = event.data;
  if (!msg || typeof msg !== 'object') return;
  if (msg.action === 'openRolling') openRollingUi(msg);
  else if (msg.action === 'closeRolling') closeRollingUi();
});

/* ---- STATE ------------------------------------------------ */
const G = {
  phase: 0,
  strain: null,

  // Grind
  grindState: 'empty',      // 'empty' | 'loaded' | 'grinding' | 'done'
  grindProgress: 0,
  grindAccum: 0,            // accumulated angular rotation (degrees)
  lastAngle: null,
  particleInterval: null,
  particleAccum: 0,

  // Roll
  rollStep: 0,
  rollDragging: false,
  rollDragStartY: 0,
  rollProgress: 0,
  rollQuality: 0,           // 0..100 — based on smoothness of grind+roll
  pileDragging: false,
  pileGhostX: 0,
  pileGhostY: 0,

  // Timing
  startTime: 0,

  // Session
  session: { rolled: 0, bestTime: null },
};

/* ---- DOM CACHE -------------------------------------------- */
const $ = (id) => document.getElementById(id);

const EL = {
  bgParticles:    $('bg-particles'),
  strainGrid:     $('strain-grid'),
  toastStack:     $('toast-stack'),
  resetBtn:       $('reset-btn'),
  ssRolled:       $('ss-rolled'),

  phaseSelect:    $('phase-select'),
  phaseGrind:     $('phase-grind'),
  phaseRoll:      $('phase-roll'),
  phaseComplete:  $('phase-complete'),

  // Grind
  budCard:        $('bud-card'),
  budImg:         $('bud-img'),
  budName:        $('bud-name'),
  budThc:         $('bud-thc'),
  budRarity:      $('bud-rarity-badge'),
  loadBtn:        $('load-btn'),
  fallingBud:     $('falling-bud'),
  grinderWrap:    $('grinder-wrap'),
  grinderImg:     null, // set in init
  grinderLabel:   $('grinder-label'),
  particleField:  $('particle-field'),
  ringFill:       $('ring-fill'),
  ringPct:        $('ring-pct'),
  grindHint:      $('grind-hint'),
  grindedOut:     $('grinded-out'),
  grindedFill:    $('grinded-fill'),
  grindedAmount:  $('grinded-amount'),
  collectBtn:     $('collect-btn'),

  // Roll
  papersBooklet:  $('papers-booklet'),
  trayWeedPile:   $('tray-weed-pile'),
  pileTag:        $('pile-tag'),
  trayPaper:      $('tray-paper'),
  paperBody:      $('paper-body'),
  paperWeedLayer: $('paper-weed-layer'),
  paperJointResult: $('paper-joint-result'),
  dragGhost:      $('drag-ghost'),
  rollSwipeArea:  $('roll-swipe-area'),
  swipeFill:      $('swipe-fill'),
  swipeThumb:     $('swipe-thumb'),
  swipeTrack:     null, // set after init
  stepList:       $('step-list'),
  rollActionBtn:  $('roll-action-btn'),
  qualityMeter:   $('quality-meter'),
  qmFill:         $('qm-fill'),
  qmVal:          $('qm-val'),

  // Complete
  jointImage:     $('joint-image'),
  completTitle:   $('complete-title'),
  completStrainName: $('complete-strain-name'),
  cstatStrain:    $('cstat-strain'),
  cstatThc:       $('cstat-thc'),
  cstatQuality:   $('cstat-quality'),
  cstatTime:      $('cstat-time'),
  completeBtn:    $('complete-btn'),
};

/* ============================================================
   INIT
   ============================================================ */
function init() {
  EL.grinderImg  = EL.grinderWrap.querySelector('.grinder-img');
  EL.swipeTrack  = document.querySelector('.swipe-track');

  remapStaticAssets();

  buildStrainGrid();
  buildStepList();
  injectSvgGradient();
  loadSession();
  bindGlobalEvents();
  updatePhaseTrack(0);
  setBodyPhase(0);
}

/* ---- SESSION (localStorage) ----------------------------- */
function loadSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (raw) G.session = JSON.parse(raw);
  } catch {}
  EL.ssRolled.textContent = G.session.rolled || 0;
}
function saveSession() {
  try { localStorage.setItem(SESSION_KEY, JSON.stringify(G.session)); } catch {}
  EL.ssRolled.textContent = G.session.rolled || 0;
}

/* ---- GLOBAL EVENT BINDING -------------------------------- */
function bindGlobalEvents() {
  EL.resetBtn.addEventListener('click', () => resetGame(true));

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      e.preventDefault();
      postNui('rollingExit', {});
    }
  });

  // Grinder
  EL.loadBtn.addEventListener('click', loadBud);
  EL.grinderWrap.addEventListener('mousedown', startGrinding);
  EL.grinderWrap.addEventListener('touchstart', startGrinding, { passive: false });
  document.addEventListener('mousemove', onGrindMove);
  document.addEventListener('touchmove', onGrindMove, { passive: true });
  document.addEventListener('mouseup', stopGrinding);
  document.addEventListener('touchend', stopGrinding);
  EL.collectBtn.addEventListener('click', () => goPhase(2));

  // Roll
  EL.papersBooklet.addEventListener('click', onBookletClick);
  EL.trayWeedPile.addEventListener('mousedown', onPileDragStart);
  EL.trayWeedPile.addEventListener('touchstart', onPileDragStart, { passive: false });
  document.addEventListener('mousemove', onPileDragMove);
  document.addEventListener('touchmove', onPileDragMove, { passive: false });
  document.addEventListener('mouseup', onPileDragEnd);
  document.addEventListener('touchend', onPileDragEnd);

  EL.rollSwipeArea.addEventListener('mousedown', onSwipeStart);
  EL.rollSwipeArea.addEventListener('touchstart', onSwipeStart, { passive: false });
  document.addEventListener('mousemove', onSwipeMove);
  document.addEventListener('touchmove', onSwipeMove, { passive: false });
  document.addEventListener('mouseup', onSwipeEnd);
  document.addEventListener('touchend', onSwipeEnd);

  EL.rollActionBtn.addEventListener('click', onRollActionClick);

  EL.completeBtn.addEventListener('click', onCompleteClick);
}

/* ---- SVG GRADIENT (ring) --------------------------------- */
function injectSvgGradient() {
  const svg = document.querySelector('.ring-svg');
  const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
  defs.innerHTML = `
    <linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%"   stop-color="#2e7d32"/>
      <stop offset="100%" stop-color="#81c784"/>
    </linearGradient>`;
  svg.insertBefore(defs, svg.firstChild);
}

/* ---- STRAIN GRID ----------------------------------------- */
function buildStrainGrid() {
  EL.strainGrid.innerHTML = '';
  const list =
    gameMode !== 'practice' && filteredStrains && filteredStrains.length
      ? filteredStrains
      : ALL_STRAINS;
  list.forEach((s) => {
    const budsPer = craftMeta ? craftMeta.budsPer : 3;
    const row = craftAvailById ? craftAvailById[s.id] : null;
    const disabledCraft =
      gameMode === 'craft' && !strainRowSelectable(row, budsPer);
    const paperNote =
      gameMode === 'craft' && craftMeta && !craftMeta.hasPaper ? ' · need rolling papers to finish' : '';
    const stashLine =
      gameMode === 'craft' && craftMeta && row
        ? `<div class="strain-stash">Stock: ${Number(row.budCount) || 0} buds · rolls need ${craftMeta.budsPer}${paperNote}</div>`
        : '';

    const card = document.createElement('div');
    card.className =
      'strain-card' +
      (disabledCraft ? ' strain-card-disabled' : '');
    card.dataset.id = s.id;
    if (disabledCraft && row && row.blockedHint) card.title = row.blockedHint;
    card.innerHTML = `
      <div class="strain-card-img-wrap">
        <img src="${nuiAssetUrl(s.img)}" alt="${s.name}">
      </div>
      <div class="strain-card-name">${s.name}</div>
      ${stashLine}
      <div class="strain-card-thc">THC ${s.thc}%</div>
      <div class="strain-rarity ${s.rarityClass}">${s.rarity}</div>
      <div class="strain-card-flavor">${s.flavor}</div>
    `;
    card.addEventListener('click', () => {
      if (gameMode === 'craft') {
        const r = craftAvailById && craftAvailById[s.id];
        const budsPer = craftMeta ? craftMeta.budsPer : 3;
        if (!strainRowSelectable(r, budsPer)) {
          if (r && r.blockedHint) toast(r.blockedHint);
          else if (craftMeta && craftMeta.openHintNoPaper)
            toast(craftMeta.openHintNoPaper);
          return;
        }
        if (craftMeta && !craftMeta.hasPaper) {
          toast(craftMeta.openHintNoPaper || 'You need rolling papers to collect a joint.');
        }
      }
      selectStrain(s);
    });
    EL.strainGrid.appendChild(card);
  });
}

function selectStrain(s) {
  G.strain = s;
  populateGrindPhase(s);
  goPhase(1);
  toast(`${s.name} selected`);
}

/* ---- STEP LIST ------------------------------------------- */
function buildStepList() {
  EL.stepList.innerHTML = '';
  ROLL_STEPS.forEach((step, i) => {
    const el = document.createElement('div');
    el.className = 'step-item' + (i === 0 ? ' active' : '');
    el.id = `step-${i}`;
    el.innerHTML = `
      <div class="step-num" id="step-num-${i}">${i + 1}</div>
      <div class="step-text">
        <div class="step-title">${step.title}</div>
        <div class="step-desc">${step.desc}</div>
      </div>
    `;
    EL.stepList.appendChild(el);
  });
}

/* ---- PHASE TRANSITIONS ----------------------------------- */
function goPhase(n) {
  const phases = [EL.phaseSelect, EL.phaseGrind, EL.phaseRoll, EL.phaseComplete];
  phases.forEach((p, i) => p.classList.toggle('active', i === n));
  G.phase = n;
  updatePhaseTrack(n);
  setBodyPhase(n);
  if (n === 2) initRollPhase();
  if (n === 3) showCompletePhase();
}

function setBodyPhase(n) {
  document.body.classList.remove('phase-0','phase-1','phase-2','phase-3');
  document.body.classList.add(`phase-${n}`);
}

function updatePhaseTrack(current) {
  for (let i = 0; i <= 3; i++) {
    const step = $(`ps-${i}`);
    const dot  = step.querySelector('.phase-dot');
    step.classList.remove('active', 'done');
    dot.textContent = i < current ? '✓' : i + 1;
    if (i < current)  step.classList.add('done');
    if (i === current) step.classList.add('active');
  }
  document.querySelectorAll('.phase-line').forEach((line, i) => {
    line.classList.toggle('done', i < current);
  });
}

/* ============================================================
   PHASE 1 — GRIND (CIRCULAR ROTATION)
   ============================================================ */
function populateGrindPhase(s) {
  EL.budImg.src      = nuiAssetUrl(s.img);
  EL.fallingBud.src  = nuiAssetUrl(s.img);
  EL.budName.textContent = s.name;
  EL.budThc.textContent  = `THC ${s.thc}%`;
  EL.budRarity.textContent = s.rarity;
  EL.budRarity.className = `bud-rarity-badge ${s.rarityClass}`;

  // Reset state
  G.grindState    = 'empty';
  G.grindProgress = 0;
  G.grindAccum    = 0;
  G.lastAngle     = null;
  clearInterval(G.particleInterval);

  EL.budCard.classList.remove('dropped');
  EL.grinderWrap.className  = 'grinder-wrap';
  EL.grinderImg.style.transform = '';
  EL.grinderLabel.className = 'grinder-label';
  EL.grinderLabel.textContent = 'EMPTY';
  EL.grindHint.textContent  = 'Drop the bud in to begin';
  EL.grindHint.classList.remove('active', 'done');
  EL.fallingBud.classList.remove('fall');
  EL.fallingBud.style.opacity = '0';

  setRingProgress(0);
  EL.grindedOut.classList.remove('has-content');
  EL.grindedFill.style.height = '0%';
  EL.grindedAmount.textContent = '0g';
  EL.collectBtn.classList.add('hidden');
  EL.loadBtn.classList.remove('hidden');
  EL.particleField.innerHTML = '';
}

function loadBud() {
  if (G.grindState !== 'empty') return;

  // Trigger falling animation
  EL.budCard.classList.add('dropped');
  EL.fallingBud.classList.remove('fall');
  void EL.fallingBud.offsetWidth; // restart animation
  EL.fallingBud.classList.add('fall');
  EL.loadBtn.classList.add('hidden');

  setTimeout(() => {
    G.grindState = 'loaded';
    EL.grinderWrap.classList.add('loaded');
    EL.grinderLabel.classList.add('loaded');
    EL.grinderLabel.textContent = 'LOADED';
    EL.grindHint.textContent = 'Spin the grinder by dragging in circles';
    G.startTime = Date.now();
  }, 700);
}

/* Circular rotation — track angle from center */
function getAngleFromCenter(clientX, clientY) {
  const rect = EL.grinderWrap.getBoundingClientRect();
  const cx = rect.left + rect.width / 2;
  const cy = rect.top + rect.height / 2;
  return Math.atan2(clientY - cy, clientX - cx) * (180 / Math.PI);
}

function startGrinding(e) {
  if (G.grindState !== 'loaded' && G.grindState !== 'grinding') return;
  e.preventDefault?.();
  G.grindState = 'grinding';
  EL.grinderWrap.classList.remove('loaded');
  EL.grinderWrap.classList.add('grinding');
  EL.grinderLabel.classList.remove('loaded');
  EL.grinderLabel.classList.add('grinding');
  EL.grinderLabel.textContent = 'GRINDING...';
  EL.grindHint.textContent = 'Keep spinning...';
  EL.grindHint.classList.add('active');

  const pt = e.touches ? e.touches[0] : e;
  G.lastAngle = getAngleFromCenter(pt.clientX, pt.clientY);
}

function onGrindMove(e) {
  if (G.grindState !== 'grinding') return;
  const pt = e.touches ? e.touches[0] : e;
  const angle = getAngleFromCenter(pt.clientX, pt.clientY);

  if (G.lastAngle !== null) {
    let delta = angle - G.lastAngle;
    if (delta > 180)  delta -= 360;
    if (delta < -180) delta += 360;
    // Only count clockwise rotation OR allow both directions (we'll allow both — count abs)
    G.grindAccum += Math.abs(delta);

    // Visually rotate the grinder image (top stays put, image spins)
    const totalRotation = G.grindAccum;
    EL.grinderImg.style.transform = `rotate(${totalRotation}deg)`;

    // Progress: 5 full rotations (1800°) = 100%
    G.grindProgress = Math.min(100, (G.grindAccum / 1800) * 100);
    setRingProgress(G.grindProgress);

    // Update grinded fill
    EL.grindedFill.style.height = G.grindProgress + '%';
    EL.grindedAmount.textContent = (G.grindProgress / 100 * 3.5).toFixed(1) + 'g';
    if (G.grindProgress > 0) EL.grindedOut.classList.add('has-content');

    // Particles based on movement intensity
    G.particleAccum += Math.abs(delta);
    if (G.particleAccum > 30) {
      spawnParticles(2);
      G.particleAccum = 0;
    }

    if (G.grindProgress >= 100) {
      finishGrinding();
    }
  }
  G.lastAngle = angle;
}

function stopGrinding() {
  if (G.grindState !== 'grinding') return;
  G.grindState = 'loaded';
  EL.grinderWrap.classList.remove('grinding');
  EL.grinderWrap.classList.add('loaded');
  EL.grinderLabel.classList.remove('grinding');
  EL.grinderLabel.classList.add('loaded');
  EL.grinderLabel.textContent = 'LOADED';
  EL.grindHint.textContent = 'Keep spinning to grind...';
  G.lastAngle = null;
}

function finishGrinding() {
  G.grindState = 'done';
  EL.grinderWrap.classList.remove('grinding', 'loaded');
  EL.grinderLabel.className = 'grinder-label done';
  EL.grinderLabel.textContent = 'DONE';
  EL.grindHint.textContent = '✓ Perfectly ground!';
  EL.grindHint.classList.remove('active');
  EL.grindHint.classList.add('done');
  spawnParticles(28);

  // Calculate roll quality from grinding speed
  const elapsed = (Date.now() - G.startTime) / 1000;
  // Faster grind = lower base, but anything 4–10s = great
  G.rollQuality = Math.max(40, Math.min(85, 100 - Math.abs(7 - elapsed) * 6));

  setTimeout(() => {
    EL.collectBtn.classList.remove('hidden');
    toast('Grinded perfectly!');
  }, 350);
}

function setRingProgress(pct) {
  const circumference = 326.7;
  EL.ringFill.style.strokeDashoffset = circumference - (pct / 100) * circumference;
  EL.ringPct.textContent = Math.round(pct) + '%';
}

function spawnParticles(count) {
  const cx = 85, cy = 85;
  const colors = ['#4caf50','#8bc34a','#cddc39','#a5d6a7','#2e7d32','#dce775'];
  for (let i = 0; i < count; i++) {
    const p = document.createElement('div');
    p.className = 'particle';
    const angle = Math.random() * Math.PI * 2;
    const dist  = 30 + Math.random() * 70;
    const px = Math.cos(angle) * dist;
    const py = Math.sin(angle) * dist - 15;
    p.style.cssText = `
      left:${cx + Math.random() * 30 - 15}px;
      top:${cy + Math.random() * 30 - 15}px;
      background:${colors[Math.floor(Math.random() * colors.length)]};
      --px:${px}px; --py:${py}px;
    `;
    EL.particleField.appendChild(p);
    setTimeout(() => p.remove(), 700);
  }
}

/* ============================================================
   PHASE 2 — ROLL
   ============================================================ */
function initRollPhase() {
  G.rollStep      = 0;
  G.rollProgress  = 0;
  G.rollDragging  = false;
  G.pileDragging  = false;

  EL.papersBooklet.classList.remove('empty');
  EL.trayWeedPile.classList.remove('visible', 'empty', 'dragging');
  EL.trayPaper.classList.remove('visible', 'rolled');
  EL.rollSwipeArea.classList.add('hidden');
  EL.qualityMeter.classList.remove('active');
  EL.paperBody.classList.remove('drop-target');
  EL.paperBody.style.transform = '';
  EL.paperBody.style.borderRadius = '';
  EL.paperBody.style.background = '';
  EL.paperBody.style.opacity = '';
  EL.paperWeedLayer.style.height = '0%';
  EL.paperJointResult.src = nuiAssetUrl(G.strain.joint);
  EL.pileTag.textContent = 'Drag onto paper';
  setSwipeProgress(0);

  EL.rollActionBtn.disabled = false;
  EL.rollActionBtn.textContent = 'Open the Booklet';
  updateSteps(0);

  // Show the weed pile
  setTimeout(() => EL.trayWeedPile.classList.add('visible'), 400);
}

function updateSteps(current) {
  ROLL_STEPS.forEach((_, i) => {
    const el  = $(`step-${i}`);
    const num = $(`step-num-${i}`);
    el.classList.remove('active', 'done');
    if (i < current)  { el.classList.add('done');   num.textContent = '✓'; }
    if (i === current) { el.classList.add('active'); num.textContent = i + 1; }
  });
}

/* Step 0: click booklet to pull paper */
function onBookletClick() {
  if (G.rollStep !== 0) return;
  EL.papersBooklet.classList.add('empty');
  EL.trayPaper.classList.add('visible');
  toast('Paper laid down');
  setTimeout(() => advanceRollStep(1), 350);
}

/* Step 1: drag pile onto paper */
function onPileDragStart(e) {
  if (G.rollStep !== 1) return;
  if (EL.trayWeedPile.classList.contains('empty')) return;
  e.preventDefault?.();
  G.pileDragging = true;
  EL.trayWeedPile.classList.add('dragging');
  EL.dragGhost.classList.add('active');

  const pt = e.touches ? e.touches[0] : e;
  G.pileGhostX = pt.clientX;
  G.pileGhostY = pt.clientY;
  updateGhostPosition();
}

function onPileDragMove(e) {
  if (!G.pileDragging) return;
  e.preventDefault?.();
  const pt = e.touches ? e.touches[0] : e;
  G.pileGhostX = pt.clientX;
  G.pileGhostY = pt.clientY;
  updateGhostPosition();

  // Check hover over paper
  const paperRect = EL.paperBody.getBoundingClientRect();
  const overPaper =
    pt.clientX >= paperRect.left && pt.clientX <= paperRect.right &&
    pt.clientY >= paperRect.top  && pt.clientY <= paperRect.bottom;
  EL.paperBody.classList.toggle('drop-target', overPaper);
}

function onPileDragEnd(e) {
  if (!G.pileDragging) return;
  G.pileDragging = false;
  EL.trayWeedPile.classList.remove('dragging');
  EL.dragGhost.classList.remove('active');

  const pt = e.changedTouches ? e.changedTouches[0] : e;
  const paperRect = EL.paperBody.getBoundingClientRect();
  const overPaper =
    pt.clientX >= paperRect.left && pt.clientX <= paperRect.right &&
    pt.clientY >= paperRect.top  && pt.clientY <= paperRect.bottom;

  EL.paperBody.classList.remove('drop-target');

  if (overPaper) {
    EL.trayWeedPile.classList.add('empty');
    EL.paperWeedLayer.style.height = '60%';
    toast('Greens distributed!');
    setTimeout(() => advanceRollStep(2), 400);
  } else {
    toast('Drop the weed onto the paper');
  }
}

function updateGhostPosition() {
  EL.dragGhost.style.left = G.pileGhostX + 'px';
  EL.dragGhost.style.top  = G.pileGhostY + 'px';
}

/* Step 2: drag swipe-thumb upward to roll */
function onSwipeStart(e) {
  if (G.rollStep !== 2) return;
  e.preventDefault?.();
  G.rollDragging = true;
  EL.swipeThumb.classList.add('dragging');
  const pt = e.touches ? e.touches[0] : e;
  G.rollDragStartY = pt.clientY;
}

function onSwipeMove(e) {
  if (!G.rollDragging || G.rollStep !== 2) return;
  e.preventDefault?.();
  const pt = e.touches ? e.touches[0] : e;
  const delta = G.rollDragStartY - pt.clientY; // positive = up
  G.rollProgress = Math.max(0, Math.min(100, (delta / 120) * 100));
  setSwipeProgress(G.rollProgress);

  // Paper rolls visually
  const angle = (G.rollProgress / 100) * 75;
  const scaleY = 1 - (G.rollProgress / 100) * 0.55;
  EL.paperBody.style.transform = `rotateX(-${angle}deg) scaleY(${scaleY})`;

  if (G.rollProgress >= 100) {
    G.rollDragging = false;
    EL.swipeThumb.classList.remove('dragging');
    onRollComplete();
  }
}

function onSwipeEnd() {
  if (!G.rollDragging) return;
  G.rollDragging = false;
  EL.swipeThumb.classList.remove('dragging');
}

function setSwipeProgress(pct) {
  EL.swipeFill.style.height  = pct + '%';
  EL.swipeThumb.style.bottom = `calc(${pct}% - 14px)`;
}

function onRollComplete() {
  // Compute final roll quality based on grind quality + roll smoothness
  const finalQuality = Math.min(100, G.rollQuality + 15 + Math.random() * 5);
  G.rollQuality = finalQuality;

  EL.qualityMeter.classList.add('active');
  EL.qmFill.style.width = finalQuality + '%';
  EL.qmVal.textContent = qualityLabel(finalQuality);

  // Transform paper into joint
  EL.trayPaper.classList.add('rolled');

  toast('Joint shaped!');
  setTimeout(() => advanceRollStep(3), 600);
}

/* Step 3: seal */
function onRollActionClick() {
  if (G.rollStep === 0) {
    onBookletClick();
    return;
  }
  if (G.rollStep === 3) {
    EL.rollActionBtn.textContent = 'Sealing...';
    EL.rollActionBtn.disabled = true;
    setTimeout(() => goPhase(3), 600);
  }
}

function advanceRollStep(step) {
  G.rollStep = step;
  updateSteps(step);

  if (step === 1) {
    EL.rollActionBtn.disabled = true;
    EL.rollActionBtn.textContent = 'Drag the Pile';
  }
  if (step === 2) {
    EL.rollSwipeArea.classList.remove('hidden');
    EL.rollActionBtn.disabled = true;
    EL.rollActionBtn.textContent = 'Drag UP to Roll';
  }
  if (step === 3) {
    EL.rollSwipeArea.classList.add('hidden');
    EL.rollActionBtn.disabled = false;
    EL.rollActionBtn.textContent = 'Lick & Seal 👅';
  }
}

function qualityLabel(q) {
  if (q >= 90) return 'Flawless';
  if (q >= 75) return 'Excellent';
  if (q >= 60) return 'Solid';
  if (q >= 45) return 'Decent';
  return 'Rough';
}

function onCompleteClick() {
  if (gameMode === 'craft') {
    const s = G.strain;
    if (!s) return;
    const elapsed = Number((((Date.now() - G.startTime) / 1000).toFixed(1)));
    postNui('rollingComplete', {
      strainId: s.id,
      quality: Math.round(Number(G.rollQuality) || 0),
      seconds: elapsed,
    });
    return;
  }
  resetGame(false);
}

/* ============================================================
   PHASE 3 — COMPLETE
   ============================================================ */
function showCompletePhase() {
  const s = G.strain;
  const elapsed = ((Date.now() - G.startTime) / 1000).toFixed(1);

  EL.jointImage.src = nuiAssetUrl(s.joint);
  EL.completStrainName.textContent = `Premium ${s.name} Pre-Roll`;
  EL.cstatStrain.textContent  = s.name;
  EL.cstatThc.textContent     = s.thc + '%';
  EL.cstatQuality.textContent = qualityLabel(G.rollQuality);
  EL.cstatTime.textContent    = elapsed + 's';

  EL.completeBtn.textContent =
    gameMode === 'craft' ? 'Collect joint' : 'Roll another';

  if (gameMode === 'practice') {
    // Update session
    G.session.rolled = (G.session.rolled || 0) + 1;
    if (!G.session.bestTime || +elapsed < G.session.bestTime) {
      G.session.bestTime = +elapsed;
    }
    saveSession();
  }
}

/* ============================================================
   RESET
   ============================================================ */
function resetGame(toStart) {
  G.grindState = 'empty';
  G.grindProgress = 0;
  G.grindAccum = 0;
  G.lastAngle = null;
  G.rollStep = 0;
  G.rollProgress = 0;
  G.strain = null;
  G.pileDragging = false;
  G.rollDragging = false;
  G.rollQuality = 0;
  clearInterval(G.particleInterval);
  EL.particleField.innerHTML = '';
  EL.dragGhost.classList.remove('active');
  goPhase(0);
  if (toStart) toast('Reset');
}

/* ============================================================
   TOAST
   ============================================================ */
function toast(msg) {
  const t = document.createElement('div');
  t.className = 'toast';
  t.textContent = msg;
  EL.toastStack.appendChild(t);
  setTimeout(() => t.remove(), 2700);
}

/* ============================================================
   BOOT
   ============================================================ */
document.addEventListener('DOMContentLoaded', init);
