# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

=head1 NAME

  RT::Transactions - a collection of RT Transaction objects

=head1 SYNOPSIS

  use RT::Transactions;


=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Transactions;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::Transaction;
use 5.010;

sub Table { 'Transactions'}

# {{{ sub _Init  
sub _Init   {
    my $self = shift;

    $self->{'table'} = "Transactions";
    $self->{'primary_key'} = "id";

    # By default, order by the date of the transaction, rather than ID.
    $self->OrderByCols( { FIELD => 'Created',
                          ORDER => 'ASC' },
                        { FIELD => 'id',
                          ORDER => 'ASC' } );

    $self->SUPER::_Init(@_);
    $self->_InitSQL();
}

sub _InitSQL {
    my $self = shift;
    # Private Member Variables (which should get cleaned)
    $self->{'_sql_query'}         = '';
}

=head2 LimitToTicket TICKETID 

Find only transactions for the ticket whose id is TICKETID.

This includes tickets merged into TICKETID.

Repeated calls to this method will intelligently limit down to that set of tickets, joined with an OR


=cut


sub LimitToTicket {
    my $self = shift;
    my $tid  = shift;

    unless ( $self->{'tickets_table'} ) {
        $self->{'tickets_table'} ||= $self->Join(
            ALIAS1 => 'main',
            FIELD1 => 'ObjectId',
            TABLE2 => 'Tickets',
            FIELD2 => 'id'
        );
        $self->Limit(
            FIELD => 'ObjectType',
            VALUE => 'RT::Ticket',
        );
    }
    $self->Limit(
        ALIAS           => $self->{tickets_table},
        FIELD           => 'EffectiveId',
        OPERATOR        => '=',
        ENTRYAGGREGATOR => 'OR',
        VALUE           => $tid,
    );

}


sub AddRecord {
    my $self = shift;
    my ($record) = @_;

    return unless $record->CurrentUserCanSee;
    return $self->SUPER::AddRecord($record);
}

our %FIELD_METADATA = (
    id         => ['INT'],                 #loc_left_pair
    ObjectId   => ['ID'],                  #loc_left_pair
    ObjectType => ['STRING'],              #loc_left_pair
    Creator    => [ 'ENUM' => 'User' ],    #loc_left_pair
    TimeTaken  => ['INT'],                 #loc_left_pair

    Type          => ['STRING'],                 #loc_left_pair
    Field         => ['STRING'],                 #loc_left_pair
    OldValue      => ['STRING'],                 #loc_left_pair
    NewValue      => ['STRING'],                 #loc_left_pair
    ReferenceType => ['STRING'],                 #loc_left_pair
    OldReference  => ['STRING'],                 #loc_left_pair
    NewReference  => ['STRING'],                 #loc_left_pair
    Data          => ['STRING'],                 #loc_left_pair
    Created       => [ 'DATE' => 'Created' ],    #loc_left_pair

    Content     => ['ATTACHCONTENT'],            #loc_left_pair
    ContentType => ['ATTACHFIELD'],              #loc_left_pair
    Filename    => ['ATTACHFIELD'],              #loc_left_pair
    Subject     => ['ATTACHFIELD'],              #loc_left_pair

    CustomFieldValue => [ 'CUSTOMFIELD' => 'Transaction' ],    #loc_left_pair
    CustomField      => [ 'CUSTOMFIELD' => 'Transaction' ],    #loc_left_pair
    CF               => [ 'CUSTOMFIELD' => 'Transaction' ],    #loc_left_pair

    TicketId              => ['TICKETFIELD'],                  #loc_left_pair
    TicketSubject         => ['TICKETFIELD'],                  #loc_left_pair
    TicketQueue           => ['TICKETFIELD'],                  #loc_left_pair
    TicketStatus          => ['TICKETFIELD'],                  #loc_left_pair
    TicketOwner           => ['TICKETFIELD'],                  #loc_left_pair
    TicketCreator         => ['TICKETFIELD'],                  #loc_left_pair
    TicketLastUpdatedBy   => ['TICKETFIELD'],                  #loc_left_pair
    TicketCreated         => ['TICKETFIELD'],                  #loc_left_pair
    TicketStarted         => ['TICKETFIELD'],                  #loc_left_pair
    TicketResolved        => ['TICKETFIELD'],                  #loc_left_pair
    TicketTold            => ['TICKETFIELD'],                  #loc_left_pair
    TicketLastUpdated     => ['TICKETFIELD'],                  #loc_left_pair
    TicketStarts          => ['TICKETFIELD'],                  #loc_left_pair
    TicketDue             => ['TICKETFIELD'],                  #loc_left_pair
    TicketPriority        => ['TICKETFIELD'],                  #loc_left_pair
    TicketInitialPriority => ['TICKETFIELD'],                  #loc_left_pair
    TicketFinalPriority   => ['TICKETFIELD'],                  #loc_left_pair
    TicketType            => ['TICKETFIELD'],                  #loc_left_pair
    TicketQueueLifecycle  => ['TICKETQUEUEFIELD'],             #loc_left_pair

    CustomFieldName => ['CUSTOMFIELDNAME'],                    #loc_left_pair
    CFName          => ['CUSTOMFIELDNAME'],                    #loc_left_pair

    OldCFValue => ['OBJECTCUSTOMFIELDVALUE'],                  #loc_left_pair
    NewCFValue => ['OBJECTCUSTOMFIELDVALUE'],                  #loc_left_pair
);

