#$Header$

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
  shift->SUPER::_Accessible ( @_,
    Keyword     => 'read/write', #link to the B<RT::Keyword>
    ObjectType  => 'read/write', #currently only C<Ticket>
    ObjectId    => 'read/write', #link to the object specified in I<ObjectType>
  );
}

=head1 NAME

 RT::ObjectKeyword - Manipulate an RT::ObjectKeyword record

=head1 SYNOPSIS

  use RT::ObjectKeyword;

  my $keyword = RT::ObjectKeyword->new($CurrentUser);
  $keyword->Create;

=head1 DESCRIPTION

An B<RT::ObjectKeyword> object associates an B<RT::Keyword> with another
object (currently only B<RT::Ticket>

=head1 METHODS

=over 4

=item new CURRENT_USER

Takes a single argument, an RT::CurrentUser object.  Instantiates a new
(uncreated) RT::ObjectKeyword object.

=item Create KEY => VALUE, ...

Takes a list of key/value pairs and creates a the object.  Returns the id of
the newly created record, or false if there was an error.

Keys are:

Keyword - link to the B<RT::Keyword>
ObjectType - currently only C<Ticket>
ObjectId - link to the object specified in I<ObjectType>

=cut

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

