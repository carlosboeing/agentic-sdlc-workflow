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
// Step 2: Process CSS
// Bun's CSS bundler names the output after the input file (globals.css).
// We rename to main.css to match the reference in index.html.
// ---------------------------------------------------------------------------

const cssResult = await Bun.build({
  entrypoints: [join(frontendDir, "src", "styles", "globals.css")],
  outdir: assetsDir,
  target: "browser",
});

if (!cssResult.success) {
  for (const log of cssResult.logs) {
    process.stderr.write(`CSS build error: ${log.message}\n`);
  }
  // Non-fatal: CSS failures shouldn't block the build
  process.stderr.write("Warning: CSS bundling failed — writing fallback stylesheet\n");
  writeFileSync(
    join(assetsDir, "main.css"),
    "/* CSS build failed — fallback */\nbody { font-family: system-ui, sans-serif; margin: 0; }\n"
  );
} else {
  process.stderr.write(`Bundled CSS: ${cssResult.outputs.length} output file(s)\n`);

  // Bun names the CSS output after the source file (globals.css → globals.css).
  // Rename to main.css to match the <link> reference in index.html.
  const globalsPath = join(assetsDir, "globals.css");
  const mainCssPath = join(assetsDir, "main.css");
  if (existsSync(globalsPath)) {
    renameSync(globalsPath, mainCssPath);
    process.stderr.write("Renamed: globals.css → main.css\n");
  }
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
