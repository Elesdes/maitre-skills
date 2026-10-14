# Asking the user

Shared by every `maitre-skills` skill. Some decisions are the user's: what goes into their vault,
which of two contradicting rules applies, whether a fix that worked deserves a node.

This reference is **agent-agnostic on purpose**. Skills name this file, not a specific tool, and let
the agent pick the mechanism it has.

## Protocol

If you have a built-in structured question tool (a tool that presents multiple-choice options), use
it, batching related questions where it supports that. If not, present the same options as a plain
numbered list and wait for the reply.

Either way the content is the same: same question, same options, same order. Never skip the question
because the structured tool is missing, and never invent an answer to keep going.

## Shape of a question

- **One question per decision**, collected into **one round** where possible. A run must not become
  a prompt storm.
- **Two to four options**, mutually exclusive, best first. Mark one `(Recommended)` and say why in a
  few words.
- **Always include an opt-out** ("skip", "don't propose anything").
- **Name the concrete thing**: the node id, the file, the error line.

Plain-list fallback:

```
Two confirmed rules disagree for this task: [[pref-sqlalchemy-orm]] (use the ORM) and
[[conv-raw-sql-reports]] (reports in raw SQL). This task builds a report endpoint.

1) Follow conv-raw-sql-reports (recommended - it is about reports specifically)
2) Follow pref-sqlalchemy-orm
3) Neither; I will tell you

Reply with a number, or tell me what you would rather do.
```

Then **stop and wait**.

## When not to ask

- Do not ask what config, the vault's rules or a sensible default already settle. Pick, say so in one
  line, move on.
- Do ask before writing proposals the user has not seen when the evidence is thin, and whenever two
  confirmed nodes contradict for the task at hand.

## Honour the answer

A decision holds for the rest of the run. Do not re-ask it under another name.
