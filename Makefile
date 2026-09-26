# Orion Unchained: build and install the driver, orionctl, the app, styles and services.
#
#   make                 build the kernel module for the running kernel
#   make check           compile the Python code, validate every style and load the app's interface
#   sudo make install    install everything (DKMS keeps the driver built across kernel updates)
#   sudo make uninstall  remove it again
#   make shortcut        add an app menu entry and desktop icon that start the app from this checkout (no root)
#   make unshortcut      remove them again

VERSION    := 0.2.0
DKMS_NAME  := acer-predator-dt-rgb
PREFIX     ?= /usr/local
BINDIR     ?= $(PREFIX)/bin
DATADIR    ?= $(PREFIX)/share/orion-unchained
LIBEXECDIR ?= $(PREFIX)/libexec/orion-unchained
LIBDIR     ?= $(PREFIX)/lib/orion-unchained
APPDIR     ?= $(PREFIX)/share/applications
ICONDIR    ?= $(PREFIX)/share/icons/hicolor/scalable/apps
SYSCONFDIR ?= /etc
UNITDIR    ?= $(SYSCONFDIR)/systemd/system
UDEVDIR    ?= $(SYSCONFDIR)/udev/rules.d
DKMS_SRC   := $(DESTDIR)/usr/src/$(DKMS_NAME)-$(VERSION)
KVER       ?= $(shell uname -r)
# The account that ran "sudo make install" gets lighting access without sudo.
INSTALL_USER ?= $(SUDO_USER)

# Per-user launcher for running the app from a git checkout.
USER_APPDIR  ?= $(HOME)/.local/share/applications
USER_ICONDIR ?= $(HOME)/.local/share/icons/hicolor/scalable/apps
USER_DESKTOP ?= $(shell xdg-user-dir DESKTOP 2>/dev/null || echo $(HOME)/Desktop)

# Every version of the driver DKMS knows about, so upgrades and uninstalls catch older ones too.
DKMS_VERSIONS = $$(dkms status -m $(DKMS_NAME) 2>/dev/null | sed -n 's|^$(DKMS_NAME)/\([^,:]*\)[,:].*|\1|p' | sort -u)

SUBST = sed -e 's|@VERSION@|$(VERSION)|g' -e 's|@BINDIR@|$(BINDIR)|g' -e 's|@LIBEXECDIR@|$(LIBEXECDIR)|g'

.PHONY: all module check clean install dkms-install install-files post-install uninstall shortcut unshortcut

all: module

module:
	$(MAKE) -C driver KVER=$(KVER)

