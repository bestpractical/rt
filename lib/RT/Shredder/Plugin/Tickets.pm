package RT::Shredder::Plugin::Tickets;

use strict;
use warnings FATAL => 'all';
use base qw(RT::Shredder::Plugin::Base::Search);

=head1 NAME

RT::Shredder::Plugin::Tickets - search plugin for wiping tickets.

=head1 ARGUMENTS

=head2 query - query string

Search tickets with query string.
Examples:
  Queue = 'my queue' AND ( Status = 'deleted' OR Status = 'rejected' )
  LastUpdated < '2003-12-31 23:59:59'

B<Hint:> You can construct query with the query builder in RT's web
interface and then open advanced page and copy query string.

Arguments C<queue>, C<status> and C<updated_before> have been dropped
as you can easy make the same search with the C<query> option.
See examples above.

=cut

sub SupportArgs { return $_[0]->SUPER::SupportArgs, qw(query) }

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    my $queue;
    if( $args{'query'} ) {
        my $objs = RT::Tickets->new( $RT::SystemUser );
        $objs->{'allow_deleted_search'} = 1;
        my ($status, $msg) = $queue->FromSQL( $args{'query'} );
        return( 0, "Bad query argument, error: $msg" ) unless $status;
        $args{'query'} = $objs;
    }
    return $self->SUPER::TestArgs( %args );
}

sub Run
{
    my $self = shift;
    my $objs = $self->{'opt'}{'query'}
        or return (1, undef);
    if( $self->{'opt'}{'limit'} ) {
        $objs->RowsPerPage( $self->{'opt'}{'limit'} );
    }
    $objs->OrderByCols( { FIELD => 'id', ORDER => 'ASC' } );
    return (1, $objs);
}

1;
