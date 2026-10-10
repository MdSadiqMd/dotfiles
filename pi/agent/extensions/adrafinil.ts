import { execFileSync } from "node:child_process"

function run(args) {
  try { execFileSync("\/Applications\/Adrafinil.app\/Contents\/Helpers\/adrafinil", args, { stdio: "ignore" }) } catch (_) {}
}

export default function (pi) {
  const id = (ctx) => ctx?.sessionManager?.getSessionFile?.() ?? String(process.pid)
  pi.on("agent_start", async (_event, ctx) =>
    run(["acquire", id(ctx), "--tool", "pi", "--pid", String(process.pid), "--ttl", "14400"]))
  pi.on("agent_settled", async (_event, ctx) => run(["release", id(ctx), "--tool", "pi"]))
  pi.on("session_shutdown", async (_event, ctx) => run(["release", id(ctx), "--tool", "pi"]))
}