# Lower Case version of FIELDS, for case insensitivity
our %LOWER_CASE_FIELDS = map { ( lc($_) => $_ ) } (keys %FIELD_METADATA);

our %dispatch = (
    INT                    => \&_IntLimit,
    ID                     => \&_IdLimit,
    ENUM                   => \&_EnumLimit,
    DATE                   => \&_DateLimit,
    STRING                 => \&_StringLimit,
    CUSTOMFIELD            => \&_CustomFieldLimit,
    ATTACHFIELD            => \&_AttachLimit,
    ATTACHCONTENT          => \&_AttachContentLimit,
    TICKETFIELD            => \&_TicketLimit,
    TICKETQUEUEFIELD       => \&_TicketQueueLimit,
    OBJECTCUSTOMFIELDVALUE => \&_ObjectCustomFieldValueLimit,
    CUSTOMFIELDNAME        => \&_CustomFieldNameLimit,
);

sub FIELDS     { return \%FIELD_METADATA }

our @SORTFIELDS = qw(id ObjectId Created);

=head2 SortFields

Returns the list of fields that lists of transactions can easily be sorted by

=cut

sub SortFields {
    my $self = shift;
    return (@SORTFIELDS);
}

=head1 Limit Helper Routines

These routines are the targets of a dispatch table depending on the
type of field.  They all share the same signature:

  my ($self,$field,$op,$value,@rest) = @_;

The values in @rest should be suitable for passing directly to
DBIx::SearchBuilder::Limit.

Essentially they are an expanded/broken out (and much simplified)
version of what ProcessRestrictions used to do.  They're also much
more clearly delineated by the TYPE of field being processed.

=head2 _IdLimit

Handle ID field.

=cut

sub _IdLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    if ( $value eq '__Bookmarked__' ) {
        return $sb->_BookmarkLimit( $field, $op, $value, @rest );
    } else {
        return $sb->_IntLimit( $field, $op, $value, @rest );
    }
}

=head2 _EnumLimit

Handle Fields which are limited to certain values, and potentially
need to be looked up from another class.

This subroutine actually handles two different kinds of fields.  For
some the user is responsible for limiting the values.  (i.e. ObjectType).

For others, the value specified by the user will be looked by via
specified class.

Meta Data:
  name of class to lookup in (Optional)

=cut

sub _EnumLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # SQL::Statement changes != to <>.  (Can we remove this now?)
    $op = "!=" if $op eq "<>";

    die "Invalid Operation: $op for $field"
        unless $op eq "="
        or $op     eq "!=";

    my $meta = $FIELD_METADATA{$field};
    if ( defined $meta->[1] && defined $value && $value !~ /^\d+$/ ) {
        my $class = "RT::" . $meta->[1];
        my $o     = $class->new( $sb->CurrentUser );
        $o->Load($value);
        $value = $o->Id || 0;
    }
    $sb->Limit(
        FIELD    => $field,
        VALUE    => $value,
        OPERATOR => $op,
        @rest,
    );
}

=head2 _IntLimit

