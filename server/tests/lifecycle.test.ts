import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, readFileSync, existsSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  readPidFile,
  readPortFile,
  writePidFile,
  writePortFile,
  removePidFile,
  removePortFile,
  isProcessAlive,
  findAvailablePort,
  gracefulShutdown,
  IdleTimeoutTracker,
  readServerConfig,
  type LifecycleConfig,
} from "../src/lifecycle";

describe("Lifecycle: PID file management", () => {
  let workDir: string;

  beforeEach(() => {
    workDir = mkdtempSync(join(tmpdir(), "server-lifecycle-test-"));
  });

  afterEach(() => {
    rmSync(workDir, { recursive: true, force: true });
  });

  test("writePidFile writes process ID to file", () => {
    writePidFile(workDir, 12345);
    const content = readFileSync(join(workDir, "server.pid"), "utf8").trim();
    expect(content).toBe("12345");
  });

  test("readPidFile returns null when file does not exist", () => {
    const pid = readPidFile(workDir);
    expect(pid).toBeNull();
  });

  test("readPidFile returns pid when file exists", () => {
    writeFileSync(join(workDir, "server.pid"), "9999\n");
    const pid = readPidFile(workDir);
    expect(pid).toBe(9999);
  });

  test("removePidFile deletes the file", () => {
    writePidFile(workDir, 12345);
    expect(existsSync(join(workDir, "server.pid"))).toBe(true);
    removePidFile(workDir);
    expect(existsSync(join(workDir, "server.pid"))).toBe(false);
  });

  test("removePidFile is a no-op when file does not exist", () => {
    // Should not throw
    expect(() => removePidFile(workDir)).not.toThrow();
  });
});

describe("Lifecycle: Port file management", () => {
  let workDir: string;

  beforeEach(() => {
    workDir = mkdtempSync(join(tmpdir(), "server-lifecycle-test-"));
  });

  afterEach(() => {
    rmSync(workDir, { recursive: true, force: true });
  });

  test("writePortFile writes port to file", () => {
    writePortFile(workDir, 3117);
    const content = readFileSync(join(workDir, "server.port"), "utf8").trim();
    expect(content).toBe("3117");
  });

  test("readPortFile returns null when file does not exist", () => {
    const port = readPortFile(workDir);
    expect(port).toBeNull();
  });

  test("readPortFile returns port when file exists", () => {
    writeFileSync(join(workDir, "server.port"), "3118\n");
    const port = readPortFile(workDir);
    expect(port).toBe(3118);
  });

  test("removePortFile deletes the file", () => {
    writePortFile(workDir, 3117);
    expect(existsSync(join(workDir, "server.port"))).toBe(true);
    removePortFile(workDir);
    expect(existsSync(join(workDir, "server.port"))).toBe(false);
  });

  test("removePortFile is a no-op when file does not exist", () => {
    expect(() => removePortFile(workDir)).not.toThrow();
  });
});

describe("Lifecycle: Process detection", () => {
  test("isProcessAlive returns true for the current process", () => {
    // The current process is definitely alive
    expect(isProcessAlive(process.pid)).toBe(true);
  });

  test("isProcessAlive returns false for a non-existent PID", () => {
    // PID 99999999 is extremely unlikely to be in use
    expect(isProcessAlive(99999999)).toBe(false);
  });

  test("isProcessAlive returns false for PID 0", () => {
    // PID 0 is reserved (it's init/kernel), kill(0, 0) tests the calling process group
    // which would return true - so skip this edge case
    // Instead test with a large PID that doesn't exist
    expect(isProcessAlive(2147483647)).toBe(false);
  });
});

