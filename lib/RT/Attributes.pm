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

=head1 NAME

RT::Attributes - collection of RT::Attribute objects

=head1 SYNOPSIS

    use RT::Attributes;
    my $Attributes = RT::Attributes->new($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=cut


package RT::Attributes;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::Attribute;

sub Table { 'Attributes'}


sub _DoSearch {
    my $self = shift;
    $self->SUPER::_DoSearch();
# if _DoSearch doesn't fully succeed, 'must_redo_search' will be true
# and call _BuildAccessTable then will result in a deep recursion
    if ( $self->{'must_redo_search'} ) {
        $RT::Logger->crit(
"_DoSearch is not so successful as it still needs redo search, won't call _BuildAccessTable"
        );
    }
    else {
        $self->_BuildAccessTable();
    }
}


sub _BuildAccessTable {
    my $self = shift;
    delete $self->{'attr'};
    while (my $attr = $self->Next) {
        push @{$self->{'attr'}->{$attr->Name}}, $attr;
    }
}


sub _AttrHash {
    my $self = shift;
    $self->_DoSearch if ($self->{'must_redo_search'} && $self->{'is_limited'});
    unless ($self->{'attr'}) {
        $self->{'attr'}->{'__none'} = RT::Attribute->new($self->CurrentUser);
    }
    return ($self->{'attr'});
}

=head2 Names

Returns a list of the Names of all attributes for this object. 

=cut

sub Names {
    my $self = shift;
    my @keys =  keys %{$self->_AttrHash};
    return(@keys);


}

=head2 Named STRING

Returns an array of all the RT::Attribute objects with the name STRING

=cut

sub Named {
    my $self = shift;
    my $name = shift;
    my @attributes; 
    if ($self->_AttrHash) {
        @attributes = @{($self->_AttrHash->{$name}||[])};
    }
    return (@attributes);   
}

=head2 DeleteEntry { Name =>   Content => , id => }

Deletes attributes with
    the matching name 
 and the matching content or id

If Content and id are both undefined, delete all attributes with
the matching name.

=cut


sub DeleteEntry {
    my $self = shift;
    my %args = (
        Name    => undef,
        Content => undef,
        id      => undef,
        @_
    );
    my $found = 0;
    foreach my $attr ( $self->Named( $args{'Name'} ) ) {
        if ( ( !defined $args{'id'} and !defined $args{'Content'} )
             or ( defined $args{'id'} and $attr->id eq $args{'id'} )
             or ( defined $args{'Content'} and $attr->Content eq $args{'Content'} ) )
        {
            my ($id, $msg) = $attr->Delete;
            return ($id, $msg) unless $id;
            $found = 1;
        }
    }
    return (0, "No entry found") unless $found;
    $self->RedoSearch;
    # XXX: above string must work but because of bug in DBIx::SB it doesn't,
    # to reproduce delete string below and run t/api/attribute-tests.t
    $self->_DoSearch;
    return (1, $self->loc('Attribute Deleted'));
}



=head2 LimitToObject $object

Limit the Attributes to rights for the object $object. It needs to be an RT::Record class.

=cut

sub LimitToObject {
    my $self = shift;
    my $obj = shift;
    unless (eval { $obj->id} ){
        return undef;
    }

    my $type = $obj->isa("RT::CurrentUser") ? "RT::User" : ref($obj);

    $self->Limit(FIELD => 'ObjectType', OPERATOR=> '=', VALUE => $type, ENTRYAGGREGATOR => 'OR');
    $self->Limit(FIELD => 'ObjectId', OPERATOR=> '=', VALUE => $obj->id, ENTRYAGGREGATOR => 'OR', QUOTEVALUE => 0);

}

RT::Base->_ImportOverlays();

1;
