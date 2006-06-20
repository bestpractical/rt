use RT::Link ();
package RT::Link;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Exceptions;
use RT::Shredder::Dependencies;
use RT::Shredder::Constants;

use RT::Shredder::Transaction;
use RT::Shredder::Record;

sub __DependsOn
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

# AddLink transactions
    my $map = RT::Ticket->LINKTYPEMAP;
    my $link_meta = $map->{ $self->Type };
    unless ( $link_meta && $link_meta->{'Mode'} && $link_meta->{'Type'} ) {
        RT::Shredder::Exception->throw( 'Wrong link link_meta, no record for '. $self->Type );
    }
    if ( $self->BaseURI->IsLocal ) {
        my $objs = $self->BaseObj->Transactions;
        $objs->Limit(
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => 'AddLink',
        );
        $objs->Limit( FIELD => 'NewValue', VALUE => $self->Target );
        while ( my ($k, $v) = each %$map ) {
            next unless $v->{'Type'} eq $link_meta->{'Type'};
            next unless $v->{'Mode'} eq $link_meta->{'Mode'};
            $objs->Limit( FIELD => 'Field', VALUE => $k );
        }
        push( @$list, $objs );
    }

    my %reverse = ( Base => 'Target', Target => 'Base' );
    if ( $self->TargetURI->IsLocal ) {
        my $objs = $self->TargetObj->Transactions;
        $objs->Limit(
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => 'AddLink',
        );
        $objs->Limit( FIELD => 'NewValue', VALUE => $self->Base );
        while ( my ($k, $v) = each %$map ) {
            next unless $v->{'Type'} eq $link_meta->{'Type'};
            next unless $v->{'Mode'} eq $reverse{ $link_meta->{'Mode'} };
            $objs->Limit( FIELD => 'Field', VALUE => $k );
        }
        push( @$list, $objs );
    }

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON|WIPE_AFTER,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return $self->SUPER::__DependsOn( %args );
}

#TODO: Link record has small strength, but should be encountered
# if we plan write export tool.

sub __Relates
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];
# FIXME: if link is local then object should exist

    return $self->SUPER::__Relates( %args );
}

1;
