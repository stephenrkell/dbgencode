.PHONY: default clean
codebases := gnu-hello tar
default: $(foreach c,$(codebases),$(foreach mode,justcil dbgencode,$(foreach opt,O0 O2,\
$(c)-$(mode)-$(opt).stamp)))

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

$(1)-%.stamp: download
	(test -d $(1)-$$* || { mkdir $(1)-$$* && cd $(1)-$$* && tar --strip-components=1 -xzf ../$(1).tar.gz; })
	(cd $(1)-$$* && test -e config.log || CFLAGS="$$(CFLAGS)" ./configure)
	(cd $(1)-$$* && make -j$$(PARALLEL))
	touch $$@
# I initially had this attempt at a phony pattern rule:
#build-$(1)-%: download
# but if we make the build-$(1)-* rules phony, make will not
# select them for rebuilding, via the above pattern rule.
# I'm not sure why... perhaps phony targets just never
# match an implicit rule? Indeed if we run a simple test
# makefile
#
# .PHONY: default does_not_exist
# default: does_not_exist
#
# ... then indeed it does not complain about 'does_not_exist' and indeed
# the make -d output happily says "Successfully remade target file 'does_not_exist'."
#
# What we really want is the above steps to run unconditionally, because they build
# in their own test for up-to-dateness (whether by 'test' or by recursive make). The
# workaround is to make a stamp file.

#.PHONY: build-$(1)-dbgencode-O0 \
#        build-$(1)-dbgencode-O2 \
#        build-$(1)-justcil-O0 \
#        build-$(1)-justcil-O2

$(1)-dbgencode-O0.stamp $(1)-dbgencode-O2.stamp: CFLAGS := `$${TOOLSUB}/cilpp/bin/cilpp-cflags`\
 -save-temps \
 -Wp,-save-temps \
 -Wp,-plugin,$${CIL_INSTALL}/cil/liveness.cmxs \
 -Wp,-plugin,`pwd`/../../src/dbgencode.cmxs \
 -Wp,-fpass-dbgencode
$(1)-justcil-O0.stamp $(1)-justcil-O2.stamp: CFLAGS := `$${TOOLSUB}/cilpp/bin/cilpp-cflags`\
 -save-temps \
 -Wp,-save-temps

$(1)-justcil-O0.stamp $(1)-dbgencode-O0.stamp: CFLAGS += -O0
$(1)-justcil-O2.stamp $(1)-dbgencode-O2.stamp: CFLAGS += -O2

.PHONY: $(1)-report-text-size
$(1)-report-text-size:
	find $(1)-justcil-O0* $(1)-dbgencode-O0* $(1)-justcil-O2* $(1)-dbgencode-O2* -name '$(1)' | xargs readelf -WS  | egrep '^File:|Type|\.text'

clean::
	find -maxdepth 1 -type d -name '$(1)-*' | xargs rm -rf
endef
$(foreach n,$(codebases),$(eval $(call per-codebase-rules,$(n))))

