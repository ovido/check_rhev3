# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# directories
PLUGIN_DIR=@srcdir@/plugin-dir
CONTRIB_DIR=@srcdir@/contrib

distdir=$(PACKAGE)-$(VERSION)
DIST_COMMON=config.sub configure.in configure NEWS INSTALL missing aclocal.m4 TODO install-sh Makefile.am ChangeLog COPYING README AUTHORS Makefile.in config.guess
PLUGIN_COMMON=$(PLUGIN_DIR)/Makefile.am $(PLUGIN_DIR)/Makefile.in $(PLUGIN_DIR)/check_rhev3.pl
CONTRIB_COMMON=$(CONTRIB_DIR)/Makefile.am $(CONTRIB_DIR)/Makefile.in $(CONTRIB_DIR)/check_rhev3.php
DISTFILES=$(DIST_COMMON) $(PLUGIN_COMMON) $(CONTRIB_COMMON)

# compiler settings
prefix=@prefix@
INSTALL=@INSTALL@

# Compile
all:
	cd $(PLUGIN_DIR) && $(MAKE) $@
	cd $(CONTRIB_DIR) && $(MAKE) $@

# Install
install:
	cd $(PLUGIN_DIR) && $(MAKE) $@
	cd $(CONTRIB_DIR) && $(MAKE) $@

# Cleanup
clean:
	cd $(PLUGIN_DIR) && $(MAKE) $@
	cd $(CONTRIB_DIR) && $(MAKE) $@

