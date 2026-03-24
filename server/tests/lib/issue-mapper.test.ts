import { describe, test, expect } from "bun:test";
import { IssueMapper, type GitHubIssueNode } from "../../src/lib/issue-mapper";

// ---------------------------------------------------------------------------
// Helpers to build minimal GitHubIssueNode fixtures
// ---------------------------------------------------------------------------

function makeIssueNode(
  overrides: Partial<GitHubIssueNode> = {}
): GitHubIssueNode {
  return {
    number: 1,
    title: "Test Issue",
    body: "Issue body",
    state: "OPEN",
    createdAt: "2026-03-01T00:00:00Z",
    updatedAt: "2026-03-02T00:00:00Z",
    url: "https://github.com/owner/repo/issues/1",
    parent: null,
    labels: { nodes: [] },
    projectItems: { nodes: [] },
    comments: {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
    ...overrides,
  };
}

function makeProjectItem(statusName: string): GitHubIssueNode["projectItems"]["nodes"][number] {
  return {
    fieldValues: {
      nodes: [
        {
          name: statusName,
          field: { name: "Status" },
        },
      ],
    },
  };
}

const mapper = new IssueMapper();

// ---------------------------------------------------------------------------
// Type derivation from labels
// ---------------------------------------------------------------------------

describe("IssueMapper.mapIssue - type derivation", () => {
  test("hierarchy/backlog label -> type backlog", () => {
    const node = makeIssueNode({
      labels: { nodes: [{ name: "hierarchy/backlog" }] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.type).toBe("backlog");
  });

  test("hierarchy/epic label -> type epic", () => {
    const node = makeIssueNode({
      labels: { nodes: [{ name: "hierarchy/epic" }] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.type).toBe("epic");
  });

  test("hierarchy/story label -> type story", () => {
    const node = makeIssueNode({
      labels: { nodes: [{ name: "hierarchy/story" }] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.type).toBe("story");
  });

  test("type/docs label with no hierarchy label -> type docs", () => {
    const node = makeIssueNode({
      labels: { nodes: [{ name: "type/docs" }] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.type).toBe("docs");
  });

  test("type/docs label with hierarchy label -> hierarchy wins, type backlog", () => {
    const node = makeIssueNode({
      labels: { nodes: [{ name: "hierarchy/backlog" }, { name: "type/docs" }] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.type).toBe("backlog");
  });

  test("no matching label -> default type story", () => {
    const node = makeIssueNode({
      labels: { nodes: [{ name: "type/feature" }, { name: "difficulty/easy" }] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.type).toBe("story");
  });

  test("no labels at all -> default type story", () => {
    const node = makeIssueNode({ labels: { nodes: [] } });
    const result = mapper.mapIssue(node);
    expect(result.item.type).toBe("story");
  });
});

// ---------------------------------------------------------------------------
// Status mapping from project board field values
// ---------------------------------------------------------------------------

describe("IssueMapper.mapIssue - status mapping", () => {
  test('"Backlog" status -> backlog', () => {
    const node = makeIssueNode({
      projectItems: { nodes: [makeProjectItem("Backlog")] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("backlog");
  });

  test('"Ready" status -> ready', () => {
    const node = makeIssueNode({
      projectItems: { nodes: [makeProjectItem("Ready")] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("ready");
  });

  test('"In Progress" status -> in-progress', () => {
    const node = makeIssueNode({
      projectItems: { nodes: [makeProjectItem("In Progress")] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("in-progress");
  });

  test('"In Review" status -> in-review', () => {
    const node = makeIssueNode({
      projectItems: { nodes: [makeProjectItem("In Review")] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("in-review");
  });

  test('"Done" status -> done', () => {
    const node = makeIssueNode({
      projectItems: { nodes: [makeProjectItem("Done")] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("done");
  });

  test("status mapping is case-insensitive: IN PROGRESS -> in-progress", () => {
    const node = makeIssueNode({
      projectItems: { nodes: [makeProjectItem("IN PROGRESS")] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("in-progress");
  });

  test("status mapping is case-insensitive: in review -> in-review", () => {
    const node = makeIssueNode({
      projectItems: { nodes: [makeProjectItem("in review")] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("in-review");
  });

  test("no projectItems -> default status backlog", () => {
    const node = makeIssueNode({ projectItems: { nodes: [] } });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("backlog");
  });

  test("projectItems with no Status field -> default status backlog", () => {
    const node = makeIssueNode({
      projectItems: {
        nodes: [
          {
            fieldValues: {
              nodes: [{ name: "SomeValue", field: { name: "Assignee" } }],
            },
          },
        ],
      },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("backlog");
  });

  test("unknown status value -> default status backlog", () => {
    const node = makeIssueNode({
      projectItems: { nodes: [makeProjectItem("UnknownStatus")] },
    });
    const result = mapper.mapIssue(node);
    expect(result.item.status).toBe("backlog");
  });
});

// ---------------------------------------------------------------------------
// State mapping
// ---------------------------------------------------------------------------

describe("IssueMapper.mapIssue - state mapping", () => {
  test("OPEN state -> open", () => {
    const node = makeIssueNode({ state: "OPEN" });
    const result = mapper.mapIssue(node);
    expect(result.item.state).toBe("open");
  });

  test("CLOSED state -> closed", () => {
    const node = makeIssueNode({ state: "CLOSED" });
    const result = mapper.mapIssue(node);
    expect(result.item.state).toBe("closed");
  });
});

// ---------------------------------------------------------------------------
// Comment author null handling
// ---------------------------------------------------------------------------

describe("IssueMapper.mapIssue - comment author handling", () => {
  test("comment with author -> uses author.login", () => {
    const node = makeIssueNode({
      comments: {
        totalCount: 1,
        pageInfo: { hasNextPage: false, endCursor: null },
        nodes: [
          {
            body: "A comment",
            author: { login: "carlosboeing" },
            createdAt: "2026-03-01T12:00:00Z",
            updatedAt: "2026-03-01T12:00:00Z",
          },
        ],
      },
    });
    const result = mapper.mapIssue(node);
    expect(result.comments[0].author).toBe("carlosboeing");
  });

  test("comment with null author -> defaults to 'unknown'", () => {
    const node = makeIssueNode({
      comments: {
        totalCount: 1,
        pageInfo: { hasNextPage: false, endCursor: null },
        nodes: [
          {
            body: "A comment",
            author: null,
            createdAt: "2026-03-01T12:00:00Z",
            updatedAt: "2026-03-01T12:00:00Z",
          },
        ],
      },
    });
    const result = mapper.mapIssue(node);
    expect(result.comments[0].author).toBe("unknown");
  });
});

// ---------------------------------------------------------------------------
// Full MappedIssue shape
// ---------------------------------------------------------------------------

describe("IssueMapper.mapIssue - full output shape", () => {
  test("maps all core fields correctly", () => {
    const node = makeIssueNode({
      number: 42,
      title: "My Backlog Item",
      body: "Description text",
      state: "OPEN",
      createdAt: "2026-03-01T10:00:00Z",
      updatedAt: "2026-03-02T10:00:00Z",
      url: "https://github.com/owner/repo/issues/42",
      labels: { nodes: [{ name: "hierarchy/backlog" }] },
      projectItems: { nodes: [makeProjectItem("In Progress")] },
    });

    const result = mapper.mapIssue(node);

    expect(result.item.id).toBe(42);
    expect(result.item.title).toBe("My Backlog Item");
    expect(result.item.body).toBe("Description text");
    expect(result.item.type).toBe("backlog");
    expect(result.item.status).toBe("in-progress");
    expect(result.item.state).toBe("open");
    expect(result.item.externalId).toBe("42");
    expect(result.item.externalUrl).toBe("https://github.com/owner/repo/issues/42");
    expect(result.item.createdAt).toBe("2026-03-01T10:00:00Z");
    expect(result.item.updatedAt).toBe("2026-03-02T10:00:00Z");
  });

  test("null body is preserved as null", () => {
    const node = makeIssueNode({ body: null });
    const result = mapper.mapIssue(node);
    expect(result.item.body).toBeNull();
  });

  test("parent number is extracted from issue.parent", () => {
    const node = makeIssueNode({ parent: { number: 100 } });
    const result = mapper.mapIssue(node);
    expect(result.parentNumber).toBe(100);
  });

  test("null parent -> parentNumber is null", () => {
    const node = makeIssueNode({ parent: null });
    const result = mapper.mapIssue(node);
    expect(result.parentNumber).toBeNull();
  });

  test("labels array contains label names", () => {
    const node = makeIssueNode({
      labels: {
        nodes: [
          { name: "hierarchy/story" },
          { name: "difficulty/easy" },
          { name: "backlog/364-github-sqlite-sync" },
        ],
      },
    });
    const result = mapper.mapIssue(node);
    expect(result.labels).toEqual([
      "hierarchy/story",
      "difficulty/easy",
      "backlog/364-github-sqlite-sync",
    ]);
  });

  test("maps multiple comments", () => {
    const node = makeIssueNode({
      comments: {
        totalCount: 2,
        pageInfo: { hasNextPage: false, endCursor: null },
        nodes: [
          {
            body: "First comment",
            author: { login: "alice" },
            createdAt: "2026-03-01T10:00:00Z",
            updatedAt: "2026-03-01T10:00:00Z",
          },
          {
            body: "Second comment",
            author: { login: "bob" },
            createdAt: "2026-03-02T10:00:00Z",
            updatedAt: "2026-03-02T10:00:00Z",
          },
        ],
      },
    });
    const result = mapper.mapIssue(node);
    expect(result.comments).toHaveLength(2);
    expect(result.comments[0].body).toBe("First comment");
    expect(result.comments[0].author).toBe("alice");
    expect(result.comments[1].body).toBe("Second comment");
    expect(result.comments[1].author).toBe("bob");
  });
});
