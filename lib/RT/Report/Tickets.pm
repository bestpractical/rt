package RT::Report::Tickets;

use base qw/RT::Tickets/;
use RT::Report::Tickets::Entry;

use strict;
use warnings;

sub Groupings {
    my $self = shift;
    my %args = (@_);
    my @fields = qw(
        Owner
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
    );
    if ( $args{'Query'} ) {
        require RT::Interface::Web::QueryBuilder::Tree;
        my $tree = RT::Interface::Web::QueryBuilder::Tree->new('AND');
        $tree->ParseSQL( Query => $args{'Query'}, CurrentUser => $self->CurrentUser );
        my $queues = $tree->GetReferencedQueues;

        my $CustomFields = RT::CustomFields->new( $self->CurrentUser );
        foreach my $id (keys %$queues) {
            my $queue = RT::Queue->new( $self->CurrentUser );
            $queue->Load($id);
            unless ($queue->id) {
                # XXX TODO: This ancient code dates from a former developer
                # we have no idea what it means or why cfqueues are so encoded.
                $id =~ s/^.'*(.*).'*$/$1/;
                $queue->Load($id);
            }
            $CustomFields->LimitToQueue($queue->Id);
        }
        $CustomFields->LimitToGlobal;
        while ( my $CustomField = $CustomFields->Next ) {
            push @fields, "CF.{". $CustomField->Name ."}";
        }
    }
    return @fields;
}

sub GroupBy {
    my $self = shift;
    my %args = ref $_[0]? %{ $_[0] }: (@_);

    $self->{'_group_by_field'} = $args{'FIELD'};
    %args = $self->_FieldToFunction( %args );

    $self->SUPER::GroupBy( \%args );
}

sub Column {
    my $self = shift;
    my %args = (@_);

    if ( $args{'FIELD'} && !$args{'FUNCTION'} ) {
        %args = $self->_FieldToFunction( %args );
    }

    return $self->SUPER::Column( %args );
}

=head2 _DoSearch

Subclass _DoSearch from our parent so we can go through and add in empty 
columns if it makes sense 

=cut

sub _DoSearch {
    my $self = shift;
    $self->SUPER::_DoSearch( @_ );
    $self->AddEmptyRows;
}

=head2 _FieldToFunction FIELD

Returns a tuple of the field or a database function to allow grouping on that 
field.

=cut

sub _FieldToFunction {
    my $self = shift;
    my %args = (@_);

    my $field = $args{'FIELD'};

    if ($field =~ /^(.*)(Daily|Monthly|Annually)$/) {
        my ($field, $grouping) = ($1, $2);
        if ( $grouping =~ /Daily/ ) {
            $args{'FUNCTION'} = "SUBSTR($field,1,10)";
        }
        elsif ( $grouping =~ /Monthly/ ) {
            $args{'FUNCTION'} = "SUBSTR($field,1,7)";
        }
        elsif ( $grouping =~ /Annually/ ) {
            $args{'FUNCTION'} = "SUBSTR($field,1,4)";
        }
    } elsif ( $field =~ /^(?:CF|CustomField)\.{(.*)}$/ ) { #XXX: use CFDecipher method
        my $cf_name = $1;
        my $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->Load($cf_name);
        unless ( $cf->id ) {
            $RT::Logger->error("Couldn't load CustomField #$cf_name");
        } else {
            my ($ticket_cf_alias, $cf_alias) = $self->_CustomFieldJoin($cf->id, $cf->id, $cf_name);
            @args{qw(ALIAS FIELD)} = ($ticket_cf_alias, 'Content');
        }
    }
    return %args;
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


=head2 AddEmptyRows

If we're grouping on a criterion we know how to add zero-value rows
for, do that.

=cut

sub AddEmptyRows {
    my $self = shift;
    if ( $self->{'_group_by_field'} eq 'Status' ) {
        foreach my $status ( RT::Queue->new($self->CurrentUser)->StatusArray ) {
            next if grep $_->__Value('Status') eq $status, @{ $self->ItemsArrayRef };

            my $record = $self->NewItem;
            $record->LoadFromHash( {
                id     => 0,
                status => $status
            } );
            $self->AddRecord($record);
        }
    }
}

1;