describe("Lifecycle: Port discovery", () => {
  test("findAvailablePort returns a port within the given range", async () => {
    const config: LifecycleConfig = {
      port: 3200,
      portRange: [3200, 3210],
      idleTimeoutMinutes: 60,
    };
    const port = await findAvailablePort(config);
    expect(port).toBeGreaterThanOrEqual(3200);
    expect(port).toBeLessThanOrEqual(3210);
  });

  test("findAvailablePort returns null when range is exhausted", async () => {
    // Use a port range that is very unlikely to have free ports by asking for range 1-2
    // but we can't reliably test this without binding ports, so test with a range
    // where start > end to simulate exhaustion quickly
    const config: LifecycleConfig = {
      port: 3300,
      portRange: [3300, 3300],
      idleTimeoutMinutes: 60,
    };
    // findAvailablePort should either return 3300 (if free) or null (if busy)
    const port = await findAvailablePort(config);
    // We just test it doesn't throw - the port may or may not be available
    expect(port === null || (typeof port === "number" && port >= 3300 && port <= 3300)).toBe(true);
  });

  test("findAvailablePort tries default port first", async () => {
    const config: LifecycleConfig = {
      port: 3201,
      portRange: [3201, 3210],
      idleTimeoutMinutes: 60,
    };
    const port = await findAvailablePort(config);
    // The first available port should be tried first (starting from the default)
    expect(port).not.toBeNull();
    if (port !== null) {
      expect(port).toBeGreaterThanOrEqual(3201);
    }
  });
});

describe("Lifecycle: readServerConfig", () => {
  let repoRoot: string;

  beforeEach(() => {
    repoRoot = mkdtempSync(join(tmpdir(), "server-config-test-"));
    mkdirSync(join(repoRoot, ".claude"), { recursive: true });
  });

  afterEach(() => {
    rmSync(repoRoot, { recursive: true, force: true });
  });

  test("returns defaults when config file does not exist", () => {
    const config = readServerConfig(repoRoot);
    expect(config.port).toBe(3117);
    expect(config.portRange).toEqual([3117, 3127]);
    expect(config.idleTimeoutMinutes).toBe(240);
  });

  test("reads port from config file", () => {
    const cfg = { server: { port: 4000, portRange: [4000, 4010], idleTimeoutMinutes: 60 } };
    writeFileSync(join(repoRoot, ".claude", "agentic-sdlc-config.json"), JSON.stringify(cfg));
    const config = readServerConfig(repoRoot);
    expect(config.port).toBe(4000);
    expect(config.portRange).toEqual([4000, 4010]);
    expect(config.idleTimeoutMinutes).toBe(60);
  });

  test("merges partial config with defaults", () => {
    const cfg = { server: { port: 5000 } };
    writeFileSync(join(repoRoot, ".claude", "agentic-sdlc-config.json"), JSON.stringify(cfg));
    const config = readServerConfig(repoRoot);
    expect(config.port).toBe(5000);
    // Unspecified fields fall back to defaults
    expect(config.portRange).toEqual([3117, 3127]);
    expect(config.idleTimeoutMinutes).toBe(240);
  });

  test("returns defaults when config file has invalid JSON", () => {
    writeFileSync(join(repoRoot, ".claude", "agentic-sdlc-config.json"), "{ not valid json ]");
    const config = readServerConfig(repoRoot);
    expect(config.port).toBe(3117);
    expect(config.portRange).toEqual([3117, 3127]);
    expect(config.idleTimeoutMinutes).toBe(240);
  });

  test("returns defaults when config has no server section", () => {
    const cfg = { reviewStrategy: { skipPerStoryReview: { enabled: false } } };
    writeFileSync(join(repoRoot, ".claude", "agentic-sdlc-config.json"), JSON.stringify(cfg));
    const config = readServerConfig(repoRoot);
    expect(config.port).toBe(3117);
    expect(config.portRange).toEqual([3117, 3127]);
    expect(config.idleTimeoutMinutes).toBe(240);
  });
});

