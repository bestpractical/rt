# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::Attributes - collection of RT::Attribute objects

=head1 SYNOPSIS

  use RT:Attributes;
my $Attributes = new RT::Attributes($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok(require RT::Attributes);

=end testing

=cut

use strict;
no warnings qw(redefine);


=head2 Next

Hand out the next Attribute that was found

=cut


# {{{ LimitToObject 

=head2 LimitToObject $object

Limit the Attributes to rights for the object $object. It needs to be an RT::Record class.

=cut

sub LimitToObject {
    my $self = shift;
    my $obj = shift;
    unless (defined($obj) && ref($obj) && UNIVERSAL::can($obj, 'id')) {
    return undef;
    }
    $self->Limit(FIELD => 'ObjectType', OPERATOR=> '=', VALUE => ref($obj), ENTRYAGGREGATOR => 'OR');
    $self->Limit(FIELD => 'ObjectId', OPERATOR=> '=', VALUE => $obj->id, ENTRYAGGREGATOR => 'OR', QUOTEVALUE => 0);

}

# }}}

1;
