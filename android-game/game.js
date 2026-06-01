// Monster Realm: Pal Quest — core game engine
'use strict';

// ─── Constants ───────────────────────────────────────────────────────────────
const W = 400, H = 700;
const TILE = 40;
const MAP_W = 30, MAP_H = 30;

const STATE = { TITLE: 0, CLASS_SELECT: 1, WORLD: 2, BATTLE: 3, DUNGEON: 4, PAL_MENU: 5, SHOP: 6, PAUSE: 7, GAME_OVER: 8 };

const TYPE_COLOR = {
  Fire:'#f4622a', Water:'#3a9bd5', Grass:'#5cb85c', Electric:'#f0d030',
  Rock:'#b8a060', Ground:'#c8a040', Psychic:'#d060c8', Dark:'#504060',
  Ice:'#80c8e8', Ghost:'#8860b8', Flying:'#80a8d0', Dragon:'#5040c0',
  Normal:'#a8a890',
};

const RARITY_COLOR = { Common:'#aaa', Uncommon:'#6af', Rare:'#c6f', Epic:'#f96', Legendary:'#fd0' };

// ─── Monster Definitions (30 species from MonsterData) ───────────────────────
const MONSTERS = [
  { id:'emberpup',   name:'Emberpup',    types:['Fire'],           biomes:['Volcanic','Grassland'],       rarity:'Common',    hp:45,  atk:14, def:9,  spd:16, moves:[{n:'Ember',p:12,t:'Fire'},{n:'Tackle',p:8,t:'Normal'}],  cr:0.15, coin:40  },
  { id:'flameox',    name:'Flameox',     types:['Fire'],           biomes:['Volcanic'],                   rarity:'Uncommon',  hp:80,  atk:22, def:14, spd:12, moves:[{n:'Flamecharge',p:22,t:'Fire'},{n:'Gore',p:18,t:'Normal'}], cr:0.35, coin:120 },
  { id:'cindermaw',  name:'Cindermaw',   types:['Fire','Dark'],    biomes:['Volcanic'],                   rarity:'Rare',      hp:110, atk:30, def:18, spd:14, moves:[{n:'Infernal Bite',p:32,t:'Fire'},{n:'Shadow Lunge',p:24,t:'Dark'}], cr:0.55, coin:340 },
  { id:'aquafin',    name:'Aquafin',     types:['Water'],          biomes:['Shore'],                      rarity:'Common',    hp:48,  atk:12, def:11, spd:18, moves:[{n:'Water Jet',p:12,t:'Water'},{n:'Tail Slap',p:9,t:'Normal'}], cr:0.15, coin:45  },
  { id:'tidewyrm',   name:'Tidewyrm',    types:['Water','Dragon'], biomes:['Shore','Swamp'],              rarity:'Epic',      hp:140, atk:28, def:20, spd:19, moves:[{n:'Hydro Pulse',p:30,t:'Water'},{n:'Dragon Coil',p:26,t:'Dragon'}], cr:0.70, coin:620 },
  { id:'coralix',    name:'Coralix',     types:['Water','Rock'],   biomes:['Shore'],                      rarity:'Uncommon',  hp:72,  atk:15, def:28, spd:9,  moves:[{n:'Shell Bash',p:18,t:'Rock'},{n:'Bubble',p:14,t:'Water'}], cr:0.35, coin:130 },
  { id:'sproutcub',  name:'Sprout Cub',  types:['Grass'],          biomes:['Forest','Grassland'],         rarity:'Common',    hp:46,  atk:11, def:12, spd:14, moves:[{n:'Vine Whip',p:11,t:'Grass'},{n:'Bite',p:8,t:'Normal'}], cr:0.12, coin:35  },
  { id:'verdantusk', name:'Verdantusk',  types:['Grass','Ground'], biomes:['Forest'],                     rarity:'Uncommon',  hp:90,  atk:20, def:22, spd:10, moves:[{n:'Tusk Charge',p:22,t:'Ground'},{n:'Leaf Blade',p:19,t:'Grass'}], cr:0.40, coin:150 },
  { id:'thornvine',  name:'Thornvine',   types:['Grass','Dark'],   biomes:['Forest','Swamp'],             rarity:'Rare',      hp:85,  atk:26, def:14, spd:16, moves:[{n:'Thorn Lash',p:25,t:'Grass'},{n:'Night Creep',p:22,t:'Dark'}], cr:0.55, coin:320 },
  { id:'sparkmouse', name:'Sparkmouse',  types:['Electric'],       biomes:['Grassland','Forest'],         rarity:'Common',    hp:40,  atk:15, def:8,  spd:22, moves:[{n:'Spark',p:12,t:'Electric'},{n:'Quick Bite',p:9,t:'Normal'}], cr:0.18, coin:50  },
  { id:'voltcrest',  name:'Voltcrest',   types:['Electric','Flying'],biomes:['Grassland'],               rarity:'Rare',      hp:95,  atk:28, def:12, spd:24, moves:[{n:'Thunderstrike',p:30,t:'Electric'},{n:'Sky Dive',p:24,t:'Flying'}], cr:0.55, coin:330 },
  { id:'boltfang',   name:'Boltfang',    types:['Electric','Dark'],biomes:['Forest'],                     rarity:'Epic',      hp:120, atk:34, def:18, spd:22, moves:[{n:'Volt Tackle',p:36,t:'Electric'},{n:'Shadow Bite',p:28,t:'Dark'}], cr:0.70, coin:600 },
  { id:'stonelet',   name:'Stonelet',    types:['Rock'],           biomes:['Desert','Volcanic'],          rarity:'Common',    hp:60,  atk:10, def:22, spd:6,  moves:[{n:'Rock Throw',p:14,t:'Rock'},{n:'Tackle',p:8,t:'Normal'}], cr:0.18, coin:55  },
  { id:'cragback',   name:'Cragback',    types:['Rock','Ground'],  biomes:['Desert'],                     rarity:'Uncommon',  hp:100, atk:22, def:30, spd:8,  moves:[{n:'Rockslide',p:24,t:'Rock'},{n:'Quake Stomp',p:22,t:'Ground'}], cr:0.40, coin:160 },
  { id:'boulderion', name:'Boulderion',  types:['Rock'],           biomes:['Volcanic'],                   rarity:'Legendary', hp:220, atk:38, def:48, spd:6,  moves:[{n:'Mountain Slam',p:44,t:'Rock'},{n:'Eruption',p:40,t:'Fire'}], cr:0.90, coin:1800},
  { id:'sandpaw',    name:'Sandpaw',     types:['Ground'],         biomes:['Desert'],                     rarity:'Common',    hp:52,  atk:14, def:12, spd:15, moves:[{n:'Sand Attack',p:10,t:'Ground'},{n:'Claw',p:11,t:'Normal'}], cr:0.18, coin:45  },
  { id:'dusthorn',   name:'Dusthorn',    types:['Ground','Rock'],  biomes:['Desert'],                     rarity:'Rare',      hp:110, atk:26, def:24, spd:12, moves:[{n:'Sand Vortex',p:26,t:'Ground'},{n:'Horn Drill',p:30,t:'Rock'}], cr:0.55, coin:340 },
  { id:'mindling',   name:'Mindling',    types:['Psychic'],        biomes:['Grassland','Forest'],         rarity:'Uncommon',  hp:55,  atk:22, def:10, spd:14, moves:[{n:'Mind Beam',p:20,t:'Psychic'},{n:'Confuse',p:14,t:'Psychic'}], cr:0.40, coin:140 },
  { id:'psybeam',    name:'Psybeam',     types:['Psychic','Flying'],biomes:['Tundra','Grassland'],        rarity:'Epic',      hp:115, atk:32, def:16, spd:21, moves:[{n:'Psystorm',p:34,t:'Psychic'},{n:'Air Cutter',p:24,t:'Flying'}], cr:0.70, coin:640 },
  { id:'shadeling',  name:'Shadeling',   types:['Dark'],           biomes:['Swamp','Forest'],             rarity:'Common',    hp:44,  atk:16, def:9,  spd:17, moves:[{n:'Shadow Nip',p:13,t:'Dark'},{n:'Sneak',p:9,t:'Normal'}], cr:0.20, coin:55  },
  { id:'nightmaul',  name:'Nightmaul',   types:['Dark','Rock'],    biomes:['Swamp'],                      rarity:'Rare',      hp:120, atk:30, def:22, spd:13, moves:[{n:'Crushing Dark',p:30,t:'Dark'},{n:'Rock Maul',p:26,t:'Rock'}], cr:0.55, coin:350 },
  { id:'frostkit',   name:'Frostkit',    types:['Ice'],            biomes:['Tundra'],                     rarity:'Common',    hp:50,  atk:12, def:11, spd:15, moves:[{n:'Icy Breath',p:12,t:'Ice'},{n:'Pounce',p:10,t:'Normal'}], cr:0.18, coin:50  },
  { id:'glacierion', name:'Glacierion',  types:['Ice','Rock'],     biomes:['Tundra'],                     rarity:'Legendary', hp:200, atk:36, def:42, spd:10, moves:[{n:'Avalanche',p:42,t:'Ice'},{n:'Glacier Slam',p:38,t:'Rock'}], cr:0.90, coin:1700},
  { id:'phantlet',   name:'Phantlet',    types:['Ghost'],          biomes:['Swamp','Forest'],             rarity:'Uncommon',  hp:55,  atk:18, def:10, spd:16, moves:[{n:'Spirit Touch',p:18,t:'Ghost'},{n:'Haunt',p:14,t:'Ghost'}], cr:0.45, coin:150 },
  { id:'wispmaw',    name:'Wispmaw',     types:['Ghost','Fire'],   biomes:['Swamp','Volcanic'],           rarity:'Rare',      hp:95,  atk:28, def:14, spd:18, moves:[{n:'Hexflame',p:28,t:'Ghost'},{n:'Cinder Curse',p:24,t:'Fire'}], cr:0.60, coin:380 },
  { id:'pebbletoad', name:'Pebbletoad',  types:['Rock','Water'],   biomes:['Shore','Swamp'],              rarity:'Common',    hp:58,  atk:13, def:18, spd:10, moves:[{n:'Pebble Toss',p:14,t:'Rock'},{n:'Water Splash',p:10,t:'Water'}], cr:0.20, coin:55  },
  { id:'wingnip',    name:'Wingnip',     types:['Flying'],         biomes:['Grassland','Forest'],         rarity:'Common',    hp:42,  atk:13, def:9,  spd:22, moves:[{n:'Wing Jab',p:12,t:'Flying'},{n:'Peck',p:10,t:'Normal'}], cr:0.18, coin:45  },
  { id:'skytalon',   name:'Skytalon',    types:['Flying','Fire'],  biomes:['Volcanic','Grassland'],       rarity:'Epic',      hp:130, atk:32, def:16, spd:26, moves:[{n:'Firestorm Dive',p:36,t:'Fire'},{n:'Talon Rake',p:28,t:'Flying'}], cr:0.72, coin:680 },
  { id:'rootling',   name:'Rootling',    types:['Grass','Ground'], biomes:['Forest','Swamp'],             rarity:'Uncommon',  hp:75,  atk:17, def:22, spd:8,  moves:[{n:'Root Snare',p:18,t:'Grass'},{n:'Mud Slap',p:14,t:'Ground'}], cr:0.35, coin:120 },
  { id:'dragonspawn',name:'Dragonspawn',types:['Dragon'],         biomes:['Volcanic','Tundra'],           rarity:'Legendary', hp:240, atk:42, def:34, spd:20, moves:[{n:'Dragonfire',p:46,t:'Dragon'},{n:'Wyrm Roar',p:38,t:'Dragon'}], cr:0.92, coin:2200},
];

