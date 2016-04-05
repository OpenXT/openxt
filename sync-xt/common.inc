# Common RPM tags/macros which can be overridden in the spec file if needed.

Version: %{xc_release}
Release: 1%{?dist}
Group: Applications/System
Vendor: OpenXT
License: GPLv2
URL: http://github.com/OpenXT
BuildRoot: %{name}-%{version}-%{release}

%define desc %{summary}.
