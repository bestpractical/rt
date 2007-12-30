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

  RT::Model::AttributeCollection - collection of RT::Model::Attribute objects

=head1 SYNOPSIS

  use RT::Model::AttributeCollection;
my $Attributes = RT::Model::AttributeCollection->new($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=cut


use strict;
use warnings;
package RT::Model::AttributeCollection;
use base qw'RT::SearchBuilder';


sub _do_search {
    my $self = shift;
    $self->SUPER::_do_search();
    $self->{'must_redo_search'} = 0;
    $self->_build_access_table();
}


sub _build_access_table {
    my $self = shift;
    delete $self->{'attr'};
    while (my $attr = $self->next) {
        push @{$self->{'attr'}->{$attr->name}}, $attr;
    }
}


sub _attr_hash {
    my $self = shift;
    $self->_do_search if ($self->{'must_redo_search'});
    unless ($self->{'attr'}) {
        $self->{'attr'}->{'__none'} = RT::Model::Attribute->new;
    }
    return ($self->{'attr'});
}

=head2 names

Returns a list of the names of all attributes for this object. 

=cut

sub names {
    my $self = shift;
    my @keys =  keys %{$self->_attr_hash};
    return(@keys);


}

=head2 named STRING

Returns an array of all the RT::Model::Attribute objects with the name STRING

=cut

sub named {
    my $self = shift;
    my $name = shift;
    my @attributes; 
    if ($self->_attr_hash) {
        @attributes = @{($self->_attr_hash->{$name}||[])};
    }
    return (@attributes);   
}

=head2 with_id ID

Returns the RT::Model::Attribute objects with the id ID

XXX TODO XXX THIS NEEDS A BETTER ACL CHECK

=cut

sub with_id {
    my $self = shift;
    my $id = shift;

    my $attr = RT::Model::Attribute->new;
    $attr->load_by_cols( id => $id );
    return($attr);
}

=head2 delete_entry { name =>   Content => , id => }

Deletes attributes with
    the matching name 
 and the matching content or id

If Content and id are both undefined, delete all attributes with
the matching name.

=cut


sub delete_entry {
    my $self = shift;
    my %args = (
        name    => undef,
        Content => undef,
        id      => undef,
        @_
    );
    my $found = 0;
    foreach my $attr ( $self->named( $args{'name'} ) ) {
        if ( ( !defined $args{'id'} and !defined $args{'Content'} )
             or ( defined $args{'id'} and $attr->id eq $args{'id'} )
             or ( defined $args{'Content'} and $attr->Content eq $args{'Content'} ) )
        {
            my ($id, $msg) = $attr->delete;
            return ($id, $msg) unless $id;
            $found = 1;
        }
    }
    return (0, "No entry found") unless $found;
    $self->redo_search;
    # XXX: above string must work but because of bug in DBIx::SB it doesn't,
    # to reproduce delete string below and run t/api/attribute-tests.t
    $self->_do_search;
    return (1, _('Attribute Deleted'));
}


# {{{ limit_to_object 

=head2 limit_to_object $object

Limit the Attributes to rights for the object $object. It needs to be an RT::Record class.

=cut

sub limit_to_object {
    my $self = shift;
    my $obj = shift;
    unless (defined($obj) && ref($obj) && UNIVERSAL::can($obj, 'id') && $obj->id) {
    return undef;
    }
    $self->limit(column => 'object_type', operator=> '=', value => ref($obj), entry_aggregator => 'OR');
    $self->limit(column => 'object_id', operator=> '=', value => $obj->id, entry_aggregator => 'OR', quote_value => 0);

}

# }}}

1;
