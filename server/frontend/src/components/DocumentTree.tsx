/**
 * DocumentTree — file tree navigation for the docs/ directory.
 *
 * Renders a hierarchical tree of markdown files grouped by directory.
 * Clicking a file calls onSelectPath() to load that document.
 */

import type { DocumentEntry } from "../lib/types";

interface DocumentTreeProps {
  /** Flat list of document entries from GET /api/documents. */
  files: DocumentEntry[];
  /** Currently selected document path (highlighted in the tree). */
  selectedPath: string | null;
  /** Called when the user clicks a file. */
  onSelectPath: (path: string) => void;
}

/**
 * Group a flat file list into a nested directory tree.
 *
 * Returns a sorted map of directory → files and nested directories.
 * Top-level files are under the "" (empty string) key.
 */
export function groupFilesByDirectory(
  files: DocumentEntry[]
): Map<string, DocumentEntry[]> {
  const groups = new Map<string, DocumentEntry[]>();

  for (const file of files) {
    const slashIdx = file.path.lastIndexOf("/");
    const dir = slashIdx >= 0 ? file.path.slice(0, slashIdx) : "";
    const existing = groups.get(dir) ?? [];
    existing.push(file);
    groups.set(dir, existing);
  }

  return groups;
}

interface FileNodeProps {
  file: DocumentEntry;
  selectedPath: string | null;
  onSelectPath: (path: string) => void;
}

function FileNode({ file, selectedPath, onSelectPath }: FileNodeProps) {
  const isSelected = file.path === selectedPath;

  return (
    <button
      type="button"
      onClick={() => onSelectPath(file.path)}
      className={`w-full text-left px-2 py-1 rounded text-sm truncate flex items-center gap-1.5 transition-colors ${
        isSelected
          ? "bg-blue-100 text-blue-800 font-medium"
          : "text-gray-700 hover:bg-gray-100"
      }`}
      title={file.path}
    >
      <svg
        className="w-3.5 h-3.5 flex-shrink-0 text-gray-400"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
        />
      </svg>
      <span className="truncate">{file.name}</span>
    </button>
  );
}

interface DirGroupProps {
  dirPath: string;
  files: DocumentEntry[];
  selectedPath: string | null;
  onSelectPath: (path: string) => void;
}

function DirGroup({
  dirPath,
  files,
  selectedPath,
  onSelectPath,
}: DirGroupProps) {
  const displayName = dirPath.split("/").pop() ?? dirPath;

  return (
    <div className="mb-1">
      <div className="flex items-center gap-1 px-2 py-1 text-xs font-semibold text-gray-500 uppercase tracking-wide">
        <svg
          className="w-3.5 h-3.5 flex-shrink-0"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
          />
        </svg>
        <span>{displayName}</span>
      </div>
      <div className="ml-3 space-y-0.5">
        {files.map((file) => (
          <FileNode
            key={file.path}
            file={file}
            selectedPath={selectedPath}
            onSelectPath={onSelectPath}
          />
        ))}
      </div>
    </div>
  );
}

export function DocumentTree({
  files,
  selectedPath,
  onSelectPath,
}: DocumentTreeProps) {
  if (files.length === 0) {
    return (
      <p className="text-sm text-gray-400 italic px-2">No documents found.</p>
    );
  }

  const groups = groupFilesByDirectory(files);

  // Top-level files (no directory prefix)
  const topLevelFiles = groups.get("") ?? [];

  // Collect all directories (all keys except "")
  const dirs = Array.from(groups.keys())
    .filter((k) => k !== "")
    .sort();

  return (
    <nav aria-label="Document tree" className="space-y-1">
      {/* Top-level files */}
      {topLevelFiles.map((file) => (
        <FileNode
          key={file.path}
          file={file}
          selectedPath={selectedPath}
          onSelectPath={onSelectPath}
        />
      ))}

      {/* Directory groups */}
      {dirs.map((dir) => (
        <DirGroup
          key={dir}
          dirPath={dir}
          files={groups.get(dir) ?? []}
          selectedPath={selectedPath}
          onSelectPath={onSelectPath}
        />
      ))}
    </nav>
  );
}
