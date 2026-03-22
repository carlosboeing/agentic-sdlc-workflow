/**
 * Root App component — sets up client-side routing.
 *
 * Routes:
 *   /             → Dashboard (Kanban board)
 *   /items        → Items list (placeholder — see Board for now)
 *   /items/:id    → ItemDetail
 *   /docs/*       → DocumentViewer
 *   /costs        → Telemetry
 */

import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { Layout } from "./components/Layout";
import { Dashboard } from "./pages/Dashboard";
import { ItemDetail } from "./pages/ItemDetail";
import { DocumentViewer } from "./pages/DocumentViewer";
import { Telemetry } from "./pages/Telemetry";

export function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          {/* Board (default) */}
          <Route index element={<Dashboard />} />

          {/* Items list — redirects to board for now; E05-S02 will add a list view */}
          <Route path="items" element={<Navigate to="/" replace />} />

          {/* Item detail */}
          <Route path="items/:id" element={<ItemDetail />} />

          {/* Document viewer — wildcard to capture nested paths */}
          <Route path="docs/*" element={<DocumentViewer />} />

          {/* Telemetry / costs */}
          <Route path="costs" element={<Telemetry />} />

          {/* Catch-all: redirect unknown routes to dashboard */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