Handle fields where the values are limited to integers.  (id)

Meta Data:
  None

=cut

sub _IntLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    my $is_a_like = $op =~ /MATCHES|ENDSWITH|STARTSWITH|LIKE/i;

    # We want to support <id LIKE '1%'>, but we need to explicitly typecast
    # on Postgres

    if ( $is_a_like && RT->Config->Get('DatabaseType') eq 'Pg' ) {
        return $sb->Limit(
            FUNCTION => "CAST(main.$field AS TEXT)",
            OPERATOR => $op,
            VALUE    => $value,
            @rest,
        );
    }

    $sb->Limit(
        FIELD    => $field,
        VALUE    => $value,
        OPERATOR => $op,
        @rest,
    );
}

=head2 _DateLimit

Handle date fields.  (Created)

Meta Data:
  1: type of link.  (Probably not necessary.)

=cut

sub _DateLimit {
    my ( $sb, $field, $op, $value, %rest ) = @_;

    die "Invalid Date Op: $op"
        unless $op =~ /^(=|>|<|>=|<=|IS(\s+NOT)?)$/i;

    my $meta = $FIELD_METADATA{$field};
    die "Incorrect Meta Data for $field"
        unless ( defined $meta->[1] );

    if ( $op =~ /^(IS(\s+NOT)?)$/i) {
        return $sb->Limit(
            FUNCTION => $sb->NotSetDateToNullFunction,
            FIELD    => $meta->[1],
            OPERATOR => $op,
            VALUE    => "NULL",
            %rest,
        );
    }

    my $date = RT::Date->new( $sb->CurrentUser );
    $date->Set( Format => 'unknown', Value => $value );

    if ( $op eq "=" ) {

        # if we're specifying =, that means we want everything on a
        # particular single day.  in the database, we need to check for >
        # and < the edges of that day.

        $date->SetToMidnight( Timezone => 'server' );
        my $daystart = $date->ISO;
        $date->AddDay;
        my $dayend = $date->ISO;

        $sb->_OpenParen;

        $sb->Limit(
            FIELD    => $meta->[1],
            OPERATOR => ">=",
            VALUE    => $daystart,
            %rest,
        );

        $sb->Limit(
            FIELD    => $meta->[1],
            OPERATOR => "<",
            VALUE    => $dayend,
            %rest,
            ENTRYAGGREGATOR => 'AND',
        );

        $sb->_CloseParen;

    }
    else {
        $sb->Limit(
            FUNCTION => $sb->NotSetDateToNullFunction,
            FIELD    => $meta->[1],
            OPERATOR => $op,
            VALUE    => $date->ISO,
            %rest,
        );
    }
}

=head2 _StringLimit

Handle simple fields which are just strings.  (Type, Field, OldValue, NewValue, ReferenceType)

Meta Data:
  None

=cut

sub _StringLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # FIXME:
    # Valid Operators:
    #  =, !=, LIKE, NOT LIKE
    if ( RT->Config->Get('DatabaseType') eq 'Oracle'
        && (!defined $value || !length $value)
        && lc($op) ne 'is' && lc($op) ne 'is not'
    ) {
        if ($op eq '!=' || $op =~ /^NOT\s/i) {
            $op = 'IS NOT';
        } else {
            $op = 'IS';
        }
        $value = 'NULL';
    }

    $sb->Limit(
        FIELD         => $field,
        OPERATOR      => $op,
        VALUE         => $value,
        CASESENSITIVE => 0,
        @rest,
    );
}

=head2 _ObjectCustomFieldValueLimit

Handle object custom field values.  (OldReference, NewReference)

Meta Data:
  None

=cut

sub _ObjectCustomFieldValueLimit {
    my ( $self, $field, $op, $value, @rest ) = @_;

    my $alias_name = $field =~ /new/i ? 'newocfv' : 'oldocfv';
    $self->{_sql_aliases}{$alias_name} ||= $self->Join(
        TYPE   => 'LEFT',
        FIELD1 => $field =~ /new/i ? 'NewReference' : 'OldReference',
        TABLE2 => 'ObjectCustomFieldValues',
        FIELD2 => 'id',
    );

    my $value_is_long = ( length( Encode::encode( "UTF-8", $value ) ) > 255 ) ? 1 : 0;

    $self->Limit(
        @rest,
        ALIAS         => $self->{_sql_aliases}{$alias_name},
        FIELD         => $value_is_long ? 'LargeContent' : 'Content',
        OPERATOR      => $op,
        VALUE         => $value,
        CASESENSITIVE => 0,
        @rest,
    );
}