// ─── Class Definitions ────────────────────────────────────────────────────────
const CLASSES = [
  {
    id:'warrior', name:'Warrior', color:'#e8503a', icon:'⚔️',
    desc:'High defense, close-range strikes.',
    baseHP:120, baseAtk:18, baseDef:16, baseMag:6, baseSpd:10,
    skills:[
      { name:'Slash',      mp:0,  power:22, type:'Normal',  range:'melee', cd:0 },
      { name:'Shield Bash',mp:15, power:18, type:'Normal',  range:'melee', cd:3, stun:1 },
      { name:'Warcry',     mp:25, power:0,  type:'Normal',  range:'self',  cd:5, buffAtk:6, dur:3 },
      { name:'Whirlwind',  mp:30, power:30, type:'Normal',  range:'all',   cd:6 },
    ]
  },
  {
    id:'mage', name:'Mage', color:'#6a5acd', icon:'🔮',
    desc:'Powerful spells, lower defense.',
    baseHP:80, baseAtk:10, baseDef:8, baseMag:26, baseSpd:12,
    skills:[
      { name:'Arcane Bolt', mp:0,  power:20, type:'Psychic', range:'single', cd:0 },
      { name:'Fireball',    mp:20, power:35, type:'Fire',    range:'single', cd:3 },
      { name:'Blizzard',    mp:30, power:28, type:'Ice',     range:'all',    cd:5 },
      { name:'Thunder',     mp:35, power:42, type:'Electric',range:'single', cd:7 },
    ]
  },
  {
    id:'ranger', name:'Ranger', color:'#4caf50', icon:'🏹',
    desc:'Fast attacks, status effects.',
    baseHP:95, baseAtk:16, baseDef:12, baseMag:10, baseSpd:20,
    skills:[
      { name:'Quick Shot',  mp:0,  power:16, type:'Normal',  range:'single', cd:0 },
      { name:'Poison Arrow',mp:15, power:14, type:'Grass',   range:'single', cd:3, poison:3 },
      { name:'Multishot',   mp:25, power:20, type:'Flying',  range:'all',    cd:5 },
      { name:'Eagle Eye',   mp:30, power:50, type:'Normal',  range:'single', cd:8, crit:1 },
    ]
  },
];

// ─── Items / Equipment ────────────────────────────────────────────────────────
const ITEMS = [
  { id:'heal_sm',  name:'Small Potion', type:'consumable', effect:'hp', val:30,  cost:50  },
  { id:'heal_md',  name:'Mega Potion',  type:'consumable', effect:'hp', val:80,  cost:120 },
  { id:'trap_sm',  name:'Basic Trap',   type:'trap',       cr:0.4,      cost:80  },
  { id:'trap_md',  name:'Super Trap',   type:'trap',       cr:0.65,     cost:200 },
  { id:'trap_lg',  name:'Legend Trap',  type:'trap',       cr:0.85,     cost:500 },
  { id:'sword1',   name:'Iron Sword',   type:'weapon',     atk:8,       cost:200 },
  { id:'sword2',   name:'Steel Sword',  type:'weapon',     atk:16,      cost:500 },
  { id:'staff1',   name:'Oak Staff',    type:'weapon',     mag:10,      cost:200 },
  { id:'staff2',   name:'Crystal Staff',type:'weapon',     mag:20,      cost:500 },
  { id:'bow1',     name:'Shortbow',     type:'weapon',     atk:6,spd:4, cost:200 },
  { id:'bow2',     name:'Longbow',      type:'weapon',     atk:14,spd:6,cost:500 },
  { id:'armor1',   name:'Leather Armor',type:'armor',      def:10,      cost:200 },
  { id:'armor2',   name:'Chain Armor',  type:'armor',      def:22,      cost:500 },
  { id:'mp_pot',   name:'Ether',        type:'consumable', effect:'mp', val:40,  cost:90  },
];

// ─── Biome Map Layout ─────────────────────────────────────────────────────────
const BIOMES = [
  { id:'Grassland', color:'#5d9e4f', dark:'#3d7a30', label:'Grassland', enc:0.12 },
  { id:'Forest',    color:'#2d6b2d', dark:'#1a4a1a', label:'Forest',    enc:0.18 },
  { id:'Desert',    color:'#c8a840', dark:'#a07828', label:'Desert',    enc:0.15 },
  { id:'Shore',     color:'#4aa8d8', dark:'#2880b8', label:'Shore',     enc:0.10 },
  { id:'Volcanic',  color:'#8b2010', dark:'#5a1008', label:'Volcanic',  enc:0.20 },
  { id:'Swamp',     color:'#486040', dark:'#304030', label:'Swamp',     enc:0.22 },
  { id:'Tundra',    color:'#d0e8f8', dark:'#a0c0d8', label:'Tundra',    enc:0.16 },
];

// ─── Dungeon Definitions ──────────────────────────────────────────────────────
const DUNGEONS = [
  { name:'Flame Cavern',    biome:'Volcanic', floors:3, baseLevel:5,  reward:{ coin:500,  xp:300  } },
  { name:'Tidal Grotto',    biome:'Shore',    floors:4, baseLevel:10, reward:{ coin:900,  xp:600  } },
  { name:'Shadow Depths',   biome:'Swamp',    floors:5, baseLevel:15, reward:{ coin:1500, xp:1200 } },
  { name:'Frozen Pinnacle', biome:'Tundra',   floors:5, baseLevel:20, reward:{ coin:2200, xp:2000 } },
  { name:'Dragon Lair',     biome:'Volcanic', floors:6, baseLevel:28, reward:{ coin:4000, xp:5000 } },
];

// ─── Procedural Map Generator ─────────────────────────────────────────────────
function generateMap() {
  const map = [];
  // Seed biome regions
  const seeds = [];
  for (const b of BIOMES) {
    seeds.push({ biome: b.id, x: Math.random() * MAP_W | 0, y: Math.random() * MAP_H | 0 });
    seeds.push({ biome: b.id, x: Math.random() * MAP_W | 0, y: Math.random() * MAP_H | 0 });
  }
  for (let y = 0; y < MAP_H; y++) {
    map[y] = [];
    for (let x = 0; x < MAP_W; x++) {
      let best = Infinity, bestB = 'Grassland';
      for (const s of seeds) {
        const d = (x - s.x) ** 2 + (y - s.y) ** 2;
        if (d < best) { best = d; bestB = s.biome; }
      }
      map[y][x] = { biome: bestB, walkable: true };
    }
  }
  // Shore: edges become water (not walkable)
  for (let y = 0; y < MAP_H; y++) {
    for (let x = 0; x < MAP_W; x++) {
      if (map[y][x].biome === 'Shore' && Math.random() < 0.3) map[y][x].walkable = false;
    }
  }
  // Place dungeons
  const dungeonTiles = [];
  for (let i = 0; i < DUNGEONS.length; i++) {
    let placed = false;
    for (let tries = 0; tries < 200 && !placed; tries++) {
      const x = 1 + Math.random() * (MAP_W - 2) | 0;
      const y = 1 + Math.random() * (MAP_H - 2) | 0;
      if (map[y][x].walkable && !map[y][x].dungeon) {
        map[y][x].dungeon = i;
        dungeonTiles.push({ x, y, idx: i });
        placed = true;
      }
    }
  }
  // Place shop
  let shopPlaced = false;
  for (let tries = 0; tries < 200 && !shopPlaced; tries++) {
    const x = MAP_W / 2 + (Math.random() * 6 - 3) | 0;
    const y = MAP_H / 2 + (Math.random() * 6 - 3) | 0;
    if (map[y][x].walkable && !map[y][x].dungeon) {
      map[y][x].shop = true;
      shopPlaced = true;
    }
  }
  return { map, dungeonTiles };
}

// ─── Utility ──────────────────────────────────────────────────────────────────
function rng(min, max) { return min + Math.random() * (max - min) | 0; }
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

