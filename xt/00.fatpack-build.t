use strict;
use warnings;

use Test::More;
use Test::Applify;
use Mojo::File qw{tempfile};
use Mojo::Loader qw{data_section};
#use Symbol 'delete_package';

my $name = 'fatpack-maint-build.pl';

ok +(-e $name and -r _ and -x _), "script ($name) exists";

is system($^X, '-c', $name), 0, "script ($name) compiles";

my $source = tempfile('simple-source-XXXXX', SUFFIX => '.pl', UNLINK => 1);
my $target = tempfile('simple-target-XXXXX', SUFFIX => '.pl', UNLINK => 1);
$source->spurt(data_section __PACKAGE__, 'simple.pl');

#
# first test original
#
my $t = new_ok('Test::Applify', ["./scripts/$name"]);
$t->version_ok('1.2')
  ->documentation_ok
  ->is_required_option('source')
  ->is_required_option('target')
  ->is_option('verbose');

my $app = $t->app_instance('-source', $source, '-target', $target);

isa_ok $app->fatpacker, 'App::FatPacker';
my ($fatpacker) = $app->packlists_containing(['App/FatPacker.pm']);
like $fatpacker, qr{App/FatPacker/\.packlist$}, 'found';
{
  my $warning = '';
  local $SIG{__WARN__} = sub { $warning = shift; };
  my ($not_exist) = $app->packlists_containing(['ACME/Does/Not/Exist.pm']);
  is $not_exist, undef, 'not there';
  like $warning, qr/^Failed to load ACME/, 'got a warning about it';
}

is $app->__require('Test/Applify.pm'), 0,
  'test __require - this is not fatpacked';

is $app->source, $source, 'source set';
is $app->target, $target, 'target set';

my ($retval, $stdout, $stderr, $exited) = $t->run_instance_ok($app);
is $retval, 0, 'success';
is $stderr, '', 'no messages on STDERR';
is $stdout, '', 'no messages on STDOUT';
is $exited, 0, 'success';

like $target->slurp, qr/END OF FATPACK CODE/m, 'fatpack included';

is $app->fatpack_script($source, $target), 3, 'replacements';

#
# complex
#
$source = tempfile('complex-source-XXXXX', SUFFIX => '.pl');
$target = tempfile('complex-target-XXXXX', SUFFIX => '.pl');
$source->spurt(data_section __PACKAGE__, 'complex.pl');
$app = $t->app_instance('-source', $source, '-target', $target, '-verbose');

($retval, $stdout, $stderr, $exited) = $t->run_instance_ok($app);
is $retval, 0, 'success';
is $stderr, '', 'no messages on STDERR';
like $stdout, qr/^Found\s(\d+)\smodules$/m, 'verbose messages';
like $stdout, qr/^Found\s(\d+)\spacklists$/m, 'verbose messages';
like $stdout, qr/^wrote:/m, 'verbose';
diag $stdout;
is $exited, 0, 'success';

## TODO: discern what __require is set to achieve.
# if (0) {
#   my $module = 'Applify';
#   (my $filename = $module) =~ s{::}{/}g; $filename .= '.pm';
#   my $file = Mojo::File->new($INC{$filename});
#   my $files = { $filename => $file->slurp };
#   my $code = $app->fatpacker->fatpack_code($files);
#   delete_package $module;
#   # delete $INC{$filename};
#   eval $code;
#   is $app->__require($filename), 0, 'test __require - this is not fatpacked';
# }

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
