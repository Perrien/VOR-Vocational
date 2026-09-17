# Execution Protocol — how the coding agent works a plan

`Version: 1.1 (2026-08-12)` · `Audience: the executing AI coding agent`

> **§2 is this project's own; everything else is portable.** The `Paths` block was filled in when
> the project was scaffolded. The other three blocks are still `⟦FILL IN⟧` — a project with no code
> yet cannot answer them honestly. See the ticket `Chore-Complete-Execution-Protocol`.
>
> Keep the §2 blocks visibly marked as project declarations even after filling them, so the next
> person editing this file knows which parts are local and which are the portable body.

---

## 1. What this is

**The plan is the work. This protocol is the guardrails.**

You execute **one plan at a time**. The plan says what to build, in what order, and when to pause.
This document says how to behave while doing it — and, above all, when to stop and ask instead of
deciding something yourself.

**You read exactly two documents:** the active plan, and this file. The plan is written to be
self-contained; if it points you at a third document for something you need to execute a task, treat
that as a defect and report it (§8). (`CLAUDE.md` is loaded for you automatically and doesn't count
— it carries the project's document map and naming conventions, not execution rules.)

**Read the entire plan before starting.** Not just the next task — the whole thing, including its
decisions, its *Explicitly not doing* section, and every task's *Done when*. A task read in isolation
is a task read wrong.

**If the plan conflicts with this protocol, or with the code, stop and report it.** Do not pick
silently. Picking silently is the worse failure, because it looks like progress.

**You do not make decisions.** Every judgment call was settled before the plan was written, or
belongs to the owner at a stop point. Where the plan is silent on something you need, that is a hole
to surface, not a gap to fill.

---

## 2. Project declarations

### Paths

Filled at scaffold time — these are the folders the project was created with.

| | |
|---|---|
| This protocol | `Design/Execution-Protocol.md` |
| Active explorations | `Design/Explorations/` |
| Active plans | `Design/Plans/` |
| Backlog — the sole authority on what to build next | `Design/Tickets/` |
| Archive | `Design/Archived/Explorations/`, `Design/Archived/Plans/`, `Design/Archived/Tickets/` |
| Archive catalog | `Design/Archived/ArchivedCatalog.md` — created on the first archive |
| Architectural decisions (ADRs) | `Design/Decisions/` — created on the first ADR |
| Canonical vocabulary | `Design/Glossary.md` — created on the first resolved term |
| Project context & conventions | `CLAUDE.md` |
| Deliverable / source tree | **⟦FILL IN⟧** — did not exist at scaffold time |

Nothing in the `Design/` root is ever archived. Everything in `Explorations/`, `Plans/` and
`Tickets/` is. See §11.

### ⟦FILL IN⟧ Gates

The checks that run before any task is marked done, **in this order**. The task may add more; it may
never remove one. A gate that doesn't apply to a task simply doesn't run — you do not record that
anywhere (§5).

> *Replace with the project's real commands. Web example:*
>
> 1. Unit tests: `npx vitest run` — green.
> 2. Types: `npx tsc --noEmit` — clean.
> 3. Build: `npm run build` — succeeds.
> 4. The task's own *Done when* items, verbatim.
>
> *Xcode example:*
>
> 1. `xcodebuild -scheme <Scheme> test` — green.
> 2. `swift format --lint` (or SwiftLint) — clean.
> 3. A release-configuration build — succeeds.
> 4. The task's own *Done when* items, verbatim.

State which gates are **conditional** and on what — e.g. a native-test gate that runs only when
engine source was touched.

### ⟦FILL IN⟧ Guardrails

Hard constraints. Never violate one to make progress; needing to is a stop rule (§8).

> *Replace with the project's own. Common shapes:*
>
> - A reference implementation that is **immutable** — you work in a copy, and the two must agree.
> - Golden vectors / fixtures that may **never** be edited or have their tolerances loosened to make
>   a failing check pass.
> - **No new dependencies** beyond those the project already names, without owner approval. Never
>   load anything from a CDN at runtime.
> - **No dependency upgrades** unless a task explicitly says so. Pins are pins.
> - Schema changes bump a version and ship a migration plus a fixture.
> - *Xcode:* never touch **signing, capabilities, entitlements, or the bundle identifier**. Treat
>   `project.pbxproj` as owner-run the way git is — hand-editing it is a corruption risk and produces
>   unreviewable diffs.

### ⟦FILL IN⟧ Environment & toolchain

Anything about this machine or toolchain that changes how you work.

> *Replace or delete. Example — a sandboxed machine with no network:*
>
> Assume **no internet access**. Before any step that needs the network (package install, SDK
> download, `git clone`, `git push`, fetching a URL), test cheaply first — attempt the smallest fetch.
> **If it fails, do not retry workarounds:** no mirrors, no curl tricks, and never hand-write a
> dependency in place of installing it. Mark the task `blocked`, and give the owner an exact,
> copy-pasteable install request: what to install, the command, the expected resulting path/version,
> and which task is waiting. Batch requests where predictable. After the owner reports done, verify
> with a version check or one-line smoke command before resuming.

---

## 3. Session ritual

Every session, in order:

1. **Read the active plan in full** (§1).
2. **Mirror the plan's tasks into the live session task list** (§4).
3. **Resolve any task marked `in progress` or `blocked` first.** Never start a new task past one of
   those. An `in progress` task carries a note saying where the last session stopped — start there.
4. **Otherwise take the first task that is not `completed`.**
5. **Do exactly what the task says.** Small steps; run checks as you go.
6. **Run the task's *Done when* items and the gates** (§2), exactly as written.
7. **Update the task's status in the plan** — this is the only record of state, and it must reflect
   reality before you stop, whatever the outcome.
8. **Surface the commit point if the plan marks one here** (§9). Otherwise say nothing about git.
9. **Continue straight to the next task unless the plan declares a pause point** (§6).

If the session must end mid-task, set the task `in progress` and write the *stopped mid-task* note
(§5) describing exactly where you stopped and what remains.

---

## 4. Task discipline

- **One task at a time, in the plan's order.** Do not reorder or parallelise unless the plan marks a
  task as safe to run alongside another.
- **Implement exactly what the task says.** Its *Files* list is the boundary — nothing outside it.
- **Adjacent problems get recorded, not fixed.** When you notice a real defect the task doesn't
  cover: append it to the plan's **Deferred** section, **and file it as a ticket in
  `Design/Tickets/`** with `Status: untriaged`, using the naming convention and ticket shape in
  `CLAUDE.md`. Then carry on with the task. Helpfully fixing something nearby is the most common way
  an executed plan goes wrong.

  You are the only filer that writes `untriaged` — it means *no human has assessed this yet*. Do not
  promote anything to `open`; that is the owner's call.
- **The live task list is a viewport, not a record.** Mirror the plan's tasks into it and update each
  as you start and finish, so the owner can watch progress without opening files. It disappears with
  the session; the plan is the durable state.

---

## 5. Statuses and notes

Five statuses:

| Status | Meaning |
|---|---|
| `not started` | Untouched. |
| `in progress` | Being worked, or interrupted mid-way. |
| `awaiting owner` | Work done, halted at an owner stop, verification not yet performed. |
| `blocked` | Cannot proceed. See §8. |
| `completed` | **Owner-verified.** |

**`completed` means the owner has verified it.** A task whose verification the owner hasn't performed
is `awaiting owner`, never `completed`. You change it to `completed` only after the owner confirms the
verification passed.

**Exactly three notes are permitted**, each recording something the code cannot tell you:

1. **Material alteration** — you had to depart from the plan to finish the task, and how.
2. **Blocked** — why.
3. **Stopped mid-task** — where the work stopped and what remains.

**Write nothing else.** In particular, **never record gate results.** Green is the precondition for
advancing — you do not move to the next task on a red gate — so noting that tests passed says nothing.
A gate that didn't apply is likewise not recorded.

---

## 6. Pause points

**Pause points are decided when the plan is written, not while coding.** The owner signed off on their
placement when they approved the plan. Between them you run continuously: do not invent a stop the
plan doesn't declare, and do not skip one it does.

**Checkpoint** — run the checks, record nothing, keep going. A red check is not a pause point; it's a
stop rule (§8).

**Owner-verification stop** — halt and wait:

1. Mark the task `awaiting owner`.
2. Give the owner the plan's **verification handle** verbatim — where to look, what to do, what must
   change, and what must *not* change.
3. Tell them exactly what to run.
4. Stop that thread of work.

**Run the plan's verification exactly as written.** It was authored against the code; improvising a
different check is how a broken feature gets signed off. If the handle doesn't work as described,
that's a defect to report (§8), not something to substitute for.

---

## 7. Verification

- Run the gates (§2) in order, plus the task's *Done when* items verbatim.
- Anything that can't be checked programmatically — how something looks, feels, or behaves on a real
  device — is an owner stop, not your judgment call. Where the plan distinguishes **simulator from
  device**, or one platform from another, honour it: they are different checks.
- **Never weaken a check to get green.** Not by loosening a tolerance, not by skipping a gate, not by
  marking a task `completed` with caveats. A failing check means the code is wrong, or you've found a
  real discrepancy worth escalating.

---

## 8. Stop rules — when not to push forward

Stop the task, set it `blocked` with a note saying why, and surface it to the owner when any of these
happens:

- A check fails and the fix isn't obvious within the task's scope.
- You would have to violate a guardrail (§2) to proceed.
- The plan and this protocol conflict, or the plan and the code conflict.
- **The task's instructions no longer match the actual code.** Propose a corrected task in the note
  rather than improvising around the drift.
- You're about to make an architectural choice the plan doesn't cover: a new layer, a new interface, a
  new dependency, a schema redesign.
- An owner stop's verification handle doesn't work, and you can't fix it within the task's scope.
- The plan points you at another document for something you need to execute a task.

**A blocked task recorded honestly is a success condition of this protocol, not a failure.**

---

## 9. Git

**The owner runs every git command that writes history.** You never run `commit`, `push`, `checkout`,
`reset`, `rebase`, `merge`, or anything else that changes the repository's state. Read-only inspection
— `status`, `diff`, `log` — is fine.

Your job is to surface the plan's commit points. When you reach one, say so and repeat the plan's
message verbatim in the session — the owner is watching the task list, not re-reading the plan file. If
the work drifted from what the plan predicted, the message you give in-session wins; the plan's copy
was a forecast.

**Never offer a commit on a red gate.**

---

## 10. Plan completion

**A plan is finished when its close-out task is `completed`** — every task before it `completed` (or
skipped with the owner's approval), and the owner signed off the final verification.

The close-out task lists its own steps, and they include archiving the plan, its source exploration,
and every ticket the plan closed — each by the routine in §11. Follow the close-out as written; don't
add ceremony it doesn't ask for.

---

## 11. The archive routine

The one procedure for retiring an exploration, a plan, or a ticket. Every skill and every close-out
that archives anything **invokes this rather than restating it**, so the convention can change in one
place. The routine is identical for all three item types.

**What is archivable:** nothing in the `Design/` root, everything in `Explorations/`, `Plans/` and
`Tickets/`. That is the whole rule.

**1. Move it, under the same name.** Active mirrors archived exactly, so this is always "move it one
level down": `Design/Plans/Shot-History-Panel.md` → `Design/Archived/Plans/Shot-History-Panel.md`. A
folder-form ticket moves whole, folder and all.

**Never rename.** No date prefix, no sequence number, no suffix. The name an item was created with is
the name it keeps forever, because every skill in this project resolves items by name — a rename
breaks every reference and every `[[wikilink]]` pointing at it. Chronology lives in the catalog, not
in filenames.

**2. Append one line to `Design/Archived/ArchivedCatalog.md`** — create the file if this is the first
archive. One file covers all three archive subfolders. It is strictly chronological and append-only:
the new entry goes at the bottom, and nothing is ever re-sorted or edited in place.

Three forms. **Choosing between them is mandatory, never inferred:**

- `- <yyyy-mm-dd> · <Item-Name> · executed` — it ran to completion.
- `- <yyyy-mm-dd> · <Item-Name> · superseded by <Name> — <one clause saying why>`
- `- <yyyy-mm-dd> · <Item-Name> · won't fix — <one clause>`

A plan that ran to completion and a plan that was abandoned are both "archived", and confusing them is
how a future session resurrects the wrong idea. The why-clause is the part that stops an abandoned
approach being retried, which is why superseded and won't-fix carry one and executed doesn't. One
clause — not a sentence.

A ticket closed by a completed plan names that plan: `- <yyyy-mm-dd> · <Ticket-Name> · executed —
closed by <Plan-Name>`. That is provenance, not a why-clause; it tells a future reader where the work
actually happened.

**One line per item. Never a paragraph.** Per-entry prose is exactly how this file becomes the
unreadable 600 KB progress log it exists to replace: too large for the agent it serves to load.

**3. Ask one question: does this document contradict shipped code?**

- **No** — you're done; the catalog line was the only write. Most items land here.
- **Yes** — put a banner at the top of the document naming the exact claim and telling the reader to
  trust the code, **and** write the catalog entry as `superseded by …` with the contradiction as its
  why-clause.

The banner cannot move into the catalog instead. Its value is positional: it works by being read
*before* the false claim is read, and the reader who is about to be misled is by definition not
looking at the catalog.

---

## Changelog

Rule history. The body above is always current; this section exists so a plan written under an older
rule can be understood rather than trusted. Add an entry every time a rule changes, with the date and
what it replaced.

- **1.1 (2026-08-12)** — added §11, the single archive routine (move under the same name, one catalog
  line, one banner judgment), replacing per-skill archive steps and the date-prefixed archive
  filenames. `Paths` is now filled at scaffold time and names `Design/Tickets/` as the backlog,
  replacing `Design/feature-catalog.md`; folder names are plural and active mirrors archived. §4's
  adjacent-problem rule now files a ticket with `Status: untriaged` and states that the executing
  agent is the only filer that writes it.
- **1.0 (2026-08-11)** — initial version, generalised from the LongRange project's protocol after
  ~144 commits of use. Portable body plus four project-declaration blocks.
