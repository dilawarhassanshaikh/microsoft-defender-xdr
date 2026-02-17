# Security Framework Compliance Dashboard

Centralised Fluent Design dashboard that maps Microsoft Defender XDR capabilities to three industry-standard security frameworks — **ISO 27001:2022**, **CIS Controls v8**, and **NIST CSF 2.0** — and lets administrators connect their tenant to review compliance posture.

## Dashboard Pages

| Page | File | Description |
|------|------|-------------|
| **Main Dashboard** | `index.html` | Hero stats, framework score cards, cross-framework mapping table, tenant connection, and admin guide |
| **ISO 27001:2022** | `iso27001.html` | Annex A control mapping across Organisational (A.5), People (A.6), Physical (A.7), and Technological (A.8) domains |
| **CIS Controls v8** | `cis.html` | Safeguard mapping with Implementation Group badges (IG1 / IG2 / IG3) across 14 control families |
| **NIST CSF 2.0** | `nist.html` | Function mapping for Govern, Identify, Protect, Detect, Respond, and Recover |
| **Tenant Review** | `tenant-review.html` | Pre-connection checklist, per-product evaluation breakdown, assessment timeline, and export options |

## Prerequisites

The dashboard is a static HTML/CSS/JS application with **zero external dependencies**. You need:

| Requirement | Detail |
|-------------|--------|
| **Web Server** | Any static file server (Python, Node, Apache, Nginx, IIS) |
| **Browser** | Any modern browser (Edge, Chrome, Firefox, Safari) |
| **Tenant Access** *(optional)* | Azure AD / Entra ID Global Administrator or Security Reader for tenant connection |

## Running the Dashboard

### Option 1 — Python (Recommended for Quick Start)

Python 3 is pre-installed on most systems. Run from the repository root:

```bash
cd security-framework-dashboard
python3 -m http.server 8000
```

Open your browser at **http://localhost:8000**.

### Option 2 — Node.js (npx)

If you have Node.js installed, use `npx serve` without installing anything globally:

```bash
npx serve security-framework-dashboard -l 8000
```

### Option 3 — PowerShell (Windows / IIS Express)

For Windows environments without Python or Node:

```powershell
# Using dotnet-serve (install once)
dotnet tool install -g dotnet-serve
dotnet serve -d security-framework-dashboard -p 8000

# Or using PowerShell's built-in .NET HttpListener
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:8000/")
$listener.Start()
Write-Host "Dashboard running at http://localhost:8000"
# (Simplified — see Microsoft docs for full static file serving)
```

### Option 4 — Docker

```bash
docker run -d -p 8000:80 \
  -v "$(pwd)/security-framework-dashboard:/usr/share/nginx/html:ro" \
  --name xdr-dashboard \
  nginx:alpine
```

### Option 5 — Open Directly

For quick local review (without a server), simply open `index.html` directly in your browser. Note: `localStorage`-based tenant persistence requires a proper `http://` origin, so the tenant connection feature works best with a web server.

## Admin Guide: Connecting Your Tenant

### Step 1 — Register an App in Azure / Entra Portal

