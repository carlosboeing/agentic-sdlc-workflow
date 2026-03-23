/**
 * Build script for the React SPA frontend.
 *
 * Uses Bun's built-in bundler to compile the React/TypeScript frontend
 * into browser-ready assets in `frontend/dist/`.
 *
 * Output structure:
 *   frontend/dist/
 *     index.html        # Copied from frontend/index.html
 *     assets/
 *       main.js         # Bundled JS (React app, minified)
 *       main.js.map     # Source map
 *       main.css        # Compiled CSS (Tailwind-processed or fallback)
 *
 * Usage:
 *   bun run scripts/build-frontend.ts
 *   bun run build:frontend   (via package.json script)
 */

import { resolve, join, dirname } from "node:path";
import { existsSync, mkdirSync, copyFileSync, writeFileSync, renameSync } from "node:fs";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serverDir = resolve(__dirname, "..");
const frontendDir = join(serverDir, "frontend");
const distDir = join(frontendDir, "dist");
const assetsDir = join(distDir, "assets");

// Ensure output directories exist
mkdirSync(assetsDir, { recursive: true });

process.stderr.write("Building frontend...\n");

// ---------------------------------------------------------------------------
// Step 1: Bundle the React app with Bun
// ---------------------------------------------------------------------------

const buildResult = await Bun.build({
  entrypoints: [join(frontendDir, "src", "main.tsx")],
  outdir: assetsDir,
  target: "browser",
  format: "esm",
  minify: true,
  sourcemap: "external",
  define: {
    "process.env.NODE_ENV": '"production"',
  },
});

if (!buildResult.success) {
  for (const log of buildResult.logs) {
    process.stderr.write(`Build error: ${log.message}\n`);
  }
  process.exit(1);
}

process.stderr.write(
  `Bundled JS: ${buildResult.outputs.length} output file(s)\n`
);

// ---------------------------------------------------------------------------
// Step 2: Process CSS with Tailwind CLI
// Bun.build() does NOT run Tailwind's content scanning — it bundles raw CSS
// without generating utility classes. We use the @tailwindcss/cli package
// which scans component files for class usage and generates the final CSS.
// ---------------------------------------------------------------------------

const cssInput = join(frontendDir, "src", "styles", "globals.css");
const cssOutput = join(assetsDir, "main.css");

// Use process.execPath to find the bun binary (works even when bun is not in $PATH)
const bunPath = process.execPath;

const cssProc = Bun.spawnSync(
  [bunPath, "x", "tailwindcss", "-i", cssInput, "-o", cssOutput, "--minify"],
  { cwd: serverDir, stderr: "pipe", stdout: "pipe" }
);

if (cssProc.exitCode !== 0) {
  const stderr = cssProc.stderr.toString();
  process.stderr.write(`CSS build error: ${stderr}\n`);
  process.stderr.write("Warning: Tailwind CSS build failed — writing fallback stylesheet\n");
  writeFileSync(
    cssOutput,
    "/* Tailwind CSS build failed — fallback */\nbody { font-family: system-ui, sans-serif; margin: 0; }\n"
  );
} else {
  const stdout = cssProc.stderr.toString().trim();
  process.stderr.write(`Tailwind CSS: ${stdout || "compiled successfully"}\n`);
}

// ---------------------------------------------------------------------------
// Step 3: Copy index.html to dist root
// ---------------------------------------------------------------------------

const indexHtmlSrc = join(frontendDir, "index.html");
if (!existsSync(indexHtmlSrc)) {
  process.stderr.write(`Error: index.html not found at ${indexHtmlSrc}\n`);
  process.exit(1);
}

copyFileSync(indexHtmlSrc, join(distDir, "index.html"));
process.stderr.write("Copied: index.html\n");

// ---------------------------------------------------------------------------
// Done
// ---------------------------------------------------------------------------

process.stderr.write(`Output: ${distDir}\n`);
process.stderr.write("Build complete.\n");
