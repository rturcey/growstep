# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- `CONTEXT.md` at the repo root.
- Relevant ADRs under `docs/adr/`.

If these files don't exist, proceed silently. The `/domain-modeling` skill creates them when terms or decisions get resolved.

## File structure

This repo uses one root `CONTEXT.md` and root `docs/adr/` for decisions.

## Use the glossary's vocabulary

Use terms defined in `CONTEXT.md` when naming domain concepts. Reconsider synonyms the glossary explicitly avoids; note genuine gaps for `/domain-modeling`.

## Flag ADR conflicts

Surface any proposal that contradicts an existing ADR rather than silently overriding it.
