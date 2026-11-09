"""Search and read past agent sessions from opencode, T3 Code and Claude Code.

  python3 -I sessions.py search <text> [--limit N]
  python3 -I sessions.py show <id> [--tools] [--max-chars N]

Databases are opened read-only, so this is safe while the apps are running.
"""

import argparse
import datetime
import glob
import json
import os
import sqlite3
import sys

HOME = os.path.expanduser("~")
OPENCODE_DB = f"{HOME}/.local/share/opencode/opencode.db"
T3_DB = f"{HOME}/.t3/userdata/statev2.sqlite"
CLAUDE_DIR = f"{HOME}/.claude/projects"


def connect(path):
    if not os.path.exists(path):
        return None
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def day(ms_or_iso):
    if isinstance(ms_or_iso, (int, float)):
        return datetime.datetime.fromtimestamp(ms_or_iso / 1000).strftime("%Y-%m-%d %H:%M")
    try:
        t = datetime.datetime.fromisoformat(str(ms_or_iso).replace("Z", "+00:00"))
    except ValueError:
        return str(ms_or_iso)[:16]
    return t.astimezone().strftime("%Y-%m-%d %H:%M")


def like(text):
    return "%" + text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"


def search_opencode(db, text, limit):
    rows = db.execute(
        """select s.id, s.title, s.directory, max(p.time_created) from part p
           join session s on s.id = p.session_id
           where (p.data like ? escape '\\' or s.title like ? escape '\\')
             and s.title not like 'T3 Code generate%'
           group by s.id order by 4 desc limit ?""",
        (like(text), like(text), limit),
    )
    return [("opencode", i, t, d, day(ts)) for i, t, d, ts in rows]


def search_t3(db, text, limit):
    phrase = '"' + text.replace('"', '""') + '"'
    rows = db.execute(
        """select t.thread_id, t.title, coalesce(p.workspace_root, ''), max(m.created_at)
           from orchestration_v2_projection_messages m
           join orchestration_v2_projection_threads t on t.thread_id = m.thread_id
           left join projection_projects p on p.project_id = t.project_id
           where m.rowid in (select rowid from orchestration_v2_message_search
                             where orchestration_v2_message_search match ?)
              or t.title like ? escape '\\'
           group by t.thread_id order by 4 desc limit ?""",
        (phrase, like(text), limit),
    )
    return [("t3", i, t, d, day(ts)) for i, t, d, ts in rows]


def claude_files():
    return glob.glob(f"{CLAUDE_DIR}/*/*.jsonl")


def first_user_text(path):
    for line in open(path, errors="ignore"):
        try:
            o = json.loads(line)
        except ValueError:
            continue
        if o.get("type") == "user" and not o.get("isMeta"):
            text = blocks_text((o.get("message") or {}).get("content"), tools=False)
            if text.strip():
                return o.get("cwd", ""), " ".join(text.split())[:80]
    return "", ""


def search_claude(text, limit):
    needle = text.lower()
    hits = []
    for path in claude_files():
        with open(path, errors="ignore") as f:
            if needle in f.read().lower():
                hits.append((os.path.getmtime(path), path))
    out = []
    for mtime, path in sorted(hits, reverse=True)[:limit]:
        cwd, title = first_user_text(path)
        out.append(("claude", os.path.basename(path)[:-6], title, cwd, day(mtime * 1000)))
    return out


def blocks_text(content, tools):
    if isinstance(content, str):
        return content
    parts = []
    for b in content or []:
        kind = b.get("type")
        if kind == "text":
            parts.append(b.get("text", ""))
        elif kind == "tool_use" and tools:
            inp = b.get("input") or {}
            brief = inp.get("command") or inp.get("file_path") or inp.get("pattern") or inp.get("url") or ""
            parts.append(f"[{b.get('name')}] {str(brief)[:300]}")
        elif kind == "tool_result" and tools:
            r = b.get("content")
            if isinstance(r, list):
                r = " ".join(x.get("text", "") for x in r if isinstance(x, dict))
            parts.append(f"[result] {str(r)[:300]}")
    return "\n".join(p for p in parts if p)


