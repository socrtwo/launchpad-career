# Legal and privacy review brief

**Status: not done.** No lawyer or privacy professional has reviewed this product. It
makes no compliance claim of any kind, and none may be added until this review has
happened. This brief collects what a reviewer needs and the questions the project cannot
answer for itself.

## What the product does with data

The authoritative description is `docs/privacy/retention.md` (what is held, where, for how
long, and the test that enforces each rule) and `docs/privacy/privacy-design.md`.

In one paragraph: by default nothing leaves the device and nothing is stored. A person may
opt in to saving their answers on the device. In a build connected to an account server
they may additionally create an account (a handle and a passphrase; no email, no name) and
opt in to sync, which sends their answers when they press a button. They can see and
delete everything in both places. There is no analytics, advertising or crash reporting.

## Questions for the reviewer

1. **Age.** The product is aimed at undergraduates and will be used by some people under
   18, and possibly under 13 if a school puts it in front of them. What follows from that
   for the account feature, for consent, and for the notice?
2. **Education records.** If a university careers office deploys this, are a student's
   answers and notes education records of that institution? Does that depend on who
   operates the account server?
3. **Roles.** When an institution runs the account server, who is the controller of what?
   What agreement is needed between the project and an operator?
4. **Sensitive content in free text.** People may type health, immigration or financial
   circumstances into notes. The product does not ask for these and refers out-of-scope
   situations to human services. Is the opt-in sufficient? Should the note fields carry a
   warning?
5. **No account recovery.** There are no contact details, so a forgotten passphrase means
   losing the account. Is that acceptable, and how should it be disclosed?
6. **Deletion and backups.** Deletion is immediate in the live store. An operator's
   backups are outside the code. What must an operator commit to?
7. **Employment-guidance regulation.** Does anything about suggesting occupations, or
   about rule-based matching, engage rules on career advice, automated decision-making or
   discrimination in any target jurisdiction? The matching uses stated interests,
   education and priorities only (`docs/product/career-recommendation-principles.md`).
8. **AI-drafted content.** Occupation descriptions and guidance were drafted with AI
   assistance and are labelled as such. Is the label adequate, and what is the position
   on errors in that content?
9. **Trade marks.** The LinkedIn guide names LinkedIn and carries a disclaimer. Is the
   usage and the disclaimer acceptable?
10. **Third-party data.** Pay figures, once imported, are from the U.S. Bureau of Labor
    Statistics. Is the attribution wording right?
11. **Accessibility law.** Which accessibility obligations apply to the likely deployers
    (public universities in particular), and what do they need from the project?
12. **Jurisdictions.** Everything above for each place the product will be offered.

## Documents that need writing and review

| Document | State |
| --- | --- |
| Privacy notice | The `/privacy` page describes the build's behaviour and says it is not a reviewed notice |
| Terms of use | Not written |
| Operator agreement and operator's retention schedule | Not written |
| Sub-processor list | Nothing is deployed, so there are none |
| Accessibility statement | Not written; depends on the audit |
| Store data-safety and privacy answers | Drafted in `store-listing.md`, unreviewed |

## Rule until this is done

No mention of FERPA, COPPA, GDPR, UK GDPR, CCPA/CPRA or any other regime as something the
product complies with — in the interface, the README, a store listing or anywhere else.
