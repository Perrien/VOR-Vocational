# VOR project guide

Start with the current project documents:

- `README.md` — what VOR is, what is working now, how the app is arranged, and how to run it.
- `IDEAS.md` — active initiatives, known issues, and sensible next moves.
- `Glossary.md` — the agreed aviation and product vocabulary.
- `Plans/` — one self-contained plan per feature while it is being worked. Completed plans move to `Plans/Archived/`.

The source code is the authority on current behavior. If it disagrees with a document, point out the difference before making a decision.

`Design/` contains the earlier planning system and useful background material, especially the route and flight-plan notes. It is reference material, not the active backlog, plan system, or document hierarchy. Do not create new tickets, ADRs, explorations, or execution-protocol updates there.

## Project guardrails

- VOR is currently one macOS SwiftUI target. iPad is a later possibility, not an active target.
- Keep the fictional Myosia chart and the navigation model honest. Do not change bundled data, test fixtures, or tolerances merely to make a check pass.
- Do not add or update dependencies, change signing/capabilities/entitlements/bundle ID, or hand-edit the Xcode project file without asking first.
- Keep the core experience focused on VOR navigation. Do not add flight-simulator complexity unless it creates a navigation decision worth teaching.
- A normal mission chart must not become a GPS display that reveals the aircraft's true position by default.

## Working style

Before implementation, read the relevant README, IDEAS entry, glossary terms, and active plan. Give the owner a visible way to try a feature at each useful stage. Stop and explain if a test fails outside the planned scope, a prerequisite is missing, or an unplanned architectural choice is required. At a plan's commit point, show the verification result and let the owner choose whether to commit before more files change.