=head2 _CustomFieldNameLimit

Handle custom field name field.  (Field)

Meta Data:
  None

=cut

sub _CustomFieldNameLimit {
    my ( $self, $_field, $op, $value, %rest ) = @_;

    $self->Limit(
        FIELD         => 'Type',
        OPERATOR      => '=',
        VALUE         => 'CustomField',
        CASESENSITIVE => 0,
        ENTRYAGGREGATOR => 'AND',
    );

    if ( $value =~ /\D/ ) {
        my $cfs = RT::CustomFields->new( RT->SystemUser );
        $cfs->Limit(
            FIELD         => 'Name',
            VALUE         => $value,
            CASESENSITIVE => 0,
        );
        $value = [ map { $_->id } @{ $cfs->ItemsArrayRef } ];

        $self->Limit(
            FIELD         => 'Field',
            OPERATOR      => $op eq '!=' ? 'NOT IN' : 'IN',
            VALUE         => $value,
            CASESENSITIVE => 0,
            ENTRYAGGREGATOR => 'AND',
            %rest,
        );
    }
    else {
        $self->Limit(
            FIELD         => 'Field',
            OPERATOR      => $op,
            VALUE         => $value,
            CASESENSITIVE => 0,
            ENTRYAGGREGATOR => 'AND',
            %rest,
        );
    }
}

=head2 _CustomFieldDecipher

Try and turn a CF descriptor into (cfid, cfname) object pair.

Takes an optional second parameter of the CF LookupType, defaults to Ticket CFs.

=cut

sub _CustomFieldDecipher {
    my ($self, $string, $lookuptype) = @_;
    $lookuptype ||= $self->_SingularClass->CustomFieldLookupType;

    my ($object, $field, $column) = ($string =~ /^(?:(.+?)\.)?\{(.+)\}(?:\.(Content|LargeContent))?$/);
    $field ||= ($string =~ /^\{(.*?)\}$/)[0] || $string;

    my ($cf, $applied_to);

    if ( $object ) {
        my $record_class = RT::CustomField->RecordClassFromLookupType($lookuptype);
        $applied_to = $record_class->new( $self->CurrentUser );
        $applied_to->Load( $object );

        if ( $applied_to->id ) {
            RT->Logger->debug("Limiting to CFs identified by '$field' applied to $record_class #@{[$applied_to->id]} (loaded via '$object')");
        }
        else {
            RT->Logger->warning("$record_class '$object' doesn't exist, parsed from '$string'");
            $object = 0;
            undef $applied_to;
        }
    }

    if ( $field =~ /\D/ ) {
        $object ||= '';
        my $cfs = RT::CustomFields->new( $self->CurrentUser );
        $cfs->Limit( FIELD => 'Name', VALUE => $field, CASESENSITIVE => 0 );
        $cfs->LimitToLookupType($lookuptype);

        if ($applied_to) {
            $cfs->SetContextObject($applied_to);
            $cfs->LimitToObjectId($applied_to->id);
        }

        # if there is more then one field the current user can
        # see with the same name then we shouldn't return cf object
        # as we don't know which one to use
        $cf = $cfs->First;
        if ( $cf ) {
            $cf = undef if $cfs->Next;
        }
    }
    else {
        $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->Load( $field );
        $cf->SetContextObject($applied_to)
            if $cf->id and $applied_to;
    }

    return ($object, $field, $cf, $column);
}

=head2 _CustomFieldLimit

Limit based on CustomFields

Meta Data:
  none

=cut

