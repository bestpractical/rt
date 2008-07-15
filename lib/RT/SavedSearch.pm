# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
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
# http://www.gnu.org/copyleft/gpl.html.
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

=head1 name

RT::SavedSearch - an API for saving and retrieving search form values.

=head1 SYNOPSIS

  use RT::SavedSearch

=head1 description

SavedSearch is an object based on L<RT::SharedSetting> that can belong
to either an L<RT::Model::User> or an L<RT::Model::Group>. It consists of an ID,
a description, and a number of search parameters.

=head1 METHODS


=cut

package RT::SavedSearch;
use strict;
use warnings;

use base qw/RT::SharedSetting/;

=head1 METHODS

=head2 object_name

An object of this class is called "search"

=cut

sub object_name { "search" }

sub post_load {
    my $self = shift;
    $self->{'type'} = $self->{'attribute'}->sub_value('search_type');
}

sub save_attribute {
    my $self   = shift;
    my $object = shift;
    my $args   = shift;

    my $params = $args->{'search_params'};

    $params->{'search_type'} = $args->{'type'} || 'Ticket';

    return $object->add_attribute(
        'name'        => 'saved_search',
        'description' => $args->{'name'},
        'content'     => $params,
    );
}


sub update_attribute {
    my $self = shift;
    my $args = shift;
    my $params = $args->{'search_params'} || {};

    my ($status, $msg) = $self->{'attribute'}->set_sub_values(%$params);

    if ($status && $args->{'name'}) {
        ($status, $msg) = $self->{'attribute'}->set_description($args->{'name'});
    }

    return ($status, $msg);
}

=head2 type

Returns the type of this search, e.g. 'Ticket'.  Useful for denoting the
saved searches that are relevant to a particular search page.

=cut

sub type {
    my $self = shift;
    return $self->{'type'};
}

1;
