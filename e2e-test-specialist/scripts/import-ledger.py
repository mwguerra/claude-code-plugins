#!/usr/bin/env python3
"""Import an e2e-testing markdown ledger into .e2e-testing/e2e-tests.sqlite.

Sections handled (any subset is fine — missing ones are skipped, not errors):
    ## Directives
    ## VPS Infrastructure & Credentials   (also accepts: Infrastructure, Credentials)
    ## Test App Matrix
    ## Server Distribution Plan
    ## E2E Test Phases                    (the meat — phases, tests, steps)
    ## Test Count Summary                 (informational; updates phases.expected_test_count)
    ## Test Results Log                   (historical runs → test_runs + memories)

Anything else under ## is preserved as a memory (kind='environment') so nothing is lost.

Usage:
    python3 import-ledger.py <ledger.md>
        [--db .e2e-testing/e2e-tests.sqlite]
        [--taxonomy /path/to/tag-taxonomy.json]
        [--dry-run]                 # parse + print counts; do not write
        [--json-summary]            # output a machine-readable summary

The parser is intentionally tolerant: structure preservation matters more than
exhaustive field extraction. Every test row keeps its `raw_markdown` so the
agent or user can refine later without re-running the importer.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# ---------------------------------------------------------------------------
# Markdown chunking
# ---------------------------------------------------------------------------

H2 = re.compile(r"^##\s+(?P<title>.+?)\s*$")
H3 = re.compile(r"^###\s+(?P<title>.+?)\s*$")
H4 = re.compile(r"^####\s+(?P<title>.+?)\s*$")
BOLD_SECTION = re.compile(r"^\*\*(?P<title>[^*][^*]*?)\*\*\s*$")
NUMBERED = re.compile(r"^(?P<num>\d+)\.\s+(?P<text>.+)$")
PHASE_HEADING = re.compile(r"^Phase\s+(?P<num>\d+)\s*[:\-—–]\s*(?P<title>.+?)$", re.IGNORECASE)
RESULTS_LOG_HEADING = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})(?:\s*\([^)]*\))?\s*[—\-–]\s*(?P<run>R\d+|R-\d+|[A-Z][A-Z0-9\-]+)?\s*[—\-–]?\s*(?P<rest>.*)$"
)
ROUND_SUFFIX_RE = re.compile(r"\(\s*R(\d+)\+?\s*\)")
# Bug heading patterns inside run blocks: "1. **LB topology includes...**" / "**Bug:** ..." / "BUGS FOUND"
BUG_NUMBERED_RE = re.compile(
    r"^(?P<num>\d+)\.\s+\*\*(?P<title>[^*]+?)\*\*\s*(?P<rest>.*)$",
    re.MULTILINE,
)
BULLET_KV = re.compile(r"^\s*[-*]\s+\*\*(?P<key>[^*]+?)\*\*[^:\n]*?:\s*(?P<val>.+?)\s*$")
# Inline pairs on one line: "**IP**: x | **Port**: y"  → list of (key,val)
INLINE_KV  = re.compile(r"\*\*(?P<key>[^*]+?)\*\*\s*:\s*(?P<val>[^|*]+?)(?=\s*\||$)")
# Common credential value patterns
PAT_RE      = re.compile(r"\b(ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b")
DO_TOKEN_RE = re.compile(r"\b(dop_v1_[a-f0-9]{40,})\b")
TABLE_ROW = re.compile(r"^\s*\|(.+)\|\s*$")
TABLE_DIVIDER = re.compile(r"^\s*\|?\s*[-:]+\s*(\|\s*[-:]+\s*)+\|?\s*$")


def slugify(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-") or "section"


def split_h2_sections(text: str) -> list[tuple[str, str]]:
    """Return [(heading, body), ...] for top-level ## sections, in order."""
    lines = text.splitlines()
    sections: list[tuple[str, list[str]]] = []
    current: tuple[str, list[str]] | None = None
    for line in lines:
        m = H2.match(line)
        if m:
            if current:
                sections.append(current)
            current = (m.group("title").strip(), [])
        elif current:
            current[1].append(line)
    if current:
        sections.append(current)
    return [(t, "\n".join(b).strip()) for t, b in sections]


def split_h3_sections(text: str) -> list[tuple[str, str]]:
    lines = text.splitlines()
    out: list[tuple[str, list[str]]] = []
    current: tuple[str, list[str]] | None = None
    for line in lines:
        m = H3.match(line)
        if m:
            if current:
                out.append(current)
            current = (m.group("title").strip(), [])
        elif current:
            current[1].append(line)
    if current:
        out.append(current)
    return [(t, "\n".join(b).strip()) for t, b in out]


def parse_table(block: str) -> list[dict]:
    """Parse the first markdown table found in the block. Returns list of dicts."""
    rows: list[list[str]] = []
    for line in block.splitlines():
        if TABLE_DIVIDER.match(line):
            continue
        m = TABLE_ROW.match(line)
        if m:
            cells = [c.strip() for c in m.group(1).split("|")]
            rows.append(cells)
        elif rows:
            break  # table ended
    if len(rows) < 2:
        return []
    headers = [h.lower().strip().strip("*") for h in rows[0]]
    out = []
    for r in rows[1:]:
        if len(r) != len(headers):
            continue
        out.append(dict(zip(headers, r)))
    return out


