PREFIX ?= /usr/local

install:
	install -m 755 open $(PREFIX)/bin/open

uninstall:
	rm -f $(PREFIX)/bin/open

.PHONY: install uninstall