function monsterInstance(def, level) {
  const scale = 1 + (level - 1) * 0.12;
  return {
    def,
    level,
    maxHp: Math.round(def.hp * scale),
    hp:    Math.round(def.hp * scale),
    atk:   Math.round(def.atk * scale),
    def_:  Math.round(def.def * scale),
    spd:   def.spd,
    captured: false,
    xp: Math.round(20 * scale),
    coin: Math.round(def.coin * 0.3),
  };
}

function typeEffectiveness(atkType, defTypes) {
  const chart = {
    Fire:    { Grass:2, Ice:2, Rock:0.5, Water:0.5, Fire:0.5, Dragon:0.5 },
    Water:   { Fire:2, Rock:2, Ground:2, Grass:0.5, Water:0.5, Dragon:0.5 },
    Grass:   { Water:2, Rock:2, Ground:2, Fire:0.5, Grass:0.5, Flying:0.5, Dragon:0.5 },
    Electric:{ Water:2, Flying:2, Ground:0, Electric:0.5, Dragon:0.5 },
    Ice:     { Grass:2, Ground:2, Flying:2, Dragon:2, Fire:0.5, Water:0.5, Ice:0.5 },
    Rock:    { Fire:2, Ice:2, Flying:2, Bug:2, Ground:0.5, Fighting:0.5, Steel:0.5 },
    Ground:  { Fire:2, Electric:2, Rock:2, Grass:0.5, Flying:0 },
    Psychic: { Fighting:2, Poison:2, Psychic:0.5, Dark:0 },
    Ghost:   { Ghost:2, Psychic:2, Normal:0, Dark:0.5 },
    Dragon:  { Dragon:2, Steel:0.5, Fairy:0 },
    Dark:    { Ghost:2, Psychic:2, Dark:0.5, Fighting:0.5, Fairy:0.5 },
    Flying:  { Grass:2, Fighting:2, Ground:1, Electric:0.5, Rock:0.5, Steel:0.5 },
    Normal:  { Rock:0.5, Ghost:0, Steel:0.5 },
  };
  let mult = 1;
  const row = chart[atkType] || {};
  for (const dt of defTypes) mult *= (row[dt] ?? 1);
  return mult;
}

function calcDamage(atk, power, def, typeMult) {
  const base = Math.max(1, (atk + power) - def * 0.5);
  const crit = Math.random() < 0.1 ? 1.5 : 1;
  return Math.round(base * typeMult * crit * (0.85 + Math.random() * 0.3));
}

// ─── Player State ─────────────────────────────────────────────────────────────
function newPlayer(cls) {
  return {
    cls,
    name: cls.name,
    level: 1, xp: 0, xpNeeded: 100,
    maxHp: cls.baseHP, hp: cls.baseHP,
    maxMp: 80, mp: 80,
    atk: cls.baseAtk, def: cls.baseDef, mag: cls.baseMag, spd: cls.baseSpd,
    equip: { weapon: null, armor: null },
    pals: [],    // captured monsters (max 6)
    activePal: null,
    inventory: [
      { ...ITEMS[0], qty: 3 },  // 3 small potions to start
      { ...ITEMS[2], qty: 2 },  // 2 basic traps
    ],
    coins: 200,
    mapX: MAP_W / 2 | 0,
    mapY: MAP_H / 2 | 0,
    dungeonsCleared: [],
  };
}

function gainXP(player, amount) {
  player.xp += amount;
  const msgs = [];
  while (player.xp >= player.xpNeeded) {
    player.xp -= player.xpNeeded;
    player.level++;
    player.xpNeeded = Math.round(player.xpNeeded * 1.35);
    player.maxHp += 12; player.hp = player.maxHp;
    player.maxMp += 8;  player.mp = player.maxMp;
    player.atk += 2; player.def += 2; player.mag += 2; player.spd += 1;
    msgs.push(`Level Up! → Lv.${player.level}`);
  }
  return msgs;
}