def parse_kv_bullets(block: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in block.splitlines():
        # Multi-pair lines: "- **IP**: x | **SSH Port**: 6985"
        if line.lstrip().startswith(("-", "*")) and "|" in line and "**" in line:
            for m in INLINE_KV.finditer(line):
                key = m.group("key").lower().strip()
                val = m.group("val").strip().rstrip("|").strip()
                if val.startswith("`") and val.endswith("`"):
                    val = val[1:-1]
                if key and val:
                    out[key] = val
            continue
        m = BULLET_KV.match(line)
        if m:
            key = m.group("key").lower().strip()
            val = m.group("val").strip()
            if val.startswith("`") and val.endswith("`"):
                val = val[1:-1]
            out[key] = val
    return out


# ---------------------------------------------------------------------------
# Phase / test extraction
# ---------------------------------------------------------------------------

@dataclass
class ParsedStep:
    order: int
    action: str
    expected: str = ""


@dataclass
class ParsedTest:
    title: str
    raw: str
    steps: list[ParsedStep] = field(default_factory=list)
    applies_to_hints: list[str] = field(default_factory=list)  # subject "kinds": ['app','site','viewport',...]


@dataclass
class ParsedPhase:
    phase_id: str
    title: str
    order: int
    raw: str
    tests: list[ParsedTest] = field(default_factory=list)
    description: str | None = None
    round_added: int | None = None


def extract_numbered_steps(block: str) -> list[ParsedStep]:
    """Pull `1. ...`, `2. ...` numbered list items from a block.
    Continuation lines (non-numbered, non-empty) merge into the previous item.
    """
    steps: list[ParsedStep] = []
    current: list[str] | None = None
    for line in block.splitlines():
        m = NUMBERED.match(line)
        if m:
            if current is not None and current:
                steps.append(ParsedStep(order=len(steps) + 1, action="\n".join(current).strip()))
            current = [m.group("text")]
        elif current is not None:
            if line.strip() == "" and (not current or not current[-1].strip()):
                continue
            # blank line + new section marker? we keep merging; section markers should end the block first
            current.append(line)
    if current is not None and current:
        steps.append(ParsedStep(order=len(steps) + 1, action="\n".join(current).strip()))
    return steps


# Patterns like "For each site:", "For every app", "Per-server", "for each of the 10 sites",
# "For EACH user role:". Captures the subject noun.
FOR_EACH_RE = re.compile(
    r"\b(?:for\s+(?:each|every)|per[- ])\s+(?:the\s+)?(?:\d+\s+)?(?P<noun>[A-Za-z][A-Za-z0-9_-]+)",
    re.IGNORECASE,
)
# Some plans phrase it as "Test EVERY page" or "for ALL roles"
ALL_RE = re.compile(r"\b(?:test|verify|check)\s+(?:every|all)\s+(?P<noun>[A-Za-z][A-Za-z0-9_-]+)", re.IGNORECASE)
NOUN_TO_KIND = {
    "site":   "app",   "sites":   "app",
    "app":    "app",   "apps":    "app",
    "server": "infrastructure", "servers": "infrastructure",
    "droplet":"infrastructure", "droplets":"infrastructure",
    "page":   "page",  "pages":   "page",
    "role":   "role",  "roles":   "role",
    "user":   "role",  "users":   "role",
    "viewport":"viewport","viewports":"viewport",
    "tab":    "tab",   "tabs":    "tab",
}


def detect_applies_to_hints(text: str) -> list[str]:
    """Look at a test's title + body and return subject 'kinds' it parametrizes over.
    Returns kind strings ('app', 'infrastructure', 'role', etc.); resolution to
    actual subject IDs happens at write time using the apps/infrastructure tables.
    """
    hints: set[str] = set()
    for rx in (FOR_EACH_RE, ALL_RE):
        for m in rx.finditer(text):
            noun = m.group("noun").lower()
            kind = NOUN_TO_KIND.get(noun)
            if kind:
                hints.add(kind)
    return sorted(hints)


def extract_tests_from_phase(phase_body: str, phase_title: str) -> list[ParsedTest]:
    """Within a phase body, identify test groups using these markers (in order of preference):

      1. Lines like ``**N.M Title**`` or ``**N.M.K Title**`` (most common in the reference)
      2. ``#### Title`` headings
      3. Otherwise the whole phase is one test.

    Steps under each marker are the numbered list items that follow.
    """
    lines = phase_body.splitlines()

    # First pass — find marker positions
    markers: list[tuple[int, str]] = []  # (line_index, title)
    for i, line in enumerate(lines):
        m = BOLD_SECTION.match(line)
        if m:
            t = m.group("title").strip()
            # Heuristic: a "test group" marker tends to look like "1.2 Title" or "Verify X"
            # We accept any **bold** standalone line.
            markers.append((i, t))
            continue
        m = H4.match(line)
        if m:
            markers.append((i, m.group("title").strip()))

    if not markers:
        body = phase_body
        return [ParsedTest(
            title=phase_title, raw=body,
            steps=extract_numbered_steps(body),
            applies_to_hints=detect_applies_to_hints(phase_title + "\n" + body),
        )]

    tests: list[ParsedTest] = []
    for idx, (line_no, title) in enumerate(markers):
        end = markers[idx + 1][0] if idx + 1 < len(markers) else len(lines)
        block = "\n".join(lines[line_no + 1 : end])
        steps = extract_numbered_steps(block)
        # Hints come from the test's own title+block, plus the phase preamble
        # (the lines before the first marker often say "For each site, do:")
        preamble = "\n".join(lines[: markers[0][0]])
        hints = detect_applies_to_hints(title + "\n" + block + "\n" + preamble)
        tests.append(ParsedTest(title=title, raw=block, steps=steps, applies_to_hints=hints))
    return tests


def split_phase_preamble(block: str) -> tuple[str, str]:
    """Split a phase body into (preamble_paragraphs, rest).
    Preamble = text before the first marker (bold subsection or H4) or first numbered list.
    """
    lines = block.splitlines()
    cut = len(lines)
    for i, line in enumerate(lines):
        if BOLD_SECTION.match(line) or H4.match(line) or NUMBERED.match(line):
            cut = i
            break
    return "\n".join(lines[:cut]).strip(), "\n".join(lines[cut:])


def parse_phases_section(body: str) -> list[ParsedPhase]:
    phases: list[ParsedPhase] = []
    h3 = split_h3_sections(body)
    for title, block in h3:
        m = PHASE_HEADING.match(title)
        if not m:
            continue
        num = int(m.group("num"))
        ptitle = m.group("title").strip()
        pid = f"P{num:02d}"
        preamble, rest = split_phase_preamble(block)
        tests = extract_tests_from_phase(rest if rest.strip() else block, ptitle)
        phases.append(ParsedPhase(
            phase_id=pid, title=ptitle, order=num,
            raw=block, tests=tests,
        ))
        # Stash preamble in a side channel: write_phase reads phase.description below
        phases[-1].description = preamble or None
        # Round-suffix tag: "Phase 32: Foo (R31+)" → tag "round-31-added"
        rm = ROUND_SUFFIX_RE.search(ptitle)
        phases[-1].round_added = int(rm.group(1)) if rm else None
    return phases


# ---------------------------------------------------------------------------
# Tag taxonomy
# ---------------------------------------------------------------------------

class Tagger:
    def __init__(self, taxonomy: dict):
        self.flat: list[tuple[str, str]] = []  # (tag, keyword_lower)
        for group, mapping in taxonomy.get("auto_tags", {}).items():
            if not isinstance(mapping, dict):
                continue
            for tag, keywords in mapping.items():
                for kw in keywords:
                    self.flat.append((tag, kw.lower()))

    def for_text(self, *texts: str) -> set[str]:
        joined = " ".join(t for t in texts if t).lower()
        out: set[str] = set()
        for tag, kw in self.flat:
            if kw in joined:
                out.add(tag)
        return out


# ---------------------------------------------------------------------------
# Directives
# ---------------------------------------------------------------------------

def infer_enforcement(text: str) -> str:
    t = text.upper()
    if "NEVER" in t or "MUST NOT" in t or " STRICTLY " in t:
        return "blocking"
    if "MUST" in t or "REQUIRED" in t:
        return "warning"
    return "advisory"


def parse_directives(body: str) -> list[dict]:
    out: list[dict] = []
    for title, block in split_h3_sections(body):
        if not block.strip():
            continue
        out.append({
            "title": title,
            "body": block.strip(),
            "category": slugify(title),
            "enforcement": infer_enforcement(block + " " + title),
        })
    if not out and body.strip():
        # fall back: one big directive
        out.append({"title": "Directives", "body": body.strip(), "category": "general",
                    "enforcement": infer_enforcement(body)})
    return out


# ---------------------------------------------------------------------------
# Infrastructure + credentials
# ---------------------------------------------------------------------------

# Recognized "kind" hints from headings
INFRA_KIND_HINTS = [
    ("control plane",  "control-plane"),
    ("panel",          "panel"),
    ("app server",     "app-server"),
    ("all-in-one",     "all-in-one"),
    ("load balancer",  "load-balancer"),
    ("droplet",        "do-droplet"),
    ("dev machine",    "dev-machine"),
    ("worker",         "worker"),
]


def detect_infra_kind(heading: str) -> str:
    h = heading.lower()
    for needle, kind in INFRA_KIND_HINTS:
        if needle in h:
            return kind
    return "other"


def parse_infra_and_credentials(body: str) -> tuple[list[dict], list[dict]]:
    """Returns (infrastructure, credentials).

    Each ### subsection may yield: 0 or 1 infrastructure entries + 0..N credentials.
    The textual rules are pragmatic — we look for **IP**, **SSH**, **password**,
    **token**, **URL**, **wildcard domain** style bullet keys, and also scan the
    raw text for known credential patterns (ghp_*, dop_v1_*).
    """
    infra: list[dict] = []
    creds: list[dict] = []

    for heading, block in split_h3_sections(body):
        kv = parse_kv_bullets(block)

        # Pattern-matched credentials (work even if parse_kv_bullets fails on the line)
        for m in PAT_RE.finditer(block):
            creds.append({
                "name": f"{slugify(heading)}-pat-{len(creds)+1}",
                "kind": "pat",
                "fields": json.dumps({"token": m.group(1)}),
                "notes": heading,
            })
        for m in DO_TOKEN_RE.finditer(block):
            creds.append({
                "name": f"{slugify(heading)}-do-token",
                "kind": "api-token",
                "fields": json.dumps({"provider": "digitalocean", "token": m.group(1)}),
                "notes": heading,
            })

        if not kv:
            continue

        # --- credentials ---
        # SSH credential when there's a password + ip/port
        if any(k in kv for k in ("root password", "password")) and "ip" in kv:
            creds.append({
                "name": f"{slugify(heading)}-ssh",
                "kind": "ssh",
                "fields": json.dumps({
                    "host": kv.get("ip", ""),
                    "port": kv.get("ssh port", "22"),
                    "user": "root",
                    "password": kv.get("root password") or kv.get("password", ""),
                }),
                "notes": heading,
            })
        # API token / PAT
        for key in list(kv.keys()):
            v = kv[key]
            if "token" in key and v and "expired" not in v.lower():
                kind = "pat" if v.lower().startswith("ghp_") or v.lower().startswith("github_pat_") else "api-token"
                creds.append({
                    "name": f"{slugify(heading)}-{slugify(key)}",
                    "kind": kind,
                    "fields": json.dumps({"token": v}),
                    "notes": heading,
                })
        # Composer registry
        if "url" in kv and ("username" in kv or "user" in kv) and ("password" in kv or "token" in kv):
            creds.append({
                "name": f"{slugify(heading)}-composer",
                "kind": "composer",
                "fields": json.dumps({
                    "url": kv.get("url", ""),
                    "username": kv.get("username") or kv.get("user", ""),
                    "password": kv.get("password") or kv.get("token", ""),
                }),
                "notes": heading,
            })

        # --- infrastructure ---
        if "ip" in kv or "wildcard domain" in kv or "wireguard ip" in kv:
            metadata = {k: v for k, v in kv.items() if k not in {
                "ip", "ssh port", "root password", "password",
                "wildcard domain", "wireguard ip", "ssh"
            }}
            infra.append({
                "name": heading,
                "kind": detect_infra_kind(heading),
                "ip": kv.get("ip"),
                "ssh_port": int(kv.get("ssh port", "22") or 22) if (kv.get("ssh port", "22") or "22").isdigit() else 22,
                "wildcard_domain": kv.get("wildcard domain"),
                "wireguard_ip": kv.get("wireguard ip"),
                "metadata": json.dumps(metadata),
                "credential_link_to": f"{slugify(heading)}-ssh" if any(k in kv for k in ("root password", "password")) and "ip" in kv else None,
            })
    return infra, creds


# ---------------------------------------------------------------------------
# Test App Matrix
# ---------------------------------------------------------------------------

SERVICE_KEYS = ["db", "redis", "horizon", "reverb", "scheduler", "s3"]


def parse_app_matrix(body: str) -> list[dict]:
    rows = parse_table(body)
    if not rows:
        return []
    apps: list[dict] = []
    for r in rows:
        # heading rows like 'app | type | db | ...'
        name = (r.get("app") or "").strip(" *")
        if not name or name.lower() in {"app", "name", "----"}:
            continue
        services = {}
        for k in SERVICE_KEYS:
            v = (r.get(k) or "").strip().lower()
            if not v or v == "—" or v == "-":
                services[k] = False
            elif "yes" in v or "✓" in v or "**yes**" in v:
                services[k] = True
            elif v in ("pg", "postgres", "**pg**"):
                services[k] = "pg"
            elif v in ("mysql",):
                services[k] = "mysql"
            elif v in ("sqlite", "**sqlite**"):
                services[k] = "sqlite"
            else:
                services[k] = v
        apps.append({
            "name": name.lstrip("*").strip(),
            "app_type": (r.get("type") or "").strip(),
            "description": (r.get("key features") or r.get("notes") or "").strip(),
            "services": json.dumps(services),
        })
    return apps


# ---------------------------------------------------------------------------
# Test Results Log → historical runs + memories
# ---------------------------------------------------------------------------

def extract_bugs_from_run_block(run_id: str, block: str) -> list[dict]:
    """Pull individual bug entries from a Test Results Log run block.
    Looks for two patterns:
      - Numbered bullets like "1. **Title**.  description..."
      - "**Bug:** ..." or "BUG: ..." inline
    Splits on numbered headings within a "BUGS FOUND" / "BUGS / FIXES" section if present.
    """
    bugs: list[dict] = []
    # Find sections that mention BUG(s) — heuristic: extract chunks that follow a header containing 'BUG'
    lower = block.lower()
    if "bug" not in lower:
        return bugs

    # Find numbered bug entries
    matches = list(BUG_NUMBERED_RE.finditer(block))
    if not matches:
        return bugs

    for i, m in enumerate(matches):
        title = m.group("title").strip().rstrip(".")
        rest_start = m.end()
        rest_end = matches[i + 1].start() if i + 1 < len(matches) else len(block)
        body = block[rest_start:rest_end].strip()
        # Heuristic severity from keywords
        severity = "high"
        bl = (title + " " + body).lower()
        if any(s in bl for s in ("critical", "data loss", "production down")):
            severity = "critical"
        elif any(s in bl for s in ("medium", "non-blocking")):
            severity = "medium"
        elif any(s in bl for s in ("minor", "low", "cosmetic")):
            severity = "low"
        bugs.append({
            "title": title[:300],
            "description": body[:8000],
            "severity": severity,
            "discovered_in_run": run_id,
            "status": "fixed" if "fix proposed" in bl or "fixed in" in bl or "manual fix applied" in bl else "open",
            "root_cause": None,  # could regex for "Root cause:" — left to manual curation
        })
    return bugs


def parse_results_log(body: str) -> tuple[list[dict], list[dict], list[dict]]:
    """Returns (runs, memories, bugs)."""
    runs: list[dict] = []
    memories: list[dict] = []
    bugs: list[dict] = []
    for heading, block in split_h3_sections(body):
        m = RESULTS_LOG_HEADING.match(heading.replace("—", "-").replace("–", "-"))
        if not m:
            memories.append({
                "title": heading[:200],
                "kind": "lesson-learned",
                "body": block.strip(),
                "why_important": "Historical reference",
                "importance": 3,
                "tags": json.dumps(["historical"]),
            })
            continue
        date = m.group("date")
        run_label = (m.group("run") or "").strip()
        rest = (m.group("rest") or "").strip()
        run_id = run_label if run_label.startswith("R-") else (f"R-{run_label[1:].zfill(3)}" if run_label.startswith("R") else f"R-{slugify(date)}")
        runs.append({
            "id": run_id,
            "label": rest or heading,
            "started_at": f"{date}T00:00:00Z",
            "ended_at":   f"{date}T23:59:59Z",
            "status": "completed",
            "context": heading,
            "final_state": block.strip(),
        })
        # Extract structured bugs into the bugs table
        for b in extract_bugs_from_run_block(run_id, block):
            bugs.append(b)
        # Also keep a coarse memory for full-text search across rounds
        if "BUG" in block.upper() or "bug:" in block.lower():
            memories.append({
                "title": f"{run_id} — bugs noted",
                "kind": "bug-pattern",
                "body": block.strip(),
                "why_important": "Bugs reported in this round",
                "importance": 4,
                "tags": json.dumps([run_id.lower(), "historical-bugs"]),
            })
    return runs, memories, bugs


# ---------------------------------------------------------------------------
# DB writers
# ---------------------------------------------------------------------------

class Writer:
    def __init__(self, db_path: str, dry: bool = False):
        self.dry = dry
        if not dry:
            self.conn = sqlite3.connect(db_path)
            self.conn.execute("PRAGMA foreign_keys = ON;")
        else:
            self.conn = None

    def _exec(self, sql: str, params: tuple = ()):
        if self.dry or not self.conn:
            return
        self.conn.execute(sql, params)

    def commit(self):
        if self.conn:
            self.conn.commit()

    def next_id(self, table: str, prefix: str) -> str:
        if self.dry or not self.conn:
            n = getattr(self, f"_dry_{table}_{prefix}", 0) + 1
            setattr(self, f"_dry_{table}_{prefix}", n)
            return f"{prefix}-{n:03d}"
        cur = self.conn.execute(
            f"SELECT COALESCE(MAX(CAST(SUBSTR(id, ?+2) AS INTEGER)), 0)+1 FROM {table} WHERE id LIKE ?;",
            (len(prefix), f"{prefix}-%"),
        )
        n = cur.fetchone()[0]
        return f"{prefix}-{n:03d}"

    # ---- specific writers ----

    def write_directive(self, d: dict):
        did = self.next_id("directives", "DIR")
        self._exec(
            "INSERT INTO directives (id,title,body,category,enforcement,active,source) VALUES (?,?,?,?,?,1,?)",
            (did, d["title"], d["body"], d.get("category", "general"), d["enforcement"], "import"),
        )

    def write_credential(self, c: dict) -> str:
        # Credentials have UNIQUE(name); a re-import of the same ledger should
        # be a no-op rather than crash. Look up the existing row first.
        if not self.dry and self.conn:
            existing = self.conn.execute(
                "SELECT id FROM credentials WHERE name = ?", (c["name"],)
            ).fetchone()
            if existing:
                return existing[0]
        cid = self.next_id("credentials", "CRED")
        self._exec(
            "INSERT INTO credentials (id,name,kind,fields,notes) VALUES (?,?,?,?,?)",
            (cid, c["name"], c["kind"], c["fields"], c.get("notes", "")),
        )
        return cid

    def write_infra(self, i: dict, cred_lookup: dict[str, str]):
        # infrastructure.name is UNIQUE — a re-import of the same ledger row
        # should be a no-op.
        if not self.dry and self.conn:
            existing = self.conn.execute(
                "SELECT id FROM infrastructure WHERE name = ?", (i["name"],)
            ).fetchone()
            if existing:
                return
        iid = self.next_id("infrastructure", "INF")
        link = i.pop("credential_link_to", None)
        cred_id = cred_lookup.get(link) if link else None
        self._exec(
            """INSERT INTO infrastructure
               (id,name,kind,ip,ssh_port,wildcard_domain,wireguard_ip,credential_id,metadata)
               VALUES (?,?,?,?,?,?,?,?,?)""",
            (iid, i["name"], i["kind"], i.get("ip"), i.get("ssh_port", 22),
             i.get("wildcard_domain"), i.get("wireguard_ip"), cred_id, i.get("metadata", "{}")),
        )

    def write_app(self, a: dict):
        # apps.name is UNIQUE — re-import of the same row is a no-op.
        if not self.dry and self.conn:
            existing = self.conn.execute(
                "SELECT id FROM apps WHERE name = ?", (a["name"],)
            ).fetchone()
            if existing:
                return
        aid = self.next_id("apps", "APP")
        self._exec(
            "INSERT INTO apps (id,name,app_type,description,services) VALUES (?,?,?,?,?)",
            (aid, a["name"], a.get("app_type", ""), a.get("description", ""), a.get("services", "{}")),
        )

    def _resolve_hints_to_subject_ids(self, hints: list[str]) -> list[str]:
        """For each hint kind ('app','infrastructure','role','viewport',...),
        return all known subject IDs of that kind. 'role' and 'viewport' have no
        backing tables yet — they emit synthetic IDs the executor can pattern-match
        on, so the test still expands and the user can curate later.
        """
        out: list[str] = []
        for kind in hints:
            if kind == "app":
                if self.dry or not self.conn:
                    n = getattr(self, "_dry_apps_APP", 0)
                    out.extend(f"APP-{i:03d}" for i in range(1, n + 1))
                else:
                    out.extend(r[0] for r in self.conn.execute("SELECT id FROM apps ORDER BY id"))
            elif kind == "infrastructure":
                if not (self.dry or not self.conn):
                    out.extend(r[0] for r in self.conn.execute("SELECT id FROM infrastructure ORDER BY id"))
            elif kind == "role":
                # Synthetic — user populates real role IDs later via /plan update-test.
                out.extend(["ROLE-admin", "ROLE-user", "ROLE-guest"])
            elif kind == "viewport":
                out.extend(["VP-desktop", "VP-tablet", "VP-mobile"])
            elif kind == "page":
                # Pages aren't a first-class table; leave the test un-parametrized
                # but tag it so /plan can suggest parametrization later.
                pass
            elif kind == "tab":
                pass
        return out

    def write_phase(self, p: ParsedPhase, tagger: Tagger, with_raw: bool = True) -> dict:
        # Insert phase
        self._exec(
            "INSERT OR REPLACE INTO phases (id,title,description,phase_order,raw_markdown) VALUES (?,?,?,?,?)",
            (p.phase_id, p.title, getattr(p, "description", None), p.order,
             p.raw if with_raw else None),
        )
        # Insert tests + steps + tags
        expansions = 0
        for tidx, t in enumerate(p.tests, start=1):
            tid = f"T-{p.phase_id[1:]}.{tidx:02d}"
            applies_to = self._resolve_hints_to_subject_ids(t.applies_to_hints)
            applies_to_json = json.dumps(applies_to)
            expansions += max(len(applies_to), 1)

            self._exec(
                """INSERT OR REPLACE INTO tests
                   (id,phase_id,title,test_order,raw_markdown,test_kind,is_critical,applies_to)
                   VALUES (?,?,?,?,?,?,1,?)""",
                (tid, p.phase_id, t.title[:500], tidx, t.raw if with_raw else None,
                 infer_test_kind(t.raw), applies_to_json),
            )
            for s in t.steps:
                sid = f"S-{tid[2:]}.{s.order:03d}"
                # If the test is parametrized, also store the action as an
                # action_template — the executor uses the template column when subject is non-null.
                action_template = s.action if applies_to else None
                self._exec(
                    """INSERT OR REPLACE INTO test_steps
                       (id,test_id,step_order,action,action_template)
                       VALUES (?,?,?,?,?)""",
                    (sid, tid, s.order, s.action[:8000], action_template[:8000] if action_template else None),
                )
            tags = tagger.for_text(t.title, t.raw)
            tags.add(p.phase_id.lower())
            tk = infer_test_kind(t.raw)
            if tk:
                tags.add(tk)
            if applies_to:
                tags.add("parametrized")
                for kind in t.applies_to_hints:
                    tags.add(f"per-{kind}")
            # Round-added tag (when phase title has "(R31+)" suffix)
            if getattr(p, "round_added", None):
                tags.add(f"round-{p.round_added}-added")
            for tag in tags:
                self._exec("INSERT OR IGNORE INTO tags (name,auto) VALUES (?,1)", (tag,))
                self._exec("INSERT OR IGNORE INTO test_tags (test_id,tag_name) VALUES (?,?)", (tid, tag))
        return {
            "phase": p.phase_id,
            "tests": len(p.tests),
            "steps": sum(len(t.steps) for t in p.tests),
            "expansions": expansions,
        }

    def write_run(self, r: dict):
        self._exec(
            """INSERT OR REPLACE INTO test_runs
               (id,label,started_at,ended_at,status,context,final_state) VALUES (?,?,?,?,?,?,?)""",
            (r["id"], r.get("label", ""), r["started_at"], r["ended_at"],
             r["status"], r.get("context", ""), r.get("final_state", "")),
        )

    def write_bug(self, b: dict):
        bid = self.next_id("bugs", "BUG")
        self._exec(
            """INSERT INTO bugs
               (id, discovered_in_run, severity, title, description, status)
               VALUES (?,?,?,?,?,?)""",
            (bid, b["discovered_in_run"], b.get("severity", "medium"),
             b["title"], b.get("description", ""), b.get("status", "open")),
        )

    def write_memory(self, m: dict):
        mid = self.next_id("memories", "M")
        self._exec(
            """INSERT INTO memories (id,title,kind,body,why_important,importance,tags)
               VALUES (?,?,?,?,?,?,?)""",
            (mid, m["title"], m.get("kind", "lesson-learned"), m["body"],
             m.get("why_important", ""), m.get("importance", 3), m.get("tags", "[]")),
        )


def infer_test_kind(text: str) -> str:
    t = (text or "").lower()
    if "browser_" in t or "navigate to" in t or "click " in t or "snapshot" in t:
        return "browser"
    if "ssh " in t or "/root/.ssh" in t or "authorized_keys" in t:
        return "ssh"
    if "curl " in t or "/api/" in t:
        return "api"
    if "docker " in t or "docker compose" in t:
        return "cli"
    if "stress" in t or "concurrent" in t:
        return "stress"
    return "mixed"


# ---------------------------------------------------------------------------
# Top-level driver
# ---------------------------------------------------------------------------

def detect_section(heading: str) -> str:
    h = heading.lower()
    if "directive" in h:                                   return "directives"
    if "infrastructure" in h or "credential" in h:         return "infra"
    if "app matrix" in h or "test app matrix" in h:        return "apps"
    if "distribution plan" in h:                            return "distribution"
    if "test phases" in h or "e2e test phases" in h:        return "phases"
    if "test count" in h:                                   return "counts"
    if "test results log" in h or "results log" in h:        return "results"
    return "other"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("ledger", help="path to the markdown ledger file")
    p.add_argument("--db", default=os.environ.get("E2E_DB", ".e2e-testing/e2e-tests.sqlite"))
    p.add_argument("--taxonomy", default=None,
                   help="path to tag-taxonomy.json (defaults to plugin's schemas/tag-taxonomy.json)")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--json-summary", action="store_true")
    args = p.parse_args(argv)

    ledger_path = Path(args.ledger)
    if not ledger_path.exists():
        print(f"error: ledger not found: {ledger_path}", file=sys.stderr)
        return 2

    if not args.taxonomy:
        plugin_root = Path(os.environ.get("CLAUDE_PLUGIN_ROOT", str(Path(__file__).resolve().parent.parent)))
        args.taxonomy = str(plugin_root / "schemas" / "tag-taxonomy.json")

    with open(args.taxonomy) as f:
        taxonomy = json.load(f)
    tagger = Tagger(taxonomy)

    raw = ledger_path.read_text(encoding="utf-8")
    sections = split_h2_sections(raw)

    summary = {
        "ledger": str(ledger_path),
        "h2_sections": [s[0] for s in sections],
        "directives": 0,
        "credentials": 0,
        "infrastructure": 0,
        "apps": 0,
        "phases": 0,
        "tests": 0,
        "steps": 0,
        "expansions": 0,
        "runs": 0,
        "memories": 0,
        "bugs": 0,
        "coverage_targets": 0,
        "count_warnings": [],
        "skipped_sections": [],
    }

    if not args.dry_run:
        if not Path(args.db).exists():
            print(f"error: db not found: {args.db}. Run /e2e-test-specialist:init first.", file=sys.stderr)
            return 2

    w = Writer(args.db, dry=args.dry_run)

    cred_lookup: dict[str, str] = {}

    for heading, body in sections:
        kind = detect_section(heading)

        if kind == "directives":
            for d in parse_directives(body):
                w.write_directive(d)
                summary["directives"] += 1

        elif kind == "infra":
            infra, creds = parse_infra_and_credentials(body)
            for c in creds:
                cred_lookup[c["name"]] = w.write_credential(c) if not args.dry_run else c["name"]
                summary["credentials"] += 1
            for i in infra:
                w.write_infra(i, cred_lookup)
                summary["infrastructure"] += 1

        elif kind == "apps":
            for a in parse_app_matrix(body):
                w.write_app(a)
                summary["apps"] += 1
            # GitHub PATs and Composer creds typically live under H3 subsections of "Test App Matrix"
            extra_infra, extra_creds = parse_infra_and_credentials(body)
            for c in extra_creds:
                cred_lookup[c["name"]] = w.write_credential(c) if not args.dry_run else c["name"]
                summary["credentials"] += 1
            for i in extra_infra:
                w.write_infra(i, cred_lookup)
                summary["infrastructure"] += 1

        elif kind == "phases":
            phases = parse_phases_section(body)
            for ph in phases:
                stats = w.write_phase(ph, tagger)
                summary["phases"] += 1
                summary["tests"] += stats["tests"]
                summary["steps"] += stats["steps"]
                summary["expansions"] += stats.get("expansions", stats["tests"])

        elif kind == "results":
            runs, mems, bugs_extracted = parse_results_log(body)
            for r in runs:
                w.write_run(r)
                summary["runs"] += 1
            for m in mems:
                w.write_memory(m)
                summary["memories"] += 1
            for b in bugs_extracted:
                w.write_bug(b)
                summary["bugs"] = summary.get("bugs", 0) + 1

        elif kind == "distribution":
            # Distribution may include DO API tokens and droplet inventories.
            extra_infra, extra_creds = parse_infra_and_credentials(body)
            for c in extra_creds:
                cred_lookup[c["name"]] = w.write_credential(c) if not args.dry_run else c["name"]
                summary["credentials"] += 1
            for i in extra_infra:
                w.write_infra(i, cred_lookup)
                summary["infrastructure"] += 1
            # And preserve the textual plan — the agent uses it to map app→server.
            w.write_memory({
                "title": "Server Distribution Plan",
                "kind": "environment",
                "body": body.strip(),
                "why_important": "Maps which apps live on which servers; used to plan deploys.",
                "importance": 4,
                "tags": json.dumps(["distribution", "infrastructure"]),
            })
            summary["memories"] += 1

        elif kind == "counts":
            # Try to extract the table and update phases.expected_test_count
            for row in parse_table(body):
                phase_field = (row.get("phase") or row.get("what") or "").strip()
                tests_field = (row.get("tests") or "").strip().replace("~", "").replace(",", "")
                m = re.search(r"\d+", phase_field)
                if not m:
                    continue
                pid = f"P{int(m.group()):02d}"
                try:
                    n = int(tests_field)
                except ValueError:
                    continue
                w._exec("UPDATE phases SET expected_test_count = ? WHERE id = ?", (n, pid))

        else:
            summary["skipped_sections"].append(heading)
            # Preserve as memory so we never silently drop content
            w.write_memory({
                "title": f"Unparsed section: {heading}",
                "kind": "environment",
                "body": body.strip()[:8000],
                "why_important": "Preserved from import; importer didn't recognize this section.",
                "importance": 2,
                "tags": json.dumps(["import-residual", slugify(heading)]),
            })
            summary["memories"] += 1

    # Validate expected vs imported test counts (warn loudly on big mismatches)
    if not args.dry_run:
        for pid, expected, actual in w.conn.execute("""
            SELECT p.id, p.expected_test_count,
                   (SELECT COUNT(*) FROM tests WHERE phase_id = p.id AND deprecated_at IS NULL)
              FROM phases p
             WHERE p.expected_test_count IS NOT NULL
        """):
            if expected and actual and (actual < expected * 0.5 or actual > expected * 2):
                summary["count_warnings"].append({
                    "phase": pid, "expected": expected, "actual": actual,
                })

    w.commit()

    if args.json_summary:
        print(json.dumps(summary, indent=2))
    else:
        print(f"Imported from {ledger_path.name}{' (DRY RUN — nothing written)' if args.dry_run else ''}")
        print(f"  H2 sections seen        : {len(summary['h2_sections'])}")
        print(f"  directives              : {summary['directives']}")
        print(f"  credentials             : {summary['credentials']}")
        print(f"  infrastructure          : {summary['infrastructure']}")
        print(f"  apps                    : {summary['apps']}")
        print(f"  phases                  : {summary['phases']}")
        print(f"  tests                   : {summary['tests']}")
        print(f"  parametrized expansions : {summary['expansions']}  (test × subject pairs the executor will run)")
        print(f"  steps                   : {summary['steps']}")
        print(f"  historical runs         : {summary['runs']}")
        print(f"  bugs (extracted)        : {summary.get('bugs', 0)}")
        print(f"  memories                : {summary['memories']}")
        if summary.get("count_warnings"):
            print(f"  expected-vs-actual mismatches:")
            for w_ in summary["count_warnings"]:
                print(f"    {w_['phase']}: expected ~{w_['expected']}, imported {w_['actual']}")
        if summary["skipped_sections"]:
            print(f"  preserved-as-memory     : {', '.join(summary['skipped_sections'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