sub _CustomFieldLimit {
    my ( $self, $_field, $op, $value, %rest ) = @_;

    my $meta  = $FIELD_METADATA{ $_field };
    my $class = $meta->[1] || 'Transaction';
    my $type  = "RT::$class"->CustomFieldLookupType;

    my $field = $rest{'SUBKEY'} || die "No field specified";

    # For our sanity, we can only limit on one object at a time

    my ($object, $cfid, $cf, $column);
    ($object, $field, $cf, $column) = $self->_CustomFieldDecipher( $field, $type );


    $self->_LimitCustomField(
        %rest,
        LOOKUPTYPE  => $type,
        CUSTOMFIELD => $cf || $field,
        KEY      => $cf ? $cf->id : "$type-$object.$field",
        OPERATOR => $op,
        VALUE    => $value,
        COLUMN   => $column,
        SUBCLAUSE => "txnsql",
    );
}

=head2 _AttachLimit

Limit based on the ContentType or the Filename of an attachment.

=cut

sub _AttachLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;

    unless ( defined $self->{_sql_aliases}{attach} ) {
        $self->{_sql_aliases}{attach} = $self->Join(
            TYPE   => 'LEFT', # not all txns have an attachment
            FIELD1 => 'id',
            TABLE2 => 'Attachments',
            FIELD2 => 'TransactionId',
        );
    }

    $self->Limit(
        %rest,
        ALIAS         => $self->{_sql_aliases}{attach},
        FIELD         => $field,
        OPERATOR      => $op,
        VALUE         => $value,
        CASESENSITIVE => 0,
    );
}

=head2 _AttachContentLimit

Limit based on the Content of a transaction.

=cut

sub _AttachContentLimit {

    my ( $self, $field, $op, $value, %rest ) = @_;
    $field = 'Content' if $field =~ /\W/;

    my $config = RT->Config->Get('FullTextSearch') || {};
    unless ( $config->{'Enable'} ) {
        $self->Limit( %rest, FIELD => 'id', VALUE => 0 );
        return;
    }

    unless ( defined $self->{_sql_aliases}{attach} ) {
        $self->{_sql_aliases}{attach} = $self->Join(
            TYPE   => 'LEFT', # not all txns have an attachment
            FIELD1 => 'id',
            TABLE2 => 'Attachments',
            FIELD2 => 'TransactionId',
        );
    }

    $self->_OpenParen;
    if ( $config->{'Indexed'} ) {
        my $db_type = RT->Config->Get('DatabaseType');

        my $alias;
        if ( $config->{'Table'} and $config->{'Table'} ne "Attachments") {
            $alias = $self->{'_sql_aliases'}{'full_text'} ||= $self->Join(
                TYPE   => 'LEFT',
                ALIAS1 => $self->{_sql_aliases}{attach},
                FIELD1 => 'id',
                TABLE2 => $config->{'Table'},
                FIELD2 => 'id',
            );
        } else {
            $alias = $self->{_sql_aliases}{attach};
        }

        #XXX: handle negative searches
        my $index = $config->{'Column'};
        if ( $db_type eq 'Oracle' ) {
            my $dbh = $RT::Handle->dbh;
            my $alias = $self->{_sql_aliases}{attach};
            $self->Limit(
                %rest,
                FUNCTION      => "CONTAINS( $alias.$field, ".$dbh->quote($value) .")",
                OPERATOR      => '>',
                VALUE         => 0,
                QUOTEVALUE    => 0,
                CASESENSITIVE => 1,
            );
            # this is required to trick DBIx::SB's LEFT JOINS optimizer
            # into deciding that join is redundant as it is
            $self->Limit(
                ENTRYAGGREGATOR => 'AND',
                ALIAS           => $self->{_sql_aliases}{attach},
                FIELD           => 'Content',
                OPERATOR        => 'IS NOT',
                VALUE           => 'NULL',
            );
        }
        elsif ( $db_type eq 'Pg' ) {
            my $dbh = $RT::Handle->dbh;
            $self->Limit(
                %rest,
                ALIAS       => $alias,
                FIELD       => $index,
                OPERATOR    => '@@',
                VALUE       => 'plainto_tsquery('. $dbh->quote($value) .')',
                QUOTEVALUE  => 0,
            );
        }
        elsif ( $db_type eq 'mysql' and not $config->{Sphinx}) {
            my $dbh = $RT::Handle->dbh;
            $self->Limit(
                %rest,
                FUNCTION    => "MATCH($alias.Content)",
                OPERATOR    => 'AGAINST',
                VALUE       => "(". $dbh->quote($value) ." IN BOOLEAN MODE)",
                QUOTEVALUE  => 0,
            );
            # As with Oracle, above, this forces the LEFT JOINs into
            # JOINS, which allows the FULLTEXT index to be used.
            # Orthogonally, the IS NOT NULL clause also helps the
            # optimizer decide to use the index.
            $self->Limit(
                ENTRYAGGREGATOR => 'AND',
                ALIAS           => $alias,
                FIELD           => "Content",
                OPERATOR        => 'IS NOT',
                VALUE           => 'NULL',
                QUOTEVALUE      => 0,
            );
        }
        elsif ( $db_type eq 'mysql' ) {
            # This is a special character.  Note that \ does not escape
            # itself (in Sphinx 2.1.0, at least), so 'foo\;bar' becoming
            # 'foo\\;bar' is not a vulnerability, and is still parsed as
            # "foo, \, ;, then bar".  Happily, the default mode is
            # "all", meaning that boolean operators are not special.
            $value =~ s/;/\\;/g;

            my $max = $config->{'MaxMatches'};
            $self->Limit(
                %rest,
                ALIAS       => $alias,
                FIELD       => 'query',
                OPERATOR    => '=',
                VALUE       => "$value;limit=$max;maxmatches=$max",
            );
        }
    } else {
        # This is the main difference from ticket content search.
        # For transaction searches, it probably worths keeping emails.
        # $self->Limit(
        #     %rest,
        #     FIELD    => 'Type',
        #     OPERATOR => 'NOT IN',
        #     VALUE    => ['EmailRecord', 'CommentEmailRecord'],
        # );

        $self->Limit(
            ENTRYAGGREGATOR => 'AND',
            ALIAS           => $self->{_sql_aliases}{attach},
            FIELD           => $field,
            OPERATOR        => $op,
            VALUE           => $value,
            CASESENSITIVE   => 0,
        );
    }
    if ( RT->Config->Get('DontSearchFileAttachments') ) {
        $self->Limit(
            ENTRYAGGREGATOR => 'AND',
            ALIAS           => $self->{_sql_aliases}{attach},
            FIELD           => 'Filename',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
        );
    }
    $self->_CloseParen;
}

