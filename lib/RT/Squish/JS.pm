# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 SYNOPSIS

  use RT::Squish::JS;
  my $squish = RT::Squish::JS->new(
    Name  => 'head',
    Files => ['...'],
  );

=head1 DESCRIPTION

This module lets you create squished content of js files.

=head1 METHODS

=cut

use strict;
use warnings;

package RT::Squish::JS;
use base 'RT::Squish';
use List::MoreUtils 'uniq';

=head2 SquishFiles

not just concatenate files, but also minify them

=cut

sub SquishFiles {
    my $self    = shift;
    my $content;

    for my $file ( @{ $self->Files } ) {
        $content .= $HTML::Mason::Commands::m->scomp($file);
    }

    return $self->Filter($content);
}

=head2 UpdateFilesMap

name => files map

this is mainly for plugins, e.g.

to add extra css files for style 'aileron', you can add the following line
in the plugin's main file:

    require RT::Squish::JS;
    RT::Squish::JS->UpdateFilesMap( aileron => ['/NoAuth/js/foo.js'] ); 

=cut

my %FILES_MAP;

sub UpdateFilesMap {
    my $self = shift;
    my %args = @_;

    for my $name ( keys %args ) {
        next unless $name;
        my $files = $args{$name};
        $FILES_MAP{$name} ||= [];
        push @{ $FILES_MAP{$name} }, ref $files eq 'ARRAY' ? @$files : $files;
    }
    return 1;
}

=head2 UpdateFilesByName

update files by name, it'll try to find files in the following places:

1. if the name is 'head', add files in config item C<JSFilesInHead>.

2. if there is a files map for the name, add the corresponding files.

=cut

sub UpdateFilesByName {
    my $self = shift;
    my $name = $self->Name;

    if ( $name eq 'head' ) {
        $self->Files(
            [
                uniq @{ $self->Files },
                map { "/NoAuth/js/$_" } RT->Config->Get('JSFilesInHead'),
            ]
        );
    }

    if ( $FILES_MAP{$name} ) {

        $self->Files( [ uniq @{$self->Files}, @{$FILES_MAP{$name}} ] );
    }


    return 1;
}

sub Filter {
    my $self    = shift;
    my $content = shift;

    my $minified;
    my $jsmin = RT->Config->Get('JSMinPath');
    if ( $jsmin && -x $jsmin ) {
        my $input = $content;
        my ( $output, $error );

        local $SIG{'CHLD'} = 'DEFAULT';
        require IPC::Run3;
        IPC::Run3::run3( [$jsmin], \$input, \$output, \$error );
        if ( $? >> 8 ) {
            $RT::Logger->warning("failed to jsmin: $error ");
        }
        else {
            $content  = $output;
            $minified = 1;
        }
    }

    unless ($minified) {
        eval { require JavaScript::Minifier };
        if ($@) {
            $RT::Logger->debug("can't load JavaScript::Minifier: $@");
        }
        else {
            $content = JavaScript::Minifier::minify( input => $content );
        }
    }
    return $content;
}

1;

