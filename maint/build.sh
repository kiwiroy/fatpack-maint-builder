#!/bin/sh

export PERL5OPT='-I./lib'

./scripts/fatpack-maint-build.pl \
    -source ./scripts/fatpack-maint-build.pl \
    -target ./fatpack-maint-build.pl
