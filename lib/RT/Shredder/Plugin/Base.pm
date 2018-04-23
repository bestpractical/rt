# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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

package RT::Shredder::Plugin::Base;

use strict;
use warnings FATAL => 'all';

=head1 NAME

RT::Shredder::Plugin::Base - base class for Shredder plugins.

=cut

sub new
{
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    return $self->_Init( @_ );
}

sub _Init
{
    my $self = shift;
    $self->{'opt'} = { @_ };
    return $self;
}

=head1 USAGE

=head2 masks

If any argument is marked with keyword C<mask> then it means
that this argument support two special characters:

1) C<*> matches any non empty sequence of the characters.
For example C<*@example.com> will match any email address in
C<example.com> domain.

2) C<?> matches exactly one character.
For example C<????> will match any string four characters long.

=head1 METHODS

=head2 for subclassing in plugins

=head3 Type - is not supported yet

See F<Todo> for more info.

=cut

sub Type { return '' }

=head3 SupportArgs

Takes nothing.
Returns list of the supported plugin arguments.

Base class returns list of the arguments which all
classes B<must> support.

=cut

sub SupportArgs { return () }

=head3 HasSupportForArgs

Takes a list of argument names. Returns true if
all arguments are supported by plugin and returns
C<(0, $msg)> in other case.

=cut

sub HasSupportForArgs
{
    my $self = shift;
    my @args = @_;
    my @unsupported = ();
    foreach my $a( @args ) {
        push @unsupported, $a unless grep $_ eq $a, $self->SupportArgs;
    }
    return( 0, "Plugin doesn't support argument(s): @unsupported" )
        if @unsupported;
    return( 1 );
}

=head3 TestArgs

Takes hash with arguments and thier values and returns true
if all values pass testing otherwise returns C<(0, $msg)>.

Stores arguments hash in C<$self->{'opt'}>, you can access this hash
from C<Run> method.

Method should be subclassed if plugin support non standard arguments.

=cut

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    if ( $self->{'opt'} ) {
        $self->{'opt'} = { %{$self->{'opt'}}, %args };
    } else {
        $self->{'opt'} = \%args;
    }
    return 1;
}

=head3 Run

Takes no arguments.
Executes plugin and return C<(1, @objs)> on success or
C<(0, $msg)> if error had happenned.

Method B<must> be subclassed, this class always returns error.

Method B<must> be called only after C<TestArgs> method in other
case values of the arguments are not available.

=cut

sub Run { return (0, "This is abstract plugin, you couldn't use it directly") }

=head2 utils

=head3 ConvertMaskToSQL

Takes one argument - mask with C<*> and C<?> chars and
return mask SQL chars.

=cut

sub ConvertMaskToSQL {
    my $self = shift;
    my $mask = shift || '';
    $mask =~ s/\*/%/g;
    $mask =~ s/\?/_/g;
    return $mask;
}

1;
