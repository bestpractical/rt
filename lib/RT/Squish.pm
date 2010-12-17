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

  use RT::Squish;
  my $squish = RT::Squish->new(
    Name  => 'foo',
    Files => [ '/path/to/a', '/path/to/b' ],
  );

=head1 DESCRIPTION

This module lets you create squished content of files.

to add files automatically by the name, you can create method named
UpdateFilesByName in your subclass to do this, see
C<RT::Squish::CSS::UpdateFilesByName>
and C<RT::Squish::JS::UpdateFilesByName> for example.

=head1 METHODS

=cut

use strict;
use warnings;

package RT::Squish;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/Name Files Content Key ModifiedTime ModifiedTimeString/);

use Digest::MD5 'md5_hex';
use HTTP::Date;

=head2 new (ARGS)

ARGS is a hash of named parameters.  Valid parameters are:

  Name - name for this object
  Files - a reference to a list of files to be squished

=cut

sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = \%args;
    bless $self, $class;

    $self->Files( $args{Files} || [] );
    $self->UpdateFilesByName() if $self->can('UpdateFilesByName');

    my $content = $self->SquishFiles;
    $self->Content($content);
    $self->Key( md5_hex $content );
    $self->ModifiedTime( time() );
    $self->ModifiedTimeString( HTTP::Date::time2str( $self->ModifiedTime ) );
    return $self;
}

=head2 SquishFiles

default squish action is just concatenating files.
return the concatenated content.

you can subclass this method to customize the squish way.

=cut

sub SquishFiles {
    my $self  = shift;
    my $files = $self->Files;
    my $c     = '';
    local $/;
    for my $file (@$files) {
        open my $fh, '<', $file or die "can't open $file: $!";
        $c .= <$fh>;
    }

    return $c;
}

=head2 Name

this object's name, to distinguish with other objects

=head2 Files

arrayref of files to be squished.

=head2 Key

=head2 Content

squished content

=head2 Key

md5 of the squished content

=head2 ModifiedTime

created time of squished content, i.e. seconds since 00:00:00 UTC, January 1, 1970

=head2 ModifiedTimeString

created time of squished content, with HTTP::Date format

=cut

1;