1. Sign in to the [Azure portal](https://portal.azure.com) as a **Global Administrator** or **Application Administrator**
2. Navigate to **Microsoft Entra ID > App registrations > New registration**
3. Name the app (e.g. `XDR Compliance Dashboard`) and set the redirect URI if using interactive auth
4. Record the **Application (Client) ID** and **Directory (Tenant) ID**

### Step 2 — Configure API Permissions

Add the following **Application permissions** under **Microsoft Graph**:

| Permission | Type | Purpose |
|-----------|------|---------|
| `SecurityEvents.Read.All` | Application | Read security alerts and incidents |
| `DeviceManagementConfiguration.Read.All` | Application | Read Intune/MDE device configurations |
| `Policy.Read.All` | Application | Read conditional access and security policies |
| `Directory.Read.All` | Application | Read directory data for identity posture |

### Step 3 — Grant Admin Consent

A **Global Administrator** must grant tenant-wide consent:

1. In the app registration, go to **API permissions**
2. Click **Grant admin consent for [your tenant]**
3. Confirm in the dialog

Without admin consent, the dashboard cannot retrieve any compliance data from the tenant.

### Step 4 — Create a Client Secret (Service Principal Auth)

If using service principal authentication:

1. Go to **Certificates & secrets > New client secret**
2. Set a description and expiry (recommended: 6-12 months)
3. Copy the **Value** immediately — it is shown only once

### Step 5 — Connect via the Dashboard

1. Open the dashboard and click **Connect Tenant** in the top navigation bar
2. Enter your **Tenant ID** (GUID or `.onmicrosoft.com` domain)
3. Enter a **Display Name** for the tenant
4. Select an **Authentication Method**:
   - **Interactive (Browser Sign-In)** — redirects to Microsoft login; suitable for ad-hoc reviews
   - **Service Principal** — uses the App Registration client ID and secret; suitable for automated or headless environments
   - **Managed Identity** — uses Azure Managed Identity; suitable when the dashboard runs on an Azure VM or App Service
5. Tick the frameworks you want to evaluate (ISO 27001, CIS, NIST)
6. Click **Connect & Evaluate**

### Step 6 — Review Compliance Scores

After connection, the dashboard will:

- Query Microsoft Graph for your Defender XDR configuration
- Map each capability to the selected framework controls
- Calculate compliance scores (Compliant = 100%, Partial = 50%, Non-Compliant = 0%)
- Display recommendations for non-compliant and partially compliant controls
- Provide links to the PowerShell remediation scripts in this repository

### Step 7 — Remediate Findings

Use the deployment scripts in this repository to address gaps:

| Finding | Remediation Script |
|---------|-------------------|
| MDI sensor not deployed | `defender-for-identity/sensor-deployment/Install-MDISensor.ps1` |
| Audit policies missing | `defender-for-identity/prerequisites/Set-MDIAuditPolicy.ps1` |
| Safe Attachments not configured | `defender-for-office365/deployment/Invoke-MDODeployment.ps1` |
| ASR rules not enabled | `defender-for-endpoint/deployment/Invoke-MDEDeployment.ps1` |
| DMARC/DKIM/SPF not configured | Configure via your DNS provider (outside Defender scope) |
| DLP not enabled | Configure via the Microsoft Purview compliance portal |

## Frameworks Covered

### ISO 27001:2022

The international standard for information security management systems (ISMS). The 2022 revision reorganises controls into four themes:

- **A.5** — Organisational Controls (37 controls)
- **A.6** — People Controls (8 controls)
- **A.7** — Physical Controls (14 controls)
- **A.8** — Technological Controls (34 controls)

The dashboard maps Defender capabilities primarily to A.5 and A.8 domains, where digital security controls apply.

### CIS Controls v8

A prioritised set of 18 top-level controls with 153 safeguards from the Center for Internet Security. Organised into three Implementation Groups:

- **IG1** — Essential Cyber Hygiene (56 safeguards)
- **IG2** — Expanded coverage (74 additional safeguards)
- **IG3** — Comprehensive coverage (23 additional safeguards)

The dashboard maps across CIS 1-2 (Asset Inventory), 4-6 (Configuration and Access), 7 (Vulnerability Management), 8-10 (Logging and Malware), 13-14 (Network and Awareness), 16-18 (Application Security, Incident Response, Penetration Testing).

### NIST CSF 2.0

The NIST Cybersecurity Framework 2.0 defines six core functions:

- **Govern (GV)** — Organisational context, strategy, and oversight
- **Identify (ID)** — Asset management, risk assessment, improvement
- **Protect (PR)** — Access control, data security, platform security
- **Detect (DE)** — Continuous monitoring, adverse event analysis
- **Respond (RS)** — Incident management, analysis, mitigation
- **Recover (RC)** — Incident recovery planning and execution

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Markup** | Semantic HTML5 with ARIA attributes |
| **Styling** | Fluent Design System 2 dark theme (CSS custom properties) |
| **Logic** | Vanilla JavaScript (ES2020, IIFE pattern) |
| **Typography** | Segoe UI Variable, system-ui fallback |
| **Icons** | Inline SVG (no icon library dependency) |
| **State** | `localStorage` for tenant persistence |
| **Build** | None — zero-build, zero-dependency static files |

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| Tenant connection not persisting | Ensure you are serving via `http://` or `https://`, not `file://`. localStorage requires a proper origin. |
| Scores showing `--` | Click **Connect Tenant** and complete the connection flow. Scores populate after evaluation. |
| CORS errors in browser console | Ensure the Microsoft Graph API permissions include the correct application permissions and admin consent has been granted. |
| Dashboard not rendering | Check the browser console for JavaScript errors. Ensure all files (`index.html`, `styles.css`, `app.js`) are in the same directory. |
| Service Principal auth failing | Verify the Client ID and Client Secret are correct, the secret has not expired, and admin consent has been granted. |
