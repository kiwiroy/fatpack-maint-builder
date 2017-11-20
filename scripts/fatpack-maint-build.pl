#!/usr/bin/env perl

# DEVELOPERS: something
# __FATPACK__

use App::FatPacker;
use Applify;
use Mojo::Asset::Memory;
use Mojo::Base -base;
use Mojo::Collection 'c';
use Mojo::File;
use Mojo::Home;

documentation $0;

extends 'Mojo::Base';

has fatpacker => sub { App::FatPacker->new };

sub fatpack_script {
  my $self = shift;
  my ($script, $target, $shebang_replace) = @_;

  my $pack = $self->fatpacker;
  my @modules = split /\r?\n/, $pack->trace(args => [ $script ]);
  my @packlists = $pack->packlists_containing(\@modules);

  my $base = Mojo::Home->new->detect->to_abs->child('fatlib');
  $pack->packlists_to_tree($base, \@packlists);

  my $asset = Mojo::Asset::Memory->new(max_memory_size => 2e7);

  my $packed = $pack->fatpack_file();
  my $lines = c(split /\r?\n/, Mojo::File->new($script)->slurp)->map(sub {
    s|^#!/usr/bin/env perl|$shebang_replace| if $shebang_replace;
    s/^#.*DEVELOPERS:.*/# DO NOT EDIT -- this is an auto generated file/;
    s/^#.*__FATPACK__/$packed/;
    $_;
  });

  $asset->add_chunk($lines->join("\n")->to_string)->move_to($target);

  $base->remove_tree();
}

has includes => sub { Mojo::Home->new->detect->to_abs->child('lib') };

option file => source => 'path to source script', (
    required => 1, isa => 'Mojo::File');
option file => target => 'path to target script', (
    required => 1, isa => 'Mojo::File');

app {
  my $self = shift;

  $ENV{PERL5OPT} = '-I'.$self->includes;
  say $ENV{PERL5OPT};
  unlink $self->target;

  $self->fatpack_script($self->source, $self->target, '#!/usr/bin/perl');

  chmod 0755, $self->target;

  return 0;
};

=pod

=head1 NAME

fatpack-maint-build.pl

=head1 DESCRIPTION

=head1 SYNOPSIS

fatpack-maint-build.pl -source scripts/script.pl -target script.pl

=head1 SEE ALSO

=over 4

=item L<App::FatPacker>

=back

=cut
