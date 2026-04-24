# AGENTS.md Discipline

`AGENTS.md` (and its tool-specific twin `CLAUDE.md`) is the **hottest** doc in the repo. It loads every session, crowding out task context, code, and other docs. Every line must earn its place.

The monolithic-instruction failure mode is predictable: file grows to 400 lines, nobody maintains it, agents ignore the bottom half, and the signal-to-noise collapses. The fix is structural, not cosmetic.

---

## The 100-line target

Aim for ~100 lines. Hard ceiling: 150. If you're past 150, something belongs in `docs/` instead.

This isn't about pagination — it's about **context cost**. Every line of AGENTS.md is a line that isn't the user's task, the file being edited, or the library doc that would actually solve the problem.

---

## AGENTS.md is a table of contents, not an encyclopedia

The mental model: AGENTS.md answers **"where do I look?"** — not **"what do I do?"**

**Weak (encyclopedia):**
> ## Testing
> We use vitest. Tests live in `tests/` folders. Write failing tests first. Use
> `describe`/`it` blocks. Mock external services. Prefer integration tests over unit
> tests for business logic. For async code, use `await` not `.then()`. Group related
> assertions... (40 more lines)

**Strong (table of contents):**
> ## Testing
> - vitest, tests in `tests/` per package (not co-located)
> - TDD: failing test → implement → pass → commit
> - Full conventions: `docs/references/vitest.md`

Short, scannable, points to depth when needed.

---

## What belongs in AGENTS.md

**Yes — belongs here:**
- Project identity (what this repo is, in 1–2 sentences)
- Stack summary (languages, frameworks, package manager)
- The 3–5 inviolable rules (things that would cause real damage if violated)
- A routing table: "for X, read Y"
- Commit / test / build command conventions
- Pointer to `ARCHITECTURE.md` for structure

**No — belongs elsewhere:**
- Full coding style guides → `.agents/rules/` or `.claude/rules/`
- Architectural rationale → `docs/design-docs/`
- Feature specs → `docs/product-specs/`
- Library tutorials → `docs/references/<lib>.md`
- Historical context → `docs/design-docs/` or commit messages
- Onboarding narrative → `CONTRIBUTING.md` or `README.md`

If in doubt: would this rot in 3 months if nobody touched it? If yes, move it to a doc that has a clear owner and trigger to update.

---

## Skeleton

A lean AGENTS.md looks roughly like this:

```markdown
# <project-name>

<One-sentence description. What this repo is.>

## Stack
<Language, runtime, build tool, key frameworks — one line.>

## Key principles
- <3–5 bullets. The things an agent must not violate.>

## Conventions
- Commits: <style> — see `docs/references/commits.md`
- Tests: <location and style>
- Build: <command>

## Docs

| When you need to...      | Read                                   |
|--------------------------|----------------------------------------|
| Understand the structure | `ARCHITECTURE.md`                      |
| Understand a decision    | `docs/design-docs/<topic>.md`          |
| Find active plans        | `docs/exec-plans/active/`              |
| Check known tech debt    | `docs/exec-plans/tech-debt-tracker.md` |
| Use library X correctly  | `docs/references/<lib>.md`             |

## Structure
See `ARCHITECTURE.md`.
```

That's ~30 lines of signal. Fill in, but resist the urge to expand every section into paragraphs.

---

## Anti-patterns

**The manifesto.** "Our philosophy is to build clean, maintainable code that..." Agents don't need philosophy; they need rules with file paths.

**The changelog.** "Recently we migrated from X to Y, and previously we used Z." Belongs in git log or a superseded ADR.

**The tutorial.** Step-by-step how-to for a common task. Belongs in a reference doc; link from AGENTS.md.

**The safety blanket.** Reiterating instructions that already exist in system prompts or tool docs ("always be careful with git push"). If the base model already knows it, re-stating wastes context.

**The wishlist.** "In the future we want to add..." Not actionable. Goes in `docs/DESIGN.md` or an exec plan.

**Duplication with README.md.** README is for humans finding the project; AGENTS.md is for agents working in it. Overlap is fine (identity line, stack) but don't repeat setup instructions — link.

---

## Auditing an existing AGENTS.md

When asked to review one, go line by line with these questions:

1. **Would removing this line change agent behavior?** If no, cut it.
2. **Is this info duplicated anywhere else?** If yes, keep one copy, link from the other.
3. **Will this rot?** (Mentions specific versions, team members, or "current" state.) If yes, either move to a dated doc or remove.
4. **Is this a rule or a narrative?** Narrative → move. Rule → keep but tighten.
5. **Could a pointer replace a paragraph?** Almost always yes.

Typical reduction: 300-line AGENTS.md → 80-line AGENTS.md + 4 new/updated docs under `docs/`. The information doesn't disappear — it moves to where it's loaded only when needed.

---

## CLAUDE.md vs AGENTS.md

`CLAUDE.md` is the Claude-specific variant. Conventions:
- If both exist, keep them in sync (or symlink)
- Tool-specific nuances (e.g., "use the Skill tool for X") go in the tool-specific file
- Shared content should live in AGENTS.md with CLAUDE.md as a superset or symlink

Don't let them drift. If they diverge silently, both become untrustworthy.
