#$Header$

package RT::KeywordSelect;

use strict;
use vars qw(@ISA);
use RT::Record;
use RT::Keyword;

@ISA = qw(RT::Record);

sub _Init {
    my $self = shift;
    $self->{'table'} = "KeywordSelects";
    $self->SUPER::_Init(@_);
}

sub _Accessible {
    shift->SUPER::_Accessible( @_,
      Parent => 'read/write', # link to Keywords.  Can be specified by id or Name.,
      Single => 'read/write', # bool (described below)
      Generations => 'read/write', #- If non-zero, limits the descendents to this number of levels deep.
      ObjectType  => 'read/write', # currently only C<Ticket>
      ObjectField => 'read/write', #optional, currently only C<Queue>
      ObjectValue => 'read/write', #constrains KeywordSelect function to when B<ObjectType>.I<ObjectField> equals I<ObjectValue>
  );
}

=head1 NAME

 RT::KeywordSelect - Manipulate an RT::KeywordSelect record

=head1 SYNOPSIS

  use RT::KeywordSelect;

  my $keyword_select = RT::KeywordSelect->new($CurrentUser);
  $keyword_select->Create(
    Parent     => 20,
    ObjectType => 'Ticket',
  );

  my $keyword_select = RT::KeywordSelect->new($CurrentUser);
  $keyword_select->Create(
    Parent      => 20,
    ObjectType  => 'Ticket',
    ObjectField => 'Queue',
    ObjectValue => 1,
    Single      => 1,
    Generations => 4,
  );

=head1 DESCRIPTION

An B<RT::KeywordSelect> object is a link between a Keyword and a object
type (one of: Ticket), titled by the I<Name> field of the B<RT::Keyword> such
that:

- Object display will contain a field, titled with the I<Name> field of the
B<RT::Keyword> and showing any descendent keywords which are related to this
object via the B<RT::ObjectKeywords> table.

- Object creation for this object will contain a field titled with the
I<Name> field of the B<RT::Keyword> and containing the descendents of the
B<RT::Keyword> as choices.  If the I<Single> field of this
B<RT::KeywordSelect> is true, each object must be associated (via an
B<RT::ObjectKeywords> record) to a single descendent.  If the I<Single>
field is false, each object may be connect to zero, one, or many descendents.

- Searches for this object type will contain a selection field titled with
the I<Name> field of the B<RT::Keyword> and containing the descendents of the
B<RT::Keyword> as choices.

-If I<ObjectField> is defined (one of: Queue), all of the above apply only when
 the value of I<ObjectField> (Queue) in B<ObjectType> (Ticket) matches
 I<ObjectValue>.

=head1 METHODS

=over 4

=item new CURRENT_USER

Takes a single argument, an RT::CurrentUser object.  Instantiates a new
(uncreated) RT::KeywordSelect object.

=item Create KEY => VALUE, ...

Takes a list of key/value pairs and creates a the object.  Returns the id of
the newly created record, or false if there was an error.

Keys are:

Parent - link to Keywords.  Can be specified by id or Name.
Single - bool (described above)
Generations - If non-zero, limits the descendents to this number of levels deep.
ObjectType - currently only C<Ticket>
ObjectField - optional, currently only C<Queue>
ObjectValue - constrains KeywordSelect function to when B<ObjectType>.I<ObjectField> equals I<ObjectValue>

=cut

sub Create {
    my $self = shift;
    my %hash = @_;
    if ( $hash{Parent} && $hash{Parent} !~ /^\d+$/ ) {
	#TODO +++ never die in core code. return failure.
	die "not yet";
    }
    return($self->SUPER::Create(%hash));
}

=item KeywordObj

Returns the B<RT::Keyword> referenced by the I<Parent> field.

=cut

sub KeywordObj {
    my $self = shift;

    my $Keyword = new RT::Keyword($self->CurrentUser);
    $Keyword->Load( $self->Parent ); #or ?
    return($Keyword);
} 

=item Object

Returns the object (currently only RT::Queue) specified by ObjectField and ObjectValue.

=cut

sub Object {
    my $self = shift;
    if ( $self->ObjectField eq 'Queue' ) {
	my $Queue = new RT::Queue($self->CurrentUser);
	$Queue->Load( $self->ObjectValue );
	return ($Queue);
    } else {
	return (undef);
    }
}

=back

=head1 AUTHOR

Ivan Kohler <ivan-rt@420.am>

=head1 BUGS

Yes.

=head1 SEE ALSO

L<RT::KeywordSelects>, L<RT::Keyword>, L<RT::Keywords>, L<RT::ObjectKeyword>,
L<RT::ObjectKeywords>, L<RT::Record>

=cut

1;

