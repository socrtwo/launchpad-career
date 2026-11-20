# Accessibility audit brief

**Status: not done.** No one who uses assistive technology daily has tested this product.
Until that happens and its findings are addressed, the product makes no conformance claim,
and the in-app accessibility page says so.

This brief is for whoever commissions or carries out that audit.

## What is already tested automatically

See the table in `docs/accessibility/accessibility-requirements.md`. In short: contrast in
both themes, 48dp labelled targets, keyboard activation, semantics roles and states,
headings, live regions, 2× text on a narrow phone, and reduced motion, on every screen.

Automated checks find missing labels and low contrast. They do not find a screen that is
labelled correctly and still exhausting to use.

## What the audit should cover

Target: WCAG 2.1 AA, with the platform conventions for each screen reader.

| Assistive technology | Platform | Build |
| --- | --- | --- |
| TalkBack | Android | native |
| VoiceOver | iOS, macOS | native, and Safari for web |
| NVDA and JAWS | Windows | web (Chrome, Firefox) |
| Keyboard only | desktop | web and native |
| Switch access or voice control | any one platform | native |
| Screen magnification at 400% | desktop | web |
| Windows High Contrast / forced colours | Windows | web |

Tasks to attempt end to end, without help:

1. Choose a goal and answer the questions, skipping at least one.
2. Find an occupation by search, save it, and compare it with another.
3. Read why an occupation was suggested, and change an answer.
4. Build a plan and tick off a step; add a step of your own.
5. Practise one interview question, writing notes.
6. Turn saving on, view your data, and delete everything.

## Known risks to look at first

- **Flutter web builds its accessibility tree on demand.** Screen-reader users on the web
  first meet a single "Enable accessibility" control. Whether that is acceptable is a
  judgement for people who rely on it.
- **Typed text in scripts outside Latin, Greek and Cyrillic is drawn as empty boxes** in
  the web build (`web-hosting.md`).
- **Comparison stacks on narrow screens**; each cell repeats the occupation name. Whether
  that reads well with a screen reader has not been checked by a person.
- **Long lists of choices** (28 occupations as selectable tiles) may be tiring to traverse.
- **Target spacing** (WCAG 2.2 success criterion 2.5.8) has not been verified, only size.
- **Reading order versus visual order** has only been checked by the tab-order test.

## What to deliver

Findings by screen and task, each with the assistive technology, the platform, what
happened, what was expected, and a severity. Findings go in as issues labelled
`accessibility`. The accessibility statement is written only after they are resolved or
listed as known limitations.
