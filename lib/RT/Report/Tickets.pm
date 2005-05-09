package RT::Report::Tickets;
use base qw/RT::Tickets/;
use RT::Report::Tickets::Entry;


sub Groupings {
    qw (Owner
    Status
    Queue
    DueDaily
    DueMonthly
    DueAnnually
    ResolvedDaily
    ResolvedMonthly
    ResolvedAnnually
    CreatedDaily
    CreatedMonthly
    CreatedAnnually
    LastUpdatedDaily
    LastUpdatedMonthly
    LastUpdatedAnnually
    StartedDaily
    StartedMonthly
    StartedAnnually
    StartsDaily
    StartsMonthly
    StartsAnnually
    )

}

sub GroupBy {
    my $self = shift;
    my $field = shift;
    my $function;
    (undef, $function) = $self->_FieldToFunction($field);
    $self->GroupByCols({ FIELD => $field, FUNCTION => $function});

}

sub Column {
    my $self = shift;
    my %args = (@_);

    if ( $args{'FIELD'} ) { ( undef, $args{'FUNCTION'} ) = $self->_FieldToFunction( $args{'FIELD'} ); }

    return $self->SUPER::Column(%args);
}

=head2 _FieldToFunction FIELD

Returns a tuple of the field or a database function to allow grouping on that 
field.

=cut

sub _FieldToFunction{
    my $self = shift;
    my $field = shift;
    my $func = '';

    if ($field =~ /^(.*)(Daily|Monthly|Annually)$/) {
        $field = $1;
        $grouping = $2;
        if ($grouping =~ /Daily/) {
            $func = "SUBSTR($field,1,10)";
            $field = '';
        }
        elsif ($grouping =~ /Monthly/) {
            $func = "SUBSTR($field,1,7)";
            $field = '';
        }
        elsif ($grouping =~ /Annually/) {
            $func = "SUBSTR($field,1,4)";
            $field = '';
        }

    }
    return ($field, $func);
}


# Override the AddRecord from DBI::SearchBuilder::Unique. id isn't id here
# wedon't want to disambiguate all the items with a count of 1.
sub AddRecord {
    my $self = shift;
    my $record = shift;
    push @{$self->{'items'}}, $record;
    $self->{'rows'}++;
}

1;



# Gotta skip over RT::Tickets->Next, since it does all sorts of crazy magic we 
# don't want.
sub Next {
    my $self = shift;
    $self->RT::SearchBuilder::Next(@_);

}

sub NewItem {
    my $self = shift;
    return RT::Report::Tickets::Entry->new($RT::SystemUser); # $self->CurrentUser);
}





1;