sub _TicketLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;
    $field =~ s!^Ticket!!;

    if ( $field eq 'Queue' && $value =~ /\D/ ) {
        my $queue = RT::Queue->new($self->CurrentUser);
        $queue->Load($value);
        $value = $queue->id if $queue->id;
    }

    if ( $field =~ /^(?:Owner|Creator)$/ && $value =~ /\D/ ) {
        my $user = RT::User->new( $self->CurrentUser );
        $user->Load($value);
        $value = $user->id if $user->id;
    }

    $self->Limit(
        %rest,
        ALIAS         => $self->_JoinTickets,
        FIELD         => $field,
        OPERATOR      => $op,
        VALUE         => $value,
        CASESENSITIVE => 0,
    );
}

sub _TicketQueueLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;
    $field =~ s!^TicketQueue!!;

    my $queue = $self->{_sql_aliases}{ticket_queues} ||= $_[0]->Join(
        ALIAS1 => $self->_JoinTickets,
        FIELD1 => 'Queue',
        TABLE2 => 'Queues',
        FIELD2 => 'id',
    );

    $self->Limit(
        ALIAS    => $queue,
        FIELD    => $field,
        OPERATOR => $op,
        VALUE    => $value,
        %rest,
    );
}

sub PrepForSerialization {
    my $self = shift;
    delete $self->{'items'};
    delete $self->{'items_array'};
    $self->RedoSearch();
}

sub _OpenParen {
    $_[0]->SUPER::_OpenParen( $_[1] || 'txnsql' );
}
sub _CloseParen {
    $_[0]->SUPER::_CloseParen( $_[1] || 'txnsql' );
}

sub Limit {
    my $self = shift;
    my %args = @_;
    $self->{'must_redo_search'} = 1;
    delete $self->{'raw_rows'};
    delete $self->{'count_all'};

    $args{SUBCLAUSE} ||= "txnsql"
        if $self->{parsing_txnsql} and not $args{LEFTJOIN};

    $self->SUPER::Limit(%args);
}

=head2 FromSQL

Convert a RT-SQL string into a set of SearchBuilder restrictions.

