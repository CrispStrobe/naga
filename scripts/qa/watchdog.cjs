// A frozen page (renderer main thread stuck) never runs in-page timers, and
// Playwright's evaluate() has no timeout of its own, so a harness waiting on
// such a page hangs until the CI job is killed. These node-side limits turn
// that into a fast, named failure.
class WatchdogTimeout extends Error {}

function withTimeout(promise, ms, label) {
  let timer;
  const expiry = new Promise((_, reject) => {
    timer = setTimeout(
      () => reject(new WatchdogTimeout(`Watchdog: ${label} made no progress in ${ms / 1000}s (page frozen?)`)),
      ms,
    );
  });
  return Promise.race([promise, expiry]).finally(() => clearTimeout(timer));
}

// Closes a context whose renderer may be hung; never waits more than 10s.
async function closeQuietly(context) {
  try { await withTimeout(context.close(), 10000, 'context.close'); } catch (_) {}
}

module.exports = {withTimeout, closeQuietly, WatchdogTimeout};
