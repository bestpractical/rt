#$Header$

package RT::Keyword;

use strict;
use vars qw(@ISA);
use Tie::IxHash;
use RT::Record;
use RT::Keywords;
use RT::ObjectKeywords;

@ISA = qw(RT::Record);

sub _Init {
    my $self = shift;
    $self->{'table'} = "Keywords";
    $self->SUPER::_Init(@_);
}

sub _Accessible {
    shift->SUPER::_Accessible( @_,
    Name        => 'read/write', #the keyword itself
    Description => 'read/write', #(not yet used)
    Parent      => 'read/write', #optional link to another B<RT::Keyword>, allowing keyword to be arranged in a hierarchical fashion.  Can be specified by id or Name.
  );
}

=head1 NAME

 RT::Keyword - Manipulate an RT::ObjectKeyword record

=head1 SYNOPSIS

  use RT::Keyword;

  my $keyword = RT::Keyword->new($CurrentUser);
  $keyword->Create(
    Name => 'tofu',
  );

  my $keyword = RT::Keyword->new($CurrentUser);
  $keyword->Create(
    Name   => 'beast',
    Parent => 2,
  );

=head1 DESCRIPTION

An B<RT::Keyword> object is an arbitrary string. 

=head1 METHODS

=over 4

=item new CURRENT_USER

Takes a single argument, an RT::CurrentUser object.  Instantiates a new
(uncreated) RT::Keyword object.

=item Create KEY => VALUE, ...

Takes a list of key/value pairs and creates a the object.  Returns the id of
the newly created record, or false if there was an error.

Keys are:

Name - the keyword itself
Description - (not yet used)
Parent - optional link to another B<RT::Keyword>, allowing keyword to be arranged in a hierarchical fashion.  Can be specified by id or Name.

=cut

sub Create {
    my $self = shift;
    my %hash = @_;
    if ( $hash{Parent} && $hash{Parent} !~ /^\d+$/ ) {
	#TODO +++ should not be dieing in the core. 
	die "can't yet specify parents by name, sorry: ". $hash{Parent};
    }
    $self->SUPER::Create(%hash);
}

=item Set KEY => VALUE

=cut

#TODO +++ why would we ever use this when we have the _Accessible generated SetFoo methods?
sub Set {
    my $self = shift;
    my $field = shift;
    my $value = shift;
    $self->_Set( Field=>$field, Value=>$value );
}

=item Delete

=cut

sub Delete {
    my $self = shift;
    #TODO: check referential integrety - Keywords, ObjectKeywords, KeywordSelects
    $self->SUPER::Delete(@_);
}

=item Descendents [ NUM_GENERATIONS [ EXCLUDE_HASHREF ]  ]

Returns an ordered (see L<Tie::IxHash>) hash reference of the descendents of
this keyword, possibly limited to a given number of generations.  The keys
are B<RT::Keyword> I<id>s, and the values are strings containing the I<Name>s
of all relevant B<RT::Keyword>s.

=cut

sub Descendents {
    my $self = shift;
    my $generations = shift || 0;
    my $exclude = shift || {};
    my %results;
    
    tie %results, 'Tie::IxHash';
    my $Keywords = new RT::Keywords($self->CurrentUser);
    $Keywords->Limit( FIELD => 'Parent', VALUE => $self->id );
    
    while ( my $Keyword = $Keywords->Next ) {
	next if defined $exclude->{ $Keyword->id };
	$results{ $Keyword->id } = $Keyword->Name;
	if ( $generations == 0 || $generations > 1 ) {
	    my $kids = $Keyword->Descendents($generations-1, \%results);
	    $results { $_ } = $Keyword->Name. " | ". $kids->{$_}
	      foreach keys %{$kids};
	}
    }
    return(\%results);
}

=item TicketDescendents TICKET_ID

Like the I<Descendents> method, except only returns those keywords which are
associated with an B<RT::Ticket> record via an B<RT::ObjectKeyword> record.

=cut

sub TicketDescendents {
    my $self = shift;
    my $ticket = shift;
  my $Descendents = $self->Descendents;
    my %results;
    tie %results, 'Tie::IxHash';
    %results = map { $_ => $Descendents->{$_} }
      grep { $self->TicketObjectKeyword( $_, $ticket ) }
	keys %{$Descendents};
    return (\%results);
}

=item TicketObjectKeyword KEYWORD_ID TICKET_ID

Returns the B<RT::ObjectKeyword> object for the given ticket and keyword
descendent (not this keyword), or false if the given ticket is not associated
with the keyword descendent.

=cut

sub TicketObjectKeyword {
    my $self = shift;
    my $kid = shift;
    my $ticket = shift;
    my $ObjectKeywords = new RT::ObjectKeywords($self->CurrentUser);

    #TODO +++ I think this just wants to use RT::ObjectKeyword->LoadByCols
    # there's no need for the weight of using a search object.

    $ObjectKeywords->Limit( FIELD=>'Keyword',    VALUE=>$kid );
    $ObjectKeywords->Limit( FIELD=>'ObjectType', VALUE=>'Ticket' );
    $ObjectKeywords->Limit( FIELD=>'ObjectId',   VALUE=>$ticket );
    
    return($ObjectKeywords->Next);
}

=back

=head1 AUTHOR

Ivan Kohler <ivan-rt@420.am>

=head1 BUGS

Yes.

=head1 SEE ALSO

L<RT::Keywords>, L<RT::ObjectKeyword>, L<RT::ObjectKeywords>, L<RT::Ticket>,
L<RT::Record>

=cut

1;

