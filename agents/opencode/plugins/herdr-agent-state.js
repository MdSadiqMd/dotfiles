// installed by herdr
// managed by herdr; reinstalling or updating the integration overwrites this file.
// add custom hooks/plugins beside this file instead of editing it.
// HERDR_INTEGRATION_ID=opencode
// HERDR_INTEGRATION_VERSION=10
// Ported to the OpenCode V2 plugin API (default export with id + setup):
// chat.message hook → ctx.session.hook("prompt"), and V1 event names/property
// locations updated to the V2 event stream.

import net from "node:net";

const SOURCE = "herdr:opencode";
const AGENT = "opencode";
let reportSeq = Date.now() * 1000;
let requestChain = Promise.resolve();
let reportedRootSessionID;

// Track child sessions so their events cannot replace the pane's root session.
// Their user prompts still project state without attaching the child session id.
const childSessions = new Set();
const CHILD_EVENT_STATES = new Map([
  ["permission.asked", "blocked"],
  ["form.created", "blocked"],
  ["permission.replied", "working"],
  ["form.replied", "working"],
  ["form.cancelled", "working"],
]);

function nextReportSeq() {
  reportSeq += 1;
  return reportSeq;
}

function sessionIDFromEventData(data) {
  const direct = data?.sessionID;
  if (typeof direct === "string" && direct) return direct;
  const nested = data?.form?.sessionID ?? data?.session?.sessionID ?? data?.message?.sessionID;
  return typeof nested === "string" && nested ? nested : undefined;
}

const SESSION_STATE_BY_STATUS = new Map([
  ["idle", "idle"],
  ["active", "working"],
  ["busy", "working"],
  ["pending", "working"],
  ["retry", "working"],
  ["running", "working"],
  ["streaming", "working"],
  ["working", "working"],
]);

function stateFromSessionStatus(status) {
  const kind = typeof status === "string" ? status : status?.type;
  return typeof kind === "string"
    ? SESSION_STATE_BY_STATUS.get(kind.toLowerCase())
    : undefined;
}

function request(method, params) {
  const pending = requestChain.then(() => requestOnce(method, params));
  requestChain = pending.catch(() => {});
  return pending;
}

function requestOnce(method, params) {
  const paneId = process.env.HERDR_PANE_ID;
  const socketPath = process.env.HERDR_SOCKET_PATH;

  if (!paneId || !socketPath) {
    return Promise.resolve();
  }

  const socketEndpoint =
    process.platform === "win32" ? `\\\\.\\pipe\\${socketPath}` : socketPath;

  const requestId = `${SOURCE}:${Date.now()}:${Math.floor(Math.random() * 1_000_000)
    .toString()
    .padStart(6, "0")}`;
  const request = {
    id: requestId,
    method,
    params: {
      pane_id: paneId,
      source: SOURCE,
      agent: AGENT,
      seq: nextReportSeq(),
      ...params,
    },
  };

  return new Promise((resolve) => {
    const client = net.createConnection(socketEndpoint, () => {
      client.write(`${JSON.stringify(request)}\n`);
    });

    const finish = () => {
      client.destroy();
      resolve();
    };

    client.setTimeout(500, finish);
    client.on("data", finish);
    client.on("error", finish);
    client.on("end", finish);
    client.on("close", resolve);
  });
}

function reportSession(sessionID) {
  if (!sessionID) {
    return Promise.resolve();
  }
  return request("pane.report_agent_session", { agent_session_id: sessionID });
}

function reportState(state, sessionID) {
  const params = { state };
  if (sessionID) {
    reportedRootSessionID = sessionID;
    params.agent_session_id = sessionID;
  }
  return request("pane.report_agent", params);
}

// V2 events that carry a session reference worth reporting to the pane.
const SESSION_UPDATE_EVENTS = new Set([
  "session.viewed",
  "session.metadata.updated",
  "session.renamed",
  "session.forked",
  "session.agent.selected",
  "session.model.selected",
]);

const WORKING_EVENTS = new Set([
  "session.execution.started",
  "session.step.started",
  "session.tool.called",
  "session.tool.success",
  "session.tool.failed",
  "session.compaction.ended",
  "permission.replied",
  "form.replied",
  "form.cancelled",
]);

const BLOCKED_EVENTS = new Set([
  "permission.asked",
  "form.created",
  "session.execution.failed",
  "session.step.failed",
]);

async function onEvent(event) {
  const type = event?.type;
  const data = event?.data ?? {};
  const sessionID = sessionIDFromEventData(data);

  if (type === "session.created" && data.sessionID) {
    // Creation is server-global, so an attached client may own it. The
    // TUI plugin separately reports the root selected in this pane.
    if (typeof data.parentID === "string" && data.parentID) {
      childSessions.add(data.sessionID);
    } else {
      reportedRootSessionID = data.sessionID;
    }
  }
  if (sessionID && childSessions.has(sessionID)) {
    const state = CHILD_EVENT_STATES.get(type);
    if (state) {
      await reportState(state);
    }
    return;
  }

  if (SESSION_UPDATE_EVENTS.has(type)) {
    if (sessionID && sessionID !== reportedRootSessionID) {
      await reportSession(sessionID);
    }
    return;
  }
  if (type === "session.status") {
    const state = stateFromSessionStatus(data.status);
    if (state) {
      await reportState(state, sessionID);
    } else {
      await reportSession(sessionID);
    }
    return;
  }
  if (WORKING_EVENTS.has(type)) {
    await reportState("working", sessionID);
    return;
  }
  if (BLOCKED_EVENTS.has(type)) {
    await reportState("blocked", sessionID);
    return;
  }
  if (type === "session.idle") {
    await reportState("idle", sessionID);
    return;
  }
  // "session.deleted" and anything unknown are ignored.
}

const HerdrAgentStatePlugin = {
  id: "herdr.agent-state",
  async setup(ctx) {
    if (
      process.env.HERDR_ENV !== "1" ||
      !process.env.HERDR_SOCKET_PATH ||
      !process.env.HERDR_PANE_ID
    ) {
      return;
    }

    const controller = new AbortController();
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          await onEvent(event);
        }
      } catch (err) {
        if (controller.signal.aborted) return;
        console.error("[herdr-agent-state] event stream failed", err);
      }
    })();

    await ctx.session.hook("prompt", async ({ sessionID }) => {
      if (sessionID && childSessions.has(sessionID)) {
        return;
      }
      await reportState("working", sessionID);
    });

    return () => controller.abort();
  },
};

export default HerdrAgentStatePlugin;
