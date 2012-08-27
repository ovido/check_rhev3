Name:		nagios-plugins-rhev3
Version:	1.0.0
Release:	1%{?dist}
Summary:	RHEV monitoring plugin for Nagios/Icinga

Group:		Applications/System
License:	GPLv2+
URL:		https://labs.ovido.at/monitoring
Source0:	%{name}-%{version}.tar.gz
BuildArch:	noarch
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root

Requires:	perl-Crypt-SSLeay
Requires:	perl-libwww-perl
Requires:	perl-HTTP-Message
Requires:	perl-XML-Simple

%description
This plugin for Icinga/Nagios is used to monitor a variety of
a RHEV environement including datacenters, clusters, hosts,
vms, vm pools and storage domains.

%prep
%setup -q

%build
%configure --prefix=%{_libdir}/nagios/plugins \
	   --with-nagios-user=nagios \
	   --with-nagios-group=nagios \
	   --with-pnp-dir=%{_datadir}/nagios/html/pnp4nagios

make all


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%{_libdir}/nagios/plugins/check_rhev3
%{_datadir}/nagios/html/pnp4nagios/templates/check_rhev3.php
%doc



%changelog
* Wed Aug 22 2012 Rene Koch <r.koch@ovido.at> 1.0.0-1
- Initial build.

