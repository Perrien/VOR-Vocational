# VOR project guide

Start with the current project documents:

- `README.md` — what VOR is, what is working now, how the app is arranged, and how to run it.
- `Design/IDEAS.md` — active initiatives, known issues, and sensible next moves.
- `Design/Glossary.md` — the agreed aviation and product vocabulary.
- `Design/Explorations/` — current exploration of a feature or bounded initiative milestone.
- `Design/Plans/` — one self-contained implementation plan per feature while it is being worked.
- `Design/Archived/Explorations/` and `Design/Archived/Plans/` — completed or superseded records, preserving their original scope and verification.

The source code is the authority on current behavior. If it disagrees with a document, point out the difference before making a decision.

`Design/` is the canonical home for project design and work records. Keep `README.md` and this guide at the repository root; do not create parallel root-level IDEAS, glossary, exploration, or plan copies. Keep the idea index concise and link to the detailed exploration and plan using paths relative to the linking file. On completion or supersession, archive the relevant exploration and plan and repair incoming and relative links. An exploration ready for implementation stays active until its bounded scope is complete; later work can have a new exploration that references the archived record.

`Design/Documents/` contains background references, especially the route and flight-plan notes. The earlier ticket, ADR, and execution-protocol system is retained under `Design/Archived/` as history; do not reactivate it or create new process records there. Archive placement alone does not imply owner acceptance of outstanding review items. Use `Design/IDEAS.md` for current work and read archived records when they answer a relevant question.

## Project guardrails

- VOR is currently one macOS SwiftUI target. iPad is a later possibility, not an active target.
- Keep the fictional Myosia chart and the navigation model honest. Do not change bundled data, test fixtures, or tolerances merely to make a check pass.
- Do not add or update dependencies, change signing/capabilities/entitlements/bundle ID, or hand-edit the Xcode project file without asking first.
- Keep the core experience focused on VOR navigation. Do not add flight-simulator complexity unless it creates a navigation decision worth teaching.
- A normal mission chart must not become a GPS display that reveals the aircraft's true position by default.

## Working style

Before implementation, read the relevant README, IDEAS entry, glossary terms, and active plan. Give the owner a visible way to try a feature at each useful stage. Stop and explain if a test fails outside the planned scope, a prerequisite is missing, or an unplanned architectural choice is required. At a plan's commit point, show the verification result and let the owner choose whether to commit before more files change.
