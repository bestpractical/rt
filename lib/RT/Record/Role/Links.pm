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

use strict;
use warnings;

package RT::Record::Role::Links;
use Role::Basic;

=head1 NAME

RT::Record::Role::Links - Common methods for records which handle links

=head1 REQUIRES

=head2 L<RT::Record::Role>

=head2 _AddLink

Usually provided by L<RT::Record/_AddLink>.

=head2 _DeleteLink

Usually provided by L<RT::Record/_DeleteLink>.

=head2 ModifyLinkRight

The right name to check in L<AddLink> and L<DeleteLink>.

=head2 CurrentUserHasRight

=cut

with 'RT::Record::Role';

requires '_AddLink';
requires '_DeleteLink';

requires 'ModifyLinkRight';
requires 'CurrentUserHasRight';

=head1 PROVIDES

=head2 _AddLinksOnCreate

Calls _AddLink (usually L<RT::Record/_AddLink>) for all valid link types and
aliases found in the hash.  Refer to L<RT::Link/%TYPEMAP> for details of link
types.  Key values may be a single URI or an arrayref of URIs.

Takes two hashrefs.  The first is the argument hash provided to the consuming
class's Create method.  The second is optional and contains extra arguments to
pass to _AddLink.

By default records a transaction on the link's destination object (if any), but
not on the origin object.

Returns an array of localized error messages, if any.

=cut

sub _AddLinksOnCreate {
    my $self    = shift;
    my %args    = %{shift || {}};
    my %AddLink = %{shift || {}};
    my @results;

    foreach my $type ( keys %RT::Link::TYPEMAP ) {
        next unless defined $args{$type};

        my $links = $args{$type};
           $links = [$links] unless ref $links;

        for my $link (@$links) {
            my $typemap       = $RT::Link::TYPEMAP{$type};
            my $opposite_mode = $typemap->{Mode} eq "Base" ? "Target" : "Base";
            my ($ok, $msg) = $self->_AddLink(
                Type                    => $typemap->{Type},
                $typemap->{Mode}        => $link,
                "Silent$opposite_mode"  => 1,
                %AddLink,
            );
            push @results,
                 $self->loc("Unable to add [_1] link: [_2]", $self->loc($type), $msg)
                     unless $ok;
        }
    }
    return @results;
}

=head2 AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this
record.

Refer to L<RT::Record/_AddLink> for full documentation.  This method implements
permissions and ticket validity checks before calling into L<RT::Record>
(usually).

=cut

sub AddLink {
    my $self = shift;

    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserHasRight($self->ModifyLinkRight);

    return $self->_AddLink(@_);
}

=head2 DeleteLink

Takes a paramhash of Type and one of Base or Target. Removes that link from the
record.

Refer to L<RT::Record/_DeleteLink> for full documentation.  This method
implements permission checks before calling into L<RT::Record> (usually).

=cut

sub DeleteLink {
    my $self = shift;

    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserHasRight($self->ModifyLinkRight);

    return $self->_DeleteLink(@_);
}

1;
