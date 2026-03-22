import { z } from "zod";

// ---------------------------------------------------------------------------
// Shared enum schemas derived from domain types
// ---------------------------------------------------------------------------

export const ItemTypeSchema = z.enum(["backlog", "epic", "story", "docs"]);

export const BoardStatusSchema = z.enum([
  "backlog",
  "ready",
  "in-progress",
  "in-review",
  "done",
]);

export const ItemStateSchema = z.enum(["open", "closed"]);

// ---------------------------------------------------------------------------
// Request schemas
// ---------------------------------------------------------------------------

/** Body for POST /api/items */
export const CreateItemBodySchema = z.object({
  title: z.string().min(1, "title is required"),
  type: ItemTypeSchema,
  body: z.string().optional(),
  status: BoardStatusSchema.optional(),
  state: ItemStateSchema.optional(),
  parentId: z.number().int().positive().optional(),
  externalId: z.string().optional(),
  externalUrl: z.string().optional(),
  createdBy: z.string().optional(),
  labels: z.array(z.string()).optional(),
});

/** Body for PATCH /api/items/:id */
export const UpdateItemBodySchema = z
  .object({
    title: z.string().min(1).optional(),
    body: z.string().optional(),
    externalId: z.string().optional(),
    externalUrl: z.string().optional(),
  })
  .refine(
    (data) =>
      data.title !== undefined ||
      data.body !== undefined ||
      data.externalId !== undefined ||
      data.externalUrl !== undefined,
    {
      message: "At least one updatable field must be provided",
    }
  );

/** Query params for GET /api/items */
export const ListItemsQuerySchema = z.object({
  type: ItemTypeSchema.optional(),
  status: BoardStatusSchema.optional(),
  state: ItemStateSchema.optional(),
  label: z.string().optional(),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? Number(v) : undefined))
    .pipe(z.number().int().positive().optional()),
});

/** Body for POST /api/labels */
export const CreateLabelBodySchema = z.object({
  name: z.string().min(1, "name is required"),
  color: z.string().optional(),
  description: z.string().optional(),
});

// ---------------------------------------------------------------------------
// Error format helpers
// ---------------------------------------------------------------------------

/** Standard validation error response shape. */
export interface ValidationErrorResponse {
  error: string;
  details: Array<{ field: string; message: string }>;
}

/** Convert Zod validation errors into the standard error response. */
export function formatZodError(err: z.ZodError): ValidationErrorResponse {
  return {
    error: "Validation failed",
    details: err.errors.map((issue) => ({
      field: issue.path.join(".") || "(root)",
      message: issue.message,
    })),
  };
}
