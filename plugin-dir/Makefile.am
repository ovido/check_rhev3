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

# compiler settings
prefix=@prefix@
INSTALL=@INSTALL@
INSTALL_OPTS=@INSTALL_OPTS@
libexec_SCRIPTS=check_rhev3

# compile
check_rhev3:
	sed '1,2d' check_rhev3.pl > check_rhev3.tmp
	echo "#!@PERL@ -w" > $(libexec_SCRIPTS)
	echo "# nagios: -epn" >> $(libexec_SCRIPTS)
	cat check_rhev3.tmp >> $(libexec_SCRIPTS)
	rm -f check_rhev3.tmp

# install
install:
	$(INSTALL) -m 755 $(INSTALL_OPTS) $(libexec_SCRIPTS) $(prefix)/$(libexec_SCRIPTS)

# cleanup
clean:
	rm -f $(libexec_SCRIPTS)

