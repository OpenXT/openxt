# Common RPM tags/macros which can be overridden in the spec file if needed.

Version: %{xc_release}
Release: 1%{?dist}
Group: Applications/System
Vendor: Citrix Systems
License: Proprietary
URL: http://www.citrix.com/xenclient/xt
BuildRoot: %{name}-%{version}-%{release}

%define desc %{summary}.
