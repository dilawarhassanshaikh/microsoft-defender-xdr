/* ============================================================
   Security Framework Compliance Dashboard — Application Logic
   ============================================================ */

(function () {
  "use strict";

  /* ----------------------------------------------------------
     1. CROSS-FRAMEWORK CONTROL MAPPING DATA MODEL
     Maps Microsoft Defender XDR capabilities to ISO 27001,
     CIS Controls v8, and NIST CSF 2.0
  ---------------------------------------------------------- */

  const controlMappings = [
    // --- Defender for Endpoint (MDE) ---
    {
      capability: "Endpoint Detection & Response (EDR)",
      iso27001: "A.8.7 — Malware protection",
      cis: "CIS 10.1 — Deploy anti-malware software",
      nist: "DE.CM-01 — Networks monitored",
      status: "pass",
      product: "mde",
    },
    {
      capability: "Attack Surface Reduction Rules",
      iso27001: "A.8.8 — Management of technical vulnerabilities",
      cis: "CIS 10.5 — Enable anti-exploitation features",
      nist: "PR.PT-03 — Least functionality principle",
      status: "pass",
      product: "mde",
    },
    {
      capability: "Automated Investigation & Remediation",
      iso27001: "A.5.25 — Assessment of information security events",
      cis: "CIS 17.4 — Establish incident response process",
      nist: "RS.AN-03 — Analysis performed",
      status: "pass",
      product: "mde",
    },
    {
      capability: "Device Inventory & Health",
      iso27001: "A.5.9 — Inventory of information assets",
      cis: "CIS 1.1 — Establish enterprise asset inventory",
      nist: "ID.AM-01 — Hardware inventoried",
      status: "pass",
      product: "mde",
    },
    {
      capability: "Network Protection",
      iso27001: "A.8.20 — Network security",
      cis: "CIS 9.2 — Use DNS filtering services",
      nist: "PR.DS-02 — Data-in-transit protected",
      status: "partial",
      product: "mde",
    },
    {
      capability: "Web Content Filtering",
      iso27001: "A.8.23 — Web filtering",
      cis: "CIS 9.3 — Maintain URL filtering",
      nist: "PR.PT-03 — Least functionality principle",
      status: "partial",
      product: "mde",
    },
    {
      capability: "Controlled Folder Access",
      iso27001: "A.8.3 — Information access restriction",
      cis: "CIS 10.4 — Configure anti-malware scanning",
      nist: "PR.DS-01 — Data-at-rest protected",
      status: "pass",
      product: "mde",
    },

    // --- Defender for Identity (MDI) ---
    {
      capability: "Identity Threat Detection",
      iso27001: "A.8.16 — Monitoring activities",
      cis: "CIS 8.11 — Conduct audit log reviews",
      nist: "DE.AE-02 — Events analysed for anomalies",
      status: "pass",
      product: "mdi",
    },
    {
      capability: "Lateral Movement Path Detection",
      iso27001: "A.8.15 — Logging",
      cis: "CIS 13.5 — Manage access control",
      nist: "DE.CM-03 — Personnel activity monitored",
      status: "pass",
      product: "mdi",
    },
    {
      capability: "Compromised Credential Detection",
      iso27001: "A.5.17 — Authentication information",
      cis: "CIS 5.2 — Use unique passwords",
      nist: "PR.AC-07 — Users authenticated",
      status: "pass",
      product: "mdi",
    },
    {
      capability: "Active Directory Security Posture",
      iso27001: "A.5.15 — Access control",
      cis: "CIS 5.4 — Restrict administrator privileges",
      nist: "PR.AC-06 — Identities managed",
      status: "partial",
      product: "mdi",
    },
    {
      capability: "Domain Controller Sensor Deployment",
      iso27001: "A.8.9 — Configuration management",
      cis: "CIS 4.1 — Establish secure configuration process",
      nist: "PR.IP-01 — Baseline configurations",
      status: "pass",
      product: "mdi",
    },

    // --- Defender for Office 365 (MDO) ---
    {
      capability: "Safe Attachments",
      iso27001: "A.8.7 — Malware protection",
      cis: "CIS 9.6 — Block unnecessary file types",
      nist: "DE.CM-01 — Networks monitored",
      status: "pass",
      product: "mdo",
    },
    {
      capability: "Safe Links",
      iso27001: "A.8.23 — Web filtering",
      cis: "CIS 9.3 — Maintain URL filtering",
      nist: "PR.PT-03 — Least functionality principle",
      status: "pass",
      product: "mdo",
    },
    {
      capability: "Anti-Phishing Policies",
      iso27001: "A.6.3 — Information security awareness",
      cis: "CIS 14.1 — Establish security awareness program",
      nist: "PR.AT-01 — Users informed & trained",
      status: "partial",
      product: "mdo",
    },
    {
      capability: "Zero-hour Auto Purge (ZAP)",
      iso27001: "A.5.26 — Response to information security incidents",
      cis: "CIS 17.5 — Assign incident response roles",
      nist: "RS.MI-01 — Incidents contained",
      status: "pass",
      product: "mdo",
    },
    {
      capability: "Email Authentication (DMARC/DKIM/SPF)",
      iso27001: "A.5.14 — Information transfer",
      cis: "CIS 9.5 — Implement DMARC",
      nist: "PR.DS-02 — Data-in-transit protected",
      status: "fail",
      product: "mdo",
    },

    // --- Defender for Cloud Apps (MDCA) ---
    {
      capability: "Shadow IT Discovery",
      iso27001: "A.5.9 — Inventory of information assets",
      cis: "CIS 2.1 — Establish software inventory",
      nist: "ID.AM-02 — Software inventoried",
      status: "pass",
      product: "mdca",
    },
    {
      capability: "App Governance Policies",
      iso27001: "A.5.23 — Information security for cloud services",
      cis: "CIS 2.3 — Address unauthorised software",
      nist: "PR.AC-04 — Access permissions managed",
      status: "partial",
      product: "mdca",
    },
    {
      capability: "Session Controls (Conditional Access App Control)",
      iso27001: "A.8.3 — Information access restriction",
      cis: "CIS 6.8 — Define and maintain role-based access control",
      nist: "PR.AC-04 — Access permissions managed",
      status: "partial",
      product: "mdca",
    },
    {
      capability: "OAuth App Monitoring",
      iso27001: "A.8.26 — Application security requirements",
      cis: "CIS 16.10 — Apply secure design principles",
      nist: "PR.AC-06 — Identities managed",
      status: "pass",
      product: "mdca",
    },

    // --- Defender Vulnerability Management (MDVM) ---
    {
      capability: "Vulnerability Assessment & Prioritisation",
      iso27001: "A.8.8 — Management of technical vulnerabilities",
      cis: "CIS 7.1 — Establish vulnerability management process",
      nist: "ID.RA-01 — Vulnerabilities identified",
      status: "pass",
      product: "mdvm",
    },
    {
      capability: "Security Baselines Assessment",
      iso27001: "A.8.9 — Configuration management",
      cis: "CIS 4.1 — Establish secure configuration process",
      nist: "PR.IP-01 — Baseline configurations",
      status: "partial",
      product: "mdvm",
    },
    {
      capability: "Software Inventory",
      iso27001: "A.5.9 — Inventory of information assets",
      cis: "CIS 2.1 — Establish software inventory",
      nist: "ID.AM-02 — Software inventoried",
      status: "pass",
      product: "mdvm",
    },
    {
      capability: "Browser Extension Assessment",
      iso27001: "A.8.26 — Application security requirements",
      cis: "CIS 2.3 — Address unauthorised software",
      nist: "ID.AM-02 — Software inventoried",
      status: "fail",
      product: "mdvm",
    },

    // --- XDR Portal ---
    {
      capability: "Unified Incident Queue",
      iso27001: "A.5.25 — Assessment of information security events",
      cis: "CIS 17.4 — Establish incident response process",
      nist: "DE.AE-04 — Impact of events determined",
      status: "pass",
      product: "xdr",
    },
    {
      capability: "Advanced Hunting (KQL)",
      iso27001: "A.8.15 — Logging",
      cis: "CIS 8.2 — Collect audit logs",
      nist: "DE.AE-02 — Events analysed for anomalies",
      status: "pass",
      product: "xdr",
    },
    {
      capability: "Automated Investigation & Response",
      iso27001: "A.5.26 — Response to information security incidents",
      cis: "CIS 17.8 — Conduct post-incident reviews",
      nist: "RS.RP-01 — Response plan executed",
      status: "pass",
      product: "xdr",
    },
    {
      capability: "Secure Score",
      iso27001: "A.5.36 — Compliance with policies",
      cis: "CIS 18.1 — Establish penetration testing program",
      nist: "ID.GV-03 — Cybersecurity roles established",
      status: "partial",
      product: "xdr",
    },
    {
      capability: "Role-Based Access Control (RBAC)",
      iso27001: "A.5.15 — Access control",
      cis: "CIS 6.8 — Define and maintain role-based access control",
      nist: "PR.AC-04 — Access permissions managed",
      status: "pass",
      product: "xdr",
    },
    {
      capability: "Threat Analytics Reports",
      iso27001: "A.5.7 — Threat intelligence",
      cis: "CIS 17.9 — Establish security incident thresholds",
      nist: "ID.RA-02 — Threat intelligence received",
      status: "pass",
      product: "xdr",
    },
    {
      capability: "Data Loss Prevention Integration",
      iso27001: "A.5.12 — Classification of information",
      cis: "CIS 3.1 — Establish data management process",
      nist: "PR.DS-01 — Data-at-rest protected",
      status: "fail",
      product: "xdr",
    },
    {
      capability: "Multi-Tenant Management",
      iso27001: "A.5.8 — Information security in project management",
      cis: "CIS 18.3 — Remediate penetration test findings",
      nist: "ID.GV-02 — Cybersecurity roles coordinated",
      status: "partial",
      product: "xdr",
    },
  ];

  /* ----------------------------------------------------------
     2. PRODUCT NAME MAP
  ---------------------------------------------------------- */

  const productNames = {
    mde:  "Defender for Endpoint",
    mdi:  "Defender for Identity",
    mdo:  "Defender for Office 365",
    mdca: "Defender for Cloud Apps",
    mdvm: "Vulnerability Management",
    xdr:  "XDR Portal",
  };

  /* ----------------------------------------------------------
     3. TENANT CONNECTION STATE
  ---------------------------------------------------------- */

  let tenantState = {
    connected: false,
    tenantId: "",
    tenantName: "",
    authMethod: "interactive",
    frameworks: { iso27001: true, cis: true, nist: true },
    lastAssessment: null,
  };

  /* ----------------------------------------------------------
     4. DOM REFERENCES
  ---------------------------------------------------------- */

  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => document.querySelectorAll(sel);

  /* ----------------------------------------------------------
     5. INITIALISATION
  ---------------------------------------------------------- */

  document.addEventListener("DOMContentLoaded", () => {
    initModal();
    initFilters();
    renderMappingTable(controlMappings);
    updateScores(controlMappings);
    restoreTenantState();
  });

  /* ----------------------------------------------------------
     6. MODAL: TENANT CONNECTION
  ---------------------------------------------------------- */

  function initModal() {
    const overlay = $("#modal-overlay");
    const btnOpen = $("#btn-connect-tenant");
    const btnClose = $("#modal-close");
    const btnCancel = $("#btn-cancel");
    const btnConnect = $("#btn-connect");
    const authSelect = $("#auth-method");
    const spFields = $("#sp-fields");

    btnOpen.addEventListener("click", () => {
      overlay.hidden = false;
      $("#tenant-id").focus();
    });

    function closeModal() { overlay.hidden = true; }
    btnClose.addEventListener("click", closeModal);
    btnCancel.addEventListener("click", closeModal);
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) closeModal();
    });

    // Toggle service principal fields
    authSelect.addEventListener("change", () => {
      spFields.hidden = authSelect.value !== "service-principal";
    });

    // Connect
    btnConnect.addEventListener("click", () => {
      const tenantId = $("#tenant-id").value.trim();
      const tenantName = $("#tenant-name").value.trim() || tenantId;
      if (!tenantId) {
        $("#tenant-id").focus();
        return;
      }

      tenantState = {
        connected: true,
        tenantId,
        tenantName,
        authMethod: authSelect.value,
        frameworks: {
          iso27001: $("#fw-iso27001").checked,
          cis: $("#fw-cis").checked,
          nist: $("#fw-nist").checked,
        },
        lastAssessment: new Date().toISOString(),
      };

      try { localStorage.setItem("xdr-tenant", JSON.stringify(tenantState)); } catch (_) {}

      applyTenantState();
      closeModal();
      simulateAssessment();
    });
  }

  /* ----------------------------------------------------------
     7. TENANT STATE MANAGEMENT
  ---------------------------------------------------------- */

  function restoreTenantState() {
    try {
      const saved = localStorage.getItem("xdr-tenant");
      if (saved) {
        tenantState = JSON.parse(saved);
        if (tenantState.connected) {
          applyTenantState();
        }
      }
    } catch (_) {}
  }

  function applyTenantState() {
    if (!tenantState.connected) return;

    // Show tenant indicator
    const indicator = $("#tenant-indicator");
    indicator.hidden = false;
    $("#tenant-name-display").textContent = tenantState.tenantName;

    // Update connect button
    const btnConnect = $("#btn-connect-tenant");
    btnConnect.innerHTML = '<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1a3 3 0 100 6 3 3 0 000-6zM3 12c0-2.2 2.2-4 5-4s5 1.8 5 4v1H3v-1z"/></svg><span>Switch Tenant</span>';
  }

  /* ----------------------------------------------------------
     8. SIMULATE COMPLIANCE ASSESSMENT
  ---------------------------------------------------------- */

  function simulateAssessment() {
    // Randomise some statuses to simulate a real assessment
    const statuses = ["pass", "pass", "pass", "partial", "partial", "fail"];
    const assessed = controlMappings.map((m) => ({
      ...m,
      status: statuses[Math.floor(Math.random() * statuses.length)],
    }));

    renderMappingTable(assessed);
    updateScores(assessed);
    updateReviewSection(assessed);
  }

  /* ----------------------------------------------------------
     9. SCORING ENGINE
  ---------------------------------------------------------- */

  function updateScores(mappings) {
    const total = mappings.length;
    const passing = mappings.filter((m) => m.status === "pass").length;
    const partial = mappings.filter((m) => m.status === "partial").length;
    const failing = mappings.filter((m) => m.status === "fail").length;
    const score = total > 0 ? Math.round(((passing + partial * 0.5) / total) * 100) : 0;

    // Overall stats
    $("#stat-overall").textContent = score + "%";
    $("#stat-controls").textContent = total;
    $("#stat-passing").textContent = passing;
    $("#stat-failing").textContent = failing;
    $("#bar-overall").style.width = score + "%";

    // Per-framework scoring
    updateFrameworkScore("iso27001", mappings);
    updateFrameworkScore("cis", mappings);
    updateFrameworkScore("nist", mappings);
  }

  function updateFrameworkScore(framework, mappings) {
    const key = framework === "iso27001" ? "iso27001" : framework === "cis" ? "cis" : "nist";
    const field = framework === "iso27001" ? "iso27001" : framework === "cis" ? "cis" : "nist";

    // Count statuses (all mappings have entries in every framework)
    const total = mappings.length;
    const pass = mappings.filter((m) => m.status === "pass").length;
    const partial = mappings.filter((m) => m.status === "partial").length;
    const fail = mappings.filter((m) => m.status === "fail").length;
    const score = total > 0 ? Math.round(((pass + partial * 0.5) / total) * 100) : 0;

    // Update ring
    const ring = $(`#ring-${key}`);
    if (ring) {
      ring.dataset.score = score;
      const fillPath = ring.querySelector(".score-fill");
      if (fillPath) fillPath.setAttribute("stroke-dasharray", `${score}, 100`);
      const scoreText = ring.querySelector(".score-text");
      if (scoreText) scoreText.textContent = score + "%";
    }

    // Update detail counts
    const passEl = $(`#${field}-pass`);
    const partialEl = $(`#${field}-partial`);
    const failEl = $(`#${field}-fail`);
    if (passEl) passEl.textContent = pass;
    if (partialEl) partialEl.textContent = partial;
    if (failEl) failEl.textContent = fail;
  }

  /* ----------------------------------------------------------
     10. CROSS-FRAMEWORK MAPPING TABLE
  ---------------------------------------------------------- */

  function renderMappingTable(mappings) {
    const tbody = $("#mapping-tbody");
    tbody.innerHTML = "";

    const search = ($("#search-controls").value || "").toLowerCase();
    const statusFilter = $("#filter-status").value;
    const productFilter = $("#filter-product").value;

    const filtered = mappings.filter((m) => {
      if (statusFilter !== "all" && m.status !== statusFilter) return false;
      if (productFilter !== "all" && m.product !== productFilter) return false;
      if (search) {
        const haystack = [m.capability, m.iso27001, m.cis, m.nist, productNames[m.product]].join(" ").toLowerCase();
        if (!haystack.includes(search)) return false;
      }
      return true;
    });

    if (filtered.length === 0) {
      $("#table-empty").hidden = false;
      return;
    }
    $("#table-empty").hidden = true;

    filtered.forEach((m) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td><strong>${esc(m.capability)}</strong></td>
        <td>${esc(m.iso27001)}</td>
        <td>${esc(m.cis)}</td>
        <td>${esc(m.nist)}</td>
        <td><span class="status-badge status-badge--${m.status}">${statusLabel(m.status)}</span></td>
        <td><span class="product-tag">${esc(productNames[m.product])}</span></td>
      `;
      tbody.appendChild(tr);
    });
  }

  function statusLabel(s) {
    return s === "pass" ? "Compliant" : s === "partial" ? "Partial" : "Non-Compliant";
  }

  function esc(str) {
    const el = document.createElement("span");
    el.textContent = str;
    return el.innerHTML;
  }

  /* ----------------------------------------------------------
     11. FILTERS
  ---------------------------------------------------------- */

  function initFilters() {
    $("#search-controls").addEventListener("input", () => renderMappingTable(controlMappings));
    $("#filter-status").addEventListener("change", () => renderMappingTable(controlMappings));
    $("#filter-product").addEventListener("change", () => renderMappingTable(controlMappings));
  }

  /* ----------------------------------------------------------
     12. REVIEW SECTION
  ---------------------------------------------------------- */

  function updateReviewSection(mappings) {
    // Recommendations
    const failing = mappings.filter((m) => m.status === "fail");
    const partials = mappings.filter((m) => m.status === "partial");
    const recList = $("#recommendations-list");
    recList.innerHTML = "";

    if (failing.length > 0) {
      failing.forEach((m) => {
        const li = document.createElement("li");
        li.className = "review-item--fail";
        li.innerHTML = `<strong>${esc(m.capability)}</strong> — Non-compliant. Review ${esc(productNames[m.product])} configuration.`;
        recList.appendChild(li);
      });
    }
    if (partials.length > 0) {
      partials.slice(0, 5).forEach((m) => {
        const li = document.createElement("li");
        li.className = "review-item--warn";
        li.innerHTML = `<strong>${esc(m.capability)}</strong> — Partially compliant. Verify ${esc(productNames[m.product])} policies.`;
        recList.appendChild(li);
      });
    }
    if (failing.length === 0 && partials.length === 0) {
      const li = document.createElement("li");
      li.className = "review-item--pass";
      li.textContent = "All controls are fully compliant.";
      recList.appendChild(li);
    }

    // Recent assessments
    const assessList = $("#assessments-list");
    assessList.innerHTML = "";
    const li = document.createElement("li");
    li.className = "review-item--info";
    li.innerHTML = `Assessment completed for <strong>${esc(tenantState.tenantName)}</strong> on ${new Date().toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })}`;
    assessList.appendChild(li);

    // Deployment actions
    const actionsList = $("#actions-list");
    actionsList.innerHTML = "";
    const actions = [
      { text: "Deploy Safe Attachments baseline → defender-for-office365/", cls: "review-item--info" },
      { text: "Run MDI prerequisite checks → defender-for-identity/prerequisites/", cls: "review-item--info" },
      { text: "Enable Attack Surface Reduction rules → defender-for-endpoint/", cls: "review-item--warn" },
      { text: "Configure DMARC/DKIM/SPF records → DNS provider", cls: "review-item--fail" },
      { text: "Enable DLP policies → Microsoft Purview portal", cls: "review-item--fail" },
    ];
    actions.forEach((a) => {
      const actionLi = document.createElement("li");
      actionLi.className = a.cls;
      actionLi.textContent = a.text;
      actionsList.appendChild(actionLi);
    });
  }
})();