// ─── Game Object ─────────────────────────────────────────────────────────────
class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.state = STATE.TITLE;
    this.player = null;
    this.worldMap = null;
    this.cam = { x: 0, y: 0 };
    this.battle = null;
    this.dungeon = null;
    this.shopOpen = false;
    this.messages = [];
    this.msgTimer = 0;
    this.input = { up:false, down:false, left:false, right:false, action:false };
    this.moveTimer = 0;
    this.selectedClass = 0;
    this.selectedSkill = 0;
    this.palMenuPage = 0;
    this.frame = 0;
    this.lastTime = 0;
    this.particles = [];
    this._bindInput();
    this._loop(0);
  }

  // ─── Input ─────────────────────────────────────────────────────────────────
  _bindInput() {
    const c = this.canvas;
    c.addEventListener('touchstart', e => { e.preventDefault(); this._onTouch(e.touches); }, { passive: false });
    c.addEventListener('touchmove',  e => { e.preventDefault(); this._onTouch(e.touches); }, { passive: false });
    c.addEventListener('touchend',   e => { e.preventDefault(); this._clearTouch(e.touches); }, { passive: false });
    c.addEventListener('mousedown',  e => { this._onMouse(e, true);  });
    c.addEventListener('mouseup',    e => { this._onMouse(e, false); });
    c.addEventListener('mousemove',  e => { if (this._mouseDown) this._onMouse(e, true); });
    this._mouseDown = false;
    this._touches = {};
  }

  _getPos(e) {
    const r = this.canvas.getBoundingClientRect();
    const scaleX = W / r.width, scaleY = H / r.height;
    return { x: (e.clientX - r.left) * scaleX, y: (e.clientY - r.top) * scaleY };
  }

  _onMouse(e, down) {
    this._mouseDown = down;
    const p = this._getPos(e);
    if (down) this._tap(p.x, p.y);
    this._updateDpad(p, down);
  }

  _onTouch(touches) {
    for (const t of touches) {
      const p = this._getPos(t);
      this._updateDpad(p, true);
    }
  }

  _clearTouch() {
    this.input.up = this.input.down = this.input.left = this.input.right = false;
  }

  _updateDpad(p, active) {
    // D-pad zone: bottom-left quadrant
    const cx = 80, cy = H - 90, r = 55;
    const dx = p.x - cx, dy = p.y - cy;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist < r + 20 && active) {
      this.input.up    = dy < -15;
      this.input.down  = dy > 15;
      this.input.left  = dx < -15;
      this.input.right = dx > 15;
    } else if (!active && Math.sqrt((p.x-cx)**2+(p.y-cy)**2) < r+20) {
      this.input.up = this.input.down = this.input.left = this.input.right = false;
    }
  }

  _tap(x, y) {
    if (this.state === STATE.TITLE) { this.state = STATE.CLASS_SELECT; return; }
    if (this.state === STATE.CLASS_SELECT) { this._handleClassSelectTap(x, y); return; }
    if (this.state === STATE.BATTLE)       { this._handleBattleTap(x, y);       return; }
    if (this.state === STATE.PAL_MENU)     { this._handlePalMenuTap(x, y);      return; }
    if (this.state === STATE.SHOP)         { this._handleShopTap(x, y);         return; }
    if (this.state === STATE.DUNGEON)      { this._handleBattleTap(x, y);       return; }
    if (this.state === STATE.GAME_OVER)    { this._restart();                    return; }
    // World buttons
    if (this.state === STATE.WORLD) {
      // Pal button (bottom right)
      if (x > W - 90 && y > H - 110 && y < H - 60) { this.state = STATE.PAL_MENU; return; }
      // Interact / dungeon enter
      if (x > 140 && x < 260 && y > H - 110 && y < H - 60) { this._tryInteract(); return; }
    }
  }

  _handleClassSelectTap(x, y) {
    // 3 class cards
    for (let i = 0; i < CLASSES.length; i++) {
      const cx_ = 40 + i * 110, cy_ = 200, cw = 100, ch = 200;
      if (x >= cx_ && x <= cx_ + cw && y >= cy_ && y <= cy_ + ch) {
        this.selectedClass = i;
      }
    }
    // Confirm
    if (x > 100 && x < 300 && y > 450 && y < 510) {
      this._startGame(CLASSES[this.selectedClass]);
    }
  }

  _handleBattleTap(x, y) {
    if (!this.battle || this.battle.animating) return;
    const b = this.battle;
    // Skill buttons (4 across bottom)
    if (y > H - 160 && y < H - 80) {
      const skills = b.isDungeon ? this.player.cls.skills : this.player.cls.skills;
      for (let i = 0; i < 4; i++) {
        const bx = 10 + i * 95, by = H - 160, bw = 88, bh = 68;
        if (x >= bx && x <= bx + bw && y >= by && y <= by + bh) {
          this._useSkill(i);
          return;
        }
      }
    }
    // Use item button
    if (x > 10 && x < 130 && y > H - 75 && y < H - 20) { this._battleUseItem(); return; }
    // Pal attack button
    if (x > 140 && x < 260 && y > H - 75 && y < H - 20) { this._palAttack(); return; }
    // Flee
    if (x > 270 && x < 390 && y > H - 75 && y < H - 20) { this._flee(); return; }
  }

  _handlePalMenuTap(x, y) {
    // Back
    if (x < 80 && y < 60) { this.state = STATE.WORLD; return; }
    // Set active pal
    const pals = this.player.pals;
    for (let i = 0; i < pals.length; i++) {
      const py_ = 80 + i * 90;
      if (y >= py_ && y <= py_ + 80 && x > 10 && x < W - 10) {
        this.player.activePal = i;
        this._msg(`${pals[i].def.name} is now your active Pal!`);
      }
    }
  }

  _handleShopTap(x, y) {
    if (x < 80 && y < 60) { this.state = STATE.WORLD; return; }
    const shopItems = ITEMS.slice(0, 13);
    for (let i = 0; i < shopItems.length; i++) {
      const row = i % 7, col = Math.floor(i / 7);
      const ix = 10 + col * 195, iy = 80 + row * 75;
      if (x >= ix && x <= ix + 185 && y >= iy && y <= iy + 65) {
        this._buyItem(shopItems[i]);
        return;
      }
    }
  }

  // ─── Game Start ────────────────────────────────────────────────────────────
  _startGame(cls) {
    this.player = newPlayer(cls);
    const { map } = generateMap();
    this.worldMap = map;
    this._centerCam();
    this.state = STATE.WORLD;
    this._msg(`Welcome, ${cls.name}! Explore the world, capture Pals, raid dungeons!`);
    this._saveGame();
  }

  _restart() {
    this.state = STATE.TITLE;
    this.player = null;
  }

  // ─── World Update ──────────────────────────────────────────────────────────
  _updateWorld(dt) {
    this.moveTimer += dt;
    if (this.moveTimer < 220) return;
    this.moveTimer = 0;
    const p = this.player;
    let nx = p.mapX, ny = p.mapY;
    if (this.input.up)    ny--;
    if (this.input.down)  ny++;
    if (this.input.left)  nx--;
    if (this.input.right) nx++;
    nx = clamp(nx, 0, MAP_W - 1);
    ny = clamp(ny, 0, MAP_H - 1);
    if (nx === p.mapX && ny === p.mapY) return;
    const tile = this.worldMap[ny][nx];
    if (!tile.walkable) return;
    p.mapX = nx; p.mapY = ny;
    this._centerCam();
    // Random encounter
    const biome = BIOMES.find(b => b.id === tile.biome);
    if (biome && Math.random() < biome.enc) {
      this._startBattle(tile.biome);
    }
  }

  _centerCam() {
    const p = this.player;
    this.cam.x = clamp(p.mapX * TILE - W / 2 + TILE / 2, 0, MAP_W * TILE - W);
    this.cam.y = clamp(p.mapY * TILE - H * 0.45 + TILE / 2, 0, MAP_H * TILE - H);
  }

  _tryInteract() {
    const p = this.player;
    const tile = this.worldMap[p.mapY][p.mapX];
    if (tile.dungeon !== undefined) { this._startDungeon(tile.dungeon); return; }
    if (tile.shop) { this.state = STATE.SHOP; return; }
    // Check adjacent tiles
    const dirs = [{dx:0,dy:-1},{dx:0,dy:1},{dx:-1,dy:0},{dx:1,dy:0}];
    for (const d of dirs) {
      const nx = p.mapX + d.dx, ny = p.mapY + d.dy;
      if (nx < 0 || nx >= MAP_W || ny < 0 || ny >= MAP_H) continue;
      const t = this.worldMap[ny][nx];
      if (t.dungeon !== undefined) { this._startDungeon(t.dungeon); return; }
      if (t.shop) { this.state = STATE.SHOP; return; }
    }
    this._msg('Nothing to interact with here.');
  }

  // ─── Battle ────────────────────────────────────────────────────────────────
  _startBattle(biome) {
    const eligible = MONSTERS.filter(m => m.biomes.includes(biome));
    const def = eligible[rng(0, eligible.length)];
    const level = clamp(this.player.level + rng(-2, 3), 1, 50);
    const enemy = monsterInstance(def, level);
    this.battle = {
      enemy, isDungeon: false, animating: false,
      turn: 'player', log: [`A wild ${def.name} appeared! (Lv.${level})`],
      skillCDs: [0, 0, 0, 0],
      result: null,
      shake: 0, flash: null, bgBiome: biome,
    };
    this.state = STATE.BATTLE;
  }

  _startDungeon(idx) {
    const dg = DUNGEONS[idx];
    if (this.player.dungeonsCleared.includes(idx)) {
      this._msg(`${dg.name} already cleared!`); return;
    }
    const floor = 1;
    const level = dg.baseLevel + rng(0, 5);
    const eligible = MONSTERS.filter(m => m.biomes.includes(dg.biome));
    const def = eligible[rng(0, eligible.length)];
    const enemy = monsterInstance(def, level);
    // Boss on last floor is stronger
    this.dungeon = { def: dg, idx, floor, totalFloors: dg.floors };
    this.battle = {
      enemy, isDungeon: true, animating: false,
      turn: 'player', log: [`${dg.name} — Floor ${floor}/${dg.floors}`, `${def.name} Lv.${level} blocks the way!`],
      skillCDs: [0, 0, 0, 0],
      result: null, shake: 0, flash: null, bgBiome: dg.biome,
    };
    this.state = STATE.DUNGEON;
  }

  _useSkill(idx) {
    const b = this.battle, p = this.player;
    const skill = p.cls.skills[idx];
    if (!skill) return;
    if (b.skillCDs[idx] > 0) { this._msg(`${skill.name} on cooldown (${b.skillCDs[idx]} turns)`); return; }
    if (p.mp < skill.mp) { this._msg(`Not enough MP!`); return; }
    p.mp -= skill.mp;
    b.skillCDs[idx] = skill.cd;
    b.skillCDs = b.skillCDs.map((cd, i) => i === idx ? skill.cd : Math.max(0, cd - 1));

    let dmg = 0;
    const log = [`You used ${skill.name}!`];
    if (skill.power > 0) {
      const eff = skill.range === 'all' ? 1 : typeEffectiveness(skill.type, b.enemy.def.types);
      const atkStat = p.cls.id === 'mage' ? p.mag : p.atk;
      dmg = calcDamage(atkStat, skill.power, b.enemy.def_, eff);
      if (skill.crit) dmg = Math.round(dmg * 1.8);
      b.enemy.hp = Math.max(0, b.enemy.hp - dmg);
      log.push(`Dealt ${dmg} dmg${eff > 1 ? ' (super effective!)' : eff < 1 ? ' (not very effective)' : ''}!`);
    }
    if (skill.buffAtk) { p.atk += skill.buffAtk; log.push(`ATK +${skill.buffAtk}!`); }
    if (skill.poison)  { b.enemy.poisonTurns = skill.poison; log.push('Enemy poisoned!'); }
    if (skill.stun)    { b.enemy.stun = true; log.push('Enemy stunned!'); }
    b.flash = '#fff'; b.shake = 8;
    this._addParticles(W / 2, 260, TYPE_COLOR[skill.type] || '#fff', 18);
    b.log = log;

    if (b.enemy.hp <= 0) { this._battleWin(); return; }
    setTimeout(() => this._enemyTurn(), 600);
  }

  _palAttack() {
    const b = this.battle, p = this.player;
    if (p.activePal === null || !p.pals[p.activePal]) { this._msg('No active Pal!'); return; }
    const pal = p.pals[p.activePal];
    const move = pal.def.moves[rng(0, pal.def.moves.length)];
    const eff = typeEffectiveness(move.t, b.enemy.def.types);
    const dmg = calcDamage(pal.atk, move.p, b.enemy.def_, eff);
    b.enemy.hp = Math.max(0, b.enemy.hp - dmg);
    b.log = [`${pal.def.name} used ${move.n}!`, `Dealt ${dmg} dmg!`];
    b.flash = TYPE_COLOR[move.t];
    this._addParticles(W / 2, 260, TYPE_COLOR[move.t] || '#fff', 12);
    if (b.enemy.hp <= 0) { this._battleWin(); return; }
    setTimeout(() => this._enemyTurn(), 600);
  }

  _flee() {
    if (this.battle.isDungeon) { this._msg("Can't flee from a dungeon!"); return; }
    if (Math.random() < 0.6) {
      this.battle = null; this.state = STATE.WORLD;
      this._msg('Got away safely!');
    } else {
      this.battle.log = ['Failed to flee!'];
      this._enemyTurn();
    }
  }

  _battleUseItem() {
    const b = this.battle, p = this.player;
    // Find first usable item
    const healIdx = p.inventory.findIndex(i => i.type === 'consumable');
    const trapIdx = p.inventory.findIndex(i => i.type === 'trap');
    if (healIdx >= 0) {
      const item = p.inventory[healIdx];
      if (item.effect === 'hp') { p.hp = Math.min(p.maxHp, p.hp + item.val); b.log = [`Used ${item.name}! HP +${item.val}`]; }
      if (item.effect === 'mp') { p.mp = Math.min(p.maxMp, p.mp + item.val); b.log = [`Used ${item.name}! MP +${item.val}`]; }
      item.qty--;
      if (item.qty <= 0) p.inventory.splice(healIdx, 1);
      setTimeout(() => this._enemyTurn(), 600);
    } else if (trapIdx >= 0) {
      this._useTrap(trapIdx);
    } else {
      this._msg('No items!');
    }
  }

  _useTrap(idx) {
    const b = this.battle, p = this.player;
    if (b.isDungeon) { this._msg("Can't capture dungeon monsters!"); return; }
    const trap = p.inventory[idx];
    const hpRatio = b.enemy.hp / b.enemy.maxHp;
    const chance = trap.cr * (1 - b.enemy.def.cr) * (1.5 - hpRatio);
    if (Math.random() < chance) {
      b.enemy.captured = true;
      b.log = [`Captured ${b.enemy.def.name}!`];
      if (p.pals.length < 6) {
        p.pals.push(b.enemy);
        this._msg(`${b.enemy.def.name} joined your Pal team!`);
      } else {
        this._msg(`Pal storage full! ${b.enemy.def.name} released.`);
      }
      trap.qty--;
      if (trap.qty <= 0) p.inventory.splice(idx, 1);
      setTimeout(() => { this.battle = null; this.state = STATE.WORLD; }, 800);
    } else {
      b.log = [`${b.enemy.def.name} broke free!`];
      trap.qty--;
      if (trap.qty <= 0) p.inventory.splice(idx, 1);
      setTimeout(() => this._enemyTurn(), 600);
    }
  }

  _enemyTurn() {
    const b = this.battle, p = this.player;
    if (!b || b.result) return;

    // Poison tick
    if (b.enemy.poisonTurns > 0) {
      const pdmg = Math.round(b.enemy.maxHp * 0.08);
      b.enemy.hp = Math.max(0, b.enemy.hp - pdmg);
      b.enemy.poisonTurns--;
      if (b.enemy.hp <= 0) { this._battleWin(); return; }
    }

    if (b.enemy.stun) { b.enemy.stun = false; b.log = ['Enemy is stunned!']; return; }

    const move = b.enemy.def.moves[rng(0, b.enemy.def.moves.length)];
    const dmg = calcDamage(b.enemy.atk, move.p, p.def, 1);
    p.hp = Math.max(0, p.hp - dmg);
    b.log = [`${b.enemy.def.name} used ${move.n}! You took ${dmg} dmg!`];
    b.shake = 12;

    if (p.hp <= 0) {
      b.result = 'lose';
      b.log.push('You were defeated...');
      setTimeout(() => { this.state = STATE.GAME_OVER; }, 1000);
    }
  }

  _battleWin() {
    const b = this.battle, p = this.player;
    b.result = 'win';
    const msgs = gainXP(p, b.enemy.xp);
    p.coins += b.enemy.coin;
    b.log = [`${b.enemy.def.name} defeated!`, `+${b.enemy.xp} XP  +${b.enemy.coin} coins`, ...msgs];

    if (b.isDungeon) {
      const dg = this.dungeon;
      dg.floor++;
      if (dg.floor > dg.totalFloors) {
        // Dungeon cleared
        p.dungeonsCleared.push(dg.idx);
        p.coins += dg.def.reward.coin;
        gainXP(p, dg.def.reward.xp);
        b.log.push(`Dungeon Cleared! +${dg.def.reward.coin} coins!`);
        setTimeout(() => { this.battle = null; this.dungeon = null; this.state = STATE.WORLD; this._saveGame(); }, 1500);
      } else {
        // Next floor
        setTimeout(() => {
          const level = dg.def.baseLevel + dg.floor * 2 + rng(0, 4);
          const eligible = MONSTERS.filter(m => m.biomes.includes(dg.def.biome));
          const isBoss = dg.floor === dg.totalFloors;
          let def = eligible[rng(0, eligible.length)];
          if (isBoss) {
            const epics = eligible.filter(m => ['Epic','Legendary'].includes(m.rarity));
            if (epics.length) def = epics[rng(0, epics.length)];
          }
          const enemy = monsterInstance(def, level + (isBoss ? 5 : 0));
          this.battle = {
            enemy, isDungeon: true, animating: false,
            turn: 'player',
            log: [`Floor ${dg.floor}/${dg.totalFloors}${isBoss?' — BOSS!':''}`, `${def.name} Lv.${level}!`],
            skillCDs: b.skillCDs,
            result: null, shake: 0, flash: null, bgBiome: dg.def.biome,
          };
        }, 1200);
      }
    } else {
      setTimeout(() => { this.battle = null; this.state = STATE.WORLD; this._saveGame(); }, 1000);
    }
  }

  // ─── Shop ──────────────────────────────────────────────────────────────────
  _buyItem(item) {
    const p = this.player;
    if (p.coins < item.cost) { this._msg('Not enough coins!'); return; }
    p.coins -= item.cost;
    if (item.type === 'consumable' || item.type === 'trap') {
      const existing = p.inventory.find(i => i.id === item.id);
      if (existing) existing.qty++;
      else p.inventory.push({ ...item, qty: 1 });
      this._msg(`Bought ${item.name}!`);
    } else {
      // Equip immediately if better
      const slot = item.type === 'weapon' ? 'weapon' : 'armor';
      p.equip[slot] = item;
      if (item.atk) p.atk = p.cls.baseAtk + item.atk + (p.level - 1) * 2;
      if (item.def) p.def = p.cls.baseDef + item.def + (p.level - 1) * 2;
      if (item.mag) p.mag = p.cls.baseMag + item.mag + (p.level - 1) * 2;
      if (item.spd) p.spd = p.cls.baseSpd + (item.spd || 0) + (p.level - 1);
      this._msg(`Equipped ${item.name}!`);
    }
  }

  // ─── Particles ─────────────────────────────────────────────────────────────
  _addParticles(x, y, color, count) {
    for (let i = 0; i < count; i++) {
      this.particles.push({
        x, y, vx: (Math.random() - 0.5) * 6, vy: (Math.random() - 1.5) * 6,
        color, life: 1, size: 3 + Math.random() * 5,
      });
    }
  }

  _updateParticles(dt) {
    const ms = dt / 1000;
    this.particles = this.particles.filter(p => {
      p.x += p.vx; p.y += p.vy; p.vy += 0.18; p.life -= ms * 2;
      return p.life > 0;
    });
  }

  // ─── Save / Load ───────────────────────────────────────────────────────────
  _saveGame() {
    if (!this.player) return;
    try {
      const save = {
        cls: this.player.cls.id, level: this.player.level, xp: this.player.xp,
        xpNeeded: this.player.xpNeeded, maxHp: this.player.maxHp, hp: this.player.hp,
        maxMp: this.player.maxMp, mp: this.player.mp,
        atk: this.player.atk, def: this.player.def, mag: this.player.mag, spd: this.player.spd,
        coins: this.player.coins, mapX: this.player.mapX, mapY: this.player.mapY,
        pals: this.player.pals.map(pal => ({ id: pal.def.id, level: pal.level, hp: pal.hp })),
        inventory: this.player.inventory,
        dungeonsCleared: this.player.dungeonsCleared,
        activePal: this.player.activePal,
        equip: { weapon: this.player.equip.weapon?.id, armor: this.player.equip.armor?.id },
      };
      localStorage.setItem('monsterRealm_save', JSON.stringify(save));
    } catch(_) {}
  }

  _loadGame() {
    try {
      const raw = localStorage.getItem('monsterRealm_save');
      if (!raw) return false;
      const s = JSON.parse(raw);
      const cls = CLASSES.find(c => c.id === s.cls);
      if (!cls) return false;
      this.player = newPlayer(cls);
      Object.assign(this.player, {
        level: s.level, xp: s.xp, xpNeeded: s.xpNeeded,
        maxHp: s.maxHp, hp: s.hp, maxMp: s.maxMp, mp: s.mp,
        atk: s.atk, def: s.def, mag: s.mag, spd: s.spd,
        coins: s.coins, mapX: s.mapX, mapY: s.mapY,
        inventory: s.inventory, dungeonsCleared: s.dungeonsCleared, activePal: s.activePal,
      });
      this.player.pals = (s.pals || []).map(ps => {
        const def = MONSTERS.find(m => m.id === ps.id);
        if (!def) return null;
        const inst = monsterInstance(def, ps.level);
        inst.hp = ps.hp;
        return inst;
      }).filter(Boolean);
      const { map } = generateMap();
      this.worldMap = map;
      this._centerCam();
      return true;
    } catch(_) { return false; }
  }

  // ─── Messages ──────────────────────────────────────────────────────────────
  _msg(text) { this.messages = [text]; this.msgTimer = 2500; }

  // ─── Main Loop ─────────────────────────────────────────────────────────────
  _loop(ts) {
    const dt = Math.min(ts - this.lastTime, 100);
    this.lastTime = ts;
    this.frame++;

    if (this.state === STATE.WORLD) this._updateWorld(dt);
    this._updateParticles(dt);
    if (this.msgTimer > 0) this.msgTimer -= dt;
    if (this.battle) {
      if (this.battle.shake > 0) this.battle.shake = Math.max(0, this.battle.shake - 1);
      if (this.battle.flash)     this.battle.flash  = null;
    }

    this._draw();
    requestAnimationFrame(t => this._loop(t));
  }

  // ─── Drawing ───────────────────────────────────────────────────────────────
  _draw() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, W, H);

    switch (this.state) {
      case STATE.TITLE:        this._drawTitle();      break;
      case STATE.CLASS_SELECT: this._drawClassSelect();break;
      case STATE.WORLD:        this._drawWorld();      break;
      case STATE.BATTLE:
      case STATE.DUNGEON:      this._drawBattle();     break;
      case STATE.PAL_MENU:     this._drawPalMenu();    break;
      case STATE.SHOP:         this._drawShop();       break;
      case STATE.GAME_OVER:    this._drawGameOver();   break;
    }

    // Particles (overlay on battle/world)
    for (const p of this.particles) {
      ctx.save();
      ctx.globalAlpha = p.life;
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    // Floating message
    if (this.msgTimer > 0 && this.messages.length) {
      ctx.save();
      ctx.globalAlpha = Math.min(1, this.msgTimer / 400);
      ctx.fillStyle = 'rgba(0,0,0,0.7)';
      roundRect(ctx, 20, H - 170, W - 40, 44, 8);
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(this.messages[0], W / 2, H - 142);
      ctx.restore();
    }
  }

  _drawTitle() {
    const ctx = this.ctx;
    // Background
    const bg = ctx.createLinearGradient(0, 0, 0, H);
    bg.addColorStop(0, '#0a0018'); bg.addColorStop(1, '#1a0830');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H);

    // Stars
    ctx.fillStyle = '#fff';
    for (let i = 0; i < 80; i++) {
      const sx = (i * 137.5 + 50) % W;
      const sy = (i * 97.3 + 20) % (H * 0.6);
      const sz = (i % 3 === 0) ? 2 : 1;
      const op = 0.4 + 0.6 * Math.abs(Math.sin(this.frame * 0.02 + i));
      ctx.globalAlpha = op;
      ctx.fillRect(sx, sy, sz, sz);
    }
    ctx.globalAlpha = 1;

    // Title
    ctx.save();
    ctx.shadowColor = '#c060ff'; ctx.shadowBlur = 30;
    ctx.fillStyle = '#fff';
    ctx.font = 'bold 32px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('MONSTER REALM', W / 2, 180);
    ctx.font = 'italic 18px sans-serif';
    ctx.fillStyle = '#c8a0ff';
    ctx.fillText('Pal Quest', W / 2, 215);
    ctx.restore();

    // Subtitle
    ctx.fillStyle = '#888';
    ctx.font = '13px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('Inspired by World Zero & Palworld', W / 2, 250);

    // Pal icons
    const iconPals = ['emberpup','aquafin','sparkmouse','sproutcub','frostkit','shadeling'];
    iconPals.forEach((id, i) => {
      const m = MONSTERS.find(m => m.id === id);
      const x = 30 + i * 60, y = 290, r = 22;
      ctx.save();
      ctx.shadowColor = TYPE_COLOR[m.types[0]]; ctx.shadowBlur = 12;
      drawMonsterIcon(ctx, m, x + r, y + r, r, this.frame * 0.04 + i);
      ctx.restore();
    });

    // Play button
    const pulse = 0.85 + 0.15 * Math.sin(this.frame * 0.07);
    ctx.save();
    ctx.shadowColor = '#c060ff'; ctx.shadowBlur = 20 * pulse;
    drawButton(ctx, W / 2 - 100, 380, 200, 55, 'PLAY', '#7030c0', '#fff', 20);
    ctx.restore();

    // Load
    const hasSave = (() => { try { return !!localStorage.getItem('monsterRealm_save'); } catch(_) { return false; } })();
    if (hasSave) {
      drawButton(ctx, W / 2 - 80, 450, 160, 42, 'Continue', '#303060', '#aaa', 15);
      ctx.canvas.addEventListener('click', (e) => {
        const r = ctx.canvas.getBoundingClientRect();
        const sx = (e.clientX - r.left) * (W / r.width);
        const sy = (e.clientY - r.top) * (H / r.height);
        if (sx > W/2-80 && sx < W/2+80 && sy > 450 && sy < 492) {
          if (this._loadGame()) this.state = STATE.WORLD;
        }
      }, { once: true });
    }

    ctx.fillStyle = '#555'; ctx.font = '12px sans-serif';
    ctx.fillText('Tap anywhere to start', W / 2, 530);
  }

  _drawClassSelect() {
    const ctx = this.ctx;
    const bg = ctx.createLinearGradient(0, 0, 0, H);
    bg.addColorStop(0, '#080818'); bg.addColorStop(1, '#101828');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H);

    ctx.fillStyle = '#fff'; ctx.font = 'bold 22px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('Choose Your Class', W / 2, 60);
    ctx.fillStyle = '#888'; ctx.font = '13px sans-serif';
    ctx.fillText('This determines your skills and playstyle', W / 2, 85);

    CLASSES.forEach((cls, i) => {
      const cx_ = 25 + i * 120, cy_ = 110, cw = 108, ch = 300;
      const sel = this.selectedClass === i;
      ctx.save();
      if (sel) { ctx.shadowColor = cls.color; ctx.shadowBlur = 18; }
      ctx.fillStyle = sel ? cls.color + '33' : '#181828';
      roundRect(ctx, cx_, cy_, cw, ch, 12); ctx.fill();
      ctx.strokeStyle = sel ? cls.color : '#333';
      ctx.lineWidth = sel ? 2.5 : 1;
      roundRect(ctx, cx_, cy_, cw, ch, 12); ctx.stroke();
      ctx.restore();

      // Icon
      ctx.font = '36px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText(cls.icon, cx_ + cw / 2, cy_ + 55);

      // Name
      ctx.fillStyle = sel ? cls.color : '#ddd';
      ctx.font = `bold 15px sans-serif`;
      ctx.fillText(cls.name, cx_ + cw / 2, cy_ + 82);

      // Desc
      ctx.fillStyle = '#aaa'; ctx.font = '11px sans-serif';
      wrapText(ctx, cls.desc, cx_ + cw / 2, cy_ + 100, cw - 10, 15);

      // Stats bars
      const stats = [
        { label:'HP',  val: cls.baseHP / 120 },
        { label:'ATK', val: cls.baseAtk / 18 },
        { label:'DEF', val: cls.baseDef / 16 },
        { label:'MAG', val: cls.baseMag / 26 },
        { label:'SPD', val: cls.baseSpd / 20 },
      ];
      stats.forEach((s, si) => {
        const bx = cx_ + 8, by = cy_ + 145 + si * 22, bw = cw - 16, bh = 12;
        ctx.fillStyle = '#222'; roundRect(ctx, bx, by, bw, bh, 4); ctx.fill();
        ctx.fillStyle = cls.color;
        roundRect(ctx, bx, by, bw * Math.min(1, s.val), bh, 4); ctx.fill();
        ctx.fillStyle = '#aaa'; ctx.font = '9px sans-serif'; ctx.textAlign = 'left';
        ctx.fillText(s.label, bx + 2, by + 9);
      });

      // Skills preview
      ctx.fillStyle = '#888'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
      cls.skills.forEach((sk, si) => {
        ctx.fillStyle = TYPE_COLOR[sk.type] || '#aaa';
        ctx.fillText(`• ${sk.name}`, cx_ + cw / 2, cy_ + 260 + si * 14);
      });
    });

    // Confirm button
    const cls = CLASSES[this.selectedClass];
    ctx.save();
    ctx.shadowColor = cls.color; ctx.shadowBlur = 14;
    drawButton(ctx, W / 2 - 110, 450, 220, 55, `Play as ${cls.name}`, cls.color, '#fff', 18);
    ctx.restore();
  }

  _drawWorld() {
    const ctx = this.ctx;
    const p = this.player;
    ctx.save();
    ctx.translate(-this.cam.x, -this.cam.y);

    // Tiles
    const startX = Math.max(0, (this.cam.x / TILE) | 0);
    const startY = Math.max(0, (this.cam.y / TILE) | 0);
    const endX   = Math.min(MAP_W, startX + Math.ceil(W / TILE) + 1);
    const endY   = Math.min(MAP_H, startY + Math.ceil(H / TILE) + 1);

    for (let ty = startY; ty < endY; ty++) {
      for (let tx = startX; tx < endX; tx++) {
        const tile = this.worldMap[ty][tx];
        const biome = BIOMES.find(b => b.id === tile.biome);
        ctx.fillStyle = tile.walkable ? biome.color : biome.dark;
        ctx.fillRect(tx * TILE, ty * TILE, TILE, TILE);
        // Grid subtle
        ctx.strokeStyle = 'rgba(0,0,0,0.08)'; ctx.lineWidth = 0.5;
        ctx.strokeRect(tx * TILE, ty * TILE, TILE, TILE);

        if (!tile.walkable) {
          // Water ripple
          ctx.fillStyle = 'rgba(255,255,255,0.08)';
          ctx.fillRect(tx * TILE + 4, ty * TILE + 8, TILE - 8, 3);
        }
        if (tile.dungeon !== undefined) {
          ctx.font = '22px sans-serif'; ctx.textAlign = 'center';
          const pulse = 0.7 + 0.3 * Math.sin(this.frame * 0.06 + tile.dungeon);
          ctx.globalAlpha = pulse;
          ctx.fillText('🏯', tx * TILE + TILE / 2, ty * TILE + TILE / 2 + 8);
          ctx.globalAlpha = 1;
        }
        if (tile.shop) {
          ctx.font = '22px sans-serif'; ctx.textAlign = 'center';
          ctx.fillText('🏪', tx * TILE + TILE / 2, ty * TILE + TILE / 2 + 8);
        }
      }
    }

    // Player
    const px = p.mapX * TILE + TILE / 2;
    const py = p.mapY * TILE + TILE / 2;
    ctx.shadowColor = p.cls.color; ctx.shadowBlur = 12;
    ctx.fillStyle = p.cls.color;
    ctx.beginPath(); ctx.arc(px, py, 14, 0, Math.PI * 2); ctx.fill();
    ctx.shadowBlur = 0;
    ctx.font = '18px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(p.cls.icon, px, py + 6);

    ctx.restore();

    // HUD
    this._drawWorldHUD();
  }

  _drawWorldHUD() {
    const ctx = this.ctx, p = this.player;

    // Top bar
    ctx.fillStyle = 'rgba(0,0,0,0.65)';
    roundRect(ctx, 8, 8, W - 16, 58, 10); ctx.fill();

    ctx.fillStyle = '#fff'; ctx.font = 'bold 14px sans-serif'; ctx.textAlign = 'left';
    ctx.fillText(`${p.cls.name}  Lv.${p.level}`, 16, 28);
    ctx.fillStyle = '#aaa'; ctx.font = '11px sans-serif';
    ctx.fillText(`XP: ${p.xp}/${p.xpNeeded}`, 16, 44);

    // HP bar
    drawBar(ctx, 130, 18, 150, 14, p.hp / p.maxHp, '#e84040', '#300');
    ctx.fillStyle = '#fff'; ctx.font = '10px sans-serif';
    ctx.fillText(`${p.hp}/${p.maxHp}`, 210, 29);

    // MP bar
    drawBar(ctx, 130, 36, 150, 14, p.mp / p.maxMp, '#4040e8', '#003');
    ctx.fillStyle = '#fff'; ctx.font = '10px sans-serif';
    ctx.fillText(`${p.mp}/${p.maxMp}`, 210, 47);

    // Coins
    ctx.fillStyle = '#fd0'; ctx.font = 'bold 13px sans-serif'; ctx.textAlign = 'right';
    ctx.fillText(`💰 ${p.coins}`, W - 14, 28);

    // Active pal indicator
    if (p.activePal !== null && p.pals[p.activePal]) {
      const pal = p.pals[p.activePal];
      ctx.fillStyle = 'rgba(0,0,0,0.6)';
      roundRect(ctx, 8, 72, 130, 36, 8); ctx.fill();
      ctx.fillStyle = '#adf'; ctx.font = '11px sans-serif'; ctx.textAlign = 'left';
      ctx.fillText(`🐾 ${pal.def.name}`, 14, 86);
      drawBar(ctx, 14, 92, 110, 8, pal.hp / pal.maxHp, '#4e4', '#030');
    }

    // Biome label
    const tile = this.worldMap[this.player.mapY][this.player.mapX];
    const biome = BIOMES.find(b => b.id === tile.biome);
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    roundRect(ctx, W / 2 - 60, H - 145, 120, 24, 6); ctx.fill();
    ctx.fillStyle = '#ddd'; ctx.font = '12px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(biome.label, W / 2, H - 128);

    // D-pad
    drawDpad(ctx, 80, H - 90);

    // Buttons row
    drawButton(ctx, W - 90, H - 110, 82, 44, '🐾 Pals', '#1a3040', '#7df', 13);
    drawButton(ctx, 140, H - 110, 120, 44, '⚡ Interact', '#203030', '#adf', 13);
  }

  _drawBattle() {
    const ctx = this.ctx, b = this.battle, p = this.player;
    const shake = b.shake > 0 ? (Math.random() - 0.5) * b.shake : 0;

    // Background
    const biome = BIOMES.find(bi => bi.id === b.bgBiome) || BIOMES[0];
    const bg = ctx.createLinearGradient(0, 0, 0, H);
    bg.addColorStop(0, biome.dark + 'cc'); bg.addColorStop(1, '#060610');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H);

    // Ground platform
    ctx.fillStyle = biome.color + '88';
    ctx.beginPath(); ctx.ellipse(W/2, 340, 130, 28, 0, 0, Math.PI*2); ctx.fill();
    ctx.fillStyle = biome.color + '44';
    ctx.beginPath(); ctx.ellipse(W/2, 460, 100, 22, 0, 0, Math.PI*2); ctx.fill();

    // Dungeon header
    if (b.isDungeon && this.dungeon) {
      const dg = this.dungeon;
      ctx.fillStyle = 'rgba(0,0,0,0.7)';
      roundRect(ctx, 0, 0, W, 42, 0); ctx.fill();
      ctx.fillStyle = '#f80'; ctx.font = 'bold 14px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText(`${dg.def.name} — Floor ${dg.floor}/${dg.totalFloors}`, W/2, 26);
    }

    // Enemy
    ctx.save(); ctx.translate(shake, shake * 0.5);
    const enemy = b.enemy;
    const er = 48 + Math.sin(this.frame * 0.04) * 3;
    ctx.save();
    ctx.shadowColor = TYPE_COLOR[enemy.def.types[0]]; ctx.shadowBlur = 18;
    drawMonsterIcon(ctx, enemy.def, W/2, 280, er, this.frame * 0.025);
    ctx.restore();

    // Enemy HP bar
    const ehpRatio = enemy.hp / enemy.maxHp;
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    roundRect(ctx, 40, 190, W - 80, 50, 10); ctx.fill();
    ctx.fillStyle = RARITY_COLOR[enemy.def.rarity];
    ctx.font = `bold 15px sans-serif`; ctx.textAlign = 'left';
    ctx.fillText(`${enemy.def.name}`, 48, 210);
    ctx.fillStyle = '#aaa'; ctx.font = '11px sans-serif';
    ctx.fillText(`Lv.${enemy.level}  [${enemy.def.types.join('/')}]  ${enemy.def.rarity}`, 48, 226);
    drawBar(ctx, 48, 228, W - 96, 10, ehpRatio, '#e84040', '#300');
    ctx.fillStyle = '#ddd'; ctx.font = '10px sans-serif'; ctx.textAlign = 'right';
    ctx.fillText(`${enemy.hp}/${enemy.maxHp}`, W - 48, 237);
    ctx.restore();

    // Player character
    ctx.save();
    ctx.shadowColor = p.cls.color; ctx.shadowBlur = 10;
    ctx.font = '38px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(p.cls.icon, W/2, 465);
    ctx.restore();

    // Player HP/MP
    ctx.fillStyle = 'rgba(0,0,0,0.65)';
    roundRect(ctx, 20, 390, W - 40, 55, 10); ctx.fill();
    ctx.fillStyle = '#fff'; ctx.font = 'bold 13px sans-serif'; ctx.textAlign = 'left';
    ctx.fillText(`${p.cls.name} Lv.${p.level}`, 28, 410);
    drawBar(ctx, 28, 415, W - 56, 12, p.hp / p.maxHp, '#e84040', '#300');
    ctx.fillStyle = '#ddd'; ctx.font = '10px sans-serif';
    ctx.fillText(`HP ${p.hp}/${p.maxHp}`, 28, 427);
    drawBar(ctx, 28, 430, W - 56, 12, p.mp / p.maxMp, '#4040e8', '#003');
    ctx.fillStyle = '#aad'; ctx.font = '10px sans-serif';
    ctx.fillText(`MP ${p.mp}/${p.maxMp}`, 28, 442);

    // Battle log
    ctx.fillStyle = 'rgba(0,0,0,0.75)';
    roundRect(ctx, 8, 478, W - 16, 58, 8); ctx.fill();
    ctx.fillStyle = '#eee'; ctx.font = '12px sans-serif'; ctx.textAlign = 'left';
    const log = b.log || [];
    log.slice(-3).forEach((line, i) => {
      ctx.fillStyle = i === log.length - 1 ? '#fff' : '#aaa';
      ctx.fillText(line, 14, 495 + i * 14);
    });

    // Skill buttons
    ctx.fillStyle = 'rgba(0,0,0,0.8)';
    roundRect(ctx, 0, H - 165, W, 95, 0); ctx.fill();
    p.cls.skills.forEach((sk, i) => {
      const bx = 10 + i * 95, by = H - 160, bw = 88, bh = 68;
      const onCD = b.skillCDs[i] > 0;
      const noMP = p.mp < sk.mp;
      const disabled = onCD || noMP;
      const col = disabled ? '#333' : TYPE_COLOR[sk.type] || '#555';
      ctx.fillStyle = col; roundRect(ctx, bx, by, bw, bh, 8); ctx.fill();
      ctx.strokeStyle = disabled ? '#555' : '#fff'; ctx.lineWidth = 1;
      roundRect(ctx, bx, by, bw, bh, 8); ctx.stroke();
      ctx.fillStyle = disabled ? '#666' : '#fff';
      ctx.font = 'bold 11px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText(sk.name, bx + bw / 2, by + 18);
      ctx.fillStyle = '#ccc'; ctx.font = '10px sans-serif';
      if (sk.power) ctx.fillText(`PWR ${sk.power}`, bx + bw / 2, by + 32);
      if (sk.mp)    ctx.fillText(`MP ${sk.mp}`, bx + bw / 2, by + 45);
      else          ctx.fillText('Free', bx + bw / 2, by + 45);
      if (onCD) {
        ctx.fillStyle = '#f84'; ctx.font = '10px sans-serif';
        ctx.fillText(`CD:${b.skillCDs[i]}`, bx + bw / 2, by + 58);
      }
    });

    // Bottom row buttons
    drawButton(ctx, 10,  H - 68, 118, 44, '🧪 Item', '#2a2020', '#fca', 12);
    drawButton(ctx, 140, H - 68, 120, 44, '🐾 Pal Atk', '#1a2a1a', '#afa', 12);
    drawButton(ctx, 272, H - 68, 118, 44, '🏃 Flee', '#1a1a2a', '#acf', 12);
  }

  _drawPalMenu() {
    const ctx = this.ctx, p = this.player;
    const bg = ctx.createLinearGradient(0, 0, 0, H);
    bg.addColorStop(0, '#080818'); bg.addColorStop(1, '#0a1020');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H);

    drawButton(ctx, 8, 8, 72, 40, '◀ Back', '#222', '#aaa', 13);

    ctx.fillStyle = '#fff'; ctx.font = 'bold 18px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('Your Pals', W / 2, 36);
    ctx.fillStyle = '#888'; ctx.font = '12px sans-serif';
    ctx.fillText(`${p.pals.length}/6 captured  •  Tap to set active`, W / 2, 56);

    if (p.pals.length === 0) {
      ctx.fillStyle = '#555'; ctx.font = '14px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('No pals yet! Use traps in battle.', W / 2, 200);
      return;
    }

    p.pals.forEach((pal, i) => {
      const py_ = 70 + i * 95;
      const isActive = p.activePal === i;
      ctx.fillStyle = isActive ? '#1a2a1a' : '#101018';
      roundRect(ctx, 10, py_, W - 20, 82, 10); ctx.fill();
      ctx.strokeStyle = isActive ? '#4e4' : '#333'; ctx.lineWidth = isActive ? 2 : 1;
      roundRect(ctx, 10, py_, W - 20, 82, 10); ctx.stroke();

      // Icon
      drawMonsterIcon(ctx, pal.def, 52, py_ + 41, 28, this.frame * 0.02 + i);

      ctx.fillStyle = RARITY_COLOR[pal.def.rarity];
      ctx.font = `bold 14px sans-serif`; ctx.textAlign = 'left';
      ctx.fillText(pal.def.name, 90, py_ + 22);
      ctx.fillStyle = '#aaa'; ctx.font = '11px sans-serif';
      ctx.fillText(`Lv.${pal.level}  [${pal.def.types.join('/')}]  ${pal.def.rarity}`, 90, py_ + 38);
      drawBar(ctx, 90, py_ + 44, W - 110, 12, pal.hp / pal.maxHp, '#4e4', '#030');
      ctx.fillStyle = '#ccc'; ctx.font = '10px sans-serif';
      ctx.fillText(`HP ${pal.hp}/${pal.maxHp}`, 90, py_ + 56);
      ctx.fillStyle = '#888'; ctx.font = '10px sans-serif';
      ctx.fillText(`ATK ${pal.atk}  DEF ${pal.def_}  SPD ${pal.spd}`, 90, py_ + 68);

      if (isActive) {
        ctx.fillStyle = '#4e4'; ctx.font = 'bold 11px sans-serif'; ctx.textAlign = 'right';
        ctx.fillText('ACTIVE', W - 18, py_ + 22);
      }
    });
  }

  _drawShop() {
    const ctx = this.ctx, p = this.player;
    const bg = ctx.createLinearGradient(0, 0, 0, H);
    bg.addColorStop(0, '#18100a'); bg.addColorStop(1, '#100808');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H);

    drawButton(ctx, 8, 8, 72, 40, '◀ Back', '#222', '#aaa', 13);

    ctx.fillStyle = '#fc8'; ctx.font = 'bold 18px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('🏪 Market', W / 2, 36);
    ctx.fillStyle = '#fd0'; ctx.font = '13px sans-serif';
    ctx.fillText(`Your coins: ${p.coins} 💰`, W / 2, 56);

    const shopItems = ITEMS;
    shopItems.forEach((item, i) => {
      const col = Math.floor(i / 7), row = i % 7;
      const ix = 10 + col * 195, iy = 65 + row * 82;
      const canAfford = p.coins >= item.cost;
      ctx.fillStyle = canAfford ? '#1a1208' : '#0c0c0c';
      roundRect(ctx, ix, iy, 183, 74, 8); ctx.fill();
      ctx.strokeStyle = canAfford ? '#664400' : '#222'; ctx.lineWidth = 1;
      roundRect(ctx, ix, iy, 183, 74, 8); ctx.stroke();

      ctx.fillStyle = canAfford ? '#fc8' : '#664';
      ctx.font = `bold 12px sans-serif`; ctx.textAlign = 'left';
      ctx.fillText(item.name, ix + 8, iy + 18);
      ctx.fillStyle = '#888'; ctx.font = '10px sans-serif';
      const desc = item.type === 'consumable' ? `${item.effect === 'hp' ? 'HP' : 'MP'} +${item.val}`
                 : item.type === 'trap'       ? `Capture rate ${Math.round(item.cr * 100)}%`
                 : `${item.atk ? 'ATK +'+item.atk : ''}${item.def ? 'DEF +'+item.def : ''}${item.mag ? 'MAG +'+item.mag : ''}${item.spd ? ' SPD +'+item.spd : ''}`;
      ctx.fillText(desc, ix + 8, iy + 33);
      ctx.fillStyle = '#fd0'; ctx.font = 'bold 12px sans-serif';
      ctx.fillText(`💰 ${item.cost}`, ix + 8, iy + 50);

      // In inventory?
      const inv = p.inventory.find(inv => inv.id === item.id);
      if (inv) {
        ctx.fillStyle = '#4e4'; ctx.font = '10px sans-serif'; ctx.textAlign = 'right';
        ctx.fillText(`x${inv.qty}`, ix + 175, iy + 18);
      }
      ctx.textAlign = 'left';
    });
  }

  _drawGameOver() {
    const ctx = this.ctx;
    ctx.fillStyle = '#060610'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = 'rgba(180,0,0,0.3)'; ctx.fillRect(0, 0, W, H);

    ctx.fillStyle = '#e84040'; ctx.font = 'bold 40px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('DEFEATED', W / 2, 240);
    ctx.fillStyle = '#aaa'; ctx.font = '16px sans-serif';
    ctx.fillText('Your journey ends here...', W / 2, 290);
    ctx.fillStyle = '#777'; ctx.font = '13px sans-serif';
    ctx.fillText(`Lv.${this.player?.level || 1} ${this.player?.cls.name || ''}`, W / 2, 325);

    drawButton(ctx, W / 2 - 80, 390, 160, 50, 'Try Again', '#400', '#fff', 16);
  }
}

