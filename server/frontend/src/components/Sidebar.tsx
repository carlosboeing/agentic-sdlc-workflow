/**
 * Sidebar navigation component.
 *
 * Renders navigation links for all dashboard pages.
 * Links use react-router-dom NavLink so the active route gets the active class.
 */

import { NavLink } from "react-router-dom";

interface NavItem {
  to: string;
  label: string;
  icon: string; // Unicode icon character
}

const NAV_ITEMS: NavItem[] = [
  { to: "/", label: "Board", icon: "▦" },
  { to: "/items", label: "Items", icon: "☰" },
  { to: "/docs", label: "Docs", icon: "⎘" },
  { to: "/costs", label: "Costs", icon: "◈" },
];

export function Sidebar() {
  return (
    <nav
      className="w-48 shrink-0 border-r border-gray-200 bg-white flex flex-col"
      aria-label="Main navigation"
    >
      {/* Logo / title */}
      <div className="px-4 py-4 border-b border-gray-100">
        <span className="text-sm font-semibold text-gray-700 tracking-tight">
          Workflow
        </span>
      </div>

      {/* Nav links */}
      <div className="flex-1 px-2 py-3 space-y-1">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === "/"}
            className={({ isActive }) =>
              [
                "sidebar-link",
                isActive ? "active" : "",
              ]
                .filter(Boolean)
                .join(" ")
            }
          >
            <span className="text-base leading-none" aria-hidden="true">
              {item.icon}
            </span>
            {item.label}
          </NavLink>
        ))}
      </div>
    </nav>
  );
}
