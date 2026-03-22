/**
 * React application entry point.
 *
 * Mounts the App component into the #root DOM element defined in index.html.
 */

import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./styles/globals.css";
import { App } from "./App";

const root = document.getElementById("root");
if (!root) {
  throw new Error(
    "Could not find #root element. index.html may be missing or misconfigured."
  );
}

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>
);
