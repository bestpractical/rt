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

package RT::Shredder::Plugin::Base::Search;

use strict;
use warnings FATAL => 'all';

use base qw(RT::Shredder::Plugin::Base);

=head1 NAME

RT::Shredder::Plugin::Base - base class for Shredder plugins.

=cut

sub Type { return 'search' }

=head1 ARGUMENTS

Arguments which all plugins support.

=head2 limit - unsigned integer

Allow you to limit search results. B<< Default value is C<10> >>.

=head1 METHODS

=cut

sub SupportArgs
{
    my %seen;
    my @args = sort
        grep $_ && !$seen{$_},
            shift->SUPER::SupportArgs(@_),
            qw(limit);
    return @args;
}

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    if( defined $args{'limit'} && $args{'limit'} ne '' ) {
        my $limit = $args{'limit'};
        $limit =~ s/[^0-9]//g;
        unless( $args{'limit'} eq $limit ) {
            return( 0, "'limit' should be an unsigned integer");
        }
        $args{'limit'} = $limit;
    } else {
        $args{'limit'} = 10;
    }
    return $self->SUPER::TestArgs( %args );
}

sub SetResolvers { return 1 }


=head2 FetchNext $collection [, $init]

Returns next object in collection as method L<RT::SearchBuilder/Next>, but
doesn't stop on page boundaries.

When method is called with true C<$init> arg it enables pages on collection
and selects first page.

Main purpose of this method is to avoid loading of whole collection into
memory as RT does by default when pager is not used. This method init paging
on the collection, but doesn't stop when reach page end.

Example:

    $plugin->FetchNext( $tickets, 'init' );
    while( my $ticket = $plugin->FetchNext( $tickets ) ) {
        ...
    }

=cut

use constant PAGE_SIZE => 100;
sub FetchNext {
    my ($self, $objs, $init) = @_;
    if ( $init ) {
        $objs->RowsPerPage( PAGE_SIZE );
        $objs->FirstPage;
        return;
    }

    my $obj = $objs->Next;
    return $obj if $obj;
    $objs->NextPage;
    return $objs->Next;
}

1;

