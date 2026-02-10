const offerings = [
  {
    id: "defender-for-endpoint",
    name: "Defender for Endpoint",
    tag: "Endpoint",
    href: "defender-for-endpoint.html",
    description: "Threat and vulnerability management, endpoint protection, and EDR coverage for devices.",
    howTo: [
      "Onboard pilot devices by OS family and validate sensor health telemetry.",
      "Enable next-gen protection baseline: AV, cloud-delivered protection, and tamper protection.",
      "Roll out attack surface reduction rules in audit mode before enforce mode.",
      "Integrate with Intune or Configuration Manager for policy deployment at scale."
    ],
    bestPractices: [
      "Use device groups aligned to business criticality and data sensitivity.",
      "Prioritize remediation using exposure score and active threat context.",
      "Automate low-risk responses while requiring approval for disruptive actions.",
      "Review advanced hunting queries weekly and tune custom detections."
    ]
  },
  {
    id: "defender-for-identity",
    name: "Defender for Identity",
    tag: "Identity",
    href: "defender-for-identity.html",
    description: "Detect identity-based attacks across hybrid Active Directory and Entra identities.",
    howTo: [
      "Deploy sensors to all domain controllers and standalone AD FS servers.",
      "Configure directory service accounts with least-privilege permissions.",
      "Validate lateral movement path data quality and entity enrichment.",
      "Connect identity alerts to Defender XDR incidents for triage correlation."
    ],
    bestPractices: [
      "Tune exclusions sparingly and document rationale for each suppression.",
      "Investigate suspicious auth patterns with conditional access and sign-in logs.",
      "Use identity posture assessments to prioritize hardening workstreams.",
      "Run periodic attack simulations for pass-the-hash and Kerberoasting scenarios."
    ]
  },
  {
    id: "defender-for-office365",
    name: "Defender for Office 365",
    tag: "Email & Collaboration",
    href: "defender-for-office365.html",
    description: "Protect collaboration workloads from phishing, malware, and business email compromise.",
    howTo: [
      "Enable preset security policies and align strictness to user risk tiers.",
      "Configure Safe Links and Safe Attachments for email and collaboration tools.",
      "Set up anti-phishing with user/domain impersonation protection.",
      "Enable automated investigation and response for mailbox threats."
    ],
    bestPractices: [
      "Use simulation training to improve user resilience to phishing campaigns.",
      "Monitor top targeted users and protect executives with stricter policies.",
      "Review quarantine and false positive trends to tune filtering actions.",
      "Integrate with SIEM for cross-domain detection and reporting."
    ]
  },
  {
    id: "defender-for-cloud-apps",
    name: "Defender for Cloud Apps",
    tag: "SaaS Security",
    href: "defender-for-cloud-apps.html",
    description: "Gain cloud app visibility, apply policy controls, and investigate risky user behavior.",
    howTo: [
      "Connect Microsoft 365 and priority third-party SaaS connectors first.",
      "Import firewall/proxy logs to build your shadow IT baseline.",
      "Create session and app governance policies for high-risk activities.",
      "Enable file and data policies for sensitive information exposure."
    ],
    bestPractices: [
      "Tag sanctioned apps and automatically block unsanctioned categories.",
      "Use anomaly detections as investigations, not direct enforcement signals.",
      "Correlate cloud app alerts with endpoint and identity detections in XDR.",
      "Review OAuth app permissions regularly and revoke risky grants quickly."
    ]
  },
  {
    id: "defender-vulnerability-management",
    name: "Defender Vulnerability Management",
    tag: "Exposure Management",
    href: "defender-vulnerability-management.html",
    description: "Prioritize and remediate vulnerabilities with risk-based scoring and recommendations.",
    howTo: [
      "Validate device inventory completeness and onboarding consistency.",
      "Define remediation SLAs by severity and business criticality.",
      "Integrate ticketing systems for recommendation-driven workflows.",
      "Track baseline security recommendations and exception approvals."
    ],
    bestPractices: [
      "Prioritize exploitable vulnerabilities observed in active attack campaigns.",
      "Measure remediation success using exposure score trends over time.",
      "Segment reporting by ownership to improve engineering accountability.",
      "Combine misconfiguration and vulnerability data for true risk ranking."
    ]
  },
  {
    id: "microsoft-defender-xdr",
    name: "Microsoft Defender XDR",
    tag: "Unified Operations",
    href: "microsoft-defender-xdr.html",
    description: "Correlate incidents, automate responses, and investigate threats across domains.",
    howTo: [
      "Configure RBAC roles for SOC tiers and incident response owners.",
      "Build custom detection rules from advanced hunting outcomes.",
      "Implement automation with approval gates for high-impact playbooks.",
      "Enable incident tagging taxonomy for reporting and lessons learned."
    ],
    bestPractices: [
      "Use correlation insights to avoid duplicate investigations across tools.",
      "Standardize triage runbooks to improve mean time to contain (MTTC).",
      "Run tabletop exercises using real incidents and automation fallbacks.",
      "Track detection coverage gaps and iterate on hunting hypotheses monthly."
    ]
  }
];

const listEl = document.getElementById("offeringList");
const detailTag = document.getElementById("detailTag");
const detailTitle = document.getElementById("detailTitle");
const detailDescription = document.getElementById("detailDescription");
const detailLink = document.getElementById("detailLink");
const detailHowTo = document.getElementById("detailHowTo");
const detailBestPractices = document.getElementById("detailBestPractices");

function renderList(activeId) {
  listEl.innerHTML = "";

  offerings.forEach((offering) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `offering-item ${offering.id === activeId ? "active" : ""}`;
    button.setAttribute("aria-pressed", String(offering.id === activeId));
    button.innerHTML = `
      <span class="tag">${offering.tag}</span>
      <strong>${offering.name}</strong>
      <small>${offering.description}</small>
    `;

    button.addEventListener("click", () => {
      renderList(offering.id);
      renderDetails(offering);
    });

    listEl.appendChild(button);
  });
}

function renderDetails(offering) {
  detailTag.textContent = offering.tag;
  detailTitle.textContent = offering.name;
  detailDescription.textContent = offering.description;
  detailLink.href = offering.href;

  detailHowTo.innerHTML = offering.howTo.map((item) => `<li>${item}</li>`).join("");
  detailBestPractices.innerHTML = offering.bestPractices.map((item) => `<li>${item}</li>`).join("");
}

renderList(offerings[0].id);
renderDetails(offerings[0]);
