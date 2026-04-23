# CLAUDE.md

Guidance for Claude when working in this repository.

## What this is

An interactive, xv6-style rewrite of an existing bash scripting video course. Target audience: university students with command-line basics. Each chapter ends with a runnable script auto-graded by a local grader.

Core decision: **course content is decoupled from the grader.** The grader is generic infrastructure; chapters are just directories of YAML test specs and starter code. Adding/editing a chapter never requires touching `grader/`.

## Repo layout

```
grader/grade        # generic Python grader (the only piece of infra)
grader/README.md    # full test-spec reference
exercises/NN-topic/
  README.md         # student-facing prompt (Chinese)
  starter/          # student edits these files
  solution/         # reference solution (for course author validation)
  tests/*.yml       # public test specs
  Makefile          # one-liner that calls ../../grader/grade .
```

## Test spec format (quick reference)

See `grader/README.md` for the full schema. The shape:

```yaml
name: ...
points: N
setup: |       # optional bash run in tmpdir before the test
run: ...       # required; runs in tmpdir with $EXERCISE_DIR set
expect:
  exit: 0
  stdout / stdout_contains / stdout_matches
  stderr / stderr_contains / stderr_matches
  files:
    - path: ...
      exists: true|false
      contains: ...
      matches: ...
```

Each test runs in a fresh `tempfile.TemporaryDirectory()`. `$EXERCISE_DIR` points to the exercise dir so tests can reference `starter/` scripts without depending on cwd.

## Conventions

- **No hidden tests.** All `.yml` specs are visible to the learner — the spec *is* the contract. Do not add a "hidden" subdirectory of secret tests.
- **Starter must fail loudly.** A fresh `starter/` script should print to stderr and `exit 1` so a baseline `make grade` produces a clean 0/N rather than misleading partial credit.
- **Solutions live alongside.** Every exercise has a `solution/` so the course author can sanity-check that the spec actually passes when the work is done correctly. Solutions are not graded against and not hidden — they're documentation for the maintainer.
- **READMEs are in Chinese**, code/comments in English unless the comment is teaching content for the learner.
- **Grader stays generic.** If a new chapter needs a kind of assertion the grader can't express, add the assertion type to `grader/grade` (and document it in `grader/README.md`) — never special-case a chapter inside the grader.

## Course outline

The 10-chapter outline is in the top-level `README.md`. Chapters 5 and 7 are flagged as candidates for browser-based visualizations (pipes/fds, process substitution) — visualizations are not yet built.

## Running the grader

```bash
# Single exercise
./grader/grade exercises/01-variables
# or
cd exercises/01-variables && make grade

# Everything (CI)
make grade-all
```

Dependency: `python3` + `pyyaml`. Nothing else.

## When adding a new chapter

1. Copy an existing exercise dir as a template.
2. Write the prompt (`README.md`) and a reference `solution/`.
3. Write `tests/*.yml` — at least one happy path, one edge case, and one error-handling check (matches the pattern set by `01-variables`).
4. Confirm `solution/` passes 100% and a stub `starter/` produces 0%. Both should be verified before committing.
5. Add the chapter row to the top-level `README.md` table.

## What not to do

- Do not introduce a build system, package manager, or test framework beyond `python3 + pyyaml + make`. The whole point is that the infra is small and a learner can read all of `grader/grade` in one sitting.
- Do not add features to the grader speculatively. Add an assertion type only when an actual exercise needs it.
- Do not commit network-dependent tests. Everything must run offline in a tmpdir.
