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

1;

