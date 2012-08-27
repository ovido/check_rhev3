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