// ─── Drawing Helpers ──────────────────────────────────────────────────────────
function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y); ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r); ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h); ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r); ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function drawBar(ctx, x, y, w, h, ratio, fill, bg) {
  ctx.fillStyle = bg; roundRect(ctx, x, y, w, h, h / 2); ctx.fill();
  if (ratio > 0) {
    ctx.fillStyle = fill; roundRect(ctx, x, y, Math.max(h, w * ratio), h, h / 2); ctx.fill();
  }
}

function drawButton(ctx, x, y, w, h, label, bg, fg, fs) {
  ctx.fillStyle = bg; roundRect(ctx, x, y, w, h, 8); ctx.fill();
  ctx.strokeStyle = fg + '55'; ctx.lineWidth = 1;
  roundRect(ctx, x, y, w, h, 8); ctx.stroke();
  ctx.fillStyle = fg; ctx.font = `bold ${fs}px sans-serif`; ctx.textAlign = 'center';
  ctx.fillText(label, x + w / 2, y + h / 2 + fs * 0.36);
}

function drawDpad(ctx, cx, cy) {
  const r = 55;
  ctx.fillStyle = 'rgba(255,255,255,0.08)';
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = 'rgba(255,255,255,0.12)';
  [0, 90, 180, 270].forEach(a => {
    const rad = a * Math.PI / 180;
    ctx.beginPath();
    ctx.moveTo(cx + Math.cos(rad) * 18, cy + Math.sin(rad) * 18);
    ctx.lineTo(cx + Math.cos(rad - 0.4) * 48, cy + Math.sin(rad - 0.4) * 48);
    ctx.lineTo(cx + Math.cos(rad + 0.4) * 48, cy + Math.sin(rad + 0.4) * 48);
    ctx.closePath(); ctx.fill();
  });
  ctx.fillStyle = 'rgba(255,255,255,0.05)';
  ctx.beginPath(); ctx.arc(cx, cy, 12, 0, Math.PI * 2); ctx.fill();
  // Arrows
  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.font = '16px sans-serif'; ctx.textAlign = 'center';
  ctx.fillText('▲', cx, cy - 28); ctx.fillText('▼', cx, cy + 36);
  ctx.fillText('◀', cx - 32, cy + 6); ctx.fillText('▶', cx + 32, cy + 6);
}

