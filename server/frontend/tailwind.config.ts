/**
 * Tailwind CSS configuration.
 *
 * Note: Tailwind v4 moved to CSS-first configuration.
 * This file exists for tooling compatibility (IDE, lint, etc.) but the
 * main configuration is driven by `src/styles/globals.css` via
 * `@import "tailwindcss"`.
 *
 * Custom theme extensions are added via CSS custom properties in globals.css.
 */
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./index.html",
    "./src/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};

export default config;
