const {withTimeout} = require('./watchdog.cjs');
// Wait for route animation/layout to settle before coordinate input.
async function stableTarget(locator, timeout = 5000) {
  await locator.waitFor({state: 'visible', timeout});
  // The in-page timer below cannot fire on a frozen page; bound it here too.
  return withTimeout(locator.evaluate((element, timeout) => new Promise((resolve, reject) => {
    let previous;
    let stable = 0;
    let frame;
    const timer = setTimeout(() => {
      cancelAnimationFrame(frame);
      reject(new Error('Target never settled inside viewport'));
    }, timeout);
    const check = () => {
      const r = element.getBoundingClientRect();
      const current = [r.x, r.y, r.width, r.height];
      const inside = element.isConnected && r.width > 0 && r.height > 0 &&
        r.x >= 0 && r.y >= 0 && r.right <= innerWidth && r.bottom <= innerHeight;
      stable = inside && previous && current.every((n, i) => Math.abs(n - previous[i]) < 0.1) ? stable + 1 : 0;
      previous = current;
      if (stable >= 5) {
        clearTimeout(timer);
        resolve({x: r.x + r.width / 2, y: r.y + r.height / 2});
      } else frame = requestAnimationFrame(check);
    };
    frame = requestAnimationFrame(check);
  }), timeout), timeout + 10000, 'stableTarget');
}
module.exports = {stableTarget};
