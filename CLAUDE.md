# CLAUDE.md

Guidance for Claude when working in this repository.

## What this is

An interactive, xv6-style rewrite of an existing bash scripting video course. Target audience: university students with command-line basics. Each chapter ends with a runnable script auto-graded by a local grader.

Core decision: **course content is decoupled from the grader.** The grader is generic infrastructure; chapters are just directories of YAML test specs and starter code. Adding/editing a chapter never requires touching `grader/`.

## Repo layout

```
grader/grade        # generic Python grader (the only piece of infra)
grader/README.md    # full test-spec reference (single source of truth)
exercises/NN-topic/   # CODE ONLY — no prose
  starter/          # student edits these files
  solution/         # reference solution (for course author validation)
  tests/*.yml       # public test specs
  Makefile          # one-liner that calls ../../grader/grade .
docs/               # ALL learner-facing prose lives here (mkdocs site)
  index.md
  chapters/NN-topic.md   # lecture + lab spec for chapter NN, in one page
  appendix/
    grader-spec.md  # auto-includes grader/README.md via include-markdown plugin
mkdocs.yml          # mkdocs config (root)
requirements.txt    # one venv for grader + docs deps
```

**Single source of truth principle.** Every documentation file lives under `docs/`. `exercises/` holds only code. The per-chapter page (`docs/chapters/NN-topic.md`) covers both the lecture (concepts, pitfalls, worked examples) AND the lab spec (what to build, requirements, how it's graded). The `grader/README.md` is the one exception — it stays next to the grader code, but is auto-included into the docs site rather than duplicated.

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
- **Prose is in Chinese**, code/comments in English unless the comment is teaching content for the learner.
- **No prose in `exercises/`.** All learner-facing text (lecture, lab prompt, hints, grading explanation) lives in `docs/chapters/NN-topic.md`. The exercise dir is code-only.
- **Grader stays generic.** If a new chapter needs a kind of assertion the grader can't express, add the assertion type to `grader/grade` (and document it in `grader/README.md`) — never special-case a chapter inside the grader.

## Course design: project-threaded

The course is built around **one** capstone project — `bkp`, a local incremental backup tool. Every chapter exercise builds a module of `bkp`. By the end of ch8 the student has a working ~600–900 line tool, not a pile of disconnected mini-scripts.

Full project spec: `docs/capstone.md`. Chapter pages must reference the relevant section of capstone.md rather than re-deriving the data model or storage layout.

### Chapter → bkp module map

| Ch | Topic                                       | bkp module                                      | Robustness introduced |
|----|---------------------------------------------|-------------------------------------------------|-----------------------|
| 1  | Variables, quoting, expansion               | `lib/path.sh`                                   | `set -e`, shebang     |
| 2  | Conditions, test, boolean logic             | `lib/check.sh`                                  | `set -u`              |
| 3  | Loops, arrays, pattern matching             | `lib/scan.sh` + `lib/filter.sh`                 | `nullglob`            |
| 4  | Functions, scope, libraries                 | `lib/log.sh` + `lib/lock.sh`                    | `trap`, `local`       |
| 5  | I/O redirection, pipes, fds                 | main I/O wiring + manifest output (sha256)      | `set -o pipefail`     |
| 6  | Processes, concurrency, process substitution| `bkp run --all` + `bkp diff`                    | `wait -n`, exit codes |
| 7  | Debugging + CLI argument parsing            | `bkp` CLI dispatcher + `--debug` + `getopts`    | `bash -x`, `PS4`      |
| 8  | Capstone: robustness + integration          | `prune`/`verify`/`restore` + integration tests  | shellcheck, idempotency |

**Differences from the original outline:**
- Original ch7 (process substitution) and ch8 (pattern matching) are no longer standalone chapters — folded into ch6 and ch3 respectively.
- Robustness is woven through chapters incrementally rather than dumped in one final chapter. Starter templates in ch1 already include `set -e`.
- New ch7 covers debugging tools + CLI argument parsing (previously not explicit in the outline).

### Stable-interface convention (per-chapter independence)

Each chapter's grader uses the **official `solution/`** of earlier chapters as upstream dependencies, not the student's own prior work. So ch4's grader exercises `lib/log.sh` against the `lib/path.sh` from ch1's `solution/`, not the student's ch1 starter.

This guarantees:
- Chapters can be done in any order
- ch1 being incomplete doesn't block ch4 grading
- Students focus on the current chapter's concept without debugging earlier modules

A student who wants to validate "my ch1 plus my ch4 together work" copies their ch1 implementation into `exercises/01-variables/solution/` — graders read from `solution/` first by convention.

## Local setup

All Python dependencies (grader + docs) live in **one venv** at the repo root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

The grader itself only needs `pyyaml`. `mkdocs` + `mkdocs-material` are for building the docs site and are optional for students who only want to do exercises.

## Running the grader

```bash
# Single exercise
./grader/grade exercises/01-variables
# or
cd exercises/01-variables && make grade

# Everything (CI)
make grade-all
```

## Building the docs site

```bash
make docs-serve   # live preview at http://127.0.0.1:8000
make docs         # build static HTML into ./site
```

## When adding a new chapter

1. Copy an existing exercise dir as a template — `starter/`, `solution/`, `tests/`, `Makefile`. No README.
2. Create `docs/chapters/NN-topic.md` covering: 学习目标 → 概念讲义 → 常见坑 → 实验（题面 + 要求 + 提示 + 评分项）→ 延伸阅读. Use `01-variables.md` as the structural template.
3. Write `tests/*.yml` — at least one happy path, one edge case, and one error-handling check (matches the pattern set by `01-variables`).
4. Confirm `solution/` passes 100% and the stub `starter/` produces 0%. Both should be verified before committing.
5. Add the chapter row to the top-level `README.md` table AND to `mkdocs.yml` nav.

## What not to do

- Do not introduce a build system, package manager, or test framework beyond `python3 + pyyaml + make` **for the grader**. The grader is the load-bearing piece — keep it small enough that a learner can read all of `grader/grade` in one sitting. (The docs toolchain is a separate, optional concern; see below.)
- Do not add features to the grader speculatively. Add an assertion type only when an actual exercise needs it.
- Do not commit network-dependent tests. Everything must run offline in a tmpdir.
- Do not add new doc-build dependencies casually. `mkdocs` + `mkdocs-material` is the toolchain; resist adding plugins unless a chapter actually needs the feature.