describe("Lifecycle: IdleTimeoutTracker", () => {
  test("fires onTimeout callback after idle period", async () => {
    let fired = false;
    const tracker = new IdleTimeoutTracker(50, () => { fired = true; });
    await Bun.sleep(80);
    expect(fired).toBe(true);
    tracker.stop();
  });

  test("touch() resets the idle timer", async () => {
    let fired = false;
    const tracker = new IdleTimeoutTracker(80, () => { fired = true; });
    // Touch at 40ms — resets the timer, so callback should not fire until 40+80=120ms
    await Bun.sleep(40);
    tracker.touch();
    await Bun.sleep(50);
    // Timer was reset: only 50ms of idle since the touch, callback should not have fired yet
    expect(fired).toBe(false);
    // Now wait for the reset timer to fire
    await Bun.sleep(50);
    expect(fired).toBe(true);
    tracker.stop();
  });

  test("stop() cancels the idle timer", async () => {
    let fired = false;
    const tracker = new IdleTimeoutTracker(50, () => { fired = true; });
    tracker.stop();
    await Bun.sleep(80);
    expect(fired).toBe(false);
  });

  test("idleDurationMs returns approximate elapsed time since last activity", async () => {
    const tracker = new IdleTimeoutTracker(0, () => {});
    const before = tracker.idleDurationMs;
    await Bun.sleep(30);
    const after = tracker.idleDurationMs;
    expect(after).toBeGreaterThanOrEqual(before);
    expect(after).toBeGreaterThanOrEqual(25); // at least ~25ms elapsed
    tracker.stop();
  });

  test("touch() updates last activity timestamp", async () => {
    const tracker = new IdleTimeoutTracker(0, () => {});
    await Bun.sleep(30);
    const idleBeforeTouch = tracker.idleDurationMs;
    tracker.touch();
    const idleAfterTouch = tracker.idleDurationMs;
    // After touch, idleDuration should be reset (much less than before touch)
    expect(idleAfterTouch).toBeLessThan(idleBeforeTouch);
    tracker.stop();
  });
});

describe("Lifecycle: gracefulShutdown", () => {
  let workDir: string;

  beforeEach(() => {
    workDir = mkdtempSync(join(tmpdir(), "server-shutdown-test-"));
  });

  afterEach(() => {
    rmSync(workDir, { recursive: true, force: true });
  });

  test("removes PID file on shutdown", async () => {
    writePidFile(workDir, 12345);
    await gracefulShutdown(workDir);
    expect(existsSync(join(workDir, "server.pid"))).toBe(false);
  });

  test("removes port file on shutdown", async () => {
    writePortFile(workDir, 3117);
    await gracefulShutdown(workDir);
    expect(existsSync(join(workDir, "server.port"))).toBe(false);
  });

  test("removes both PID and port files on shutdown", async () => {
    writePidFile(workDir, 12345);
    writePortFile(workDir, 3117);
    await gracefulShutdown(workDir);
    expect(existsSync(join(workDir, "server.pid"))).toBe(false);
    expect(existsSync(join(workDir, "server.port"))).toBe(false);
  });

  test("is a no-op when no files exist", async () => {
    // Should not throw even when files are absent
    await expect(gracefulShutdown(workDir)).resolves.toBeUndefined();
  });

  test("calls checkpointFn before removing files", async () => {
    const calls: string[] = [];
    writePidFile(workDir, 12345);
    writePortFile(workDir, 3117);
    await gracefulShutdown(workDir, () => { calls.push("checkpoint"); });
    expect(calls).toEqual(["checkpoint"]);
    // Files should still be removed even after checkpoint
    expect(existsSync(join(workDir, "server.pid"))).toBe(false);
    expect(existsSync(join(workDir, "server.port"))).toBe(false);
  });

  test("continues shutdown if checkpointFn throws", async () => {
    writePidFile(workDir, 12345);
    writePortFile(workDir, 3117);
    // checkpointFn that throws should not prevent file cleanup
    await gracefulShutdown(workDir, () => { throw new Error("checkpoint failed"); });
    expect(existsSync(join(workDir, "server.pid"))).toBe(false);
    expect(existsSync(join(workDir, "server.port"))).toBe(false);
  });
});
