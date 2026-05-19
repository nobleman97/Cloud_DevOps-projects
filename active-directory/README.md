# Contoso Corp — Active Directory Home Lab

A simulated enterprise Active Directory environment built to demonstrate core Windows system administration skills including domain deployment, organisational design, Group Policy enforcement, and PowerShell automation.

---

## Business Scenario

**Contoso Corp** is a fictitious 50-user organisation with four departments — IT, HR, Finance, and Sales. The goal of this lab is to simulate the kind of Active Directory environment a sysadmin would inherit or build at a small-to-mid-sized company: a single domain, a structured OU hierarchy, role-appropriate access controls, and enforced security baselines across all workstations.

The environment was built entirely from scratch — domain promotion, user provisioning, Group Policy, DNS, and DHCP — to reflect the end-to-end responsibility a Windows administrator would own in a real organisation.

---

## Environment

| Component | Detail |
|---|---|
| Hypervisor | Proxmox |
| Domain Controller | Windows Server 2022 — `DC01` — `192.168.100.27` |
| Workstation | Windows 11 — `WS01` — `192.168.100.28` |
| Domain | `contoso.local` |
| Gateway | `192.168.100.1` |

---

## OU Design

```
contoso.local
└── Contoso Corp
    ├── IT
    ├── HR
    ├── Finance
    ├── Sales
    ├── Servers
    ├── Service Accounts
    └── _Admin
```

### Design Decisions

**Single top-level OU (`Contoso Corp`)** rather than placing departments directly under the domain root. This makes it possible to link organisation-wide GPOs — like the security baseline — to a single OU and have them inherit down to all departments, rather than manually linking to each department individually. It also keeps the default AD containers (Computers, Users, Builtin) separate from managed objects.

**Department OUs (IT, HR, Finance, Sales)** map directly to the business structure. Separating by department rather than by object type (e.g. "All Users", "All Computers") allows GPOs to be targeted by role. A restriction that applies to HR should not apply to IT, and a flat structure would make that distinction impossible to enforce cleanly.

**Servers OU** separates server computer accounts from workstations. In a production environment you would apply different GPOs to servers — stricter auditing, no interactive logon for standard users, different update policies — so keeping them in a dedicated OU from the start is the right habit even in a small lab.

**Service Accounts OU** isolates accounts used by applications and scheduled tasks from regular user accounts. This matters for auditing and for applying fine-grained password policies — service accounts typically need longer, non-expiring passwords that would be inappropriate to apply to human user accounts.

**`_Admin` OU** uses an underscore prefix to force it to the top of the alphabetical list, making privileged accounts immediately visible. Administrator accounts are kept separate from standard users so that GPOs applying to regular users — like desktop restrictions — are never accidentally applied to admin accounts, which would break administrative tooling.

---

## Group Policy Objects

### GPO 1 — Security Baseline
**Linked to:** Contoso Corp (inherited by all child OUs)

This GPO enforces the minimum security standard that applies across the entire organisation regardless of department.

| Setting | Value | Reason |
|---|---|---|
| User Account Control (UAC) | Enabled | Prevents unauthorised system changes by requiring administrator approval for elevated actions. Enforcing via GPO ensures users cannot disable it locally. |
| Minimum password length | 12 characters | Short passwords are trivially brute-forced. 12 characters significantly increases the time and resources required for an offline attack. |
| Account lockout threshold | 5 attempts | Limits brute-force login attempts without being so aggressive that legitimate users frequently lock themselves out. |
| Account lockout duration | 15 minutes | Long enough to deter automated attacks, short enough that a locked-out user does not always need to call the helpdesk. |

---

### GPO 2 — Workstation Lockdown
**Linked to:** HR, Finance, Sales (not IT)

This GPO restricts what standard users can do on their workstations. It is deliberately not applied to the IT OU because administrators need unrestricted access to system tools to do their jobs.

| Setting | Reason |
|---|---|
| Prohibit access to Control Panel and PC Settings | Prevents users from changing system configuration, uninstalling software, or modifying network settings — changes that should go through IT, not be made ad hoc. |
| Prevent access to Command Prompt | `cmd.exe` can be used to circumvent desktop restrictions, access the file system in unintended ways, or run unauthorised scripts. Removing it reduces the attack surface for both malicious insiders and malware that relies on cmd for execution. |
| Remove Run dialog from Start Menu | The Run dialog (Win+R) provides a quick path to launch executables and access UNC paths, bypassing Start Menu restrictions. Removing it closes a common gap left open when other lockdown settings are applied. |

---

### GPO 3 — IT Drive Mapping
**Linked to:** IT OU only

This GPO uses Group Policy Preferences to automatically map a shared network drive at login for all members of the IT department.

| Setting | Value | Reason |
|---|---|---|
| Drive mapping | `\\DC01\ITShare` → `Z:` | Gives IT staff consistent, automatic access to a shared workspace without requiring manual drive mapping on each machine. Using GPO Preferences rather than a logon script is the modern approach — it is easier to manage, visible in GPMC, and self-healing if the mapping is accidentally removed. |

NTFS and share permissions are configured so that `IT-Team` has full control and `Domain Users` have read access — following the principle of least privilege, where users get only the access they need for their role.

---

## Skills Demonstrated

- Active Directory Domain Services — forest and domain deployment from scratch
- Organisational Unit design — role-based hierarchy with clear policy targeting
- Group Policy — security baseline, workstation restrictions, drive map preferences
- DNS — authoritative zone management, custom A records
- DHCP — scope configuration, domain-authorised server
- PowerShell automation — bulk user and group provisioning, role installation
- Windows networking — static IP assignment, domain join, name resolution
- Remote administration — RDP from Linux using xfreerdp, firewall configuration

---

## Repository Structure

```
├── README.md
└── scripts/
    ├── 01-static-ip.ps1
    ├── 02-install-adds.ps1
    ├── 03-promote-dc.ps1
    ├── 04-create-ous.ps1
    ├── 05-create-groups.ps1
    ├── 06-create-users.ps1
    ├── 07-create-gpos.ps1
    ├── 08-create-share.ps1
    ├── 09-install-dhcp.ps1
    └── 10-join-domain.ps1
```