check:
	python3 -m py_compile bin/orionctl bin/orion-unchained orion_unchained/*.py orion_unchained/gui/*.py
	bin/orionctl style validate styles/*.json
	sh -n packaging/udev/orion-unchained-permissions
	@if command -v desktop-file-validate >/dev/null; then desktop-file-validate packaging/orion-unchained.desktop; fi
	@if python3 -c "import PySide6.QtQuick" 2>/dev/null; then \
		ORION_UNCHAINED_SG=1 QT_QPA_PLATFORM=offscreen bin/orion-unchained --check; \
	else \
		echo "PySide6 is not installed, skipping the app's interface check"; \
	fi
	find . -name __pycache__ -not -path './private/*' -prune -exec rm -rf {} +

clean:
	$(MAKE) -C driver clean
	find . -name __pycache__ -not -path './private/*' -prune -exec rm -rf {} +

install: dkms-install install-files post-install

dkms-install:
	install -d $(DKMS_SRC)
	$(SUBST) packaging/dkms.conf.in > $(DKMS_SRC)/dkms.conf
	install -m644 driver/acer_predator_dt_rgb.c driver/Makefile $(DKMS_SRC)/
ifeq ($(DESTDIR),)
	for v in $(DKMS_VERSIONS); do \
		dkms remove -m $(DKMS_NAME) -v $$v --all >/dev/null 2>&1; \
		[ "$$v" = "$(VERSION)" ] || rm -rf /usr/src/$(DKMS_NAME)-$$v; \
	done
	dkms add -m $(DKMS_NAME) -v $(VERSION)
	dkms install -m $(DKMS_NAME) -v $(VERSION) -k $(KVER)
endif

install-files:
	install -d $(DESTDIR)$(LIBDIR)/orion_unchained/gui/qml $(DESTDIR)$(LIBDIR)/orion_unchained/gui/icons
	install -m644 orion_unchained/*.py $(DESTDIR)$(LIBDIR)/orion_unchained/
	install -m644 orion_unchained/gui/*.py $(DESTDIR)$(LIBDIR)/orion_unchained/gui/
	install -m644 orion_unchained/gui/qml/* $(DESTDIR)$(LIBDIR)/orion_unchained/gui/qml/
	install -m644 orion_unchained/gui/icons/* $(DESTDIR)$(LIBDIR)/orion_unchained/gui/icons/
	install -Dm755 bin/orionctl $(DESTDIR)$(BINDIR)/orionctl
	install -Dm755 bin/orion-unchained $(DESTDIR)$(BINDIR)/orion-unchained
	install -Dm644 packaging/orion-unchained.desktop $(DESTDIR)$(APPDIR)/orion-unchained.desktop
	install -Dm644 orion_unchained/gui/icons/orion-unchained.svg $(DESTDIR)$(ICONDIR)/orion-unchained.svg
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
	-update-desktop-database -q $(APPDIR)
	-gtk-update-icon-cache -q -t $(PREFIX)/share/icons/hicolor
	-modprobe -r acer_predator_dt_rgb
	modprobe acer_predator_dt_rgb
	@echo "done: try 'orionctl status', or open Orion Unchained from your app menu"
endif

uninstall:
	-systemctl disable orion-unchained.service orion-unchained-resume.service
	rm -f $(BINDIR)/orionctl $(BINDIR)/orion-unchained $(UDEVDIR)/70-orion-unchained.rules
	rm -f $(APPDIR)/orion-unchained.desktop $(ICONDIR)/orion-unchained.svg
	rm -f $(UNITDIR)/orion-unchained.service $(UNITDIR)/orion-unchained-resume.service
	rm -f $(SYSCONFDIR)/sysusers.d/orion-unchained.conf $(SYSCONFDIR)/tmpfiles.d/orion-unchained.conf
	rm -rf $(DATADIR) $(LIBEXECDIR) $(LIBDIR)
	-modprobe -r acer_predator_dt_rgb
	for v in $(DKMS_VERSIONS); do dkms remove -m $(DKMS_NAME) -v $$v --all; rm -rf /usr/src/$(DKMS_NAME)-$$v; done
	rm -rf /usr/src/$(DKMS_NAME)-$(VERSION)
	systemctl daemon-reload
	udevadm control --reload
	@echo "kept /var/lib/orion-unchained and the orion-rgb group; remove them by hand if you want"

shortcut:
	@if [ "$$(id -u)" = 0 ]; then echo "run 'make shortcut' as yourself, without sudo"; exit 1; fi
	install -d $(USER_APPDIR) $(USER_ICONDIR)
	install -m644 orion_unchained/gui/icons/orion-unchained.svg $(USER_ICONDIR)/orion-unchained.svg
	sed -e 's|^Exec=.*|Exec="$(CURDIR)/bin/orion-unchained"|' -e 's|^Icon=.*|Icon=$(USER_ICONDIR)/orion-unchained.svg|' \
		packaging/orion-unchained.desktop > $(USER_APPDIR)/orion-unchained.desktop
	chmod 755 $(USER_APPDIR)/orion-unchained.desktop
	-update-desktop-database -q $(USER_APPDIR)
	@if [ -d "$(USER_DESKTOP)" ]; then \
		install -m755 $(USER_APPDIR)/orion-unchained.desktop "$(USER_DESKTOP)/orion-unchained.desktop"; \
		gio set "$(USER_DESKTOP)/orion-unchained.desktop" metadata::trusted true 2>/dev/null || true; \
	fi
	@echo "done: Orion Unchained is in your app menu and on your desktop, running from $(CURDIR)"

unshortcut:
	rm -f $(USER_APPDIR)/orion-unchained.desktop $(USER_ICONDIR)/orion-unchained.svg "$(USER_DESKTOP)/orion-unchained.desktop"
	-update-desktop-database -q $(USER_APPDIR)
