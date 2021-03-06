#!/usr/bin/env perl

# DEVELOPERS: Read maint/build.sh in the repo how to update this
# __FATPACK__
package FatPack::Maint::Build;

use App::FatPacker ();
use Applify;
use Cwd qw(abs_path cwd);
use File::Find qw(find);
use File::Spec::Functions qw(catdir);
use Mojo::Asset::Memory;
use Mojo::Base -base;
use Mojo::Collection 'c';
use Mojo::File ();
use Mojo::Home;
use Mojo::Loader 'find_modules';

our $VERSION = '1.2'; # bump this

documentation $0;

version $VERSION;

extends 'Mojo::Base';

has fatpacker => sub { App::FatPacker->new };

my $develop_tag = qr/^#.*DEVELOPERS:.*/;
my $fatpack_tag = qr/^#.*__FATPACK__/;
my $shebang_tag = qr|^#!/usr/bin/env perl|;

sub expand_extras {
  my ($self, @result) = (shift);
  my $extras = $self->extra;
  for my $m(@$extras) {
      push @result, $m;
      push @result, find_modules($m) if $self->namespace;
  }
  return \@result;
}

sub fatpack_script {
  my $self = shift;
  my ($script, $target, $shebang_replace) = @_;
  my @replaced;

  my $pack = $self->fatpacker;
  
  my @modules = split /\r?\n/, $pack->trace(args => [ $script ], 
                                            'use' => $self->expand_extras);
  if ($self->verbose) {
    say "Found " . @modules.  " modules";
  }

  my @packlists = $self->packlists_containing(\@modules);

  if ($self->verbose) {
    say "Found " . @packlists . " packlists";
  }
  my $base = Mojo::Home->new->detect->to_abs->child('fatlib');
  $pack->packlists_to_tree($base->to_string, \@packlists);

  my $asset = Mojo::Asset::Memory->new(max_memory_size => 2e7);

  my $packed = $pack->fatpack_file();
  my $lines = c(split m/\r?\n/, Mojo::File->new($script)->slurp)
      ->tap(sub {
          splice @$_, 1, 0, '# __FATPACK__' unless $_->grep($fatpack_tag)->size;
          splice @$_, 1, 0, '# DEVELOPERS:' unless $_->grep($develop_tag)->size;
            })
      ->map(sub {
          $replaced[0] += $_ =~
              s/$shebang_tag/$shebang_replace/ if $shebang_replace;
          $replaced[1] += $_ =~ 
              s/$develop_tag/# DO NOT EDIT -- this is an auto generated file/;
          $replaced[2] += $_ =~ s/$fatpack_tag/$packed/;
    $_;
  });

  $asset->add_chunk($lines->join("\n")->to_string)->move_to($target);

  $base->remove_tree();

  return @replaced;
}

# :( re-implemented here to avoid https://git.io/vF58b and already FatPacked
# entries in %INC
sub packlists_containing {
  my ($self, $targets) = @_;
  my @targets;
  local %INC = %INC;
  {
    local @INC = ('lib', @INC);
    foreach my $t (@$targets) {
      warn "Failed to load ${t}\n" if (ref($INC{$t}) && 0 == __require($t));
      unless (eval { require $t; 1}) {
        warn "Failed to load ${t}: $@\n"
            ."Make sure you're not missing a packlist as a result\n";
        next;
      }
      push @targets, $t;
    }
  }
  my @search = grep -d $_, map catdir($_, 'auto'), @INC;
  my %pack_rev;
  find({
    no_chdir => 1,
    wanted => sub {
      return unless /[\\\/]\.packlist$/ && -f $_;
      $pack_rev{abs_path $_} = $File::Find::name for __lines_of($File::Find::name);
    },
  }, @search);
  my %found; @found{map +($pack_rev{abs_path($INC{$_})}||()), @targets} = ();
  sort keys %found;
}

# like perldoc -f require, but slimmer - only checks -e, -d and -b
sub __require {
  my ($filename) = @_;
  # uncoverable branch true
  if (exists $INC{$filename} and ref($INC{$filename})) {
    foreach my $prefix (@INC) { # uncoverable statement
      # uncoverable branch true
      if (ref($prefix)) { # uncoverable statement
        # not FatPacked entries
        next; # uncoverable statement
      }
      my $realfilename = "$prefix/$filename"; # uncoverable statement
      next if ! -e $realfilename || -d _ || -b _; # uncoverable statement
      $INC{$filename} = $realfilename; # uncoverable statement
      return 1; # uncoverable statement
    }
  }
  return 0;
}

