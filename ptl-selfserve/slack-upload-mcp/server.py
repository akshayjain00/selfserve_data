# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp>=1.2,<2", "httpx>=0.27", "python-dotenv>=1.0"]
# ///
"""Local stdio MCP server: send a Slack message with a file attached.

Fills the gap in the hosted Slack connector, which can post text but not files.
Uses Slack's external-upload flow (files.upload was retired in 2025):
  1. files.getUploadURLExternal  -> upload_url + file_id
  2. POST raw bytes to upload_url
  3. files.completeUploadExternal -> shares to channel/thread with the message text

Run:  uv run server.py   (uv reads the inline deps above; no venv needed)
"""

import csv
import json
import os
import re
from pathlib import Path

import httpx
from dotenv import load_dotenv
from mcp.server.fastmcp import FastMCP

HERE = Path(__file__).resolve().parent
load_dotenv(HERE / ".env")

SLACK_API = "https://slack.com/api"
TOKEN = os.environ.get("SLACK_USER_TOKEN", "")

mcp = FastMCP("slack-upload")


def validate_upload(path: Path) -> None:
    """Decide whether a local file may be sent to Slack. Raise ValueError to refuse.

    Called before any bytes leave the machine. `path` is already resolved and
    known to exist. This repo holds CSVs with order IDs, customer IDs and
    unmasked mobiles, plus .env files with keys — this is the one place that
    stops the wrong file going to a channel.
    """
    # `path` is resolved, so a symlink is judged by where it points, not its name.
    if not any(path.is_relative_to(root) for root in ALLOWED_ROOTS):
        raise ValueError(f"{path} is outside the allowed folders: {', '.join(map(str, ALLOWED_ROOTS))}")
    name = path.name.lower()
    if name.startswith(".env") or any(s in name for s in SECRET_HINTS):
        raise ValueError(f"{path.name} looks like a secrets file — refusing")
    if path.suffix.lower() not in ALLOWED_SUFFIXES:
        raise ValueError(f"{path.suffix or 'no extension'} not allowed; allowed: {' '.join(sorted(ALLOWED_SUFFIXES))}")
    if path.stat().st_size > MAX_BYTES:
        raise ValueError(f"{path.name} is {path.stat().st_size / 1e6:.0f} MB; limit is {MAX_BYTES / 1e6:.0f} MB")
    if path.suffix.lower() in {".csv", ".tsv"}:
        _refuse_unmasked_phones(path)


# Repo root (parent of this folder) and this user's Claude Code scratchpads only.
ALLOWED_ROOTS = (HERE.parent, Path(f"/private/tmp/claude-{os.getuid()}"))
ALLOWED_SUFFIXES = {".csv", ".tsv", ".xlsx", ".png", ".jpg", ".jpeg", ".gif", ".pdf",
                    ".html", ".md", ".txt", ".sql", ".json"}  # no .zip: it would hide CSVs from the phone check
SECRET_HINTS = ("secret", "credential", "token", "private_key", "id_rsa", ".pem", ".key")
MAX_BYTES = 50 * 1024 * 1024
# A full 10-digit Indian mobile, optionally prefixed +91/91/0. Masked ones (XXXXXX1234) don't match.
UNMASKED_PHONE = re.compile(r"^(?:\+?91|0)?[6-9]\d{9}$")
PHONE_COLUMN = re.compile(r"mobile|phone|msisdn|contact", re.I)


def _refuse_unmasked_phones(path: Path, sample_rows: int = 500) -> None:
    """Refuse a CSV whose phone-like columns hold unmasked numbers (sampled)."""
    dialect = "excel-tab" if path.suffix.lower() == ".tsv" else "excel"
    with path.open(newline="", encoding="utf-8", errors="replace") as fh:
        reader = csv.reader(fh, dialect=dialect)
        header = next(reader, [])
        cols = [i for i, h in enumerate(header) if PHONE_COLUMN.search(h)]
        if not cols:
            return
        for n, row in enumerate(reader):
            if n >= sample_rows:
                break
            for i in cols:
                if i < len(row) and UNMASKED_PHONE.match(row[i].strip().replace(" ", "")):
                    raise ValueError(
                        f"{path.name} has unmasked phone numbers in column '{header[i]}' "
                        f"(row {n + 2}); mask to XXXXXX+last4 before sharing"
                    )


async def _slack(client: httpx.AsyncClient, method: str, **data) -> dict:
    r = await client.post(
        f"{SLACK_API}/{method}",
        headers={"Authorization": f"Bearer {TOKEN}"},
        data={k: v for k, v in data.items() if v is not None},
    )
    r.raise_for_status()
    body = r.json()
    if not body.get("ok"):
        # Surface Slack's error code verbatim (missing_scope, channel_not_found, ...)
        raise RuntimeError(f"{method} failed: {body.get('error')} {body.get('needed', '')}".strip())
    return body


@mcp.tool()
async def slack_send_file(
    channel_id: str,
    file_path: str,
    message: str | None = None,
    thread_ts: str | None = None,
    title: str | None = None,
) -> str:
    """Post a local file to a Slack channel, DM or thread, as the user.

    Args:
        channel_id: Slack channel/DM ID (C…, D…, G…). Look it up with the Slack
            connector's slack_search_channels / slack_search_users first.
        file_path: Absolute path to the local file to attach.
        message: Message text posted with the file (Slack mrkdwn).
        thread_ts: Parent message ts to reply in a thread instead of the channel.
        title: Display title for the file; defaults to the file name.
    """
    if not TOKEN:
        raise RuntimeError("SLACK_USER_TOKEN is not set — copy .env.example to .env")
    path = Path(file_path).expanduser().resolve()
    if not path.is_file():
        raise FileNotFoundError(f"No such file: {path}")
    validate_upload(path)

    content = path.read_bytes()
    async with httpx.AsyncClient(timeout=120) as client:
        slot = await _slack(
            client, "files.getUploadURLExternal",
            filename=path.name, length=str(len(content)),
        )
        up = await client.post(slot["upload_url"], content=content)
        up.raise_for_status()
        done = await _slack(
            client, "files.completeUploadExternal",
            files=json.dumps([{"id": slot["file_id"], "title": title or path.name}]),
            channel_id=channel_id,
            initial_comment=message,
            thread_ts=thread_ts,
        )
    f = done["files"][0]
    return f"Uploaded {path.name} ({len(content):,} bytes) to {channel_id}: {f.get('permalink', f['id'])}"


if __name__ == "__main__":
    import sys

    # `uv run --script server.py --check FILE...` runs only the upload policy, so
    # other routes (e.g. Drive link + Slack connector) get the same safety gate.
    if sys.argv[1:2] == ["--check"]:
        failed = False
        for arg in sys.argv[2:]:
            p = Path(arg).expanduser().resolve()
            try:
                if not p.is_file():
                    raise ValueError(f"No such file: {p}")
                validate_upload(p)
                print(f"OK      {p}")
            except ValueError as e:
                failed = True
                print(f"REFUSED {p}: {e}")
        sys.exit(1 if failed else 0)
    mcp.run()
