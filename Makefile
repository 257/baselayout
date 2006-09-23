# baselayout Makefile
# Copyright (c) 2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Contributed by Roy Marples (uberlord@gentoo.org)
#
# We've moved the installation logic from Gentoo ebuild into a generic
# Makefile so that the ebuild is much smaller and more simple.
# It also has the added bonus of being easier to install on systems
# without an ebuild style package manager.

SUBDIRS = bin conf.d etc init.d man net sbin sh src

NAME = baselayout
VERSION = 1.13.0_alpha1
PKG = $(NAME)-$(VERSION)

ARCH = x86
OS = Linux

BASE_DIRS = lib/rcscripts/init.d lib/rcscripts/tmp
KEEP_DIRS = boot dev proc home \
	mnt/cdrom mnt/floppy \
	usr/local/bin usr/local/sbin usr/local/share/doc usr/local/share/man \
	var/run 

ifeq ($(OS),Linux)
	KEEP_DIRS += sys
	NET_LO = net.lo
endif
ifneq ($(OS),Linux)
	NET_LO = net.lo0
endif

TOPDIR = .
include $(TOPDIR)/default.mk

install::
	# These dirs may not exist from prior versions
	for x in $(BASE_DIRS) ; do \
		$(INSTALL_DIR) $(DESTDIR)$$x || exit $$? ; \
		touch $(DESTDIR)$$x/.keep || exit $$? ; \
	done
	# Don't install runlevels if they already exist
	if ! test -d $(DESTDIR)etc/runlevels ; then \
		(cd runlevels; $(MAKE) install) ; \
		test -d runlevels.$(OS) && (cd runlevels.$(OS); $(MAKE) install) ; \
		$(INSTALL_DIR) $(DESTDIR)etc/runlevels/single || exit $$? ; \
		$(INSTALL_DIR) $(DESTDIR)etc/runlevels/nonetwork || exit $$? ; \
	fi
	ln -snf ../../$(LIB)/rcscripts/sh/net.sh $(DESTDIR)/etc/init.d/$(NET_LO) || exit $$?
	# SPARC fixes
	# SPARC does not like stty, so we disable RC_INTERACTIVE which requires it
	# see Gentoo bug #104067.
	if test $(ARCH) = "sparc" ; then \
		sed -i -e  '/^KEYMAP=/s:us:sunkeymap:' $(DESTDIR)/etc/conf.d/keymaps || exit $$? ; \
		sed -i -e '/^RC_INTERACTIVE=/s:yes:no:' $(DESTDIR)/etc/conf.d/rc || exit $$? ; \
	fi

.PHONY: all clean install

layout:
	# Create base filesytem layout
	for x in $(KEEP_DIRS) ; do \
		$(INSTALL_DIR) $(DESTDIR)$$x || exit $$? ; \
		touch $(DESTDIR)$$x/.keep || exit $$? ; \
	done
	# Special dirs
	install -m 0700 -d $(DESTDIR)/root || exit $$?
	touch $(DESTDIR)/root/.keep || exit $$?
	install -m 1777 -d $(DESTDIR)/var/tmp || exit $$?
	touch $(DESTDIR)/var/tmp/.keep || exit $$?
	install -m 1777 -d $(DESTDIR)/tmp || exit $$?
	touch $(DESTDIR)/tmp/.keep || exit $$?
	# FHS compatibility symlinks stuff
	ln -snf /var/tmp $(DESTDIR)/usr/tmp || exit $$?
	ln -snf share/man $(DESTDIR)/usr/local/man || exit $$?

distcheck:
	svnfiles=`svn status 2>&1 | egrep -v '^(U|P)'` ; \
	if test "x$$svnfiles" != "x" ; then \
		echo "Refusing to package tarball until svn is in sync:" ; \
		echo "$$svnfiles" ; \
		echo "make distforce to force packaging" ; \
		exit 1 ; \
	fi 

distforce: clean
	install -d /tmp/$(PKG)
	cp -PRp . /tmp/$(PKG)
	find /tmp/$(PKG) -depth -path "*/.svn/*" -delete
	find /tmp/$(PKG) -depth -path "*/.svn" -delete
	rm -rf /tmp/$(PKG)/sbin.Linux/MAKEDEV-gentoo.patch /tmp/$(PKG)/src/core /tmp/$(PKG)/po
	tar -C /tmp -cvjpf /tmp/$(PKG).tar.bz2 $(PKG)
	rm -Rf /tmp/$(PKG)
	du /tmp/$(PKG).tar.bz2

dist: distcheck	distforce

# vim: set ts=4 :
