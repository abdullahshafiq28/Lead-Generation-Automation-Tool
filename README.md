# Lead-Generation Automation Tool

An internal automation that turns a **keyword** (e.g. `engineer`, `AI engineer`, `React developer`)
into a **clean, de-duplicated, scored list of sales/recruitment leads**, ready for outreach.

Built entirely on **free tooling** with [n8n](https://n8n.io) (Community Edition) as the workflow engine.
No LinkedIn scraping — only official / public APIs.

---

## What it does

Given one or more keywords, the workflow automatically:

1. **Collects** matching job/hiring leads from two free public job-board APIs (RemoteOK + Arbeitnow)
2. **Normalises** every source into one common schema
3. **De-duplicates** on company + role
4. **Enriches** each company with a likely contact email via Hunter.io
5. **Scores** every lead `0–100` using transparent rules (keyword match, seniority, location, email)
6. **Exports** a ranked CSV, ready for outreach

The manual trigger can be swapped for a **Schedule Trigger** to run it automatically every morning.

---

## Pipeline

```
Manual Trigger
      │
   Config  ......................... keyword, location, maxLeads
      ├───────────────┐
   RemoteOK        Arbeitnow ........ two free job-board APIs (no key needed)
      │               │
 Normalize RemoteOK  Normalize Arbeitnow  ... reshape to common schema + keyword filter
      └───────┬───────┘
        Merge Sources ................ append both lists
              │
        Clean & Dedupe ............... trim/normalise, drop duplicates, guess domain, cap list
              │
     Enrich Emails (Hunter) .......... 1 request/company, throttled, continue-on-error
              │
        Attach Email ................. pair response → lead, best email or "not found"
              │
     Embed Role (Gemini) ............. embed each role for semantic similarity (optional)
              │
        Score Leads .................. 0–100 score, ranked — keyword component uses
              │                        embedding similarity, else rule-based fallback
     LLM configured? (IF) ............ has a Gemini key? → yes: hook branch / no: skip
              │  yes
   Outreach Hook (Gemini) ........... one personalised opener per lead (optional)
              │
         To CSV → Write CSV File ..... output/leads.csv
              │
       Send email? (IF) → Send Email . email the CSV (optional, off by default)
```
*(A parallel `Embed Keyword (Gemini)` node off Config embeds the search keyword once, for the similarity comparison.)*

Common lead schema produced by the pipeline:

```json
{
  "company": "GFN GmbH",
  "role": "Senior Software Engineer / ML Engineer",
  "location": "Heidelberg",
  "url": "https://...",
  "source": "Arbeitnow",
  "domain": "gfn.com",
  "email": "contact@gfn.com",
  "email_confidence": 90,
  "score": 85,
  "score_reasons": "keyword x1 (+35); seniority (+20); email found conf 90 (+30)"
}
```

---

## Tech stack (100% free)

| Tool | Role | Free tier |
|------|------|-----------|
| **n8n (Community Edition)** | Workflow engine — the core deliverable | Free, self-hosted, unlimited runs |
| **RemoteOK API** | Lead source (remote tech jobs) | Free, public, no key |
| **Arbeitnow API** | Lead source (EU job board) | Free, public, no key |
| **Hunter.io** | Company email enrichment | 50 free lookups/month, no card |
| **Google Gemini** *(optional stretch)* | AI outreach-hook generation (`gemini-flash-lite-latest`) | Free tier |
| **Node.js** | Runs n8n via `npx` | Free |
| CSV file | Output destination | Free / local |

---

## Quick start

> 📋 **For a full copy-paste runbook** (Docker + Node options, every step from launch to output),
> see **[COMMANDS.md](COMMANDS.md)**.

**Prerequisites:** Node.js (LTS) — `node -v`. No Docker required.

```bash
# 1. Clone and enter the repo
git clone <your-repo-url> LeadGenerationAutomationTool
cd LeadGenerationAutomationTool

# 2. Install n8n once (recommended — makes every startup instant)
npm install -g n8n              # use: sudo npm install -g n8n  if you hit a permissions error

# 3. (Optional) enable AI features — otherwise skip this line and scoring is rule-based
cp .env.example .env            # then add GEMINI_API_KEY to .env

# 4. Start n8n from the repo root
./start-n8n.command             # loads .env + allow-lists this folder for file output

# 5. Open the editor
open http://localhost:5678      # create a local owner account (stored only on your machine)
```

> **Runs with zero keys.** Without `.env` you still get de-duplicated, scored leads (rule-based
> keyword match) written to `output/leads.csv`. Add a Gemini key for embedding-based scoring +
> outreach hooks, and a Hunter key (below) for contact emails — both optional.

> **Why the launch script?** By default n8n's file nodes are sandboxed to `~/.n8n-files` for
> security, so writing `output/leads.csv` inside this project would be refused with *"file is not
> writable."* The script sets `N8N_RESTRICT_FILE_ACCESS_TO` to this project folder, which
> allow-lists it so the workflow can write the CSV here. (Alternatively, point the **Write CSV File**
> node at `~/.n8n-files/leads.csv` and plain `npx n8n` works with no env vars.)

**Import the workflow**

1. In n8n: top-right **⋯ menu → Import from File**
2. Select `workflow/lead-generation.json`

**Add your Hunter.io credential** (keeps the key out of the workflow)

1. Get a free key at <https://hunter.io/api-keys>
2. In n8n: **Credentials → New → "Query Auth"**
   - **Name:** `api_key`
   - **Value:** *your Hunter API key*
   - Save as **"Hunter API Key"**
3. Open the **Enrich Emails (Hunter)** node → select that credential

**Run it**

- Click **Execute Workflow**. The final CSV is written to `output/leads.csv`.

---

## Configuration

Everything is controlled from the **Config** node — no code changes needed:

| Field | Meaning | Example |
|-------|---------|---------|
| `keyword` | One or more comma-separated keywords to match in the role title/tags | `engineer` · `ai engineer, ml` |
| `location` | Optional location boost for scoring (leave blank to skip) | `Berlin` |
| `maxLeads` | Cap on final leads — also protects Hunter's free credit quota | `30` |

---

## AI outreach hooks (optional stretch)

Each lead can get a **one-line, personalised outreach opener** drafted by an LLM
(Google **Gemini** `gemini-flash-lite-latest` — fast and low-cost). This is fully optional:

- Configure it by copying `.env.example` → `.env` and adding your `GEMINI_API_KEY`,
  then launch with `./start-n8n.command` (it loads `.env` automatically).
- An **IF node** (`LLM configured?`) checks for the key at runtime. **If no key is set,
  the workflow skips the LLM branch entirely and produces the same CSV as without it** —
  nothing breaks for anyone who runs it unconfigured.
- The key is read from the environment via `{{ $env.GEMINI_API_KEY }}` — never hard-coded
  in the workflow. Each Gemini call uses **continue-on-error**, so one failed request can't
  abort the run (that lead's hook becomes `not generated`).

> ⚠️ **Never commit `.env`** — it holds a live API key. Only `.env.example` (no key) is meant to be shared.

The provider is swappable: point `GEMINI_*` at any model, or change the `Outreach Hook`
node to another API. Set the model in the **Config** via `GEMINI_MODEL`.

---

## Data sources & compliance

This tool **does not scrape LinkedIn or any website**. It uses only official / public APIs:

- **RemoteOK** — public JSON API (`/api`), attribution honoured via the source URL kept on every lead.
- **Arbeitnow** — public job-board API.
- **Hunter.io** — official email-finding API, used within its free tier.

> **Why not LinkedIn?** LinkedIn's Terms of Service prohibit automated scraping, and doing so risks
> account bans and legal exposure. Public job-board APIs give equivalent hiring-intent signal
> **compliantly**. If richer people-data were required, the compliant path is a licensed provider
> (e.g. Apollo.io / official LinkedIn partner APIs), not scraping.

No real personal data is contacted — this is a demo; outreach is out of scope.

---

## How enrichment works (and its honest limitation)

Job-board APIs give a **company name**, not a website domain, and Hunter's Domain Search needs a domain.
The workflow therefore **derives a candidate domain** from the company name
(`"GFN GmbH"` → `gfn.com`, stripping legal suffixes and punctuation).

- ✅ Works for many companies whose domain matches their name.
- ⚠️ Misses companies whose domain differs (`"Flix"` → `flix.com` may be wrong vs `flixbus.com`).
- Every lookup **continues on failure** and falls back to `email: "not found"` — a bad domain never crashes the run.

To respect Hunter's **50-credit/month** free tier, the pipeline:
- de-duplicates **before** enrichment (one lookup per unique company), and
- caps the run at `maxLeads` (default 30).

A production version would resolve domains via a company-enrichment API before Hunter (see *Future improvements*).

---

## Scoring methodology

`Score Leads` assigns a transparent score `0–100` and records the reasons:

| Signal | Points |
|--------|--------|
| **Keyword relevance** — *embedding cosine similarity* (Gemini `gemini-embedding-001`), scaled | up to +40 |
| &nbsp;&nbsp;↳ fallback when no Gemini key: literal keyword match in title | +20, +15 per extra hit (max +35) |
| Seniority (`senior/lead/principal/staff/head/director/vp/chief`) | +20 |
| Location match (if `location` set) / remote-friendly | +15 / +5 |
| Verified email found | +30 (conf ≥80) · +20 (≥50) · +15 (else) |

**Embedding-based keyword relevance** is the AI/ML upgrade over pure string matching: the search
keyword and each lead's role are embedded, and their **cosine similarity** drives the score — so
"Senior ML Engineer" ranks highly for the keyword *"AI engineer"* even without a literal word match.
The raw similarity is stored per lead in a `semantic_similarity` column. If no Gemini key is set,
scoring automatically falls back to literal keyword matching — the run never breaks.

Leads are **sorted best-first**. Every row carries a `score_reasons` field so the ranking is auditable —
important for a lead list a human will actually work through.

---

## Robustness / error handling

- Both source APIs and the Hunter node use **Continue-On-Error** — one bad response never aborts the run.
- The Hunter node uses **`neverError`** + **request batching** (1 req / 1.2 s) to stay under rate limits.
- Code nodes defensively coerce/guard every field (missing company, role, tags, location).
- Records missing a company or role are dropped rather than exported dirty.

---

## Deliverables

| Deliverable | Location |
|-------------|----------|
| n8n workflow (importable JSON) | `workflow/lead-generation.json` |
| This README | `README.md` |
| Sample output (≥20 deduped, scored leads) | `output/leads.csv` |
| Screen recording of a live run | *(3–5 min, recorded separately)* |

---

## Limitations & future improvements

- **Domain guessing** is the weakest link — add a company→domain enrichment step (Clearbit-style / Apollo) before Hunter.
- Add **more sources** (Adzuna, Jooble) behind the same normalise-and-merge pattern for wider coverage.
- Replace rule-based scoring with **embedding-based keyword similarity** for fuzzier matching.
- **Smarter LLM use**: batch the Gemini calls or summarise each lead, not just a one-line hook.
- Push output to **Google Sheets / a dashboard** and send a **daily Slack digest**.
- Persist a **seen-leads store** so scheduled runs only surface genuinely new leads.

---

## Stretch goals

- [x] Multi-source merge + cross-source de-duplication (RemoteOK + Arbeitnow)
- [x] **Embedding-based keyword similarity scoring** (Gemini `gemini-embedding-001`) with rule-based fallback
- [x] **LLM-drafted personalised outreach hook per lead** (Google Gemini — optional, env-gated)
- [x] **Email digest** — sends the CSV to a recipient (optional, off by default)
---