function drawMonsterIcon(ctx, def, cx, cy, r, anim) {
  const col = TYPE_COLOR[def.types[0]] || '#888';
  const col2 = TYPE_COLOR[def.types[1]] || col;
  // Body
  const grad = ctx.createRadialGradient(cx - r * 0.2, cy - r * 0.2, r * 0.1, cx, cy, r);
  grad.addColorStop(0, col + 'ff'); grad.addColorStop(1, col2 + '88');
  ctx.fillStyle = grad;
  ctx.beginPath();

  // Different shapes per type
  const t = def.types[0];
  if (['Dragon','Flying'].includes(t)) {
    // Wing shape
    ctx.save(); ctx.translate(cx, cy);
    ctx.rotate(anim * 0.3);
    ctx.beginPath();
    ctx.ellipse(0, 0, r, r * 0.65, 0, 0, Math.PI * 2);
    ctx.fill();
    // Wings
    ctx.fillStyle = col + 'bb';
    ctx.beginPath(); ctx.ellipse(-r * 0.8, -r * 0.3, r * 0.7, r * 0.35, -0.4, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.ellipse(r * 0.8, -r * 0.3, r * 0.7, r * 0.35, 0.4, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
  } else if (['Rock','Ground'].includes(t)) {
    // Polygon
    ctx.save(); ctx.translate(cx, cy); ctx.rotate(anim * 0.1);
    ctx.beginPath();
    for (let j = 0; j < 6; j++) {
      const a = (j / 6) * Math.PI * 2 - Math.PI / 6;
      const rj = r * (0.85 + 0.15 * Math.sin(j * 1.7));
      j === 0 ? ctx.moveTo(Math.cos(a) * rj, Math.sin(a) * rj) : ctx.lineTo(Math.cos(a) * rj, Math.sin(a) * rj);
    }
    ctx.closePath(); ctx.fill();
    ctx.restore();
  } else if (['Ghost','Psychic'].includes(t)) {
    // Wispy
    ctx.save(); ctx.translate(cx, cy);
    ctx.beginPath();
    ctx.arc(0, -r * 0.1, r * 0.7, Math.PI, 0);
    ctx.lineTo(r * 0.7, r * 0.4);
    for (let j = 3; j >= 0; j--) {
      const jx = r * 0.7 - j * r * 0.47;
      ctx.quadraticCurveTo(jx - r * 0.12, r * 0.8 + Math.sin(anim + j) * r * 0.15, jx - r * 0.235, r * 0.4);
    }
    ctx.closePath(); ctx.fill();
    ctx.restore();
  } else {
    // Standard circle with bob
    ctx.arc(cx, cy + Math.sin(anim) * 3, r, 0, Math.PI * 2); ctx.fill();
  }

  // Eyes
  ctx.fillStyle = '#fff';
  ctx.beginPath(); ctx.arc(cx - r * 0.28, cy - r * 0.15, r * 0.18, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(cx + r * 0.28, cy - r * 0.15, r * 0.18, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#111';
  ctx.beginPath(); ctx.arc(cx - r * 0.25, cy - r * 0.12, r * 0.1, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(cx + r * 0.25, cy - r * 0.12, r * 0.1, 0, Math.PI * 2); ctx.fill();
  // Type label
  ctx.fillStyle = col; ctx.font = `bold ${Math.round(r * 0.28)}px sans-serif`; ctx.textAlign = 'center';
  ctx.fillText(def.types[0].slice(0, 3).toUpperCase(), cx, cy + r * 0.5);
}

function wrapText(ctx, text, cx, y, maxW, lineH) {
  const words = text.split(' ');
  let line = '';
  for (const w of words) {
    const test = line + (line ? ' ' : '') + w;
    if (ctx.measureText(test).width > maxW && line) {
      ctx.fillText(line, cx, y); y += lineH; line = w;
    } else line = test;
  }
  if (line) ctx.fillText(line, cx, y);
}

// ─── Bootstrap ────────────────────────────────────────────────────────────────
window.Game = Game;
