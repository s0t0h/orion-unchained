# Orion Unchained: build and install the driver, orionctl, styles and services.
#
#   make                 build the kernel module for the running kernel
#   make check           lint orionctl and validate every style
#   sudo make install    install everything (DKMS keeps the driver built across kernel updates)
#   sudo make uninstall  remove it again

VERSION    := 0.1.0
DKMS_NAME  := acer-predator-dt-rgb
PREFIX     ?= /usr/local
BINDIR     ?= $(PREFIX)/bin
DATADIR    ?= $(PREFIX)/share/orion-unchained
LIBEXECDIR ?= $(PREFIX)/libexec/orion-unchained
SYSCONFDIR ?= /etc
UNITDIR    ?= $(SYSCONFDIR)/systemd/system
UDEVDIR    ?= $(SYSCONFDIR)/udev/rules.d
DKMS_SRC   := $(DESTDIR)/usr/src/$(DKMS_NAME)-$(VERSION)
KVER       ?= $(shell uname -r)
# The account that ran "sudo make install" gets lighting access without sudo.
INSTALL_USER ?= $(SUDO_USER)

SUBST = sed -e 's|@VERSION@|$(VERSION)|g' -e 's|@BINDIR@|$(BINDIR)|g' -e 's|@LIBEXECDIR@|$(LIBEXECDIR)|g'

.PHONY: all module check clean install dkms-install install-files post-install uninstall

all: module

module:
	$(MAKE) -C driver KVER=$(KVER)

check:
	python3 -m py_compile cli/orionctl
	cli/orionctl style validate styles/*.json
	sh -n packaging/udev/orion-unchained-permissions
	rm -rf cli/__pycache__

clean:
	$(MAKE) -C driver clean
	rm -rf cli/__pycache__

install: dkms-install install-files post-install

dkms-install:
	install -d $(DKMS_SRC)
	$(SUBST) packaging/dkms.conf.in > $(DKMS_SRC)/dkms.conf
	install -m644 driver/acer_predator_dt_rgb.c driver/Makefile $(DKMS_SRC)/
ifeq ($(DESTDIR),)
	-dkms remove -m $(DKMS_NAME) -v $(VERSION) --all >/dev/null 2>&1
	dkms add -m $(DKMS_NAME) -v $(VERSION)
	dkms install -m $(DKMS_NAME) -v $(VERSION) -k $(KVER)
endif

install-files:
	install -Dm755 cli/orionctl $(DESTDIR)$(BINDIR)/orionctl
	install -d $(DESTDIR)$(DATADIR)/styles
	install -m644 styles/*.json $(DESTDIR)$(DATADIR)/styles/
	install -Dm755 packaging/udev/orion-unchained-permissions $(DESTDIR)$(LIBEXECDIR)/udev-permissions
	install -d $(DESTDIR)$(UDEVDIR) $(DESTDIR)$(UNITDIR) $(DESTDIR)$(SYSCONFDIR)/sysusers.d $(DESTDIR)$(SYSCONFDIR)/tmpfiles.d
	$(SUBST) packaging/udev/70-orion-unchained.rules.in > $(DESTDIR)$(UDEVDIR)/70-orion-unchained.rules
	$(SUBST) packaging/systemd/orion-unchained.service.in > $(DESTDIR)$(UNITDIR)/orion-unchained.service
	$(SUBST) packaging/systemd/orion-unchained-resume.service.in > $(DESTDIR)$(UNITDIR)/orion-unchained-resume.service
	install -m644 packaging/sysusers.d/orion-unchained.conf $(DESTDIR)$(SYSCONFDIR)/sysusers.d/
	install -m644 packaging/tmpfiles.d/orion-unchained.conf $(DESTDIR)$(SYSCONFDIR)/tmpfiles.d/

post-install:
ifeq ($(DESTDIR),)
	systemd-sysusers $(SYSCONFDIR)/sysusers.d/orion-unchained.conf
	systemd-tmpfiles --create $(SYSCONFDIR)/tmpfiles.d/orion-unchained.conf
	@if [ -n "$(INSTALL_USER)" ] && [ "$(INSTALL_USER)" != root ]; then \
		usermod -aG orion-rgb $(INSTALL_USER) && \
		echo "added $(INSTALL_USER) to orion-rgb; log out and back in to drop the sudo prompt"; \
	fi
	udevadm control --reload
	systemctl daemon-reload
	systemctl enable orion-unchained.service orion-unchained-resume.service
	-modprobe -r acer_predator_dt_rgb
	modprobe acer_predator_dt_rgb
	@echo "done: try 'orionctl status' and 'orionctl style list'"
endif

uninstall:
	-systemctl disable orion-unchained.service orion-unchained-resume.service
	rm -f $(BINDIR)/orionctl $(UDEVDIR)/70-orion-unchained.rules
	rm -f $(UNITDIR)/orion-unchained.service $(UNITDIR)/orion-unchained-resume.service
	rm -f $(SYSCONFDIR)/sysusers.d/orion-unchained.conf $(SYSCONFDIR)/tmpfiles.d/orion-unchained.conf
	rm -rf $(DATADIR) $(LIBEXECDIR)
	-modprobe -r acer_predator_dt_rgb
	-dkms remove -m $(DKMS_NAME) -v $(VERSION) --all
	rm -rf /usr/src/$(DKMS_NAME)-$(VERSION)
	systemctl daemon-reload
	udevadm control --reload
	@echo "kept /var/lib/orion-unchained and the orion-rgb group; remove them by hand if you want"