def show_opencode(db, sid, tools):
    msgs = db.execute(
        "select id, json_extract(data, '$.role'), time_created from message where session_id = ? order by time_created, id",
        (sid,),
    ).fetchall()
    for mid, role, ts in msgs:
        parts = []
        for (data,) in db.execute("select data from part where message_id = ? order by id", (mid,)):
            p = json.loads(data)
            if p.get("type") == "text" and not p.get("synthetic"):
                parts.append(p.get("text", ""))
            elif p.get("type") == "tool" and tools:
                inp = (p.get("state") or {}).get("input") or {}
                brief = inp.get("command") or inp.get("filePath") or inp.get("pattern") or ""
                parts.append(f"[{p.get('tool')}] {str(brief)[:300]}")
        yield role, day(ts), "\n".join(parts)


def show_t3(db, tid):
    rows = db.execute(
        """select role, created_at, json_extract(payload_json, '$.text')
           from orchestration_v2_projection_messages
           where thread_id = ? and streaming = 0 order by created_at, message_id""",
        (tid,),
    )
    for role, ts, text in rows:
        yield role, day(ts), text or ""


def show_claude(path, tools):
    for line in open(path, errors="ignore"):
        try:
            o = json.loads(line)
        except ValueError:
            continue
        if o.get("type") not in ("user", "assistant") or o.get("isMeta"):
            continue
        yield o["type"], day(o.get("timestamp", "")), blocks_text((o.get("message") or {}).get("content"), tools)


def show(sid, tools, max_chars):
    messages = None
    oc, t3 = connect(OPENCODE_DB), connect(T3_DB)
    if sid.startswith("ses_") and oc:
        if oc.execute("select 1 from session where id = ?", (sid,)).fetchone():
            print(f"# opencode {sid}: " + oc.execute("select title || '  (' || directory || ')' from session where id = ?", (sid,)).fetchone()[0])
            messages = show_opencode(oc, sid, tools)
    elif t3 and (row := t3.execute("select title from orchestration_v2_projection_threads where thread_id = ?", (sid,)).fetchone()):
        print(f"# t3 {sid}: {row[0]}")
        messages = show_t3(t3, sid)
    elif paths := glob.glob(f"{CLAUDE_DIR}/*/{sid}.jsonl"):
        print(f"# claude {sid}: {paths[0]}")
        messages = show_claude(paths[0], tools)
    if messages is None:
        sys.exit(f"no session {sid!r} in opencode, T3 Code or Claude Code")
    for role, ts, text in messages:
        if text.strip():
            if len(text) > max_chars:
                text = text[:max_chars] + f"\n… [{len(text) - max_chars} more chars]"
            print(f"\n## {role} · {ts}\n{text}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("search")
    s.add_argument("text")
    s.add_argument("--limit", type=int, default=15)
    sh = sub.add_parser("show")
    sh.add_argument("id")
    sh.add_argument("--tools", action="store_true", help="include tool calls and results")
    sh.add_argument("--max-chars", type=int, default=4000, help="per message")
    a = ap.parse_args()
    if a.cmd == "show":
        return show(a.id, a.tools, a.max_chars)
    rows = []
    if oc := connect(OPENCODE_DB):
        rows += search_opencode(oc, a.text, a.limit)
    if t3 := connect(T3_DB):
        rows += search_t3(t3, a.text, a.limit)
    rows += search_claude(a.text, a.limit)
    for src, sid, title, where, ts in sorted(rows, key=lambda r: r[4], reverse=True):
        print(f"{ts}  {src:8} {sid}  {' '.join((title or '').split())[:70]}  [{where}]")


if __name__ == "__main__":
    main()
