# AJW BAGS Portal: compliance register

**Last reviewed:** 3 November 2026. **Review:** every 6 months, and before any change listed in section B or C.

This register lists only what the law or the portal's own published promises require. Section A covers today's portal, which takes no money. Sections B and C are gates: work that must be finished **before** the portal ever handles money. The portal enforces the first gate itself (see section B).

This register is a working checklist, not legal advice. Have a Kenyan advocate confirm it before relying on it, and again before opening either gate.

## Abbreviations and Acronyms

| Abbreviation | Meaning |
|---|---|
| AML | Anti-Money Laundering |
| CBK | Central Bank of Kenya |
| DPA | Data Protection Act, 2019 (Kenya) |
| DPIA | Data Protection Impact Assessment |
| eTIMS | electronic Tax Invoice Management System (KRA) |
| KRA | Kenya Revenue Authority |
| ODPC | Office of the Data Protection Commissioner |
| PCI DSS | Payment Card Industry Data Security Standard |
| PSP | Payment Service Provider |
| WCAG | Web Content Accessibility Guidelines |

## A. Today: the portal holds personal data but no money

| # | Requirement | Source | Status | Owner / evidence |
|---|---|---|---|---|
| A1 | Check whether AJW must register with the ODPC as a data controller. It is exempt only with under KES 5 million turnover **and** fewer than 10 employees, and only if none of its activities is on the always-register list. | DPA s.18; Registration Regulations 2021 | **Open** | AJW management |
| A2 | Privacy Policy, Data Protection Notice, Terms, Cookie Policy, Payments and Refund Policy published and versioned | DPA s.29 (duty to notify) | Done (v2.1, 3 Nov 2026) | `legal/`, `scripts/build_legal.js` |
| A3 | Recorded consent: Terms, 18 or over, optional emails, sensitive data stored outside Kenya | DPA ss.30, 32, 49 | Done | `user_consents` table |
| A4 | Written transfer assessment for Supabase (Ireland) and Google: what data, why, safeguards, provider terms. Review it when anything changes. | DPA ss.48–49; ODPC Guidance Notes for Cross-border Data Transfers (Sept 2026) | **Open**: the Privacy Policy promises it | AJW; Claude can draft it |
| A5 | People's rights: access within 7 days, correction or deletion within 14 days | DPA ss.26, 40; General Regulations 2021 | Done (in-app requests with deadlines) | Settings and privacy; Admin "Data requests" |
| A6 | Breach plan: tell the ODPC within 72 hours, affected people without undue delay | DPA s.43 | Written | `docs/security/DATA_SECURITY.md` |
| A7 | Security: access rules in the database, private documents, short links, audit log, idle sign-out | DPA s.41 | Done | `docs/security/` |
| A8 | Retention schedule applied (chat and closed requests automatic; the rest manual until a clean-up job exists) | DPA s.25(h) (kept no longer than necessary) | Partly: first deletions due late 2027 | Privacy Policy s.7 |
| A9 | Tell workshop attendees how their details are used | DPA s.29 | **Open** | Workshop facilitators |
| A10 | Parent or guardian consent before a success story names a child | DPA s.33 | Done (database rule) | `success_stories` |
| A11 | Backups of the database and documents | DPA s.41 (availability and resilience) | **Open** | Decision pending |
| A12 | Accessibility: contrast, labels, keyboard use | WCAG 2.1 AA (good practice; supports the Persons with Disabilities Act) | Done | `scripts/check_contrast.js` |
| A13 | Google verification for the requested Google permissions; keep the Limited Use wording | Google API Services User Data Policy | Under review | `docs/google_verification.md` |
| A14 | Licences for fonts, icons and libraries | Copyright Act, 2001 | Done | `LICENSES_AND_CREDITS.md` |
| A15 | Optional emails have a working unsubscribe, and nothing optional is sent without consent | DPA s.37 (commercial use of data) | Done | `email_preferences`, `email-unsubscribe` |

## B. Gate 1: before the portal takes, holds or pays out any money

**How the portal enforces this gate:**

- `legal/payments.json` holds one switch, `takesPayments`. It is `false` today.
- Setting it to `true` breaks the build, and therefore every deploy, until `legal/refund-policy.md` is rewritten for payments (`covers_payments: "true"`).
- All payment code must also stay hidden behind `Payments.enabled`, which is generated from that switch.

Complete every line before flipping it.

| # | Requirement | Source | Notes |
|---|---|---|---|
| B1 | Use a **CBK-licensed payment provider** (for example M-PESA Daraja, Airtel Money, a card acquirer). The portal must never hold funds itself. Holding or moving others' money without a licence is a regulated payment service. | National Payment System Act, 2011, and its Regulations | Keeps AJW out of PSP licensing |
| B2 | Never store card numbers or mobile-money PINs. Use the provider's hosted checkout or STK push. | PCI DSS (card schemes); DPA s.41 | Keeps the portal out of PCI scope |
| B3 | Rewrite the Payments and Refund Policy: price shown upfront including taxes, who is paid, cancellation and refund rights, timelines, receipts. Set `covers_payments: "true"`. | Consumer Protection Act, 2012 (disclosure, cancellation, refunds) | The build checks this |
| B4 | Update the Terms (payment terms, disputes, chargebacks) and the Privacy Policy (payment data, the provider as a new processor, retention of financial records). Bump their versions so everyone is asked again. | DPA s.29; contract law | Re-consent is automatic on a version bump |
| B5 | Issue tax invoices through **eTIMS** for anything AJW sells, and register for VAT if taxable turnover passes the threshold | Tax Procedures Act, 2015; VAT Act, 2013; KRA eTIMS rules | Ask AJW's accountant |
| B6 | Keep financial and transaction records at least 5 years. Update the retention schedule. | Tax Procedures Act, 2015 | |
| B7 | Do a DPIA for payment processing, and register with the ODPC. Financial-service processing must register whatever the organisation's size. | DPA s.31; Registration Regulations 2021 | |
| B8 | Security review before launch: rate limits on payment functions, signed provider callbacks (webhooks), an audit entry for every money movement, and no amounts trusted from the app | `docs/security/SECURITY.md` | Add checks to `SECURITY_CHECKLIST.md` |
| B9 | Show every cost before the person commits. No hidden fees, no pre-ticked add-ons. | Consumer Protection Act, 2012; the portal's own fair-design rule | |

## C. Gate 2: if the portal ever lends money, disburses grants or loans, or holds balances

This is a much higher bar. Treat it as a new project with legal advice from the start.

| # | Requirement | Source |
|---|---|---|
| C1 | Lending to the public needs a CBK licence (bank, microfinance, or non-deposit-taking or digital credit provider). Partnering with a licensed lender is the usual route. | Banking Act; Microfinance Act, 2006; Digital Credit Providers Regulations, 2022 |
| C2 | Customer due diligence (Know Your Customer) and suspicious-transaction reporting, if AJW becomes a reporting institution | Proceeds of Crime and Anti-Money Laundering Act, 2009 |
| C3 | Fair lending disclosures, and credit-reference sharing only as the law allows | CBK consumer protection rules; Credit Reference Bureau Regulations, 2020 |
| C4 | Ring-fenced client money, external audit, complaints procedure | Licence conditions |

## D. When to update this register

- A new feature collects a new kind of personal data, or a new provider receives data.
- Anything in section B or C is planned.
- A law, regulation or ODPC guidance note changes.
- At each 6-monthly review: re-check A1, A4 and A8.
