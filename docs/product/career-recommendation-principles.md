# Career recommendation principles

None of this is implemented. Phase 1 ships mock data only, and the interface says so. This
document is the specification the recommendation layer must be built against, and the
`Evidence` type in `launchpad_domain` is the first piece of it.

## Every claim carries its provenance

`Evidence.kind` distinguishes four sources, and the interface must render them
differently:

| Kind | Meaning | Display requirement |
| --- | --- | --- |
| `laborMarketData` | Published statistics | Must show source and as-of date. Enforced by an assertion. |
| `editorial` | Written and reviewed by a person | Attributable on request |
| `generatedGuidance` | Model output | Must be visibly labelled as generated |
| `userProvided` | What the user told us | Must be editable |

A user must never have to guess whether a number came from the Bureau of Labor Statistics
or from a language model.

## Explain, don't assert

Every suggestion states why it is being made, in terms of what the user actually told us:
"because you said you want to stay in the Midwest and finish within two years". A
recommendation with no visible reasoning cannot be argued with, and being argued with is
how the product improves its picture of the person.

## Show uncertainty

Confidence appears in words (`ConfidenceBand`), never as a false-precision percentage.
Where the honest answer is "the data does not distinguish these two paths", say that.

## Never guarantee

No claim about admission, hiring, salary, or success. Not "graduates earn $X", but
"reported median earnings for this occupation were $X in 2025 (BLS OEWS)". Distributions,
not destinies — and note when a figure is a median with a wide spread.

## Do not stereotype

Recommendations may not be conditioned on age, gender, race, disability, nationality,
religion, or any other protected characteristic, directly or through a proxy. Watch the
proxies in particular: institution attended, home postcode, and name are all capable of
standing in for protected attributes. Any candidate model gets a disparity check across
inputs before it goes anywhere near users.

## Let people correct us

Every inference is visible and editable. If the product concluded something from an answer,
that conclusion is shown next to a control that changes it.

## Offer more than one path

Where a recommendation is possible, at least two or three are offered, including at least
one that does not require a four-year or graduate degree where such a route genuinely
exists — apprenticeships, certifications, community-college transfer, employer training.
"There is one correct answer" is almost never true and is corrosive when it is wrong.

## Date everything

Labour-market data goes stale, and 2024-vintage entry-level hiring advice is already
misleading. Every figure displays its as-of date. Anything older than a defined threshold
(to be set, likely 18 months) is either refreshed or shown with a staleness warning.

## Acknowledge that conditions change

Automation and economic conditions are reshaping entry-level work in ways the data lags.
Where a field is visibly in flux, say so rather than projecting the last five years
forward and calling it a forecast.

## Referral, not treatment

If someone describes a situation beyond the product's scope — financial hardship, a
health issue, immigration status, harassment — the correct response is to point to the
appropriate human service and to say plainly that this tool is not it. The product does not
attempt counselling and does not label the user.
