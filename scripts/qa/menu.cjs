// Opens a mode from the home menu by name, driving it like a keyboard user.
//
// Positions come from MENU below, not from the accessibility tree: Flutter
// web only exposes on-screen menu entries, so once the list scrolls the
// tree no longer shows the entries above. Keep MENU in the same order as
// lib/ui/home_screen.dart. A stale MENU fails loudly: web_modes checks
// every opened mode's dialog title, and the lifecycle scenarios assert
// mode-specific results.
const MENU = [
  ['DAILY', ['Daily']],
  ['CLASSIC', ['Classic', 'Arcade', 'Zen', 'Nightfall', 'Portals']],
  ['CROSSOVER', ['Maze Hunter', 'Trail', 'Fangs', 'Venom', 'Shed']],
  ['ACTION', ['Pit', 'Swarm', 'Rush', 'Ouroboros', 'Echo', 'Territory']],
  ['LEGACY', ['Snake II', 'ASCII', 'CGA', 'Nibbles']],
  ['MINIGAMES', ['Stampede', 'Naga Dive']],
  ['ADVENTURE', ['Dungeon']],
  ['MULTIPLAYER', ['Duel', 'VS AI', 'VS AI Split']],
];
// A fresh browser profile starts with only these sections open.
const OPEN_BY_DEFAULT = new Set(['DAILY', 'CLASSIC']);

const MODES = MENU.flatMap(([, modes]) => modes);

// Keyboard index of a section header or mode, given which sections are open.
function indexOf(target, open) {
  let i = 0;
  for (const [section, modes] of MENU) {
    if (section === target) return i;
    i++;
    if (!open.has(section)) continue;
    for (const mode of modes) {
      if (mode === target) return i;
      i++;
    }
  }
  throw new Error(`"${target}" is not in scripts/qa/menu.cjs MENU`);
}

async function moveTo(page, from, to) {
  const key = to >= from ? 'ArrowDown' : 'ArrowUp';
  for (let i = 0; i < Math.abs(to - from); i++) {
    await page.keyboard.press(key);
    await page.waitForTimeout(40);
  }
}

// Leaves keyboard focus on [name]; the caller presses Enter. Expects a fresh
// profile (default sections) and focus on nothing, as after page load.
async function openMode(page, name, width) {
  await page.mouse.click(width / 2, 170); // Refocus the app; semantics stay on.
  const section = MENU.find(([, modes]) => modes.includes(name));
  if (!section) throw new Error(`"${name}" is not in scripts/qa/menu.cjs MENU`);
  const open = new Set(OPEN_BY_DEFAULT);
  let focus = -1;
  if (!open.has(section[0])) {
    const header = indexOf(section[0], open);
    await moveTo(page, focus, header);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(250);
    open.add(section[0]);
    focus = header;
  }
  const target = indexOf(name, open);
  await moveTo(page, focus, target);
  await page.waitForTimeout(180);
  return target;
}

module.exports = {openMode, MENU, MODES};
