/**
 * Application shell layout.
 *
 * Provides the top header bar, sidebar navigation, main content area,
 * and the collapsible activity feed panel.
 * All page components are rendered inside the main content area via <Outlet />.
 *
 * Structure:
 *   +------------------------------------------+
 *   | Header (fixed top)                        |
 *   +--------+--------------------+-------------+
 *   | Sidebar|  Main content      | Activity    |
 *   |        |  (<Outlet />)      | Feed        |
 *   |        |                    | (collapsible)|
 *   +--------+--------------------+-------------+
 */

import { useState } from "react";
import { Outlet } from "react-router-dom";
import { Sidebar } from "./Sidebar";
import { ActivityFeed } from "./ActivityFeed";

export function Layout() {
  const [activityOpen, setActivityOpen] = useState(true);

  return (
    <div className="flex flex-col h-screen overflow-hidden bg-gray-50">
      {/* Top header bar */}
      <header className="shrink-0 h-12 bg-white border-b border-gray-200 flex items-center px-4 gap-3">
        <h1 className="text-sm font-semibold text-gray-900">
          Workflow Dashboard
        </h1>
        <span className="text-xs text-gray-400 ml-auto">
          Runtime Service v0.1
        </span>
      </header>

      {/* Body: sidebar + main + activity feed */}
      <div className="flex flex-1 overflow-hidden">
        <Sidebar />

        {/* Main content area */}
        <main className="flex-1 overflow-auto">
          <Outlet />
        </main>

        {/* Collapsible activity feed panel */}
        <ActivityFeed
          isOpen={activityOpen}
          onToggle={() => setActivityOpen((prev) => !prev)}
        />
      </div>
    </div>
  );
}
