.PHONY: default src-recursive test clean
default: src-recursive
test:
	$(MAKE) -C test

src-recursive: config.mk
	$(MAKE) -C src

# one way to get a config.mk is from contrib/, or you can write your owno
config.mk:
	$(MAKE) -C contrib
	ln -sf contrib/config.mk .

clean:
	$(MAKE) -C src clean
