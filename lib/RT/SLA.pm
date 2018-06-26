# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use strict;
use warnings;

package RT::SLA;

=head1 NAME

RT::SLA - Service Level Agreements for RT

=head1 DESCRIPTION

Automated due dates using service levels.

=cut

sub BusinessHours {
    my $self = shift;
    my $name = shift || 'Default';

    require Business::Hours;
    my $res = new Business::Hours;
    my %config = RT->Config->Get('ServiceBusinessHours');
    $res->business_hours(%{ $config{$name} })
        if $config{$name};
    return $res;
}

sub Agreement {
    my $self = shift;
    my %args = (
        Level => undef,
        Type => 'Response',
        Time => undef,
        Ticket => undef,
        Queue  => undef,
        @_
    );

    my %config = RT->Config->Get('ServiceAgreements');
    my $meta = $config{'Levels'}{ $args{'Level'} };
    return undef unless $meta;

    if ( exists $meta->{'StartImmediately'} || !defined $meta->{'Starts'} ) {
        $meta->{'Starts'} = {
            delete $meta->{'StartImmediately'}
                ? ( )
                : ( BusinessMinutes => 0 )
            ,
        };
    }

    return undef unless $meta->{ $args{'Type'} };

    my %res;
    if ( ref $meta->{ $args{'Type'} } ) {
        %res = %{ $meta->{ $args{'Type'} } };
    } elsif ( $meta->{ $args{'Type'} } =~ /^\d+$/ ) {
        %res = ( BusinessMinutes => $meta->{ $args{'Type'} } );
    } else {
        $RT::Logger->error("Levels of SLA should be either number or hash ref");
        return undef;
    }

    if ( $args{'Ticket'} && $res{'IgnoreOnStatuses'} ) {
        my $status = $args{'Ticket'}->Status;
        return undef if grep $_ eq $status, @{$res{'IgnoreOnStatuses'}};
    }

    $res{'OutOfHours'} = $meta->{'OutOfHours'}{ $args{'Type'} };

    $args{'Queue'} ||= $args{'Ticket'}->QueueObj if $args{'Ticket'};
    if ( $args{'Queue'} && ref $config{'QueueDefault'}{ $args{'Queue'}->Name } ) {
        $res{'Timezone'} = $config{'QueueDefault'}{ $args{'Queue'}->Name }{'Timezone'};
    }
    $res{'Timezone'} ||= $meta->{'Timezone'} || $RT::Timezone;

    $res{'BusinessHours'} = $meta->{'BusinessHours'};

    return \%res;
}

sub Due {
    my $self = shift;
    return $self->CalculateTime( @_ );
}

sub Starts {
    my $self = shift;
    return $self->CalculateTime( @_, Type => 'Starts' );
}

sub CalculateTime {
    my $self = shift;
    my %args = (@_);
    my $agreement = $args{'Agreement'} || $self->Agreement( @_ );
    return undef unless $agreement and ref $agreement eq 'HASH';

    my $res = $args{'Time'};

    my $ok = eval {
        local $ENV{'TZ'} = $ENV{'TZ'};
        if ( $agreement->{'Timezone'} && $agreement->{'Timezone'} ne ($ENV{'TZ'}||'') ) {
            $ENV{'TZ'} = $agreement->{'Timezone'};
            require POSIX; POSIX::tzset();
        }

        my $bhours = $self->BusinessHours( $agreement->{'BusinessHours'} );

        if ( $agreement->{'OutOfHours'} && $bhours->first_after( $res ) != $res ) {
            foreach ( qw(RealMinutes BusinessMinutes) ) {
                next unless my $mod = $agreement->{'OutOfHours'}{ $_ };
                ($agreement->{ $_ } ||= 0) += $mod;
            }
        }

        if (   $args{ Ticket }
            && $agreement->{ IgnoreOnStatuses }
            && $agreement->{ ExcludeTimeOnIgnoredStatuses } )
        {
            my $txns = RT::Transactions->new( RT->SystemUser );
            $txns->LimitToTicket($args{Ticket}->id);
            $txns->Limit(
                FIELD => 'Field',
                VALUE => 'Status',
            );
            my $date = RT::Date->new( RT->SystemUser );
            $date->Set( Value => $args{ Time } );
            $txns->Limit(
                FIELD    => 'Created',
                OPERATOR => '>=',
                VALUE    => $date->ISO( Timezone => 'UTC' ),
            );

            my $last_time = $args{ Time };
            while ( my $txn = $txns->Next ) {
                if ( grep( { $txn->OldValue eq $_ } @{ $agreement->{ IgnoreOnStatuses } } ) ) {
                    if ( !grep( { $txn->NewValue eq $_ } @{ $agreement->{ IgnoreOnStatuses } } ) ) {
                        if ( defined $agreement->{ 'BusinessMinutes' } ) {

                            # re-init $bhours to make sure we don't have a cached start/end,
                            # so the time here is not outside the calculated business hours

                            my $bhours = $self->BusinessHours( $agreement->{ 'BusinessHours' } );
                            my $time = $bhours->between( $last_time, $txn->CreatedObj->Unix );
                            if ( $time > 0 ) {
                                $res = $bhours->add_seconds( $res, $time );
                            }
                        }
                        else {
                            my $time = $txn->CreatedObj->Unix - $last_time;
                            $res += $time;
                        }
                        $last_time = $txn->CreatedObj->Unix;
                    }
                }
                else {
                    $last_time = $txn->CreatedObj->Unix;
                }
            }
        }

        if ( defined $agreement->{'BusinessMinutes'} ) {
            if ( $agreement->{'BusinessMinutes'} ) {
                $res = $bhours->add_seconds(
                    $res, 60 * $agreement->{'BusinessMinutes'},
                );
            }
            else {
                $res = $bhours->first_after( $res );
            }
        }
        $res += 60 * $agreement->{'RealMinutes'}
            if defined $agreement->{'RealMinutes'};
        1;
    };

    POSIX::tzset() if $agreement->{'Timezone'}
        && $agreement->{'Timezone'} ne ($ENV{'TZ'}||'');
    die $@ unless $ok;

    return $res;
}

sub GetDefaultServiceLevel {
    my $self = shift;
    my %args = (Ticket => undef, Queue => undef, @_);
    unless ( $args{'Queue'} || $args{'Ticket'} ) {
        $args{'Ticket'} = $self->TicketObj if $self->can('TicketObj');
    }
    if ( !$args{'Queue'} && $args{'Ticket'} ) {
        $args{'Queue'} = $args{'Ticket'}->QueueObj;
    }

    my %config = RT->Config->Get('ServiceAgreements');
    if ( $args{'Queue'} ) {
        return undef if $args{Queue}->SLADisabled;
        return $args{'Queue'}->SLA if $args{'Queue'}->SLA;
        if ( $config{'QueueDefault'} &&
            ( my $info = $config{'QueueDefault'}{ $args{'Queue'}->Name } )) {
            return $info unless ref $info;
            return $info->{'Level'} || $config{'Default'};
        }
    }
    return $config{'Default'};
}

RT::Base->_ImportOverlays();

1;
