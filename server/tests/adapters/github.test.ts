import { describe, test, expect, beforeEach, mock, spyOn } from "bun:test";
import { GitHubAdapter, type GitHubAdapterConfig } from "../../src/adapters/github";
import type {
  SyncCreatePayload,
  SyncUpdatePayload,
  SyncClosePayload,
  SyncSetStatusPayload,
  SyncCommentPayload,
  SyncLinkChildPayload,
} from "../../src/types/sync";

// ---------------------------------------------------------------------------
// Subprocess mock helpers
// ---------------------------------------------------------------------------

/**
 * Mock return value for Bun.spawn / child_process.spawnSync calls.
 * We mock at the module level so tests don't touch the real GitHub API.
 */
type MockSubprocessResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
};

function makeSubprocessMock(
  overrides: Partial<MockSubprocessResult> = {}
): MockSubprocessResult {
  return {
    stdout: "",
    stderr: "",
    exitCode: 0,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Test fixture
// ---------------------------------------------------------------------------

const DEFAULT_CONFIG: GitHubAdapterConfig = {
  repo: "owner/test-repo",
  projectId: "PVT_test123",
  statusFieldId: "PVTSSF_test456",
  boardStatus: {
    backlog: "opt_backlog",
    ready: "opt_ready",
    "in-progress": "opt_inprogress",
    "in-review": "opt_inreview",
    done: "opt_done",
  },
};

// ---------------------------------------------------------------------------
// createItem
// ---------------------------------------------------------------------------

describe("GitHubAdapter.createItem", () => {
  let adapter: GitHubAdapter;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    adapter = new GitHubAdapter(DEFAULT_CONFIG);
    // Spy on the internal _runGh helper so we can inject mock output
    runGhSpy = spyOn(adapter as unknown as Record<string, unknown>, "_runGh");
  });

  test("calls gh issue create with title, body, and labels", async () => {
    runGhSpy.mockResolvedValue({
      stdout: "https://github.com/owner/test-repo/issues/42\n",
      stderr: "",
      exitCode: 0,
    });

    const payload: SyncCreatePayload = {
      itemId: 1,
      title: "New Story",
      type: "story",
      body: "Story body text",
      labels: ["hierarchy/story", "difficulty/easy"],
    };

    const result = await adapter.createItem(payload);

    expect(result.externalId).toBe("42");
    expect(result.url).toBe("https://github.com/owner/test-repo/issues/42");
    expect(runGhSpy).toHaveBeenCalledTimes(1);

    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).toContain("issue");
    expect(args).toContain("create");
    expect(args).toContain("--title");
    expect(args).toContain("New Story");
    expect(args).toContain("--body");
    expect(args).toContain("Story body text");
    expect(args).toContain("--label");
  });

  test("calls gh issue create without labels when none provided", async () => {
    runGhSpy.mockResolvedValue({
      stdout: "https://github.com/owner/test-repo/issues/10\n",
      stderr: "",
      exitCode: 0,
    });

    const payload: SyncCreatePayload = {
      itemId: 2,
      title: "No Labels Item",
      type: "backlog",
    };

    const result = await adapter.createItem(payload);

    expect(result.externalId).toBe("10");
    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).not.toContain("--label");
  });

  test("extracts issue number from URL with trailing newline", async () => {
    runGhSpy.mockResolvedValue({
      stdout: "https://github.com/owner/test-repo/issues/999\n",
      stderr: "",
      exitCode: 0,
    });

    const payload: SyncCreatePayload = { itemId: 3, title: "T", type: "epic" };
    const result = await adapter.createItem(payload);

    expect(result.externalId).toBe("999");
    expect(result.url).toBe("https://github.com/owner/test-repo/issues/999");
  });

  test("throws on non-zero exit code", async () => {
    runGhSpy.mockResolvedValue({
      stdout: "",
      stderr: "gh: error: not authorized",
      exitCode: 1,
    });

    const payload: SyncCreatePayload = { itemId: 4, title: "Fail", type: "story" };

    await expect(adapter.createItem(payload)).rejects.toThrow(/gh issue create failed/);
  });

  test("throws when URL has no numeric issue number", async () => {
    runGhSpy.mockResolvedValue({
      stdout: "not-a-url\n",
      stderr: "",
      exitCode: 0,
    });

    const payload: SyncCreatePayload = { itemId: 5, title: "Bad URL", type: "story" };

    await expect(adapter.createItem(payload)).rejects.toThrow(/Could not extract issue number/);
  });
});

// ---------------------------------------------------------------------------
// updateItem
// ---------------------------------------------------------------------------

