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

package RT::Shredder::Plugin::Objects;

use strict;
use warnings FATAL => 'all';
use base qw(RT::Shredder::Plugin::Base::Search);

use RT::Shredder;

=head1 NAME

RT::Shredder::Plugin::Objects - search plugin for wiping any selected object.

=head1 ARGUMENTS

This plugin searches an RT object you want, so you can use
the object name as argument and id as value, for example if
you want select ticket #123 then from CLI you write next
command:

  rt-shredder --plugin 'Objects=Ticket,123'

=cut

sub SupportArgs
{
    return $_[0]->SUPER::SupportArgs, @RT::Shredder::SUPPORTED_OBJECTS;
}

sub TestArgs
{
    my $self = shift;
    my %args = @_;

    my @strings;
    foreach my $name( @RT::Shredder::SUPPORTED_OBJECTS ) {
        next unless $args{$name};

        my $list = $args{$name};
        $list = [$list] unless UNIVERSAL::isa( $list, 'ARRAY' );
        push @strings, map "RT::$name\-$_", @$list;
    }

    my @objs = RT::Shredder->CastObjectsToRecords( Objects => \@strings );

    my @res = $self->SUPER::TestArgs( %args );

    $self->{'opt'}->{'objects'} = \@objs;

    return (@res);
}

sub Run
{
    my $self = shift;
    my %args = ( Shredder => undef, @_ );
    return (1, @{$self->{'opt'}->{'objects'}});
}

1;
