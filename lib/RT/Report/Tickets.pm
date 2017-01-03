# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

package RT::Report::Tickets;

use base qw/RT::Tickets/;
use RT::Report::Tickets::Entry;

use strict;
use warnings;

sub Groupings {
    my $self = shift;
    my %args = (@_);
    my @fields =
      map { $self->CurrentUser->loc($_), $_ } qw( Status Queue );    # loc_qw

    foreach my $type ( qw(Owner Creator LastUpdatedBy Requestor Cc AdminCc Watcher) ) { # loc_qw
        for my $field (
            qw( Name EmailAddress RealName NickName Organization Lang City Country Timezone ) # loc_qw
          )
        {
            push @fields,
              $self->CurrentUser->loc($type) . ' '
              . $self->CurrentUser->loc($field), $type . '.' . $field;
        }
    }


    for my $field (qw(Due Resolved Created LastUpdated Started Starts Told)) { # loc_qw
        for my $frequency (qw(Hourly Daily Monthly Annually)) { # loc_qw
            push @fields,
              $self->CurrentUser->loc($field)
              . $self->CurrentUser->loc($frequency),
              $field . $frequency;
        }
    }

    my $queues = $args{'Queues'};
    if ( !$queues && $args{'Query'} ) {
        require RT::Interface::Web::QueryBuilder::Tree;
        my $tree = RT::Interface::Web::QueryBuilder::Tree->new('AND');
        $tree->ParseSQL( Query => $args{'Query'}, CurrentUser => $self->CurrentUser );
        $queues = $tree->GetReferencedQueues;
    }

    if ( $queues ) {
        my $CustomFields = RT::CustomFields->new( $self->CurrentUser );
        foreach my $id (keys %$queues) {
            my $queue = RT::Queue->new( $self->CurrentUser );
            $queue->Load($id);
            $CustomFields->LimitToQueue($queue->Id) if $queue->Id;
        }
        $CustomFields->LimitToGlobal;
        while ( my $CustomField = $CustomFields->Next ) {
            push @fields, $self->CurrentUser->loc(
                "Custom field '[_1]'",
                $CustomField->Name
              ),
              "CF.{" . $CustomField->id . "}";
        }
    }
    return @fields;
}

sub Label {
    my $self = shift;
    my $field = shift;
    if ( $field =~ /^(?:CF|CustomField)\.\{(.*)\}$/ ) {
        my $cf = $1;
        return $self->CurrentUser->loc( "Custom field '[_1]'", $cf ) if $cf =~ /\D/;
        my $obj = RT::CustomField->new( $self->CurrentUser );
        $obj->Load( $cf );
        return $self->CurrentUser->loc( "Custom field '[_1]'", $obj->Name );
    }
    return $self->CurrentUser->loc($field);
}

sub SetupGroupings {
    my $self = shift;
    my %args = (Query => undef, GroupBy => undef, @_);

    $self->FromSQL( $args{'Query'} );
    my @group_by = ref( $args{'GroupBy'} )? @{ $args{'GroupBy'} } : ($args{'GroupBy'});
    $self->GroupBy( map { {FIELD => $_} } @group_by );

    # UseSQLForACLChecks may add late joins
    my $joined = ($self->_isJoined || RT->Config->Get('UseSQLForACLChecks')) ? 1 : 0;

    my @res;
    push @res, $self->Column( FUNCTION => ($joined? 'DISTINCT COUNT' : 'COUNT'), FIELD => 'id' );
    push @res, map $self->Column( FIELD => $_ ), @group_by;
    return @res;
}

sub GroupBy {
    my $self = shift;
    my @args = ref $_[0]? @_ : { @_ };

    @{ $self->{'_group_by_field'} ||= [] } = map $_->{'FIELD'}, @args;
    $_ = { $self->_FieldToFunction( %$_ ) } foreach @args;

    $self->SUPER::GroupBy( @args );
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
    if ( $self->{'must_redo_search'} ) {
        $RT::Logger->crit(
"_DoSearch is not so successful as it still needs redo search, won't call AddEmptyRows"
        );
    }
    else {
        $self->AddEmptyRows;
    }
}

=head2 _FieldToFunction FIELD

Returns a tuple of the field or a database function to allow grouping on that 
field.

=cut

