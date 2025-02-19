THIS_MAKEFILE := $(realpath $(lastword $(MAKEFILE_LIST)))
CONTRIB := $(realpath $(dir $(THIS_MAKEFILE)))

default: $(CONTRIB)/env.sh config.mk build-cil build-toolsub

OLD_CONTRIB := $(CONTRIB)
include config.mk
ifneq ($(OLD_CONTRIB),$(CONTRIB))
$(error config.mk changed CONTRIB)
endif

# ----------------------------cil

.PHONY: build-cil
build-cil: cil.stamp

# PROBLEM: cil's ocamlbuild takes a significant time to re-run even in the
# case where nothing's changed. So use a stamp to run around that.
cil.stamp: cil/Makefile $(shell find cil -name '*.c' -o -name '*.ml' -o -name '*.mli' -o -name '*.in' -o -name '*.mly' )
	$(MAKE) -C cil all install-local && touch $@
cil/Makefile: cil/configure
	cd cil && ./configure INSTALL="`which install` -p"

CONFIG_MK += \nCIL_INSTALL ?= $(CONTRIB)/cil/lib\n
varlist += CIL_INSTALL
export CIL_INSTALL

# ----------------------------toolsub

.PHONY: build-toolsub
build-toolsub: build-cil
	$(MAKE) -C toolsub wrapper-recursive cilpp-recursive  # don't build clang-based cccppp
CONFIG_MK += \nTOOLSUB ?= $(CONTRIB)/toolsub\n
varlist += TOOLSUB


# ----------------------------config.mk
# If the user nukes a sub-config.mk that our config.mk depends on,
# we'd like to be able to rebuild it. So we include a generic rule
# for rebuilding config.mks.
config.mk: $(subconfigs)
	(printf '%%/config.mk:\n\t$$(MAKE) -C $$* config.mk\n\n'; \
	printf "$(foreach cfg,$(subconfigs),\ninclude $(CONTRIB)/$(cfg))"; \
	printf '$(CONFIG_MK)'; echo) > "$@" || (rm -f "$@"; false)
# env.sh exports some vars
env.sh $(CONTRIB)/env.sh: $(foreach cfg,$(subconfigs),$(dir $(CONTRIB)/$(cfg))env.sh)
	(printf "$(foreach cfg,$(subconfigs),\n. $$(dirname $(CONTRIB)/$(cfg))/env.sh)"; \
	printf '$(foreach var,$(varlist),\nexport $(var)="$($(var))")'; echo )>"$@" || (rm -f "$@"; false)
# Similarly when we make an env.sh, have Make ensure existence of
# its depended-on env.sh too, so that we don't get 'source'-time
# failures of sub-env.sh.
$(foreach cfg,$(subconfigs),$(dir $(CONTRIB)/$(cfg))env.sh): %/env.sh:
	$(MAKE) -C $* env.sh
clean::
	rm -f config.mk env.sh
