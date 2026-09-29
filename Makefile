TESTS_INIT=$(CURDIR)/tests/minimal_init.lua
TESTS_DIR=tests/

.PHONY: test

test:
	@XDG_CONFIG_HOME=$$(mktemp -d) nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"
