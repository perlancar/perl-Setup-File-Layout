package Setup::File::Layout;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
#use Log::Any::IfLOG '$log';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       setup_files_using_layout
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Setup files using a layout',
};

$SPEC{setup_files_using_layout} = {
    v => 1.1,
    summary => 'Setup files using layout',
    description => <<'_',

For more details on the format of the layout, see `File::Create::Layout`.

_
    args => {
        layout => {
            summary => 'Layout',
            schema => 'str*',
            req => 1,
            pos => 0,
        },
        prefix => {
            summary => 'Starting path to create the layout in',
            schema => 'str*',
            req    => 1,
            pos    => 1,
        },
    },
    features => {
        tx => {v=>2},
        idempotent => 1,
    },
};
sub setup_files_using_layout {
    require Cwd;
    require File::Create::Layout;
    require Perinci::Tx::Util;
    require Setup::File;
    require Setup::File::Symlink;

    my %args = @_;

    my $prefix = $args{prefix} or return [400, "Please specify prefix"];
    my $parse_res = File::Create::Layout::parse_layout(layout => $args{layout});
    return $parse_res unless $parse_res->[0] == 200;

    my @actions;

    my @dirs;
    for my $e (@{ $parse_res->[2] }) {

        $dirs[$e->{level}] = $e->{name} if $e->{is_dir};
        splice @dirs, $e->{level}+1;

        my $p = $prefix . join("", map {"/$_"} @dirs);

        if ($e->{is_dir}) {
            push @actions, ["Setup::File::setup_dir" => {
                should_exist => 1,
                path  => $p,
                # allow_symlink => 1, # XXX customizable
                mode  => $e->{perm},
                owner => $e->{user},
                group => $e->{group},
            }];
        } elsif ($e->{is_symlink}) {
            push @actions, ["Setup::File::Symlink::setup_symlink" => {
                symlink => abs_path($p) . "/$e->{name}",
                target  => $e->{symlink_target},
                #mode    => $e->{perm},
                #owner   => $e->{user},
                #group   => $e->{group},
            }];
        } else {
            push @actions, ["Setup::File::setup_file" => {
                should_exist => 1,
                path  => "$p/$e->{name}",
                mode  => $e->{perm},
                owner => $e->{user},
                group => $e->{group},
                (content => $e->{content}) x !!(defined $e->{content}),
            }];
        }
    }

    Perinci::Tx::Util::use_other_actions(actions => \@actions);
}

1;
# ABSTRACT: Setup files using layout

=head1 SYNOPSIS


=head1 SEE ALSO

L<Setup>

L<File::Create::Layout>