describe("GitHubAdapter.updateItem", () => {
  let adapter: GitHubAdapter;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    adapter = new GitHubAdapter(DEFAULT_CONFIG);
    runGhSpy = spyOn(adapter as unknown as Record<string, unknown>, "_runGh");
    runGhSpy.mockResolvedValue(makeSubprocessMock());
  });

  test("calls gh issue edit with title", async () => {
    const payload: SyncUpdatePayload = {
      itemId: 1,
      externalId: "42",
      changes: { title: "Updated Title" },
    };

    await adapter.updateItem(payload);

    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).toContain("issue");
    expect(args).toContain("edit");
    expect(args).toContain("42");
    expect(args).toContain("--title");
    expect(args).toContain("Updated Title");
    expect(args).not.toContain("--body");
  });

  test("calls gh issue edit with body", async () => {
    const payload: SyncUpdatePayload = {
      itemId: 1,
      externalId: "42",
      changes: { body: "New body content" },
    };

    await adapter.updateItem(payload);

    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).toContain("--body");
    expect(args).toContain("New body content");
    expect(args).not.toContain("--title");
  });

  test("calls gh issue edit with both title and body", async () => {
    const payload: SyncUpdatePayload = {
      itemId: 1,
      externalId: "55",
      changes: { title: "New title", body: "New body" },
    };

    await adapter.updateItem(payload);

    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).toContain("--title");
    expect(args).toContain("--body");
  });

  test("includes --repo flag", async () => {
    const payload: SyncUpdatePayload = {
      itemId: 1,
      externalId: "42",
      changes: { title: "X" },
    };

    await adapter.updateItem(payload);

    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).toContain("--repo");
    expect(args).toContain("owner/test-repo");
  });

  test("throws on non-zero exit code", async () => {
    runGhSpy.mockResolvedValue({ stdout: "", stderr: "permission denied", exitCode: 1 });

    const payload: SyncUpdatePayload = {
      itemId: 1,
      externalId: "42",
      changes: { title: "X" },
    };

    await expect(adapter.updateItem(payload)).rejects.toThrow(/gh issue edit failed/);
  });
});

// ---------------------------------------------------------------------------
// closeItem
// ---------------------------------------------------------------------------

describe("GitHubAdapter.closeItem", () => {
  let adapter: GitHubAdapter;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    adapter = new GitHubAdapter(DEFAULT_CONFIG);
    runGhSpy = spyOn(adapter as unknown as Record<string, unknown>, "_runGh");
    runGhSpy.mockResolvedValue(makeSubprocessMock());
  });

  test("calls gh issue close with external ID", async () => {
    const payload: SyncClosePayload = { itemId: 1, externalId: "77" };

    await adapter.closeItem(payload);

    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).toContain("issue");
    expect(args).toContain("close");
    expect(args).toContain("77");
    expect(args).toContain("--repo");
    expect(args).toContain("owner/test-repo");
  });

  test("succeeds even if gh says already closed (idempotent)", async () => {
    runGhSpy.mockResolvedValue({
      stdout: "",
      stderr: "Issue is already closed",
      exitCode: 0,
    });

    const payload: SyncClosePayload = { itemId: 1, externalId: "77" };
    await expect(adapter.closeItem(payload)).resolves.toBeUndefined();
  });

  test("throws on non-zero exit code", async () => {
    runGhSpy.mockResolvedValue({ stdout: "", stderr: "network error", exitCode: 1 });

    const payload: SyncClosePayload = { itemId: 1, externalId: "77" };
    await expect(adapter.closeItem(payload)).rejects.toThrow(/gh issue close failed/);
  });
});

// ---------------------------------------------------------------------------
// setStatus
// ---------------------------------------------------------------------------

