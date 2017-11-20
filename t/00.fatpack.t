use strict;
use warnings;

use Test::More;

my $name = 'bin/fatpack-maint-build.pl';

ok +(-e $name and -r _), 'script exists'; # EUMM makes it executable

is system($^X, '-c', $name), 0, 'script compiles';

done_testing;