sub __lines_of {
  map +(chomp,$_)[1], do { local @ARGV = ($_[0]); <> };
}

has includes => sub { Mojo::Home->new->detect->to_abs->child('lib') };

option str  => extra  => 'Modules to additionally use. e.g. App::Foo::Bar',
    n_of => '@';
option flag => namespace => 'Find (non-recursively) modules in each of -extra namespaces';
option flag => replace_shebang => 'Modify the shebang to use /usr/bin/perl',
    default => 0;
option file => source => 'Path to source script', (
    required => 1, isa => 'Mojo::File');
option file => target => 'Path to target script', (
    required => 1, isa => 'Mojo::File');
option flag => verbose => 'Increase level of notification', default => 0;

app {
  my $self = shift;

  $ENV{PERL5OPT} = c('-I'.$self->includes,
    ($ENV{PERL5OPT} ? $ENV{PERL5OPT} : ()))->uniq->join(' ')->to_string;
  say "PERL5OPT = $ENV{PERL5OPT}" if $self->verbose;

  $self->target->remove->dirname->make_path;
  my $shebang = $self->replace_shebang ? '#!/usr/bin/perl' : undef;
  my @replaced = $self->fatpack_script($self->source, $self->target, $shebang);

  chmod 0755, $self->target;

  if ($self->verbose and -e $self->target and -x _) {
    say "wrote: " . $self->target;
    say "filesize: ", (-s $self->target), " bytes";
    say "fatpacked: ", $replaced[2] ? 'true' : 'false';
  }

  return (-e $self->target and -x _ ? 0 : 1);
};

=pod

=head1 NAME

fatpack-maint-build.pl - fatpack a script for distribution

=begin html

<a href="https://travis-ci.org/kiwiroy/fatpack-maint-builder">
  <img src="https://travis-ci.org/kiwiroy/fatpack-maint-builder.svg?branch=master"
       alt="Travis Build Status">
</a>

<a href="https://coveralls.io/github/kiwiroy/fatpack-maint-builder?branch=master">
  <img src="https://coveralls.io/repos/github/kiwiroy/fatpack-maint-builder/badge.svg?branch=master"
       alt="Coverage Status" />
</a>

<a href="https://kritika.io/users/kiwiroy/repos/2685177578694295/heads/master/">
  <img src="https://kritika.io/users/kiwiroy/repos/2685177578694295/heads/master/status.svg"
       alt="Kritika Analysis Status" />
</a>

=end html

=head1 DESCRIPTION

An easy to use script to fatpack a script. Either copy this to your repository
C<maint> directory or install and add to your C<cpanfile> under a feature.

e.g.

  on develop => sub {
    # master
    requires 'git@github.com:kiwiroy/fatpack-maint-builder.git';
    # or release
    requires 'https://github.com/kiwiroy/fatpack-maint-builder/releases/download/v1.1/FatPack-Maint-Build-1.1.tar.gz'
  };

A simple C<build.sh> will facilitate remembering how to run it.

e.g.

  #!/bin/sh

  ./scripts/fatpack-maint-build.pl \
      -source ./scripts/fatpack-maint-build.pl \
      -target ./fatpack-maint-build.pl

=head1 SYNOPSIS

Examples:

  fatpack-maint-build.pl -help

  fatpack-maint-build.pl -source scripts/script.pl -target script.pl

=head1 DETAILS

The source script should include the string C<__FATPACK__> within a comment on a
line on it's own. This will be replaced by the fatpacked code.

The shebang line will be translated from C</usr/bin/env perl> to
C</usr/bin/perl> for inclusion in L<EUMM|ExtUtils::MakeMaker> C<EXE_FILES>,
where C<fixin()> will translate at C<make install> time.

Optionally, the string C<DEVELOPERS: ...> can exist within a comment in the
source script and will be replaced with a C<DO NOT EDIT> notice in the output
file.

=head1 SEE ALSO

=over 4

=item L<App::FatPacker>

=item L<App::cpanminus>

=item L<Applify>

=item L<Mojolicious>

=back

=cut