describe("GitHubAdapter.setStatus", () => {
  let adapter: GitHubAdapter;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    adapter = new GitHubAdapter(DEFAULT_CONFIG);
    runGhSpy = spyOn(adapter as unknown as Record<string, unknown>, "_runGh");
  });

  test("fetches project item ID then calls item-edit with correct option ID", async () => {
    // First call: GraphQL query to get item ID
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({
        data: {
          repository: {
            issue: {
              projectItems: {
                nodes: [{ id: "PVTI_board_item_123" }],
              },
            },
          },
        },
      }),
      stderr: "",
      exitCode: 0,
    });
    // Second call: project item-edit mutation
    runGhSpy.mockResolvedValueOnce(makeSubprocessMock());

    const payload: SyncSetStatusPayload = {
      itemId: 1,
      externalId: "42",
      status: "in-progress",
    };

    await adapter.setStatus(payload);

    expect(runGhSpy).toHaveBeenCalledTimes(2);

    // First call should be the GraphQL query
    const [firstArgs] = runGhSpy.mock.calls[0] as [string[]];
    expect(firstArgs).toContain("api");
    expect(firstArgs).toContain("graphql");

    // Second call should be project item-edit
    const [secondArgs] = runGhSpy.mock.calls[1] as [string[]];
    expect(secondArgs).toContain("project");
    expect(secondArgs).toContain("item-edit");
    expect(secondArgs).toContain("--project-id");
    expect(secondArgs).toContain("PVT_test123");
    expect(secondArgs).toContain("--id");
    expect(secondArgs).toContain("PVTI_board_item_123");
    expect(secondArgs).toContain("--field-id");
    expect(secondArgs).toContain("PVTSSF_test456");
    expect(secondArgs).toContain("--single-select-option-id");
    expect(secondArgs).toContain("opt_inprogress");
  });

  test("maps all status values to correct option IDs", async () => {
    const statusMap: Array<[SyncSetStatusPayload["status"], string]> = [
      ["backlog", "opt_backlog"],
      ["ready", "opt_ready"],
      ["in-progress", "opt_inprogress"],
      ["in-review", "opt_inreview"],
      ["done", "opt_done"],
    ];

    for (const [status, expectedOptionId] of statusMap) {
      runGhSpy.mockResolvedValueOnce({
        stdout: JSON.stringify({
          data: {
            repository: {
              issue: { projectItems: { nodes: [{ id: "PVTI_item_abc" }] } },
            },
          },
        }),
        stderr: "",
        exitCode: 0,
      });
      runGhSpy.mockResolvedValueOnce(makeSubprocessMock());

      await adapter.setStatus({ itemId: 1, externalId: "42", status });

      const lastCallArgs = runGhSpy.mock.calls[runGhSpy.mock.calls.length - 1] as [string[]];
      expect(lastCallArgs[0]).toContain(expectedOptionId);
    }
  });

  test("throws when project item not found", async () => {
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({
        data: {
          repository: {
            issue: { projectItems: { nodes: [] } },
          },
        },
      }),
      stderr: "",
      exitCode: 0,
    });

    const payload: SyncSetStatusPayload = {
      itemId: 1,
      externalId: "42",
      status: "done",
    };

    await expect(adapter.setStatus(payload)).rejects.toThrow(/not found on project board/);
  });

  test("throws when GraphQL call fails", async () => {
    runGhSpy.mockResolvedValueOnce({
      stdout: "",
      stderr: "API error",
      exitCode: 1,
    });

    const payload: SyncSetStatusPayload = {
      itemId: 1,
      externalId: "42",
      status: "done",
    };

    await expect(adapter.setStatus(payload)).rejects.toThrow(/Failed to fetch project item/);
  });

  test("throws when item-edit fails", async () => {
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({
        data: {
          repository: {
            issue: { projectItems: { nodes: [{ id: "PVTI_item_abc" }] } },
          },
        },
      }),
      stderr: "",
      exitCode: 0,
    });
    runGhSpy.mockResolvedValueOnce({
      stdout: "",
      stderr: "mutation failed",
      exitCode: 1,
    });

    const payload: SyncSetStatusPayload = {
      itemId: 1,
      externalId: "42",
      status: "done",
    };

    await expect(adapter.setStatus(payload)).rejects.toThrow(/gh project item-edit failed/);
  });
});

// ---------------------------------------------------------------------------
// addComment
// ---------------------------------------------------------------------------

describe("GitHubAdapter.addComment", () => {
  let adapter: GitHubAdapter;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    adapter = new GitHubAdapter(DEFAULT_CONFIG);
    runGhSpy = spyOn(adapter as unknown as Record<string, unknown>, "_runGh");
    runGhSpy.mockResolvedValue(makeSubprocessMock());
  });

  test("calls gh issue comment with external ID and body", async () => {
    const payload: SyncCommentPayload = {
      itemId: 1,
      externalId: "88",
      body: "This is a comment",
      author: "builder",
    };

    await adapter.addComment(payload);

    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).toContain("issue");
    expect(args).toContain("comment");
    expect(args).toContain("88");
    expect(args).toContain("--body");
    expect(args).toContain("This is a comment");
    expect(args).toContain("--repo");
    expect(args).toContain("owner/test-repo");
  });

  test("throws on non-zero exit code", async () => {
    runGhSpy.mockResolvedValue({ stdout: "", stderr: "rate limited", exitCode: 1 });

    const payload: SyncCommentPayload = {
      itemId: 1,
      externalId: "88",
      body: "Comment",
      author: "builder",
    };

    await expect(adapter.addComment(payload)).rejects.toThrow(/gh issue comment failed/);
  });
});

