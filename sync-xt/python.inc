# Common section of RPM spec file for building python code.

BuildRequires: python

%define source0_name %(basename %{SOURCE0} .tar.gz)

%prep
%setup -q -n %{source0_name}
%{?SOURCE1:%setup -q -n %(basename %{SOURCE1} .tar.gz) -T -D -b 1}

%build
cd ../%{source0_name}
VERSION=%{version} python setup.py build

%install
# If PYTHONDONTWRITEBYTECODE is set in the environment, setup.py won't compile
# the source files. The --optimize 1 flag ensures that .pyo files are generated
# and included in INSTALLED_FILES.
unset PYTHONDONTWRITEBYTECODE
cd ../%{source0_name}
VERSION=%{version} python setup.py install --optimize 1 \
                                           --root=%{buildroot} \
                                           --record=INSTALLED_FILES

%clean
rm -rf %{buildroot}

%files -f ../%{source0_name}/INSTALLED_FILES
