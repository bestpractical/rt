package RT::Shredder::Plugin::SQLDump;

use strict;
use warnings;

use base qw(RT::Shredder::Plugin::Base::Dump);
use RT::Shredder;

sub AppliesToStates { return 'after wiping dependencies' }

sub SupportArgs
{
    my $self = shift;
    return $self->SUPER::SupportArgs, qw(file_name from_storage);
}

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    $args{'from_storage'} = 1 unless defined $args{'from_storage'};
    my $file = $args{'file_name'} = RT::Shredder->GetFileName(
        FileName    => $args{'file_name'},
        FromStorage => delete $args{'from_storage'},
    );
    open $args{'file_handle'}, ">:raw", $file
        or return (0, "Couldn't open '$file' for write: $!");

    return $self->SUPER::TestArgs( %args );
}

sub FileName   { return $_[0]->{'opt'}{'file_name'}   }
sub FileHandle { return $_[0]->{'opt'}{'file_handle'} }

sub Run
{
    my $self = shift;
    return (0, 'no handle') unless my $fh = $self->{'opt'}{'file_handle'};

    my %args = ( Object => undef, @_ );
    my $query = $args{'Object'}->_AsInsertQuery;
    $query .= "\n" unless $query =~ /\n$/;

    return print $fh $query or return (0, "Couldn't write to filehandle");
    return 1;
}

1;
