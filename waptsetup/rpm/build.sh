#!/usr/bin/env bash

set -ex

rm -Rf rpmbuild
mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

cp waptdeploy.exe rpmbuild/SOURCES
cp waptsetup.exe rpmbuild/SOURCES

cp waptsetup.spec rpmbuild/SPECS

(cd rpmbuild && rpmbuild -bb -v --clean --define "_topdir $(pwd)" SPECS/waptsetup.spec)
