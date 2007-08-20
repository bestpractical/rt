package RT::Shredder::Plugin::Base::Search;

use strict;
use warnings FATAL => 'all';

use base qw(RT::Shredder::Plugin::Base);

=head1 NAME

RT::Shredder::Plugin::Base - base class for Shredder plugins.

=cut

sub Type { return 'search' }

=head1 ARGUMENTS

Arguments which all plugins support.

=head2 limit - unsigned integer

Allow you to limit search results. B<< Default value is C<10> >>.

=head1 METHODS

=cut

sub SupportArgs
{
    my %seen;
    return sort
        grep $_ && !$seen{$_},
            shift->SUPER::SupportArgs(@_),
            qw(limit);
}

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    if( defined $args{'limit'} && $args{'limit'} ne '' ) {
        my $limit = $args{'limit'};
        $limit =~ s/[^0-9]//g;
        unless( $args{'limit'} eq $limit ) {
            return( 0, "'limit' should be an unsigned integer");
        }
        $args{'limit'} = $limit;
    } else {
        $args{'limit'} = 10;
    }
    return $self->SUPER::TestArgs( %args );
}

sub SetResolvers { return 1 }


=head2 FetchNext $collection [, $init]

Returns next object in collection as method L<RT::SearchBuilder/Next>, but
doesn't stop on page boundaries.

When method is called with true C<$init> arg it enables pages on collection
and selects first page.

Main purpose of this method is to avoid loading of whole collection into
memory as RT does by default when pager is not used. This method init paging
on the collection, but doesn't stop when reach page end.

Example:

    $plugin->FetchNext( $tickets, 'init' );
    while( my $ticket = $plugin->FetchNext( $tickets ) ) {
        ...
    }

=cut

use constant PAGE_SIZE => 100;
sub FetchNext {
    my ($self, $objs, $init) = @_;
    if ( $init ) {
        $objs->RowsPerPage( PAGE_SIZE );
        $objs->FirstPage;
        return;
    }

    my $obj = $objs->Next;
    return $obj if $obj;
    $objs->NextPage;
    return $objs->Next;
}

1;

