# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

=head1 NAME

RT::SavedSearch - an API for saving and retrieving search form values.

=head1 SYNOPSIS

  use RT::SavedSearch

=head1 DESCRIPTION

SavedSearch is an object based on L<RT::SharedSetting> that can belong
to either an L<RT::User> or an L<RT::Group>. It consists of an ID,
a description, and a number of search parameters.

=cut

package RT::SavedSearch;

use strict;
use warnings;
use base qw/RT::SharedSetting/;

=head1 METHODS

=head2 ObjectName

An object of this class is called "search"

=cut

sub ObjectName { "search" }

sub PostLoad {
    my $self = shift;
    $self->{'Type'} = $self->{'Attribute'}->SubValue('SearchType');
}

sub SaveAttribute {
    my $self   = shift;
    my $object = shift;
    my $args   = shift;

    my $params = $args->{'SearchParams'};

    $params->{'SearchType'} = $args->{'Type'} || 'Ticket';

    return $object->AddAttribute(
        'Name'        => 'SavedSearch',
        'Description' => $args->{'Name'},
        'Content'     => $params,
    );
}


sub UpdateAttribute {
    my $self = shift;
    my $args = shift;
    my $params = $args->{'SearchParams'} || {};

    my ($status, $msg) = $self->{'Attribute'}->SetSubValues(%$params);

    if ($status && $args->{'Name'}) {
        ($status, $msg) = $self->{'Attribute'}->SetDescription($args->{'Name'});
    }

    return ($status, $msg);
}

=head2 Type

Returns the type of this search, e.g. 'Ticket'.  Useful for denoting the
saved searches that are relevant to a particular search page.

=cut

sub Type {
    my $self = shift;
    return $self->{'Type'};
}

eval "require RT::SavedSearch_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SavedSearch_Vendor.pm});
eval "require RT::SavedSearch_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SavedSearch_Local.pm});

1;
