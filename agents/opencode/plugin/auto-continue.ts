import { Plugin } from "@opencode/plugin"

// Ported to the OpenCode V2 plugin API: default export = Plugin.define({ id, setup }).
// V1 watched message.error events and injected a "continue" prompt. V2 exposes a
// dedicated `retry` hook that decides whether a failed provider request is retried,
// so transient provider failures are now retried natively instead of via a new prompt.

const TRANSIENT_STATUS = new Set([429, 500, 502, 503, 504, 529])
const TRANSIENT_ERROR =
  /503|502|504|529|429|queue is full|overloaded|timeout|ECONNRESET|ETIMEDOUT|fetch failed|socket hang up|stream (closed|ended|terminated)|connection (reset|refused)/i

const server = Plugin.define({
  id: "auto-continue",
  async setup(ctx) {
    const config = {
      maxConsecutive: parseInt(process.env["OPENCODE_AUTOCONTINUE_MAX_CONSECUTIVE"] ?? "3", 10),
      cooldownMs: parseInt(process.env["OPENCODE_AUTOCONTINUE_COOLDOWN_MS"] ?? "5000", 10),
      debug: process.env["OPENCODE_AUTOCONTINUE_DEBUG"] === "true",
      dryRun: process.env["OPENCODE_AUTOCONTINUE_DRY_RUN"] === "true",
    }

    const log = (msg: string, data?: Record<string, unknown>) => {
      if (!config.debug) return
      const line = data ? `${msg} ${JSON.stringify(data)}` : msg
      console.log(`[autocontinue] ${line}`)
    }

    log("Plugin loaded", { config })

    await ctx.session.hook("retry", (event) => {
      const { error, attempt, decision } = event
      const errorType = typeof error?.type === "string" ? error.type : ""
      const errorMsg = typeof error?.message === "string" ? error.message : ""
      const errorStatus = typeof error?.status === "number" ? error.status : undefined

      log("Error detected", { sessionID: event.sessionID, attempt, errorType, errorMsg: errorMsg.slice(0, 100), status: errorStatus })

      // Preserve the V1 HARD_DENY behaviour: never retry aborted messages.
      if (/abort/i.test(errorType)) {
        log("Ignoring hard-denied error", { errorType })
        return
      }

      if (
        !TRANSIENT_ERROR.test(errorMsg) &&
        !TRANSIENT_ERROR.test(errorType) &&
        !(errorStatus !== undefined && TRANSIENT_STATUS.has(errorStatus))
      ) {
        log("Ignoring non-transient error", { errorType, errorMsg: errorMsg.slice(0, 50) })
        return
      }

      if (attempt > config.maxConsecutive) {
        log("Max consecutive reached", { attempt, maxConsecutive: config.maxConsecutive })
        if (config.dryRun) {
          log("DRY RUN - would stop retrying", { sessionID: event.sessionID })
          return
        }
        event.decision = { retry: false }
        return
      }

      const proposedDelay = decision.retry ? decision.delay : 0
      const delay = Math.max(config.cooldownMs, proposedDelay)

      if (config.dryRun) {
        log("DRY RUN - would retry", { sessionID: event.sessionID, attempt, delay })
        return
      }

      event.decision = { retry: true, delay }
      log("Will retry", { sessionID: event.sessionID, attempt, delay })
    })
  },
})

export default server