// ---------------------------------------------------------------------------
// linkChild
// ---------------------------------------------------------------------------

describe("GitHubAdapter.linkChild", () => {
  let adapter: GitHubAdapter;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    adapter = new GitHubAdapter(DEFAULT_CONFIG);
    runGhSpy = spyOn(adapter as unknown as Record<string, unknown>, "_runGh");
  });

  test("fetches node IDs then calls addSubIssue GraphQL mutation", async () => {
    // First call: fetch parent node ID
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({ id: "I_parent_node_id" }),
      stderr: "",
      exitCode: 0,
    });
    // Second call: fetch child node ID
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({ id: "I_child_node_id" }),
      stderr: "",
      exitCode: 0,
    });
    // Third call: GraphQL addSubIssue mutation
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({ data: { addSubIssue: { subIssue: { id: "I_child_node_id" } } } }),
      stderr: "",
      exitCode: 0,
    });

    const payload: SyncLinkChildPayload = {
      parentItemId: 10,
      childItemId: 20,
      parentExternalId: "100",
      childExternalId: "200",
    };

    await adapter.linkChild(payload);

    expect(runGhSpy).toHaveBeenCalledTimes(3);

    // First two calls: gh issue view --json id
    const [firstArgs] = runGhSpy.mock.calls[0] as [string[]];
    expect(firstArgs).toContain("issue");
    expect(firstArgs).toContain("view");
    expect(firstArgs).toContain("100");
    expect(firstArgs).toContain("--json");
    expect(firstArgs).toContain("id");

    const [secondArgs] = runGhSpy.mock.calls[1] as [string[]];
    expect(secondArgs).toContain("200");

    // Third call: GraphQL addSubIssue mutation
    const [thirdArgs] = runGhSpy.mock.calls[2] as [string[]];
    expect(thirdArgs).toContain("api");
    expect(thirdArgs).toContain("graphql");
    const queryIndex = thirdArgs.indexOf("-f");
    if (queryIndex !== -1) {
      const queryArg = thirdArgs[queryIndex + 1];
      expect(queryArg).toContain("addSubIssue");
      expect(queryArg).toContain("I_parent_node_id");
      expect(queryArg).toContain("I_child_node_id");
    }
  });

  test("throws when parent node ID fetch fails", async () => {
    runGhSpy.mockResolvedValueOnce({ stdout: "", stderr: "not found", exitCode: 1 });

    const payload: SyncLinkChildPayload = {
      parentItemId: 10,
      childItemId: 20,
      parentExternalId: "100",
      childExternalId: "200",
    };

    await expect(adapter.linkChild(payload)).rejects.toThrow(/Could not fetch node ID for issue/);
  });

  test("throws when child node ID fetch fails", async () => {
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({ id: "I_parent_node_id" }),
      stderr: "",
      exitCode: 0,
    });
    runGhSpy.mockResolvedValueOnce({ stdout: "", stderr: "not found", exitCode: 1 });

    const payload: SyncLinkChildPayload = {
      parentItemId: 10,
      childItemId: 20,
      parentExternalId: "100",
      childExternalId: "200",
    };

    await expect(adapter.linkChild(payload)).rejects.toThrow(/Could not fetch node ID for issue/);
  });

  test("throws when addSubIssue mutation fails", async () => {
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({ id: "I_parent_node_id" }),
      stderr: "",
      exitCode: 0,
    });
    runGhSpy.mockResolvedValueOnce({
      stdout: JSON.stringify({ id: "I_child_node_id" }),
      stderr: "",
      exitCode: 0,
    });
    runGhSpy.mockResolvedValueOnce({
      stdout: "",
      stderr: "GraphQL error",
      exitCode: 1,
    });

    const payload: SyncLinkChildPayload = {
      parentItemId: 10,
      childItemId: 20,
      parentExternalId: "100",
      childExternalId: "200",
    };

    await expect(adapter.linkChild(payload)).rejects.toThrow(/addSubIssue mutation failed/);
  });
});

// ---------------------------------------------------------------------------
// GitHubAdapterConfig validation
// ---------------------------------------------------------------------------

describe("GitHubAdapter configuration", () => {
  test("accepts a minimal valid config", () => {
    const config: GitHubAdapterConfig = {
      repo: "org/repo",
      projectId: "PVT_abc",
      statusFieldId: "PVTSSF_xyz",
      boardStatus: {
        backlog: "o1",
        ready: "o2",
        "in-progress": "o3",
        "in-review": "o4",
        done: "o5",
      },
    };

    expect(() => new GitHubAdapter(config)).not.toThrow();
  });
});
