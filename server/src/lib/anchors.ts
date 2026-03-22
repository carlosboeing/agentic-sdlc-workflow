/**
 * Paragraph anchor generation utilities for document comment threading.
 *
 * Headings get slugified anchor IDs (e.g., "## Design Decisions" -> "design-decisions").
 * Paragraphs get sequential index anchors (e.g., "p-0", "p-1", "p-2").
 *
 * These anchors are used to:
 * 1. Match comments to their position in the document
 * 2. Detect stale comments when headings are renamed
 * 3. Generate stable IDs for the MarkdownViewer component
 */

/** Anchor entry describing a single anchorable element in a document. */
export interface AnchorEntry {
  /** "heading" for h1-h6 elements, "paragraph" for text paragraphs. */
  type: "heading" | "paragraph";
  /** The anchor ID string: slugified text for headings, "p-N" for paragraphs. */
  anchor: string;
  /** Heading level (1-6). Only present for heading type. */
  level?: number;
}

/**
 * Convert a heading text to a slug suitable for use as an HTML id.
 * Mirrors GitHub's heading anchor algorithm:
 * - Lowercase
 * - Remove non-word characters (except spaces and hyphens)
 * - Replace spaces with hyphens
 * - Collapse consecutive hyphens
 * - Trim leading/trailing hyphens
 */
export function slugifyHeading(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

/**
 * Parse markdown content and generate an ordered list of anchor entries.
 *
 * Each heading (h1-h6) gets a slugified anchor. Each paragraph (non-empty
 * text block between blank lines that isn't a heading) gets a sequential
 * index anchor ("p-0", "p-1", etc.).
 *
 * This function operates on raw markdown text, not on an AST. It handles
 * the common case of ATX-style headings (# prefix) and text paragraphs
 * separated by blank lines. It does not handle setext-style headings
 * (underline with = or -) as those are rarely used in this project.
 */
export function generateParagraphAnchors(markdown: string): AnchorEntry[] {
  if (!markdown.trim()) return [];

  const anchors: AnchorEntry[] = [];
  let paragraphIndex = 0;

  // Split into blocks separated by blank lines
  const blocks = markdown.split(/\n{2,}/);

  for (const block of blocks) {
    const trimmed = block.trim();
    if (!trimmed) continue;

    // Check if block is a heading (ATX style: # ... ######)
    const headingMatch = trimmed.match(/^(#{1,6})\s+(.+)$/m);
    if (headingMatch) {
      const level = headingMatch[1].length;
      const text = headingMatch[2].trim();
      anchors.push({
        type: "heading",
        anchor: slugifyHeading(text),
        level,
      });
      continue;
    }

    // Not a heading — treat as paragraph
    anchors.push({
      type: "paragraph",
      anchor: `p-${paragraphIndex}`,
    });
    paragraphIndex++;
  }

  return anchors;
}

/**
 * Detect stale anchors: comments whose anchor IDs no longer exist in the document.
 *
 * @param documentAnchors - Array of anchor IDs currently in the document
 * @param commentAnchors - Array of anchor IDs from comments (null means no anchor)
 * @returns Array of stale anchor IDs
 */
export function findStaleAnchors(
  documentAnchors: string[],
  commentAnchors: (string | null)[]
): string[] {
  const anchorSet = new Set(documentAnchors);
  return commentAnchors.filter(
    (a): a is string => a !== null && !anchorSet.has(a)
  );
}
