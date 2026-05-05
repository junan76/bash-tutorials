.PHONY: grade grade-all docs docs-serve

# Grade a single exercise:  make grade EX=01-variables
grade:
	@./grader/grade exercises/$(EX)

# Grade everything (CI use)
grade-all:
	@for d in exercises/*/; do \
		./grader/grade "$$d" || exit $$?; \
		echo; \
	done

# Build static HTML docs into ./site
docs:
	@mkdocs build

# Serve docs locally with live reload at http://127.0.0.1:8000
docs-serve:
	@mkdocs serve
