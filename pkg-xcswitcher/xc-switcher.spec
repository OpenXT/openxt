# FIXME:
#   - ...
#
# TEST:
#   - ...

%include common.inc

Name: xc-switcher
Summary: XenClient XT switcher
Source: %{name}.tar.gz
BuildArch: noarch
# TODO: Add BuildRequires when switching to building on CentOS
Requires: gcc dbus dbus-glib dbus-glib-devel glib2 glib2-devel gtk2 gtk2-devel
Requires: libnotify libnotify-devel make

%define desc RHEL/CentOS in-guest switcher for Citrix XenClient XT.

%include description.inc

%prep
%setup -q -c

%build
rm -r usr/share/lintian

%install
mkdir -p %{buildroot}
cp -r * %{buildroot}

%clean
rm -rf %{buildroot}

%files
/usr/src
/usr/share/xc-switcher/

%post
%include xc-switcher-postinst.inc

%preun

%postun
%include xc-switcher-postrm.inc
