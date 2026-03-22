import { Hono } from "hono";
import { DocumentService } from "../services/documents";
import { CommentService } from "../services/comments";
import { AddDocumentCommentBodySchema, formatZodError } from "./validation";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Extract the document path from a request path.
 *
 * The router is mounted at /api, so request paths look like:
 *   /api/documents/readme.md
 *   /api/documents/design/overview.md/comments
 *
 * We strip the "/api/documents/" prefix to get the relative file path.
 */
function extractDocPath(reqPath: string): string {
  const prefix = "/api/documents/";
  if (reqPath.startsWith(prefix)) {
    return reqPath.slice(prefix.length);
  }
  return reqPath;
}

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/**
 * Create the documents Hono router.
 *
 * Routes:
 *   GET  /api/documents                   — List markdown files in docs/ tree
 *   GET  /api/documents/:path             — Read a specific markdown file
 *   GET  /api/documents/:path/comments    — List comments for a document
 *   POST /api/documents/:path/comments    — Add a comment (with optional anchor)
 *
 * Security:
 * - All :path parameters are validated with DocumentService.isPathSafe().
 * - Paths containing ".." or starting with "/" are rejected with 400.
 * - After joining with docsDir, the resolved path must remain under docsDir.
 *
 * Routing note:
 * - Hono wildcard routes (`/documents/*`) are used because path params do not
 *   capture slashes. The wildcard captures everything after /documents/, and
 *   a trailing /comments suffix disambiguates file reads from comment reads.
 *
 * @param documentService - DocumentService instance (reads files from disk)
 * @param commentService  - CommentService instance (reads/writes DB comments)
 */
export function createDocumentsRouter(
  documentService: DocumentService,
  commentService: CommentService
): Hono {
  const router = new Hono();

  // ---------------------------------------------------------------------------
  // GET /api/documents — list all markdown files
  // ---------------------------------------------------------------------------

  router.get("/documents", async (c) => {
    const files = await documentService.listFiles();
    return c.json(files);
  });

  // ---------------------------------------------------------------------------
  // GET /api/documents/* — read file or list comments
  //
  // Routing strategy: a single wildcard catches all paths under /documents/.
  // The trailing /comments suffix distinguishes the two operations.
  // ---------------------------------------------------------------------------

  router.get("/documents/*", async (c) => {
    const rawDocPath = extractDocPath(c.req.path);
    const decodedPath = decodeURIComponent(rawDocPath);

    // Dispatch: GET /api/documents/:path/comments
    if (decodedPath.endsWith("/comments")) {
      const filePath = decodedPath.slice(0, -"/comments".length);

      if (!documentService.isPathSafe(filePath)) {
        return c.json(
          { error: "Invalid path — traversal or absolute paths not allowed", details: [] },
          400
        );
      }

      const comments = await commentService.listDocumentComments(filePath);
      return c.json(comments);
    }

    // Dispatch: GET /api/documents/:path
    if (!documentService.isPathSafe(decodedPath)) {
      return c.json(
        { error: "Invalid path — traversal or absolute paths not allowed", details: [] },
        400
      );
    }

    let content: string | null;
    try {
      content = await documentService.readFile(decodedPath);
    } catch {
      return c.json(
        { error: "Invalid path — traversal or absolute paths not allowed", details: [] },
        400
      );
    }

    if (content === null) {
      return c.json({ error: `Document not found: ${decodedPath}`, details: [] }, 404);
    }

    const parts = decodedPath.split("/");
    const name = parts[parts.length - 1];

    return c.json({ path: decodedPath, name, content });
  });

  // ---------------------------------------------------------------------------
  // POST /api/documents/* — add comment
  // ---------------------------------------------------------------------------

  router.post("/documents/*", async (c) => {
    const rawDocPath = extractDocPath(c.req.path);
    const decodedPath = decodeURIComponent(rawDocPath);

    // Only /comments suffix is supported for POST
    if (!decodedPath.endsWith("/comments")) {
      return c.json({ error: "Method not allowed", details: [] }, 405);
    }

    const filePath = decodedPath.slice(0, -"/comments".length);

    if (!documentService.isPathSafe(filePath)) {
      return c.json(
        { error: "Invalid path — traversal or absolute paths not allowed", details: [] },
        400
      );
    }

    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return c.json({ error: "Invalid JSON body", details: [] }, 400);
    }

    const parseResult = AddDocumentCommentBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const comment = await commentService.addComment({
      documentPath: filePath,
      body: parseResult.data.body,
      author: parseResult.data.author,
      anchor: parseResult.data.anchor,
      threadId: parseResult.data.thread_id,
    });

    return c.json(comment, 201);
  });

  return router;
}
