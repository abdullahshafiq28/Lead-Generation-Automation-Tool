# 🖥️ COMMANDS — run the Lead-Gen tool from scratch

Follow top to bottom. Each block says **WHERE** to run it (💻 Terminal or 🌐 Browser).
Everything after the core run (Gemini AI, email) is **optional** — skip it and the tool still works.

> **All commands below run from the repo root** — `cd` into the folder you cloned first (Step 0).

---

## STEP 0 — Get the code & prerequisites (one-time)  💻 Terminal

```bash
git clone <your-repo-url> LeadGenerationAutomationTool
cd LeadGenerationAutomationTool
cp .env.example .env          # optional — only if you want the AI / email features
npm install -g n8n            # recommended: installs n8n once so startup is instant
```

- Node.js LTS: https://nodejs.org — check with `node -v`
- **`npm install -g n8n`** (recommended, ~3–5 min once). The launcher works without it, but it
  falls back to `npx n8n`, which **re-downloads n8n whenever a newer version is published**
  (n8n ships almost daily) — that makes startup slow. A global install = instant every time.
  *(If it errors with a permissions/`EACCES` message, use `sudo npm install -g n8n`.)*
- Docker Desktop (only for Option A): https://www.docker.com/products/docker-desktop/

> ℹ️ **The tool runs with zero keys.** Without `.env` you still get de-duplicated, scored
> leads (rule-based). Add `GEMINI_API_KEY` to `.env` for AI similarity scoring + outreach
> hooks; add a Hunter.io key in the n8n UI (Step 4) for contact emails. All optional.

---

## STEP 1 — Launch n8n locally

### ▶️ Option A — Docker  💻 Terminal
Requires Docker Desktop **running**. Paste as ONE command:

```bash
# from the repo root  (no -t, so n8n won't show the interactive "Press o" prompt):
docker run --rm \
  --name n8n \
  -p 5678:5678 \
  --env-file .env \
  -e N8N_SECURE_COOKIE=false \
  -e N8N_BLOCK_ENV_ACCESS_IN_NODE=false \
  -e N8N_RESTRICT_FILE_ACCESS_TO=/data \
  -e OUTPUT_DIR=/data/output \
  -v "$(pwd)":/data \
  -v n8n_data:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n
```
> This mounts the project at `/data` so the CSV lands in your local `output/` folder,
> passes the Gemini key from `.env`, and keeps your n8n account in a `n8n_data` volume.
> If the CSV step later errors with a permission problem, use Option B instead (simpler on macOS).

### ▶️ Option B — Node / npx  💻 Terminal  *(recommended — already set up & tested)*

```bash
# from the repo root:
./start-n8n.command
```
<sub>Equivalent explicit form, if the script won't run (from the repo root):</sub>
```bash
export N8N_SECURE_COOKIE=false
export N8N_RESTRICT_FILE_ACCESS_TO="$(pwd)"
export N8N_BLOCK_ENV_ACCESS_IN_NODE=false
[ -f .env ] && { set -a; . ./.env; set +a; }
npx -y n8n start
```

✅ **Wait for the line:** `Editor is now accessible via: http://localhost:5678`
(First run downloads n8n — a few minutes. Leave this Terminal window open; it IS the server.)

---

## STEP 2 — Open the editor & create your account  🌐 Browser

1. Open **http://localhost:5678**
2. Fill in the **Set up owner account** form (email, first/last name, password). Stored only on your machine.
3. Skip the survey if it appears.

---

## STEP 3 — Import the workflow  🌐 Browser

1. Top-right **⋯ menu → Import from File**
2. Choose:
   ```
   workflow/lead-generation.json      (inside the repo folder you cloned)
   ```
3. The full pipeline appears (21 nodes).

---

## STEP 4 — Add the Hunter.io credential (for emails)  🌐 Browser

1. Get a free key: https://hunter.io/api-keys
2. Click the **Enrich Emails (Hunter)** node → **Credential → Create New → "Query Auth"**
3. Set **Name** = `api_key`, **Value** = *your Hunter key* → **Save** (call it "Hunter API Key")
4. Make sure that credential is selected on the node.

> No Hunter key? The node is continue-on-error — the run still finishes; emails just show `not found`.

**Gemini needs NO credential here** — its key is already loaded from `.env` via env vars.

---

## STEP 5 — Run it  🌐 Browser

1. Click **Execute Workflow** (bottom center).
2. Watch the nodes turn green, left → right:
   sources → merge → dedupe → **Hunter emails** → **Gemini embeddings** → **score** → **Gemini hooks** → CSV.
3. Click the **Score Leads** node to see the ranked table (`score`, `semantic_similarity`, `outreach_hook`).

---

## STEP 6 — Get the output  💻 Terminal (or Finder)

The CSV is written to your project:
```bash
open output/leads.csv       # from the repo root  (Windows: start output\leads.csv)
```
(or open `output/leads.csv` from the To CSV node's download button in the browser.)

---

## STEP 7 *(optional)* — Email the CSV to husnainkhalid626@gmail.com

The workflow has a `Send email?` gate + `Send Email` node, off by default.

1. **Create an SMTP credential** 🌐 Browser: **Credentials → New → "SMTP"**. For Gmail:
   - Host: `smtp.gmail.com` · Port: `465` · SSL: on
   - User: your Gmail · Password: a **Gmail App Password**
     (Google Account → Security → 2-Step Verification → App passwords)
   - Save it named **"SMTP"**, and select it on the **Send Email** node.
2. **Turn it on** 💻 Terminal — edit `.env`, set `SEND_EMAIL=true`, then **stop n8n (Ctrl-C) and relaunch** (Step 1) so it picks up the change.
3. Run again → the CSV is emailed as an attachment.

> Prefer Slack? Swap the `Send Email` node for an **HTTP Request** node POSTing to a Slack
> Incoming Webhook URL — no SMTP needed.

---

## Troubleshooting  💻 Terminal

| Symptom | Fix |
|---|---|
| `The file … is not writable` | Launch via **Option B** / `./start-n8n.command` (sets `N8N_RESTRICT_FILE_ACCESS_TO`). Don't use bare `npx n8n`. |
| `port 5678 already in use` | Another n8n is running. Stop it: `pkill -f n8n` then relaunch. |
| Gemini hooks show `not generated` | Key not loaded — confirm `.env` has `GEMINI_API_KEY` and you launched via the script (loads `.env`). |
| Signup screen missing / old data (**npx**) | Fresh start: stop n8n, then `mv ~/.n8n ~/.n8n.bak` and relaunch. |
| **Docker** shows **login** instead of sign-up | The `n8n_data` volume kept your old account. Wipe it: `docker rm -f n8n 2>/dev/null && docker volume rm n8n_data`, then re-run. (Or just log in with the account you made.) |
| Change `.env` | Always **stop (Ctrl-C) and relaunch** — env is read at startup. |
| Email: `535-5.7.8 Username and Password not accepted` | Gmail needs an **App Password**, not your normal password. Enable 2-Step Verification → https://myaccount.google.com/apppasswords → create one → paste it **without spaces** into the SMTP credential; **User** must be the full `…@gmail.com`; also set `SMTP_FROM` to that address in `.env` and restart. |

---

## One-glance recap

```
Terminal:  ./start-n8n.command                     (from the repo root)
Browser:   http://localhost:5678  → sign up
Browser:   ⋯ → Import → workflow/lead-generation.json
Browser:   Enrich Emails (Hunter) → add Query Auth cred (api_key = your key)
Browser:   Execute Workflow
Terminal:  open output/leads.csv
```
