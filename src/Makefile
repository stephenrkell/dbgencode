THIS_MAKEFILE := $(lastword $(MAKEFILE_LIST))

include $(dir $(THIS_MAKEFILE))/../config.mk

.PHONY: default
default: dbgencode.cmxs

OCAMLOPTFLAGS += -fPIC
CFLAGS += -fPIC

OCAMLFIND ?= ocamlfind
ifneq ($(MAKECMDGOALS),clean)
ifeq ($(CIL_INSTALL),)
$(error Please set CIL_INSTALL to your CIL directory (containing a file cil/cil.cmxa))
endif
endif

OCAMLFLAGS +=  -package findlib -package dynlink -I $(CIL_INSTALL)/cil
OCAMLFLAGS += -I $(dir $(THIS_MAKEFILE))/lib
OCAMLFLAGS += -I $(TOOLSUB)/wrapper/lib
vpath %.cmx $(TOOLSUB)/wrapper/lib
vpath %.o $(TOOLSUB)/wrapper/lib

OCAMLLIBS := str.cmxa nums.cmxa unix.cmxa

%.cmxs: %.cmx
	$(OCAMLFIND) ocamlopt -shared -o "$@" $(OCAMLOPTFLAGS) $(OCAMLFLAGS) $+
%.cmx %.cmi: %.ml
	$(OCAMLFIND) ocamlopt -o "$@" $(OCAMLOPTFLAGS) $(OCAMLFLAGS) -c "$<"
%.cmo %.cmi: %.ml
	$(OCAMLFIND) ocamlc -o "$@" $(OCAMLFLAGS) -c "$<"
%.cma: %.cmo
	$(OCAMLFIND) ocamlc -o "$@" $(OCAMLFLAGS) -a $+

.PHONY: clean
clean:
	rm -f *.o *.cmxa *.cmx *.cmo *.cmxs *.cmi

.PHONY: test
# -fno-dwarf2-cfi-asm  -- don't do this, as it just substitutes the raw asm using ULEB128
test: hello.c dbgencode.cmxs
	$(CC) -fno-lto  -O \
               `$(TOOLSUB)/cilpp/bin/cilpp-cflags`\
               -Wp,-plugin,$(CIL_INSTALL)/cil/liveness.cmxs \
               -Wp,-plugin,`pwd`/dbgencode.cmxs \
               -Wp,-fpass-dbgencode -S -save-temps -o hello.s $<