Returns (1, 'Status message') on success and (0, 'Error Message') on
failure.

=cut

sub _parser {
    my ($self,$string) = @_;

    require RT::Interface::Web::QueryBuilder::Tree;
    my $tree = RT::Interface::Web::QueryBuilder::Tree->new;
    my @results = $tree->ParseSQL(
        Query => $string,
        CurrentUser => $self->CurrentUser,
        Class => ref $self || $self,
    );
    die join "; ", map { ref $_ eq 'ARRAY' ? $_->[ 0 ] : $_ } @results if @results;


    # To handle __Active__ and __InActive__ statuses, copied from
    # RT::Tickets::_parser with field name updates, i.e.
    #   Lifecycle => TicketQueueLifecycle
    #   Status => TicketStatus

    my ( $active_status_node, $inactive_status_node );
    my $escape_quotes = sub {
        my $text = shift;
        $text =~ s{(['\\])}{\\$1}g;
        return $text;
    };

    $tree->traverse(
        sub {
            my $node = shift;
            return unless $node->isLeaf and $node->getNodeValue;
            my ($key, $subkey, $meta, $op, $value, $bundle)
                = @{$node->getNodeValue}{qw/Key Subkey Meta Op Value Bundle/};
            return unless $key eq "TicketStatus" && $value =~ /^(?:__(?:in)?active__)$/i;

            my $parent = $node->getParent;
            my $index = $node->getIndex;

            if ( ( lc $value eq '__inactive__' && $op eq '=' ) || ( lc $value eq '__active__' && $op eq '!=' ) ) {
                unless ( $inactive_status_node ) {
                    my %lifecycle =
                      map { $_ => $RT::Lifecycle::LIFECYCLES{ $_ }{ inactive } }
                      grep { @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ inactive } || [] } }
                      grep { $RT::Lifecycle::LIFECYCLES_CACHE{ $_ }{ type } eq 'ticket' }
                      keys %RT::Lifecycle::LIFECYCLES;
                    return unless %lifecycle;

                    my $sql;
                    if ( keys %lifecycle == 1 ) {
                        $sql = join ' OR ', map { qq{ TicketStatus = '$_' } } map { $escape_quotes->($_) } map { @$_ } values %lifecycle;
                    }
                    else {
                        my @inactive_sql;
                        for my $name ( keys %lifecycle ) {
                            my $escaped_name = $escape_quotes->($name);
                            my $inactive_sql =
                                qq{TicketQueueLifecycle = '$escaped_name'}
                              . ' AND ('
                              . join( ' OR ', map { qq{ TicketStatus = '$_' } } map { $escape_quotes->($_) } @{ $lifecycle{ $name } } ) . ')';
                            push @inactive_sql, qq{($inactive_sql)};
                        }
                        $sql = join ' OR ', @inactive_sql;
                    }
                    $inactive_status_node = RT::Interface::Web::QueryBuilder::Tree->new;
                    $inactive_status_node->ParseSQL(
                        Class       => ref $self,
                        Query       => $sql,
                        CurrentUser => $self->CurrentUser,
                    );
                }
                $parent->removeChild( $node );
                $parent->insertChild( $index, $inactive_status_node );
            }
            else {
                unless ( $active_status_node ) {
                    my %lifecycle =
                      map {
                        $_ => [
                            @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ initial } || [] },
                            @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ active }  || [] },
                          ]
                      }
                      grep {
                             @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ initial } || [] }
                          || @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ active }  || [] }
                      }
                      grep { $RT::Lifecycle::LIFECYCLES_CACHE{ $_ }{ type } eq 'ticket' }
                      keys %RT::Lifecycle::LIFECYCLES;
                    return unless %lifecycle;

                    my $sql;
                    if ( keys %lifecycle == 1 ) {
                        $sql = join ' OR ', map { qq{ TicketStatus = '$_' } } map { $escape_quotes->($_) } map { @$_ } values %lifecycle;
                    }
                    else {
                        my @active_sql;
                        for my $name ( keys %lifecycle ) {
                            my $escaped_name = $escape_quotes->($name);
                            my $active_sql =
                                qq{TicketQueueLifecycle = '$escaped_name'}
                              . ' AND ('
                              . join( ' OR ', map { qq{ TicketStatus = '$_' } } map { $escape_quotes->($_) } @{ $lifecycle{ $name } } ) . ')';
                            push @active_sql, qq{($active_sql)};
                        }
                        $sql = join ' OR ', @active_sql;
                    }
                    $active_status_node = RT::Interface::Web::QueryBuilder::Tree->new;
                    $active_status_node->ParseSQL(
                        Class       => ref $self,
                        Query       => $sql,
                        CurrentUser => $self->CurrentUser,
                    );
                }
                $parent->removeChild( $node );
                $parent->insertChild( $index, $active_status_node );
            }
        }
    );

    if ( RT->Config->Get('EnablePriorityAsString') ) {
        my $queues = $tree->GetReferencedQueues( CurrentUser => $self->CurrentUser );
        my %config = RT->Config->Get('PriorityAsString');
        my @names;
        if (%$queues) {
            for my $id ( keys %$queues ) {
                my $queue = RT::Queue->new( $self->CurrentUser );
                $queue->Load($id);
                if ( $queue->Id ) {
                    push @names, $queue->__Value('Name');    # Skip ACL check
                }
            }
        }
        else {
            @names = keys %config;
        }

        my %map;
        for my $name (@names) {
            if ( my $value = exists $config{$name} ? $config{$name} : $config{Default} ) {
                my %hash = ref $value eq 'ARRAY' ? @$value : %$value;
                for my $label ( keys %hash ) {
                    $map{lc $label} //= $hash{$label};
                }
            }
        }

        $tree->traverse(
            sub {
                my $node = shift;
                return unless $node->isLeaf;
                my $value = $node->getNodeValue;
                if ( $value->{Key} =~ /^Ticket(?:Initial|Final)?Priority$/i ) {
                    $value->{Value} = $map{ lc $value->{Value} } if defined $map{ lc $value->{Value} };
                }
            }
        );
    }

    my $ea = '';
    $tree->traverse(
        sub {
            my $node = shift;
            $ea = $node->getParent->getNodeValue if $node->getIndex > 0;
            return $self->_OpenParen unless $node->isLeaf;

            my ($key, $subkey, $meta, $op, $value, $bundle)
                = @{$node->getNodeValue}{qw/Key Subkey Meta Op Value Bundle/};

            # normalize key and get class (type)
            my $class = $meta->[0];

            # replace __CurrentUser__ with id
            $value = $self->CurrentUser->id if $value eq '__CurrentUser__';

            # replace __CurrentUserName__ with the username
            $value = $self->CurrentUser->Name if $value eq '__CurrentUserName__';

            my $sub = $dispatch{ $class }
                or die "No dispatch method for class '$class'";

            # A reference to @res may be pushed onto $sub_tree{$key} from
            # above, and we fill it here.
            $sub->( $self, $key, $op, $value,
                    ENTRYAGGREGATOR => $ea,
                    SUBKEY          => $subkey,
                    BUNDLE          => $bundle,
                  );
        },
        sub {
            my $node = shift;
            return $self->_CloseParen unless $node->isLeaf;
        }
    );
}

sub FromSQL {
    my ($self,$query) = @_;

    $self->CleanSlate;
    $self->_InitSQL;

    return (1, $self->loc("No Query")) unless $query;

    $self->{_sql_query} = $query;
    eval {
        local $self->{parsing_txnsql} = 1;
        $self->_parser( $query );
    };
    if ( $@ ) {
        my $error = "$@";
        $RT::Logger->error("Couldn't parse query: $error");
        return (0, $error);
    }

    # set SB's dirty flag
    $self->{'must_redo_search'} = 1;

    return (1, $self->loc("Valid Query"));
}

sub _JoinTickets {
    my $self = shift;
    unless ( defined $self->{_sql_aliases}{tickets} ) {
        $self->{_sql_aliases}{tickets} = $self->Join(
            TYPE   => 'LEFT',
            FIELD1 => 'ObjectId',
            TABLE2 => 'Tickets',
            FIELD2 => 'id',
        );
    }
    return $self->{_sql_aliases}{tickets};
}

=head2 Query

Returns the last string passed to L</FromSQL>.

=cut

sub Query {
    my $self = shift;
    return $self->{_sql_query};
}

RT::Base->_ImportOverlays();

1;
