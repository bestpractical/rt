#$Header$
# Released under the terms of the GNU Public License

=head1 NAME

  RT::ObjectKeyword -- a keyword tied to an object in the database

=head1 SYNOPSIS

  use RT::ObjectKeyword;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in Ticket, Queue and other similar objects.


=begin testing

ok (require RT::TestHarness);
ok (require RT::ObjectKeyword);

=end testing

=head1 METHODS

=cut

package RT::ObjectKeyword;

use strict;
use vars qw(@ISA);
use RT::Record;

@ISA = qw(RT::Record);

sub _Init {
    my $self = shift;
    $self->{'table'} = "ObjectKeywords";
    $self->SUPER::_Init(@_);
}

sub _Accessible {
    my $self = shift;
    
    my %cols = (
		Keyword       => 'read/write', #link to the B<RT::Keyword>
		KeywordSelect => 'read/write', #link to the B<RT::KeywordSelect>
		ObjectType    => 'read/write', #currently only C<Ticket>
		ObjectId      => 'read/write', #link to the object specified in I<ObjectType>
	       );
    return ($self->SUPER::_Accessible( @_, %cols));
}



# TODO - post 2.0. add in _Set and _Value, so we can ACL them.  protected at another API level


=head1 NAME

 RT::ObjectKeyword - Manipulate an RT::ObjectKeyword record

=head1 SYNOPSIS

  use RT::ObjectKeyword;

  my $keyword = RT::ObjectKeyword->new($CurrentUser);
  $keyword->Create;

=head1 DESCRIPTION

An B<RT::ObjectKeyword> object associates an B<RT::Keyword> with another
object (currently only B<RT::Ticket>.

This module should B<NEVER> be called directly by client code. its API is entirely through RT ticket or other objects which can have keywords assigned.


=head1 METHODS

=over 4

=item new CURRENT_USER

Takes a single argument, an RT::CurrentUser object.  Instantiates a new
(uncreated) RT::ObjectKeyword object.

=cut

# {{{ sub Create

=item Create KEY => VALUE, ...

Takes a list of key/value pairs and creates a the object.  Returns the id of
the newly created record, or false if there was an error.

Keys are:

Keyword - link to the B<RT::Keyword>
ObjectType - currently only C<Ticket>
ObjectId - link to the object specified in I<ObjectType>

=cut


sub Create {
    my $self = shift;
    my %args = (Keyword => undef,
		KeywordSelect => undef,
		ObjectType => undef,
		ObjectId => undef,
		@_);
    
    #TODO post 2.0 ACL check
    
    return ($self->SUPER::Create( Keyword => $args{'Keyword'}, 
				  KeywordSelect => $args{'KeywordSelect'},
				  ObjectType => $args{'ObjectType'}, 
				  ObjectId => $args{'ObjectId'}))
}
# }}}

# {{{ sub KeywordObj

=item KeywordObj 

Returns an B<RT::Keyword> object of the Keyword associated with this ObjectKeyword.

=cut

sub KeywordObj {
    my $self = shift;
    my $keyword = new RT::Keyword($self->CurrentUser);
    $keyword->Load($self->Keyword);
    return ($keyword);
}
# }}}

# {{{ sub KeywordSelectObj

=item KeywordSelectObj 

Returns an B<RT::KeywordSelect> object of the KeywordSelect associated with this ObjectKeyword.

=cut

sub KeywordSelectObj {
    my $self = shift;
    my $keyword_sel = new RT::KeywordSelect($self->CurrentUser);
    $keyword_sel->Load($self->KeywordSelect);
    return ($keyword_sel);
}
# }}}

# {{{ sub KeywordRelativePath

=item KeywordRelativePath

Returns a string of the Keyword's path relative to this ObjectKeyword's KeywordSelect



=cut

sub KeywordRelativePath {
    my $self = shift;
    return($self->KeywordObj->RelativePath(
              $self->KeywordSelectObj->KeywordObj->Path));
    
}
# }}}

=back

=head1 AUTHOR

Ivan Kohler <ivan-rt@420.am>

=head1 BUGS

Yes.

=head1 SEE ALSO

L<RT::ObjectKeywords>, L<RT::Keyword>, L<RT::Keywords>, L<RT::Ticket>,
L<RT::Record>

=cut

1;

