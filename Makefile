.PHONY: grade grade-all

# Grade a single exercise:  make grade EX=01-variables
grade:
	@./grader/grade exercises/$(EX)

# Grade everything (CI use)
grade-all:
	@for d in exercises/*/; do \
		./grader/grade "$$d" || exit $$?; \
		echo; \
	done
