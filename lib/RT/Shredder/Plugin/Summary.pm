package RT::Shredder::Plugin::Summary;

use strict;
use warnings FATAL => 'all';

use base qw(RT::Shredder::Plugin::SQLDump);

sub AppliesToStates { return 'before any action' }

sub TestArgs
{
    my $self = shift;
    my %args = (file_name => '', @_);
    unless( $args{'file_name'} ) {
        require POSIX;
        $args{'file_name'} = POSIX::strftime( "summary-%Y%m%dT%H%M%S.XXXX.txt", gmtime );
    }
    return $self->SUPER::TestArgs( %args );
}

sub Run
{
    my $self = shift;
    my %args = ( Object => undef, @_ );
    my $class = ref $args{'Object'};
    $class =~ s/^RT:://;
    $class =~ s/:://g;
    my $method = 'WriteDown'. $class;
    $method = 'WriteDownDefault' unless $self->can($method);
    return $self->$method( %args );
    return 1;
}

my %skip_refs_to = ();

sub WriteDownDefault {
    my $self = shift;
    my %args = ( Object => undef, @_ );
    return $self->_WriteDownHash(
        $args{'Object'},
        $self->_MakeHash( $args{'Object'} ),
    );
}

# TODO: cover other objects
# ACE.pm
# Attachment.pm
# CustomField.pm
# CustomFieldValue.pm
# GroupMember.pm
# Group.pm
# Link.pm
# ObjectCustomFieldValue.pm
# Principal.pm
# Queue.pm
# Ticket.pm
# User.pm

# ScripAction.pm - works fine with defaults
# ScripCondition.pm - works fine with defaults
# Template.pm - works fine with defaults

sub WriteDownCachedGroupMember { return 1 }
sub WriteDownPrincipal { return 1 }

sub WriteDownGroup {
    my $self = shift;
    my %args = ( Object => undef, @_ );
    if ( $args{'Object'}->Domain =~ /-Role$/ ) {
        return $skip_refs_to{ $args{'Object'}->_AsString } = 1;
    }
    return $self->WriteDownDefault( %args );
}

sub WriteDownTransaction {
    my $self = shift;
    my %args = ( Object => undef, @_ );

    my $props = $self->_MakeHash( $args{'Object'} );
    $props->{'Object'} = delete $props->{'ObjectType'};
    $props->{'Object'} .= '-'. delete $props->{'ObjectId'}
        if $props->{'ObjectId'};
    return 1 if $skip_refs_to{ $props->{'Object'} };

    delete $props->{$_} foreach grep
        !defined $props->{$_} || $props->{$_} eq '', keys %$props;

    return $self->_WriteDownHash( $args{'Object'}, $props );
}

sub WriteDownScrip {
    my $self = shift;
    my %args = ( Object => undef, @_ );
    my $props = $self->_MakeHash( $args{'Object'} );
    $props->{'Action'} = $args{'Object'}->ActionObj->Name;
    $props->{'Condition'} = $args{'Object'}->ConditionObj->Name;
    $props->{'Template'} = $args{'Object'}->TemplateObj->Name;
    $props->{'Queue'} = $args{'Object'}->QueueObj->Name || 'global';

    return $self->_WriteDownHash( $args{'Object'}, $props );
}

sub _MakeHash {
    my ($self, $obj) = @_;
    my $hash = $self->__MakeHash( $obj );
    foreach (grep exists $hash->{$_}, qw(Creator LastUpdatedBy)) {
        my $method = $_ .'Obj';
        my $u = $obj->$method();
        $hash->{ $_ } = $u->EmailAddress || $u->Name || $u->_AsString;
    }
    return $hash;
}

sub __MakeHash {
    my ($self, $obj) = @_;
    my %hash;
    $hash{ $_ } = $obj->$_()
        foreach sort keys %{ $obj->_ClassAccessible };
    return \%hash;
}

sub _WriteDownHash {
    my ($self, $obj, $hash) = @_;
    return (0, 'no handle') unless my $fh = $self->{'opt'}{'file_handle'};

    print $fh "=== ". $obj->_AsString ." ===\n"
        or return (0, "Couldn't write to filehandle");

    foreach my $key( sort keys %$hash ) {
        my $val = $hash->{ $key };
        next unless defined $val;
        $val =~ s/\n/\n /g;
        print $fh $key .': '. $val ."\n"
            or return (0, "Couldn't write to filehandle");
    }
    print $fh "\n" or return (0, "Couldn't write to filehandle");
    return 1;
}

1;
