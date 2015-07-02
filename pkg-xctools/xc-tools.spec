# FIXME:
#   - eth0 dhcp doesn't recover from xc-netfront being inserted?
#   - sort out use of chkconfig (beware of rpm upgrade case)
#   - check calls to init scripts work in rpm upgrade case
#   - install GPLv2 COPYING in /usr/share/doc/*
#   - add dkms suffix to package release?
#   - check Requires list is complete
#   - add Requires dependency on kernel version or distro version?
#   - sort out use of dracut in postinst and test combinations below
#   - sort out excessive calls to dracut
#   - check that uninstalling package cleans up all files
#   - install.sh: yum install exits 0 even if post scriptlet fails; get
#     postinst to create a file and check it exists in install.sh?
#   - dkms depends on kernel-devel/-headers but may not be version we need
#
# TEST:
#   - running install.sh or "yum erase xc-tools" with:
#       - one kernel installed
#       - two kernels installed, older running
#       - two kernels installed, newer running
#     and with kernel-devel and kernel-headers:
#       - not installed
#       - matching running kernel
#       - matching other kernel (where applicable)
#   - kernel install/upgrade/erase with xc-tools installed

%include common.inc

Name: xc-tools
Summary: XenClient XT tools
Source0: %{name}.tar.gz
Source1: %{name}-centos.tar.gz
BuildArch: noarch
# TODO: Add BuildRequires when switching to building on CentOS
Requires: autoconf automake dkms gcc libtool libpciaccess libpciaccess-devel
Requires: libX11 libX11-devel make perl pm-utils
Requires: xorg-x11-server-devel

%define desc RHEL/CentOS in-guest tools for Citrix XenClient XT.

%include description.inc

%prep
%setup -q -c
%setup -q -T -D -a 1

%build
rm -rf etc/init.d
mkdir -p etc/rc.d/init.d
mkdir -p etc/X11/xinit/xinitrc.d
mv etc/X11/Xsession.d/95root_access etc/X11/xinit/xinitrc.d
mv centos/xenstore-agent centos/xblanker etc/rc.d/init.d
rmdir centos

rm -r usr/share

mkdir -p etc/dracut.conf.d
cat <<EOF > etc/dracut.conf.d/xc-tools
add_drivers+="xc-v4v"
EOF

%install
mkdir -p %{buildroot}
cp -r * %{buildroot}

%clean
rm -rf %{buildroot}

%files
/etc/dracut.conf.d/xc-tools
/etc/X11/xinit/xinitrc.d/95root_access
/lib/udev/rules.d
/usr/src
%config %attr(755, -, -) /etc/rc.d/init.d/xblanker
%config %attr(755, -, -) /etc/rc.d/init.d/xenstore-agent


%post
%include xc-tools-postinst.inc

%preun
%include xc-tools-prerm.inc

%postun
%include xc-tools-postrm.inc
