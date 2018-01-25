use strict;
use warnings;

use Test::More;
use Test::Applify;
use Mojo::File qw{tempfile};
use Mojo::Loader qw{data_section};
use Symbol 'delete_package';

my $name = 'fatpack-maint-build.pl';

ok +(-e $name and -r _ and -x _), "script ($name) exists";

is system($^X, '-c', $name), 0, "script ($name) compiles";

my $source = tempfile('simple-source-XXXXX', SUFFIX => '.pl');
my $target = tempfile('simple-target-XXXXX', SUFFIX => '.pl', UNLINK => 1);
$source->spurt(data_section __PACKAGE__, 'simple.pl');

#
# first test original
#
my $t = new_ok('Test::Applify', ["./scripts/$name"]);
$t->version_ok('1.1')
  ->documentation_ok
  ->is_required_option('source')
  ->is_required_option('target')
  ->is_option('verbose');

my $app = $t->app_instance('-source', $source, '-target', $target);

isa_ok $app->fatpacker, 'App::FatPacker';
is $app->__require('Test/Applify.pm'), 0, 'test __require - this is not fatpacked';

my ($retval, $stdout, $stderr, $exited) = $t->run_instance_ok($app);
is $retval, 0, 'success';
is $stderr, '', 'empty';
is $stdout, '', 'empty';
is $exited, 0, 'success';

like $target->slurp, qr/END OF FATPACK CODE/m, 'fatpack included';

#
# complex
#
$source = tempfile('complex-source-XXXXX', SUFFIX => '.pl');
$target = tempfile('complex-target-XXXXX', SUFFIX => '.pl', UNLINK => 1);
$source->spurt(data_section __PACKAGE__, 'complex.pl');
$app = $t->app_instance('-source', $source, '-target', $target, '-verbose');

($retval, $stdout, $stderr, $exited) = $t->run_instance_ok($app);
is $retval, 0, 'success';
is $stderr, '', 'empty';
like $stdout, qr/^Found\s(\d+)\smodules$/m, 'verbose';
like $stdout, qr/^Found\s(\d+)\spacklists$/m, 'verbose';
like $stdout, qr/^wrote:/m, 'verbose';
is $exited, 0, 'success';

## TODO: discern what __require is set to achieve.
if (0) {
  my $module = 'Applify';
  (my $filename = $module) =~ s{::}{/}g; $filename .= '.pm';
  my $file = Mojo::File->new($INC{$filename});
  my $files = { $filename => $file->slurp };
  my $code = $app->fatpacker->fatpack_code($files);
  delete_package $module;
  # delete $INC{$filename};
  eval $code;
  is $app->__require($filename), 0, 'test __require - this is not fatpacked';
}

like $target->slurp, qr/END OF FATPACK CODE/m, 'fatpack included';

done_testing;

__DATA__
@@ simple.pl
#!/usr/bin/perl

# __FATPACK__

use Applify;

app { warn "Hello World."; return 0; };
@@ complex.pl
#!/usr/bin/perl

# __FATPACK__

use Applify;
use HTML::TagSet;
app { warn "Hello World."; return 0; };
