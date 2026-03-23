import { eq } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "../db/schema";
import type { EventService } from "../api/websocket";

type Db = ReturnType<typeof drizzle>;

/** Row type returned from comments table queries. */
export type Comment = typeof schema.comments.$inferSelect;

/** Input for creating a new comment. */
export interface AddCommentInput {
  itemId?: number | null;
  body: string;
  author: string;
  documentPath?: string;
  anchor?: string;
  threadId?: string;
}

/**
 * Service for comment operations on work items and documents.
 * Supports item comments, document comments, and threaded replies.
 * Optionally accepts an EventService to broadcast real-time events.
 */
export class CommentService {
  constructor(
    private readonly db: Db,
    private readonly eventService?: EventService
  ) {}

  /** Add a comment to an item or document. Returns the created comment. */
  async addComment(input: AddCommentInput): Promise<Comment> {
    const now = new Date().toISOString();

    const rows = this.db
      .insert(schema.comments)
      .values({
        itemId: input.itemId ?? null,
        body: input.body,
        author: input.author,
        documentPath: input.documentPath ?? null,
        anchor: input.anchor ?? null,
        threadId: input.threadId ?? null,
        createdAt: now,
        updatedAt: now,
      })
      .returning()
      .all();

    const comment = rows[0];

    // Log activity for item comments
    if (input.itemId) {
      this.db
        .insert(schema.activityLog)
        .values({
          itemId: input.itemId,
          eventType: "comment:added",
          payload: JSON.stringify({
            commentId: comment.id,
            author: input.author,
          }),
          createdAt: now,
        })
        .run();

      // Broadcast real-time event
      this.eventService?.broadcast(
        {
          type: "comment:added",
          data: { commentId: comment.id, itemId: input.itemId, author: input.author },
          itemId: input.itemId,
        },
        { persistToDb: false }
      );
    }

    return comment;
  }

  /** List all comments for a given item, ordered by creation time. */
  async listComments(itemId: number): Promise<Comment[]> {
    return this.db
      .select()
      .from(schema.comments)
      .where(eq(schema.comments.itemId, itemId))
      .all();
  }

  /** List all comments for a given document path, ordered by creation time. */
  async listDocumentComments(documentPath: string): Promise<Comment[]> {
    return this.db
      .select()
      .from(schema.comments)
      .where(eq(schema.comments.documentPath, documentPath))
      .all();
  }
}
