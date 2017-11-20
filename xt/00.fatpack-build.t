use strict;
use warnings;

use Test::More;

my $name = 'fatpack-maint-build.pl';

ok +(-e $name and -r _ and -x _), "script ($name) exists";

is system($^X, '-c', $name), 0, "script ($name) compiles";

done_testing;