sub _FieldToFunction {
    my $self = shift;
    my %args = (@_);

    my $field = $args{'FIELD'};

    if ($field =~ /^(.*)(Hourly|Daily|Monthly|Annually)$/) {
        my ($field, $grouping) = ($1, $2);
        my $alias = $args{'ALIAS'} || 'main';

        my $func = "$alias.$field";

        my $db_type = RT->Config->Get('DatabaseType');
        if ( RT->Config->Get('ChartsTimezonesInDB') ) {
            my $tz = $self->CurrentUser->UserObj->Timezone
                || RT->Config->Get('Timezone')
                || 'UTC';
            if ( lc $tz eq 'utc' ) {
                # do nothing
            }
            elsif ( $db_type eq 'Pg' ) {
                $func = "timezone('UTC', $func)";
                $func = "timezone(". $self->_Handle->dbh->quote($tz) .", $func)";
            }
            elsif ( $db_type eq 'mysql' ) {
                $func = "CONVERT_TZ($func, 'UTC', "
                    . $self->_Handle->dbh->quote($tz)
                    .")";
            }
            else {
                $RT::Logger->warning(
                    "ChartsTimezonesInDB config option"
                    ." is not supported on $db_type."
                );
            }
        }

        # Pg 8.3 requires explicit casting
        $func .= '::text' if $db_type eq 'Pg';

        if ( $grouping eq 'Hourly' ) {
            $func = "SUBSTR($func,1,13)";
        }
        if ( $grouping eq 'Daily' ) {
            $func = "SUBSTR($func,1,10)";
        }
        elsif ( $grouping eq 'Monthly' ) {
            $func = "SUBSTR($func,1,7)";
        }
        elsif ( $grouping eq 'Annually' ) {
            $func = "SUBSTR($func,1,4)";
        }
        $args{'FUNCTION'} = $func;
    } elsif ( $field =~ /^(?:CF|CustomField)\.\{(.*)\}$/ ) { #XXX: use CFDecipher method
        my $cf_name = $1;
        my $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->Load($cf_name);
        unless ( $cf->id ) {
            $RT::Logger->error("Couldn't load CustomField #$cf_name");
        } else {
            my ($ticket_cf_alias, $cf_alias) = $self->_CustomFieldJoin($cf->id, $cf->id, $cf_name);
            @args{qw(ALIAS FIELD)} = ($ticket_cf_alias, 'Content');
        }
    } elsif ( $field =~ /^(?:(Owner|Creator|LastUpdatedBy))(?:\.(.*))?$/ ) {
        my $type = $1 || '';
        my $column = $2 || 'Name';
        my $u_alias = $self->{"_sql_report_${type}_users_${column}"}
            ||= $self->Join(
                TYPE   => 'LEFT',
                ALIAS1 => 'main',
                FIELD1 => $type,
                TABLE2 => 'Users',
                FIELD2 => 'id',
            );
        @args{qw(ALIAS FIELD)} = ($u_alias, $column);
    } elsif ( $field =~ /^(?:Watcher|(Requestor|Cc|AdminCc))(?:\.(.*))?$/ ) {
        my $type = $1 || '';
        my $column = $2 || 'Name';
        my $u_alias = $self->{"_sql_report_watcher_users_alias_$type"};
        unless ( $u_alias ) {
            my ($g_alias, $gm_alias);
            ($g_alias, $gm_alias, $u_alias) = $self->_WatcherJoin( $type );
            $self->{"_sql_report_watcher_users_alias_$type"} = $u_alias;
        }
        @args{qw(ALIAS FIELD)} = ($u_alias, $column);
    }
    return %args;
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
    return RT::Report::Tickets::Entry->new(RT->SystemUser); # $self->CurrentUser);
}


=head2 AddEmptyRows

If we're grouping on a criterion we know how to add zero-value rows
for, do that.

=cut

sub AddEmptyRows {
    my $self = shift;
    if ( @{ $self->{'_group_by_field'} || [] } == 1 && $self->{'_group_by_field'}[0] eq 'Status' ) {
        my %has = map { $_->__Value('Status') => 1 } @{ $self->ItemsArrayRef || [] };

        foreach my $status ( grep !$has{$_}, RT::Queue->new($self->CurrentUser)->StatusArray ) {

            my $record = $self->NewItem;
            $record->LoadFromHash( {
                id     => 0,
                status => $status
            } );
            $self->AddRecord($record);
        }
    }
}

RT::Base->_ImportOverlays();

1;
