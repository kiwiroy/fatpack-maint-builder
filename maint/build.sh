#!/bin/sh

./scripts/fatpack-maint-build.pl \
    -source ./scripts/fatpack-maint-build.pl \
    -target ./fatpack-maint-build.pl

cat - <<BUILD_INFO

# **************
perl Makefile.PL
make manifest
make test
make dist

# remember git clean
BUILD_INFO
