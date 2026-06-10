# BehaviorLog Pro — Privacy Policy Update (June 10, 2026)

**Status: DRAFT for Nicholas Crabtree + legal counsel review. Not yet sent.**

This documents a material update to the BehaviorLog Pro Privacy Policy
(`privacy.html`, committed 2026-06-10). Per §16 of that policy and SOPIPA
(Cal. Bus. & Prof. Code § 22584), material changes require **at least 30 days'
written notice to affected LEAs** before they take effect. The updated policy
is posted now with a **material-update effective date of July 10, 2026**.

---

## A. Notice to Local Educational Agencies — *draft, ready to adapt and send*

> **Date:** June 10, 2026
> **To:** [LEA Privacy Officer / Contracting Contact]
> **From:** Sure Step Education
> **Re:** Material update to the BehaviorLog Pro Privacy Policy — effective **July 10, 2026**
>
> Dear [LEA contact],
>
> In accordance with Section 16 of our Privacy Policy and the Student Online
> Personal Information Protection Act (SOPIPA), this is at least 30 days'
> advance written notice of material changes to the BehaviorLog Pro Privacy
> Policy, taking effect **July 10, 2026**.
>
> **Summary of material changes:**
> 1. **Sign-in options.** In addition to Google sign-in, users may now register
>    with an email address and password. Passwords are stored only as salted
>    bcrypt hashes by our authentication provider (Supabase); Sure Step never
>    stores, transmits, or can access plaintext passwords.
> 2. **Roles and district organization.** Access is now organized by school
>    district, with distinct **district-administrator** and **Sure Step-administrator**
>    roles. District administrators manage only their own district's users.
> 3. **Support ("break-glass") access.** Authorized Sure Step personnel may
>    temporarily sign in to and operate the application **as a specific user**
>    for technical support and troubleshooting. Every such access is recorded
>    in an audit log.
> 4. **Audit logging.** Sensitive administrative actions (support access, data
>    export, data deletion, and changes to a user's role or district) are now
>    recorded with the actor, the affected account, and the time.
> 5. **Teacher–specialist collaboration.** A teacher may grant a behaviorist or
>    school psychologist read access to a specific student, and those specialists
>    may define behavior targets and operational definitions the teacher then uses
>    for that student.
>
> The full updated policy is posted at
> https://behavior-log-pro.vercel.app/privacy.html . No action is required;
> the changes take effect July 10, 2026. We remain available to execute or amend
> a Data Processing Agreement (CSDPA, SDPC, or custom).
>
> Questions: Nicholas Crabtree, Co-Founder — nicholas@surestepeducation.com
>
> Sincerely,
> Nicholas Crabtree, Co-Founder, Sure Step Education

---

## B. Summary of changes for legal counsel — *prep for review (#2); this is NOT a substitute for counsel*

### What changed in `privacy.html` (commit 34d4398)
| § | Before | After |
|---|---|---|
| meta | one effective date | original effective date kept + "material update effective July 10, 2026" |
| 1 | teachers + behaviorists | + school psychologists; + roles/district structure |
| 3.1 | "Linked behaviorist assignment" | + shared-specialist assignment + specialist-defined behavior targets/operational definitions |
| 3.2 | staff identity from Google OAuth; roles teacher/behaviorist/admin | Google **or** email/password; password as bcrypt hash (never plaintext/staff-accessible); roles incl. school psych, district admin, Sure Step admin; + assigned district/site |
| 3.3 / 7.1 | "no student data in browser storage beyond session" | corrected to disclose the per-user **offline local cache** |
| 4 | "communication between teachers and behaviorists" | explicit teacher→specialist read-access + specialist-defined behaviors; + district organization |
| 7.2 | **"Google OAuth … no passwords stored"** | Google **or** email/password; bcrypt hashes only; RLS + RBAC statements updated for districts/sharing |
| **7.5 (new)** | — | user roles + district organization |
| **7.6 (new)** | — | **break-glass support access** + **audit logging** |
| 15 | Google OAuth = sign-in | noted as one of two methods (email/password via Supabase) |

### Points that warrant counsel's attention
1. **Break-glass access (§7.6).** Sure Step personnel can sign in *as* any user and operate the app on real pupil records. Review: authorization controls, the FERPA "school official / legitimate educational interest" framing (34 CFR § 99.31(a)(1)), whether any additional LEA/parent disclosure or consent is needed, and any notification expectations when it is used.
2. **Timing tension (important).** Features #1–#5 are **already live in the application**, while this notice provides a forward effective date (July 10, 2026). Counsel should advise whether interim operation — especially break-glass on live data — needs remediation, accelerated disclosure, or LEA sign-off, and whether the effective date should differ.
3. **Password storage (§7.2 / §15).** Email/password credentials are now stored (as bcrypt hashes) by Supabase. Confirm the Supabase DPA/subprocessor terms cover credential storage and that this is reflected in LEA DPAs.
4. **Audit-log retention.** Define and disclose how long audit records are retained and who may access them.
5. **Data-sharing model (teacher↔specialist).** Confirm the read-access grant + specialist-defined-behavior flow stays within "legitimate educational interest."
6. **SOPIPA / §16 mechanics.** Confirm the 30-day notice + July 10 effective date satisfy § 22584 and the policy's own §16, and the chosen LEA-notification method.

### Open accuracy item still to fix before a feature goes live
- **§15 "anonymized" (Anthropic).** AI BIP/FBA/goal generation is currently **gated off**. Today's generation code would include the student's name in the prompt, so "anonymized" is aspirational until we add PII redaction (strip name/identifiers before the API call; reinsert client-side). **Do not enable AI generation until that redaction ships.**
