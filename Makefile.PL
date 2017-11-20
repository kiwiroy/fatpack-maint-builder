use strict;
use warnings;

use ExtUtils::MakeMaker;
require ExtUtils::Manifest;

# perl Makefile.PL (from git repo) copies 'fatpack-maint-build.pl' -> 'bin/fatpack-maint-build.pl'

if (-e 'fatpack-maint-build.pl') {
    for my $file ("bin/fatpack-maint-build.pl") {
        print STDERR "Generating $file from fatpack-maint-build.pl\n";
        open my $in,  "<fatpack-maint-build.pl" or die $!;
        open my $out, ">$file" or die $!;
        while (<$in>) {
            s|^#!/usr/bin/env perl|#!perl|; # so MakeMaker can fix it
            print $out $_;
        }
    }
}

WriteMakefile(
  NAME => 'FatPack::Maint::Build',
  AUTHOR => 'Roy Storey <kiwiroy@cpan.org>',
  LICENSE => 'artistic_2',
  ABSTRACT => 'fatpack a script for distribution',
  VERSION => '0.1',
  EXE_FILES => [qw(bin/fatpack-maint-build.pl)],
  META_MERGE => {
    resources => {
      bugtracker => 'https://github.com/kiwiroy/fatpack-maint-build/issues',
      homepage => 'https://github.com/kiwiroy/fatpack-maint-build',
      repository => 'https://github.com/kiwiroy/fatpack-maint-build.git',
    },
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.90'
  }
  ,
  PREREQ_PM => {}
  ,
  test => {TESTS => (-e 'META.yml' ? 't/*.t' : 't/*.t xt/*.t')},
  dist => { ($^O eq 'darwin' ? (TAR => 'gnutar') : ())}
);
