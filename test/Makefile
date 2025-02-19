.PHONY: default clean
codebases := gnu-hello tar
default: $(foreach c,$(codebases),$(c)-justcil-O0 $(c)-justcil-O2 $(c)-dbgencode-O0 $(c)-dbgencode-O2)

clean:
	find -maxdepth 1 -type d -name 'tar-*' | xargs rm -rf

include ../config.mk
$(info TOOLSUB is $(TOOLSUB))
$(info CIL_INSTALL is $(CIL_INSTALL))

# HACK
SHELL := $(shell which bash)
.ONESHELL:
PARALLEL ?= 4

# Some test cases are regression tests that we run specially;
# others are stress tests, a.k.a. found codebases supporting a "./configure && make" workflow
# that let us set CFLAGS at configure time. gnu-hello and tar are these for now...
# How do we vendor these without bloating our repo?
# One idea is to keep a list of download URLs and sha1sums here
# and grab them on demand.
download:
	sources=([gnu-hello]="https://ftp.gnu.org/gnu/hello/hello-2.12.tar.gz" \
         [tar]="https://ftp.gnu.org/gnu/tar/tar-1.35.tar.gz" )
	sha1sums=([gnu-hello]=336b8ae5d6e72383c53ebd0d3e62d41e8266ba8b \
          [tar]=92848830c920cbaa44abc3ab70e02b0ce8f1e212)
	for t in $${!sources}; do \
            { test -r "$$t".tar.gz || wget -O "$$t".tar.gz "$${sources[$test]}"; } && \
            test "$$(sha1sum <"$$t".tar.gz | tr -cd '[0-9a-f]' )" || break; \
        done

define per-codebase-rules
$(1)-%: download
	(test -d $$@ || { mkdir $$@ && cd $$@ && tar --strip-components=1 -xzf ../$(1).tar.gz; })
	(cd $$@ && test -e config.log || CFLAGS="$$(CFLAGS)" ./configure)
	(cd $$@ && make -j$$(PARALLEL))
$(1)-dbgencode-O0 $(1)-dbgencode-O2: CFLAGS := `$${TOOLSUB}/cilpp/bin/cilpp-cflags`\
 -save-temps \
 -Wp,-save-temps \
 -Wp,-plugin,$${CIL_INSTALL}/cil/liveness.cmxs \
 -Wp,-plugin,`pwd`/../../src/dbgencode.cmxs \
 -Wp,-fpass-dbgencode
$(1)-justcil-O0 $(1)-justcil-O2: CFLAGS := `$${TOOLSUB}/cilpp/bin/cilpp-cflags`\
 -save-temps \
 -Wp,-save-temps

$(1)-justcil-O0 $(1)-dbgencode-O0: CFLAGS += -O0
$(1)-justcil-O2 $(1)-dbgencode-O2: CFLAGS += -O2

.PHONY: $(1)-report-text-size
$(1)-report-text-size:
	find $(1)-justcil-O0* $(1)-dbgencode-O0* $(1)-justcil-O2* $(1)-dbgencode-O2* -name '$(1)' | xargs readelf -WS  | egrep '^File:|Type|\.text'

endef
$(foreach n,$(codebases),$(eval $(call per-codebase-rules,$(n))))

