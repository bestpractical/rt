# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
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
# Major Changes:

# - Decimated ProcessRestrictions and broke it into multiple
# functions joined by a LUT
# - Semi-Generic SQL stuff moved to another file

# Known Issues: FIXME!

# - ClearRestrictions and Reinitialization is messy and unclear.  The
# only good way to do it is to create a new RT::Tickets object.

=head1 NAME

  RT::Tickets - A collection of Ticket objects


=head1 SYNOPSIS

  use RT::Tickets;
  my $tickets = new RT::Tickets($CurrentUser);

=head1 DESCRIPTION

   A collection of RT::Tickets.

=head1 METHODS

=begin testing

ok (require RT::Tickets);
ok( my $testtickets = RT::Tickets->new( $RT::SystemUser ) );
ok( $testtickets->LimitStatus( VALUE => 'deleted' ) );
# Should be zero until 'allow_deleted_search'
ok( $testtickets->Count == 0 );

=end testing

=cut

package RT::Tickets;

use strict;
no warnings qw(redefine);

use RT::CustomFields;
use DBIx::SearchBuilder::Unique;

# Configuration Tables:

# FIELD_METADATA is a mapping of searchable Field name, to Type, and other
# metadata.

my %FIELD_METADATA = (
    Status          => [ 'ENUM', ],
    Queue           => [ 'ENUM' => 'Queue', ],
    Type            => [ 'ENUM', ],
    Creator         => [ 'ENUM' => 'User', ],
    LastUpdatedBy   => [ 'ENUM' => 'User', ],
    Owner           => [ 'WATCHERFIELD' => 'Owner', ],
    EffectiveId     => [ 'INT', ],
    id              => [ 'INT', ],
    InitialPriority => [ 'INT', ],
    FinalPriority   => [ 'INT', ],
    Priority        => [ 'INT', ],
    TimeLeft        => [ 'INT', ],
    TimeWorked      => [ 'INT', ],
    TimeEstimated   => [ 'INT', ],
    MemberOf        => [ 'LINK' => To => 'MemberOf', ],
    DependsOn       => [ 'LINK' => To => 'DependsOn', ],
    RefersTo        => [ 'LINK' => To => 'RefersTo', ],
    HasMember       => [ 'LINK' => From => 'MemberOf', ],
    DependentOn     => [ 'LINK' => From => 'DependsOn', ],
    DependedOnBy    => [ 'LINK' => From => 'DependsOn', ],
    ReferredToBy    => [ 'LINK' => From => 'RefersTo', ],
    Told             => [ 'DATE'            => 'Told', ],
    Starts           => [ 'DATE'            => 'Starts', ],
    Started          => [ 'DATE'            => 'Started', ],
    Due              => [ 'DATE'            => 'Due', ],
    Resolved         => [ 'DATE'            => 'Resolved', ],
    LastUpdated      => [ 'DATE'            => 'LastUpdated', ],
    Created          => [ 'DATE'            => 'Created', ],
    Subject          => [ 'STRING', ],
    Content          => [ 'TRANSFIELD', ],
    ContentType      => [ 'TRANSFIELD', ],
    Filename         => [ 'TRANSFIELD', ],
    TransactionDate  => [ 'TRANSDATE', ],
    Requestor        => [ 'WATCHERFIELD'    => 'Requestor', ],
    Requestors       => [ 'WATCHERFIELD'    => 'Requestor', ],
    Cc               => [ 'WATCHERFIELD'    => 'Cc', ],
    AdminCc          => [ 'WATCHERFIELD'    => 'AdminCc', ],
    Watcher          => [ 'WATCHERFIELD', ],
    QueueCc          => [ 'WATCHERFIELD'    => 'Cc'      => 'Queue', ],
    QueueAdminCc     => [ 'WATCHERFIELD'    => 'AdminCc' => 'Queue', ],
    QueueWatcher     => [ 'WATCHERFIELD'    => undef     => 'Queue', ],
    LinkedTo         => [ 'LINKFIELD', ],
    CustomFieldValue => [ 'CUSTOMFIELD', ],
    CustomField      => [ 'CUSTOMFIELD', ],
    CF               => [ 'CUSTOMFIELD', ],
    Updated          => [ 'TRANSDATE', ],
    RequestorGroup   => [ 'MEMBERSHIPFIELD' => 'Requestor', ],
    CCGroup          => [ 'MEMBERSHIPFIELD' => 'Cc', ],
    AdminCCGroup     => [ 'MEMBERSHIPFIELD' => 'AdminCc', ],
    WatcherGroup     => [ 'MEMBERSHIPFIELD', ],
    HasAttribute     => [ 'HASATTRIBUTE', 1 ],
    HasNoAttribute     => [ 'HASATTRIBUTE', 0 ],
);

# Mapping of Field Type to Function
my %dispatch = (
    ENUM            => \&_EnumLimit,
    INT             => \&_IntLimit,
    LINK            => \&_LinkLimit,
    DATE            => \&_DateLimit,
    STRING          => \&_StringLimit,
    TRANSFIELD      => \&_TransLimit,
    TRANSDATE       => \&_TransDateLimit,
    WATCHERFIELD    => \&_WatcherLimit,
    MEMBERSHIPFIELD => \&_WatcherMembershipLimit,
    LINKFIELD       => \&_LinkFieldLimit,
    CUSTOMFIELD     => \&_CustomFieldLimit,
    HASATTRIBUTE    => \&_HasAttributeLimit,
);
my %can_bundle = (); # WATCHERFIELD => "yes", );

# Default EntryAggregator per type
# if you specify OP, you must specify all valid OPs
my %DefaultEA = (
    INT  => 'AND',
    ENUM => {
        '='  => 'OR',
        '!=' => 'AND'
    },
    DATE => {
        '='  => 'OR',
        '>=' => 'AND',
        '<=' => 'AND',
        '>'  => 'AND',
        '<'  => 'AND'
    },
    STRING => {
        '='        => 'OR',
        '!='       => 'AND',
        'LIKE'     => 'AND',
        'NOT LIKE' => 'AND'
    },
    TRANSFIELD   => 'AND',
    TRANSDATE    => 'AND',
    LINK         => 'OR',
    LINKFIELD    => 'AND',
    TARGET       => 'AND',
    BASE         => 'AND',
    WATCHERFIELD => {
        '='        => 'OR',
        '!='       => 'AND',
        'LIKE'     => 'OR',
        'NOT LIKE' => 'AND'
    },

    HASATTRIBUTE => {
        '='        => 'AND',
        '!='       => 'AND',
    },

    CUSTOMFIELD => 'OR',
);

# Helper functions for passing the above lexically scoped tables above
# into Tickets_Overlay_SQL.
sub FIELDS     { return \%FIELD_METADATA }
sub dispatch   { return \%dispatch }
sub can_bundle { return \%can_bundle }

# Bring in the clowns.
require RT::Tickets_Overlay_SQL;

# {{{ sub SortFields

our @SORTFIELDS = qw(id Status
    Queue Subject
    Owner Created Due Starts Started
    Told
    Resolved LastUpdated Priority TimeWorked TimeLeft);

=head2 SortFields

Returns the list of fields that lists of tickets can easily be sorted by

=cut

sub SortFields {
    my $self = shift;
    return (@SORTFIELDS);
}

# }}}

# BEGIN SQL STUFF *********************************


sub CleanSlate {
    my $self = shift;
    $self->SUPER::CleanSlate( @_ );
    delete $self->{$_} foreach qw(
        _sql_cf_alias
        _sql_group_members_aliases
        _sql_object_cfv_alias
        _sql_role_group_aliases
        _sql_transalias
        _sql_trattachalias
        _sql_u_watchers_alias_for_sort
        _sql_u_watchers_aliases
    );
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

=head2 _EnumLimit

Handle Fields which are limited to certain values, and potentially
need to be looked up from another class.

This subroutine actually handles two different kinds of fields.  For
some the user is responsible for limiting the values.  (i.e. Status,
Type).

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
        $value = $o->Id;
    }
    $sb->_SQLLimit(
        FIELD    => $field,
        VALUE    => $value,
        OPERATOR => $op,
        @rest,
    );
}

=head2 _IntLimit

Handle fields where the values are limited to integers.  (For example,
Priority, TimeWorked.)

Meta Data:
  None

=cut

sub _IntLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    die "Invalid Operator $op for $field"
        unless $op =~ /^(=|!=|>|<|>=|<=)$/;

    $sb->_SQLLimit(
        FIELD    => $field,
        VALUE    => $value,
        OPERATOR => $op,
        @rest,
    );
}

=head2 _LinkLimit

Handle fields which deal with links between tickets.  (MemberOf, DependsOn)

Meta Data:
  1: Direction (From, To)
  2: Link Type (MemberOf, DependsOn, RefersTo)

=cut

sub _LinkLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    my $meta = $FIELD_METADATA{$field};
    die "Incorrect Metadata for $field"
        unless defined $meta->[1] && defined $meta->[2];

    die "Invalid Operator $op for $field" unless $op =~ /^(=|!=|IS|IS NOT)$/io;

    my $direction = $meta->[1];

    my $matchfield;
    my $linkfield;
    if ( $direction eq 'To' ) {
        $matchfield = "Target";
        $linkfield  = "Base";

    }
    elsif ( $direction eq 'From' ) {
        $linkfield  = "Target";
        $matchfield = "Base";

    }
    else {
        die "Invalid link direction '$meta->[1]' for $field\n";
    }

    my ($is_local, $is_null) = (1, 0);
    if ( !$value || $value =~ /^null$/io ) {
        $is_null = 1;
        $op = ($op =~ /^(=|IS)$/)? 'IS': 'IS NOT';
    }
    elsif ( $value =~ /\D/o ) {
        $is_local = 0;
    }
    $matchfield = "Local$matchfield" if $is_local;

    my $is_negative = 0;
    if ( $op eq '!=' ) {
        $is_negative = 1;
        $op = '=';
    }

#For doing a left join to find "unlinked tickets" we want to generate a query that looks like this
#    SELECT main.* FROM Tickets main
#        LEFT JOIN Links Links_1 ON (     (Links_1.Type = 'MemberOf')
#                                      AND(main.id = Links_1.LocalTarget))
#        WHERE Links_1.LocalBase IS NULL;

    if ($is_null) {
        my $linkalias = $sb->Join(
            TYPE   => 'LEFT',
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'Links',
            FIELD2 => 'Local' . $linkfield
        );
        $sb->SUPER::Limit(
            LEFTJOIN => $linkalias,
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => $meta->[2],
        );
        $sb->_SQLLimit(
            @rest,
            ALIAS      => $linkalias,
            FIELD      => $matchfield,
            OPERATOR   => $op,
            VALUE      => 'NULL',
            QUOTEVALUE => 0,
        );
    }
    elsif ( $is_negative ) {
        my $linkalias = $sb->Join(
            TYPE   => 'LEFT',
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'Links',
            FIELD2 => 'Local' . $linkfield
        );
        $sb->SUPER::Limit(
            LEFTJOIN => $linkalias,
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => $meta->[2],
        );
        $sb->SUPER::Limit(
            LEFTJOIN => $linkalias,
            FIELD    => $matchfield,
            OPERATOR => $op,
            VALUE    => $value,
        );
        $sb->_SQLLimit(
            @rest,
            ALIAS      => $linkalias,
            FIELD      => $matchfield,
            OPERATOR   => 'IS',
            VALUE      => 'NULL',
            QUOTEVALUE => 0,
        );
    }
    else {
        my $linkalias = $sb->NewAlias('Links');
        $sb->_OpenParen();
        $sb->_SQLLimit(
            @rest,
            ALIAS    => $linkalias,
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => $meta->[2],
        );
        $sb->_SQLLimit(
            ALIAS           => $linkalias,
            FIELD           => 'Local' . $linkfield,
            OPERATOR        => '=',
            VALUE           => 'main.id',
            QUOTEVALUE      => 0,
            ENTRYAGGREGATOR => 'AND',
        );
        $sb->_SQLLimit(
            ALIAS           => $linkalias,
            FIELD           => $matchfield,
            OPERATOR        => $op,
            VALUE           => $value,
            ENTRYAGGREGATOR => 'AND',
        );
        $sb->_CloseParen();
    }
}

=head2 _DateLimit

Handle date fields.  (Created, LastTold..)

Meta Data:
  1: type of link.  (Probably not necessary.)

=cut

sub _DateLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    die "Invalid Date Op: $op"
        unless $op =~ /^(=|>|<|>=|<=)$/;

    my $meta = $FIELD_METADATA{$field};
    die "Incorrect Meta Data for $field"
        unless ( defined $meta->[1] );

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

        $sb->_SQLLimit(
            FIELD    => $meta->[1],
            OPERATOR => ">=",
            VALUE    => $daystart,
            @rest,
        );

        $sb->_SQLLimit(
            FIELD    => $meta->[1],
            OPERATOR => "<=",
            VALUE    => $dayend,
            @rest,
            ENTRYAGGREGATOR => 'AND',
        );

        $sb->_CloseParen;

    }
    else {
        $sb->_SQLLimit(
            FIELD    => $meta->[1],
            OPERATOR => $op,
            VALUE    => $date->ISO,
            @rest,
        );
    }
}

=head2 _StringLimit

Handle simple fields which are just strings.  (Subject,Type)

Meta Data:
  None

=cut

sub _StringLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # FIXME:
    # Valid Operators:
    #  =, !=, LIKE, NOT LIKE

    $sb->_SQLLimit(
        FIELD         => $field,
        OPERATOR      => $op,
        VALUE         => $value,
        CASESENSITIVE => 0,
        @rest,
    );
}

=head2 _TransDateLimit

Handle fields limiting based on Transaction Date.

The inpupt value must be in a format parseable by Time::ParseDate

Meta Data:
  None

=cut

# This routine should really be factored into translimit.
sub _TransDateLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # See the comments for TransLimit, they apply here too

    unless ( $sb->{_sql_transalias} ) {
        $sb->{_sql_transalias} = $sb->Join(
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'Transactions',
            FIELD2 => 'ObjectId',
        );
        $sb->SUPER::Limit(
            ALIAS           => $sb->{_sql_transalias},
            FIELD           => 'ObjectType',
            VALUE           => 'RT::Ticket',
            ENTRYAGGREGATOR => 'AND',
        );
    }

    my $date = RT::Date->new( $sb->CurrentUser );
    $date->Set( Format => 'unknown', Value => $value );

    $sb->_OpenParen;
    if ( $op eq "=" ) {

        # if we're specifying =, that means we want everything on a
        # particular single day.  in the database, we need to check for >
        # and < the edges of that day.

        $date->SetToMidnight( Timezone => 'server' );
        my $daystart = $date->ISO;
        $date->AddDay;
        my $dayend = $date->ISO;

        $sb->_SQLLimit(
            ALIAS         => $sb->{_sql_transalias},
            FIELD         => 'Created',
            OPERATOR      => ">=",
            VALUE         => $daystart,
            CASESENSITIVE => 0,
            @rest
        );
        $sb->_SQLLimit(
            ALIAS         => $sb->{_sql_transalias},
            FIELD         => 'Created',
            OPERATOR      => "<=",
            VALUE         => $dayend,
            CASESENSITIVE => 0,
            @rest,
            ENTRYAGGREGATOR => 'AND',
        );

    }

    # not searching for a single day
    else {

        #Search for the right field
        $sb->_SQLLimit(
            ALIAS         => $sb->{_sql_transalias},
            FIELD         => 'Created',
            OPERATOR      => $op,
            VALUE         => $date->ISO,
            CASESENSITIVE => 0,
            @rest
        );
    }

    $sb->_CloseParen;
}

=head2 _TransLimit

Limit based on the Content of a transaction or the ContentType.

Meta Data:
  none

=cut

sub _TransLimit {

    # Content, ContentType, Filename

    # If only this was this simple.  We've got to do something
    # complicated here:

    #Basically, we want to make sure that the limits apply to
    #the same attachment, rather than just another attachment
    #for the same ticket, no matter how many clauses we lump
    #on. We put them in TicketAliases so that they get nuked
    #when we redo the join.

    # In the SQL, we might have
    #       (( Content = foo ) or ( Content = bar AND Content = baz ))
    # The AND group should share the same Alias.

    # Actually, maybe it doesn't matter.  We use the same alias and it
    # works itself out? (er.. different.)

    # Steal more from _ProcessRestrictions

    # FIXME: Maybe look at the previous FooLimit call, and if it was a
    # TransLimit and EntryAggregator == AND, reuse the Aliases?

    # Or better - store the aliases on a per subclause basis - since
    # those are going to be the things we want to relate to each other,
    # anyway.

    # maybe we should not allow certain kinds of aggregation of these
    # clauses and do a psuedo regex instead? - the problem is getting
    # them all into the same subclause when you have (A op B op C) - the
    # way they get parsed in the tree they're in different subclauses.

    my ( $self, $field, $op, $value, @rest ) = @_;

    unless ( $self->{_sql_transalias} ) {
        $self->{_sql_transalias} = $self->Join(
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'Transactions',
            FIELD2 => 'ObjectId',
        );
        $self->SUPER::Limit(
            ALIAS           => $self->{_sql_transalias},
            FIELD           => 'ObjectType',
            VALUE           => 'RT::Ticket',
            ENTRYAGGREGATOR => 'AND',
        );
    }
    unless ( defined $self->{_sql_trattachalias} ) {
        $self->{_sql_trattachalias} = $self->_SQLJoin(
            TYPE   => 'LEFT', # not all txns have an attachment
            ALIAS1 => $self->{_sql_transalias},
            FIELD1 => 'id',
            TABLE2 => 'Attachments',
            FIELD2 => 'TransactionId',
        );
    }

    $self->_OpenParen;

    #Search for the right field
    if ($field eq 'Content' and $RT::DontSearchFileAttachments) {
       $self->_SQLLimit(
			ALIAS         => $self->{_sql_trattachalias},
			FIELD         => 'Filename',
			OPERATOR      => 'IS',
			VALUE         => 'NULL',
			SUBCLAUSE     => 'contentquery',
			ENTRYAGGREGATOR => 'AND',
		       );
       $self->_SQLLimit(
			ALIAS         => $self->{_sql_trattachalias},
			FIELD         => $field,
			OPERATOR      => $op,
			VALUE         => $value,
			CASESENSITIVE => 0,
			@rest,
			ENTRYAGGREGATOR => 'AND',
			SUBCLAUSE     => 'contentquery',
		       );
    } else {
        $self->_SQLLimit(
			ALIAS         => $self->{_sql_trattachalias},
			FIELD         => $field,
			OPERATOR      => $op,
			VALUE         => $value,
			CASESENSITIVE => 0,
			ENTRYAGGREGATOR => 'AND',
			@rest
		);
    }

    $self->_CloseParen;

}

=head2 _WatcherLimit

Handle watcher limits.  (Requestor, CC, etc..)

Meta Data:
  1: Field to query on


=begin testing

# Test to make sure that you can search for tickets by requestor address and
# by requestor name.

my ($id,$msg);
my $u1 = RT::User->new($RT::SystemUser);
($id, $msg) = $u1->Create( Name => 'RequestorTestOne', EmailAddress => 'rqtest1@example.com');
ok ($id,$msg);
my $u2 = RT::User->new($RT::SystemUser);
($id, $msg) = $u2->Create( Name => 'RequestorTestTwo', EmailAddress => 'rqtest2@example.com');
ok ($id,$msg);

my $t1 = RT::Ticket->new($RT::SystemUser);
my ($trans);
($id,$trans,$msg) =$t1->Create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u1->EmailAddress]);
ok ($id, $msg);

my $t2 = RT::Ticket->new($RT::SystemUser);
($id,$trans,$msg) =$t2->Create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u2->EmailAddress]);
ok ($id, $msg);


my $t3 = RT::Ticket->new($RT::SystemUser);
($id,$trans,$msg) =$t3->Create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u2->EmailAddress, $u1->EmailAddress]);
ok ($id, $msg);


my $tix1 = RT::Tickets->new($RT::SystemUser);
$tix1->FromSQL('Requestor.EmailAddress LIKE "rqtest1" OR Requestor.EmailAddress LIKE "rqtest2"');

is ($tix1->Count, 3);

my $tix2 = RT::Tickets->new($RT::SystemUser);
$tix2->FromSQL('Requestor.Name LIKE "TestOne" OR Requestor.Name LIKE "TestTwo"');

is ($tix2->Count, 3);


my $tix3 = RT::Tickets->new($RT::SystemUser);
$tix3->FromSQL('Requestor.EmailAddress LIKE "rqtest1"');

is ($tix3->Count, 2);

my $tix4 = RT::Tickets->new($RT::SystemUser);
$tix4->FromSQL('Requestor.Name LIKE "TestOne" ');

is ($tix4->Count, 2);

# Searching for tickets that have two requestors isn't supported
# There's no way to differentiate "one requestor name that matches foo and bar"
# and "two requestors, one matching foo and one matching bar"

# my $tix5 = RT::Tickets->new($RT::SystemUser);
# $tix5->FromSQL('Requestor.Name LIKE "TestOne" AND Requestor.Name LIKE "TestTwo"');
# 
# is ($tix5->Count, 1);
# 
# my $tix6 = RT::Tickets->new($RT::SystemUser);
# $tix6->FromSQL('Requestor.EmailAddress LIKE "rqtest1" AND Requestor.EmailAddress LIKE "rqtest2"');
# 
# is ($tix6->Count, 1);


=end testing

=cut

sub _WatcherLimit {
    my $self  = shift;
    my $field = shift;
    my $op    = shift;
    my $value = shift;
    my %rest  = (@_);

    my $meta = $FIELD_METADATA{ $field };
    my $type = $meta->[1] || '';
    my $class = $meta->[2] || 'Ticket';

    # Owner was ENUM field, so "Owner = 'xxx'" allowed user to
    # search by id and Name at the same time, this is workaround
    # to preserve backward compatibility
    if ( $field eq 'Owner' && !$rest{SUBKEY} && $op =~ /^!?=$/ ) {
        my $o = RT::User->new( $self->CurrentUser );
        $o->Load( $value );
        $self->_SQLLimit(
            FIELD    => 'Owner',
            OPERATOR => $op,
            VALUE    => $o->Id,
            %rest,
        );
        return;
    }
    $rest{SUBKEY} ||= 'EmailAddress';

    my $groups = $self->_RoleGroupsJoin( Type => $type, Class => $class );

    $self->_OpenParen;
    if ( $op =~ /^IS(?: NOT)?$/ ) {
        my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
        # to avoid joining the table Users into the query, we just join GM
        # and make sure we don't match records where group is member of itself
        $self->SUPER::Limit(
            LEFTJOIN   => $group_members,
            FIELD      => 'GroupId',
            OPERATOR   => '!=',
            VALUE      => "$group_members.MemberId",
            QUOTEVALUE => 0,
        );
        $self->_SQLLimit(
            ALIAS         => $group_members,
            FIELD         => 'GroupId',
            OPERATOR      => $op,
            VALUE         => $value,
            %rest,
        );
    }
    elsif ( $op =~ /^!=$|^NOT\s+/i ) {
        # reverse op
        $op =~ s/!|NOT\s+//i;

        # XXX: we have no way to build correct "Watcher.X != 'Y'" when condition
        # "X = 'Y'" matches more then one user so we try to fetch two records and
        # do the right thing when there is only one exist and semi-working solution
        # otherwise.
        my $users_obj = RT::Users->new( $self->CurrentUser );
        $users_obj->Limit(
            FIELD         => $rest{SUBKEY},
            OPERATOR      => $op,
            VALUE         => $value,
        );
        $users_obj->OrderBy;
        $users_obj->RowsPerPage(2);
        my @users = @{ $users_obj->ItemsArrayRef };

        my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
        if ( @users <= 1 ) {
            my $uid = 0;
            $uid = $users[0]->id if @users;
            $self->SUPER::Limit(
                LEFTJOIN      => $group_members,
                ALIAS         => $group_members,
                FIELD         => 'MemberId',
                VALUE         => $uid,
            );
            $self->_SQLLimit(
                %rest,
                ALIAS           => $group_members,
                FIELD           => 'id',
                OPERATOR        => 'IS',
                VALUE           => 'NULL',
            );
        } else {
            $self->SUPER::Limit(
                LEFTJOIN   => $group_members,
                FIELD      => 'GroupId',
                OPERATOR   => '!=',
                VALUE      => "$group_members.MemberId",
                QUOTEVALUE => 0,
            );
            my $users = $self->Join(
                TYPE            => 'LEFT',
                ALIAS1          => $group_members,
                FIELD1          => 'MemberId',
                TABLE2          => 'Users',
                FIELD2          => 'id',
            );
            $self->SUPER::Limit(
                LEFTJOIN      => $users,
                ALIAS         => $users,
                FIELD         => $rest{SUBKEY},
                OPERATOR      => $op,
                VALUE         => $value,
                CASESENSITIVE => 0,
            );
            $self->_SQLLimit(
                %rest,
                ALIAS         => $users,
                FIELD         => 'id',
                OPERATOR      => 'IS',
                VALUE         => 'NULL',
            );
        }
    } else {
        my $group_members = $self->_GroupMembersJoin(
            GroupsAlias => $groups,
            New => 0,
        );

        my $users = $self->{'_sql_u_watchers_aliases'}{$group_members};
        unless ( $users ) {
            $users = $self->{'_sql_u_watchers_aliases'}{$group_members} = 
                $self->NewAlias('Users');
            $self->SUPER::Limit(
                LEFTJOIN      => $group_members,
                ALIAS         => $group_members,
                FIELD         => 'MemberId',
                VALUE         => "$users.id",
                QUOTEVALUE    => 0,
            );
        }

        # we join users table without adding some join condition between tables,
        # the only conditions we have are conditions on the table iteslf,
        # for example Users.EmailAddress = 'x'. We should add this condition to
        # the top level of the query and bundle it with another similar conditions,
        # for example "Users.EmailAddress = 'x' OR Users.EmailAddress = 'Y'".
        # To achive this goal we use own SUBCLAUSE for conditions on the users table.
        $self->SUPER::Limit(
            %rest,
            SUBCLAUSE       => '_sql_u_watchers_'. $users,
            ALIAS           => $users,
            FIELD           => $rest{'SUBKEY'},
            VALUE           => $value,
            OPERATOR        => $op,
            CASESENSITIVE   => 0,
        );
        # A condition which ties Users and Groups (role groups) is a left join condition
        # of CachedGroupMembers table. To get correct results of the query we check
        # if there are matches in CGM table or not using 'cgm.id IS NOT NULL'.
        $self->_SQLLimit(
            %rest,
            ALIAS           => $group_members,
            FIELD           => 'id',
            OPERATOR        => 'IS NOT',
            VALUE           => 'NULL',
        );
    }
    $self->_CloseParen;
}

sub _RoleGroupsJoin {
    my $self = shift;
    my %args = (New => 0, Class => 'Ticket', Type => '', @_);
    return $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} }
        if $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} }
           && !$args{'New'};

    # XXX: this has been fixed in DBIx::SB-1.48
    # XXX: if we change this from Join to NewAlias+Limit
    # then Pg and mysql 5.x will complain because SB build wrong query.
    # Query looks like "FROM (Tickets LEFT JOIN CGM ON(Groups.id = CGM.GroupId)), Groups"
    # Pg doesn't like that fact that it doesn't know about Groups table yet when
    # join CGM table into Tickets. Problem is in Join method which doesn't use
    # ALIAS1 argument when build braces.

    # we always have watcher groups for ticket, so we use INNER join
    my $groups = $self->Join(
        ALIAS1          => 'main',
        FIELD1          => $args{'Class'} eq 'Queue'? 'Queue': 'id',
        TABLE2          => 'Groups',
        FIELD2          => 'Instance',
        ENTRYAGGREGATOR => 'AND',
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $groups,
        ALIAS           => $groups,
        FIELD           => 'Domain',
        VALUE           => 'RT::'. $args{'Class'} .'-Role',
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $groups,
        ALIAS           => $groups,
        FIELD           => 'Type',
        VALUE           => $args{'Type'},
    ) if $args{'Type'};

    $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} } = $groups
        unless $args{'New'};

    return $groups;
}

sub _GroupMembersJoin {
    my $self = shift;
    my %args = (New => 1, GroupsAlias => undef, @_);

    return $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} }
        if $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} }
            && !$args{'New'};

    my $alias = $self->Join(
        TYPE            => 'LEFT',
        ALIAS1          => $args{'GroupsAlias'},
        FIELD1          => 'id',
        TABLE2          => 'CachedGroupMembers',
        FIELD2          => 'GroupId',
        ENTRYAGGREGATOR => 'AND',
    );

    $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} } = $alias
        unless $args{'New'};

    return $alias;
}

=head2 _WatcherJoin

Helper function which provides joins to a watchers table both for limits
and for ordering.

=cut

sub _WatcherJoin {
    my $self = shift;
    my $type = shift || '';


    my $groups = $self->_RoleGroupsJoin( Type => $type );
    my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
    # XXX: work around, we must hide groups that
    # are members of the role group we search in,
    # otherwise them result in wrong NULLs in Users
    # table and break ordering. Now, we know that
    # RT doesn't allow to add groups as members of the
    # ticket roles, so we just hide entries in CGM table
    # with MemberId == GroupId from results
    $self->SUPER::Limit(
        LEFTJOIN   => $group_members,
        FIELD      => 'GroupId',
        OPERATOR   => '!=',
        VALUE      => "$group_members.MemberId",
        QUOTEVALUE => 0,
    );
    my $users = $self->Join(
        TYPE            => 'LEFT',
        ALIAS1          => $group_members,
        FIELD1          => 'MemberId',
        TABLE2          => 'Users',
        FIELD2          => 'id',
    );
    return ($groups, $group_members, $users);
}

=head2 _WatcherMembershipLimit

Handle watcher membership limits, i.e. whether the watcher belongs to a
specific group or not.

Meta Data:
  1: Field to query on

SELECT DISTINCT main.*
FROM
    Tickets main,
    Groups Groups_1,
    CachedGroupMembers CachedGroupMembers_2,
    Users Users_3
WHERE (
    (main.EffectiveId = main.id)
) AND (
    (main.Status != 'deleted')
) AND (
    (main.Type = 'ticket')
) AND (
    (
	(Users_3.EmailAddress = '22')
	    AND
	(Groups_1.Domain = 'RT::Ticket-Role')
	    AND
	(Groups_1.Type = 'RequestorGroup')
    )
) AND
    Groups_1.Instance = main.id
AND
    Groups_1.id = CachedGroupMembers_2.GroupId
AND
    CachedGroupMembers_2.MemberId = Users_3.id
ORDER BY main.id ASC
LIMIT 25

=cut

sub _WatcherMembershipLimit {
    my ( $self, $field, $op, $value, @rest ) = @_;
    my %rest = @rest;

    $self->_OpenParen;

    my $groups       = $self->NewAlias('Groups');
    my $groupmembers = $self->NewAlias('CachedGroupMembers');
    my $users        = $self->NewAlias('Users');
    my $memberships  = $self->NewAlias('CachedGroupMembers');

    if ( ref $field ) {    # gross hack
        my @bundle = @$field;
        $self->_OpenParen;
        for my $chunk (@bundle) {
            ( $field, $op, $value, @rest ) = @$chunk;
            $self->_SQLLimit(
                ALIAS    => $memberships,
                FIELD    => 'GroupId',
                VALUE    => $value,
                OPERATOR => $op,
                @rest,
            );
        }
        $self->_CloseParen;
    }
    else {
        $self->_SQLLimit(
            ALIAS    => $memberships,
            FIELD    => 'GroupId',
            VALUE    => $value,
            OPERATOR => $op,
            @rest,
        );
    }

    # {{{ Tie to groups for tickets we care about
    $self->_SQLLimit(
        ALIAS           => $groups,
        FIELD           => 'Domain',
        VALUE           => 'RT::Ticket-Role',
        ENTRYAGGREGATOR => 'AND'
    );

    $self->Join(
        ALIAS1 => $groups,
        FIELD1 => 'Instance',
        ALIAS2 => 'main',
        FIELD2 => 'id'
    );

    # }}}

    # If we care about which sort of watcher
    my $meta = $FIELD_METADATA{$field};
    my $type = ( defined $meta->[1] ? $meta->[1] : undef );

    if ($type) {
        $self->_SQLLimit(
            ALIAS           => $groups,
            FIELD           => 'Type',
            VALUE           => $type,
            ENTRYAGGREGATOR => 'AND'
        );
    }

    $self->Join(
        ALIAS1 => $groups,
        FIELD1 => 'id',
        ALIAS2 => $groupmembers,
        FIELD2 => 'GroupId'
    );

    $self->Join(
        ALIAS1 => $groupmembers,
        FIELD1 => 'MemberId',
        ALIAS2 => $users,
        FIELD2 => 'id'
    );

    $self->Join(
        ALIAS1 => $memberships,
        FIELD1 => 'MemberId',
        ALIAS2 => $users,
        FIELD2 => 'id'
    );

    $self->_CloseParen;

}

sub _LinkFieldLimit {
    my $restriction;
    my $self;
    my $LinkAlias;
    my %args;
    if ( $restriction->{'TYPE'} ) {
        $self->SUPER::Limit(
            ALIAS           => $LinkAlias,
            ENTRYAGGREGATOR => 'AND',
            FIELD           => 'Type',
            OPERATOR        => '=',
            VALUE           => $restriction->{'TYPE'}
        );
    }

    #If we're trying to limit it to things that are target of
    if ( $restriction->{'TARGET'} ) {

        # If the TARGET is an integer that means that we want to look at
        # the LocalTarget field. otherwise, we want to look at the
        # "Target" field
        my ($matchfield);
        if ( $restriction->{'TARGET'} =~ /^(\d+)$/ ) {
            $matchfield = "LocalTarget";
        }
        else {
            $matchfield = "Target";
        }
        $self->SUPER::Limit(
            ALIAS           => $LinkAlias,
            ENTRYAGGREGATOR => 'AND',
            FIELD           => $matchfield,
            OPERATOR        => '=',
            VALUE           => $restriction->{'TARGET'}
        );

        #If we're searching on target, join the base to ticket.id
        $self->_SQLJoin(
            ALIAS1 => 'main',
            FIELD1 => $self->{'primary_key'},
            ALIAS2 => $LinkAlias,
            FIELD2 => 'LocalBase'
        );
    }

    #If we're trying to limit it to things that are base of
    elsif ( $restriction->{'BASE'} ) {

        # If we're trying to match a numeric link, we want to look at
        # LocalBase, otherwise we want to look at "Base"
        my ($matchfield);
        if ( $restriction->{'BASE'} =~ /^(\d+)$/ ) {
            $matchfield = "LocalBase";
        }
        else {
            $matchfield = "Base";
        }

        $self->SUPER::Limit(
            ALIAS           => $LinkAlias,
            ENTRYAGGREGATOR => 'AND',
            FIELD           => $matchfield,
            OPERATOR        => '=',
            VALUE           => $restriction->{'BASE'}
        );

        #If we're searching on base, join the target to ticket.id
        $self->_SQLJoin(
            ALIAS1 => 'main',
            FIELD1 => $self->{'primary_key'},
            ALIAS2 => $LinkAlias,
            FIELD2 => 'LocalTarget'
        );
    }
}


=head2 _CustomFieldDecipher

Try and turn a CF descriptor into (cfid, cfname) object pair.

=cut

sub _CustomFieldDecipher {
    my ($self, $field) = @_;
 
    my $queue = undef;
    if ( $field =~ /^(.+?)\.{(.+)}$/ ) {
        ($queue, $field) = ($1, $2);
    }
    $field = $1 if $field =~ /^{(.+)}$/;    # trim { }

    my $cfid;
    if ( $queue ) {
        my $q = RT::Queue->new( $self->CurrentUser );
        $q->Load( $queue );

        my $cf;
        if ( $q->id ) {
            # $queue = $q->Name; # should we normalize the queue?
            $cf = $q->CustomField( $field );
        }
        else {
            $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->LoadByNameAndQueue( Queue => 0, Name => $field );
        }
        return ($queue, $field, $cf->id, $cf)
            if $cf && $cf->id;
        return ($queue, $field);
    }

    my $cfs = RT::CustomFields->new( $self->CurrentUser );
    $cfs->Limit( FIELD => 'Name', VALUE => $field );
    $cfs->LimitToLookupType('RT::Queue-RT::Ticket');
    my $count = $cfs->Count;
    return (undef, $field, undef) if $count > 1;
    return (undef, $field, 0) if $count == 0;
    my $cf = $cfs->First;
    return (undef, $field, $cf->id, $cf) if $cf && $cf->id;
    return (undef, $field, undef);
}
 
=head2 _CustomFieldJoin

Factor out the Join of custom fields so we can use it for sorting too

=cut

sub _CustomFieldJoin {
    my ($self, $cfkey, $cfid, $field) = @_;
    # Perform one Join per CustomField
    if ( $self->{_sql_object_cfv_alias}{$cfkey} ||
         $self->{_sql_cf_alias}{$cfkey} )
    {
        return ( $self->{_sql_object_cfv_alias}{$cfkey},
                 $self->{_sql_cf_alias}{$cfkey} );
    }

    my ($TicketCFs, $CFs);
    if ( $cfid ) {
        $TicketCFs = $self->{_sql_object_cfv_alias}{$cfkey} = $self->Join(
            TYPE   => 'LEFT',
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'ObjectCustomFieldValues',
            FIELD2 => 'ObjectId',
        );
        $self->SUPER::Limit(
            LEFTJOIN        => $TicketCFs,
            FIELD           => 'CustomField',
            VALUE           => $cfid,
            ENTRYAGGREGATOR => 'AND'
        );
    }
    else {
        my $ocfalias = $self->Join(
            TYPE       => 'LEFT',
            FIELD1     => 'Queue',
            TABLE2     => 'ObjectCustomFields',
            FIELD2     => 'ObjectId',
        );

        $self->SUPER::Limit(
            LEFTJOIN        => $ocfalias,
            ENTRYAGGREGATOR => 'OR',
            FIELD           => 'ObjectId',
            VALUE           => '0',
        );

        $CFs = $self->{_sql_cf_alias}{$cfkey} = $self->Join(
            TYPE       => 'LEFT',
            ALIAS1     => $ocfalias,
            FIELD1     => 'CustomField',
            TABLE2     => 'CustomFields',
            FIELD2     => 'id',
        );
        $self->SUPER::Limit(
            LEFTJOIN        => $CFs,
            ENTRYAGGREGATOR => 'AND',
            FIELD           => 'LookupType',
            VALUE           => 'RT::Queue-RT::Ticket',
        );
        $self->SUPER::Limit(
            LEFTJOIN        => $CFs,
            ENTRYAGGREGATOR => 'AND',
            FIELD           => 'Name',
            VALUE           => $field,
        );

        $TicketCFs = $self->{_sql_object_cfv_alias}{$cfkey} = $self->Join(
            TYPE   => 'LEFT',
            ALIAS1 => $CFs,
            FIELD1 => 'id',
            TABLE2 => 'ObjectCustomFieldValues',
            FIELD2 => 'CustomField',
        );
        $self->SUPER::Limit(
            LEFTJOIN        => $TicketCFs,
            FIELD           => 'ObjectId',
            VALUE           => 'main.id',
            QUOTEVALUE      => 0,
            ENTRYAGGREGATOR => 'AND',
        );
    }
    $self->SUPER::Limit(
        LEFTJOIN        => $TicketCFs,
        FIELD           => 'ObjectType',
        VALUE           => 'RT::Ticket',
        ENTRYAGGREGATOR => 'AND'
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $TicketCFs,
        FIELD           => 'Disabled',
        OPERATOR        => '=',
        VALUE           => '0',
        ENTRYAGGREGATOR => 'AND'
    );

    return ($TicketCFs, $CFs);
}

=head2 _CustomFieldLimit

Limit based on CustomFields

Meta Data:
  none

=cut

sub _CustomFieldLimit {
    my ( $self, $_field, $op, $value, @rest ) = @_;

    my %rest  = @rest;
    my $field = $rest{SUBKEY} || die "No field specified";

    # For our sanity, we can only limit on one queue at a time

    my ($queue, $cfid);
    ($queue, $field, $cfid ) = $self->_CustomFieldDecipher( $field );

# If we're trying to find custom fields that don't match something, we
# want tickets where the custom field has no value at all.  Note that
# we explicitly don't include the "IS NULL" case, since we would
# otherwise end up with a redundant clause.

    my $null_columns_ok;
    if ( ( $op =~ /^NOT LIKE$/i ) or ( $op eq '!=' ) ) {
        $null_columns_ok = 1;
    }

    my $cfkey = $cfid ? $cfid : "$queue.$field";
    my ($TicketCFs, $CFs) = $self->_CustomFieldJoin( $cfkey, $cfid, $field );

    $self->_OpenParen;

    $self->_OpenParen;
    $self->_SQLLimit(
        ALIAS      => $TicketCFs,
        FIELD      => 'Content',
        OPERATOR   => $op,
        VALUE      => $value,
        @rest
    );

    # XXX: if we join via CustomFields table then
    # because of order of left joins we get NULLs in
    # CF table and then get nulls for those records
    # in OCFVs table what result in wrong results
    # as decifer method now tries to load a CF then
    # we fall into this situation only when there
    # are more than one CF with the name in the DB.
    # the same thing applies to order by call.
    # TODO: reorder joins T <- OCFVs <- CFs <- OCFs if
    # we want treat IS NULL as (not applies or has
    # no value)
    $self->_SQLLimit(
        ALIAS      => $CFs,
        FIELD      => 'Name',
        OPERATOR   => 'IS NOT',
        VALUE      => 'NULL',
        QUOTEVALUE => 0,
        ENTRYAGGREGATOR => 'AND',
    ) if $CFs;
    $self->_CloseParen;

    if ($null_columns_ok) {
        $self->_SQLLimit(
            ALIAS           => $TicketCFs,
            FIELD           => 'Content',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
            QUOTEVALUE      => 0,
            ENTRYAGGREGATOR => 'OR',
        );
    }

    $self->_CloseParen;

}

sub _HasAttributeLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;

    my $alias = $self->Join(
        TYPE   => 'LEFT',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'Attributes',
        FIELD2 => 'ObjectId',
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $alias,
        FIELD           => 'ObjectType',
        VALUE           => 'RT::Ticket',
        ENTRYAGGREGATOR => 'AND'
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $alias,
        FIELD           => 'Name',
        OPERATOR        => $op,
        VALUE           => $value,
        ENTRYAGGREGATOR => 'AND'
    );
    $self->_SQLLimit(
        %rest,
        ALIAS      => $alias,
        FIELD      => 'id',
        OPERATOR   => $FIELD_METADATA{$field}->[1]? 'IS NOT': 'IS',
        VALUE      => 'NULL',
        QUOTEVALUE => 0,
    );
}


# End Helper Functions

# End of SQL Stuff -------------------------------------------------

# {{{ Allow sorting on watchers

=head2 OrderByCols ARRAY

A modified version of the OrderBy method which automatically joins where
C<ALIAS> is set to the name of a watcher type.

=cut

sub OrderByCols {
    my $self = shift;
    my @args = @_;
    my $clause;
    my @res   = ();
    my $order = 0;

    foreach my $row (@args) {
        if ( $row->{ALIAS} ) {
            push @res, $row;
            next;
        }
        if ( $row->{FIELD} !~ /\./ ) {
            my $meta = $self->FIELDS->{ $row->{FIELD} };
            unless ( $meta ) {
                push @res, $row;
                next;
            }

            if ( $meta->[0] eq 'ENUM' && ($meta->[1]||'') eq 'Queue' ) {
                my $alias = $self->Join(
                    TYPE   => 'LEFT',
                    ALIAS1 => 'main',
                    FIELD1 => $row->{'FIELD'},
                    TABLE2 => 'Queues',
                    FIELD2 => 'id',
                );
                push @res, { %$row, ALIAS => $alias, FIELD => "Name" };
            } elsif ( ( $meta->[0] eq 'ENUM' && ($meta->[1]||'') eq 'User' )
                || ( $meta->[0] eq 'WATCHERFIELD' && ($meta->[1]||'') eq 'Owner' )
            ) {
                my $alias = $self->Join(
                    TYPE   => 'LEFT',
                    ALIAS1 => 'main',
                    FIELD1 => $row->{'FIELD'},
                    TABLE2 => 'Users',
                    FIELD2 => 'id',
                );
                push @res, { %$row, ALIAS => $alias, FIELD => "Name" };
            } else {
                push @res, $row;
            }
            next;
        }

        my ( $field, $subkey ) = split /\./, $row->{FIELD}, 2;
        my $meta = $self->FIELDS->{$field};
        if ( $meta->[0] eq 'WATCHERFIELD' ) {
            # cache alias as we want to use one alias per watcher type for sorting
            my $users = $self->{_sql_u_watchers_alias_for_sort}{ $meta->[1] };
            unless ( $users ) {
                $self->{_sql_u_watchers_alias_for_sort}{ $meta->[1] }
                    = $users = ( $self->_WatcherJoin( $meta->[1] ) )[2];
            }
            push @res, { %$row, ALIAS => $users, FIELD => $subkey };
       } elsif ( $meta->[0] eq 'CUSTOMFIELD' ) {
           my ($queue, $field, $cfid, $cf_obj) = $self->_CustomFieldDecipher( $subkey );
           my $cfkey = $cfid ? $cfid : "$queue.$field";
           $cfkey .= ".ordering" if !$cf_obj || ($cf_obj->MaxValues||0) != 1;
           my ($TicketCFs, $CFs) = $self->_CustomFieldJoin( $cfkey, $cfid, $field );
           # this is described in _CustomFieldLimit
           $self->_SQLLimit(
               ALIAS      => $CFs,
               FIELD      => 'Name',
               OPERATOR   => 'IS NOT',
               VALUE      => 'NULL',
               QUOTEVALUE => 1,
               ENTRYAGGREGATOR => 'AND',
           ) if $CFs;
           unless ($cfid) {
               # For those cases where we are doing a join against the
               # CF name, and don't have a CFid, use Unique to make sure
               # we don't show duplicate tickets.  NOTE: I'm pretty sure
               # this will stay mixed in for the life of the
               # class/package, and not just for the life of the object.
               # Potential performance issue.
               require DBIx::SearchBuilder::Unique;
               DBIx::SearchBuilder::Unique->import;
           }
           my $CFvs = $self->Join(
               TYPE   => 'LEFT',
               ALIAS1 => $TicketCFs,
               FIELD1 => 'CustomField',
               TABLE2 => 'CustomFieldValues',
               FIELD2 => 'CustomField',
           );
           $self->SUPER::Limit(
               LEFTJOIN        => $CFvs,
               FIELD           => 'Name',
               QUOTEVALUE      => 0,
               VALUE           => $TicketCFs . ".Content",
               ENTRYAGGREGATOR => 'AND'
           );

           push @res, { %$row, ALIAS => $CFvs, FIELD => 'SortOrder' };
           push @res, { %$row, ALIAS => $TicketCFs, FIELD => 'Content' };
       } elsif ( $field eq "Custom" && $subkey eq "Ownership") {
           # PAW logic is "reversed"
           my $order = "ASC";
           if (exists $row->{ORDER} ) {
               my $o = $row->{ORDER};
               delete $row->{ORDER};
               $order = "DESC" if $o =~ /asc/i;
           }

           # Unowned
           # Else

           # Ticket.Owner  1 0 0
           my $ownerId = $self->CurrentUser->Id;
           push @res, { %$row, FIELD => "Owner=$ownerId", ORDER => $order } ;

           # Unowned Tickets 0 1 0
           my $nobodyId = $RT::Nobody->Id;
           push @res, { %$row, FIELD => "Owner=$nobodyId", ORDER => $order } ;

           push @res, { %$row, FIELD => "Priority", ORDER => $order } ;
       }
       else {
           push @res, $row;
       }
    }
    return $self->SUPER::OrderByCols(@res);
}

# }}}

# {{{ Limit the result set based on content

# {{{ sub Limit

=head2 Limit

Takes a paramhash with the fields FIELD, OPERATOR, VALUE and DESCRIPTION
Generally best called from LimitFoo methods

=cut

sub Limit {
    my $self = shift;
    my %args = (
        FIELD       => undef,
        OPERATOR    => '=',
        VALUE       => undef,
        DESCRIPTION => undef,
        @_
    );
    $args{'DESCRIPTION'} = $self->loc(
        "[_1] [_2] [_3]",  $args{'FIELD'},
        $args{'OPERATOR'}, $args{'VALUE'}
        )
        if ( !defined $args{'DESCRIPTION'} );

    my $index = $self->_NextIndex;

# make the TicketRestrictions hash the equivalent of whatever we just passed in;

    %{ $self->{'TicketRestrictions'}{$index} } = %args;

    $self->{'RecalcTicketLimits'} = 1;

# If we're looking at the effective id, we don't want to append the other clause
# which limits us to tickets where id = effective id
    if ( $args{'FIELD'} eq 'EffectiveId'
        && ( !$args{'ALIAS'} || $args{'ALIAS'} eq 'main' ) )
    {
        $self->{'looking_at_effective_id'} = 1;
    }

    if ( $args{'FIELD'} eq 'Type'
        && ( !$args{'ALIAS'} || $args{'ALIAS'} eq 'main' ) )
    {
        $self->{'looking_at_type'} = 1;
    }

    return ($index);
}

# }}}

=head2 FreezeLimits

Returns a frozen string suitable for handing back to ThawLimits.

=cut

sub _FreezeThawKeys {
    'TicketRestrictions', 'restriction_index', 'looking_at_effective_id',
        'looking_at_type';
}

# {{{ sub FreezeLimits

sub FreezeLimits {
    my $self = shift;
    require Storable;
    require MIME::Base64;
    MIME::Base64::base64_encode(
        Storable::freeze( \@{$self}{ $self->_FreezeThawKeys } ) );
}

# }}}

=head2 ThawLimits

Take a frozen Limits string generated by FreezeLimits and make this tickets
object have that set of limits.

=cut

# {{{ sub ThawLimits

sub ThawLimits {
    my $self = shift;
    my $in   = shift;

    #if we don't have $in, get outta here.
    return undef unless ($in);

    $self->{'RecalcTicketLimits'} = 1;

    require Storable;
    require MIME::Base64;

    #We don't need to die if the thaw fails.
    @{$self}{ $self->_FreezeThawKeys }
        = eval { @{ Storable::thaw( MIME::Base64::base64_decode($in) ) }; };

    $RT::Logger->error($@) if $@;

}

# }}}

# {{{ Limit by enum or foreign key

# {{{ sub LimitQueue

=head2 LimitQueue

LimitQueue takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=. (It defaults to =).
VALUE is a queue id or Name.


=cut

sub LimitQueue {
    my $self = shift;
    my %args = (
        VALUE    => undef,
        OPERATOR => '=',
        @_
    );

    #TODO  VALUE should also take queue objects
    if ( defined $args{'VALUE'} && $args{'VALUE'} !~ /^\d+$/ ) {
        my $queue = new RT::Queue( $self->CurrentUser );
        $queue->Load( $args{'VALUE'} );
        $args{'VALUE'} = $queue->Id;
    }

    # What if they pass in an Id?  Check for isNum() and convert to
    # string.

    #TODO check for a valid queue here

    $self->Limit(
        FIELD       => 'Queue',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join(
            ' ', $self->loc('Queue'), $args{'OPERATOR'}, $args{'VALUE'},
        ),
    );

}

# }}}

# {{{ sub LimitStatus

=head2 LimitStatus

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a status.

RT adds Status != 'deleted' until object has
allow_deleted_search internal property set.
$tickets->{'allow_deleted_search'} = 1;
$tickets->LimitStatus( VALUE => 'deleted' );

=cut

sub LimitStatus {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        @_
    );
    $self->Limit(
        FIELD       => 'Status',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Status'), $args{'OPERATOR'},
            $self->loc( $args{'VALUE'} ) ),
    );
}

# }}}

# {{{ sub IgnoreType

=head2 IgnoreType

If called, this search will not automatically limit the set of results found
to tickets of type "Ticket". Tickets of other types, such as "project" and
"approval" will be found.

=cut

sub IgnoreType {
    my $self = shift;

    # Instead of faking a Limit that later gets ignored, fake up the
    # fact that we're already looking at type, so that the check in
    # Tickets_Overlay_SQL/FromSQL goes down the right branch

    #  $self->LimitType(VALUE => '__any');
    $self->{looking_at_type} = 1;
}

# }}}

# {{{ sub LimitType

=head2 LimitType

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=, it defaults to "=".
VALUE is a string to search for in the type of the ticket.



=cut

sub LimitType {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        VALUE    => undef,
        @_
    );
    $self->Limit(
        FIELD       => 'Type',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Type'), $args{'OPERATOR'}, $args{'Limit'}, ),
    );
}

# }}}

# }}}

# {{{ Limit by string field

# {{{ sub LimitSubject

=head2 LimitSubject

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a string to search for in the subject of the ticket.

=cut

sub LimitSubject {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'Subject',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Subject'), $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}

# }}}

# }}}

# {{{ Limit based on ticket numerical attributes
# Things that can be > < = !=

# {{{ sub LimitId

=head2 LimitId

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a ticket Id to search for

=cut

sub LimitId {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        @_
    );

    $self->Limit(
        FIELD       => 'id',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION =>
            join( ' ', $self->loc('Id'), $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}

# }}}

# {{{ sub LimitPriority

=head2 LimitPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket\'s priority against

=cut

sub LimitPriority {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'Priority',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Priority'),
            $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}

# }}}

# {{{ sub LimitInitialPriority

=head2 LimitInitialPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket\'s initial priority against


=cut

sub LimitInitialPriority {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'InitialPriority',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Initial Priority'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}

# }}}

# {{{ sub LimitFinalPriority

=head2 LimitFinalPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket\'s final priority against

=cut

sub LimitFinalPriority {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'FinalPriority',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Final Priority'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}

# }}}

# {{{ sub LimitTimeWorked

=head2 LimitTimeWorked

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's TimeWorked attribute

=cut

sub LimitTimeWorked {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'TimeWorked',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Time Worked'),
            $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}

# }}}

# {{{ sub LimitTimeLeft

=head2 LimitTimeLeft

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's TimeLeft attribute

=cut

sub LimitTimeLeft {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'TimeLeft',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Time Left'),
            $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}

# }}}

# }}}

# {{{ Limiting based on attachment attributes

# {{{ sub LimitContent

=head2 LimitContent

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, LIKE, NOT LIKE or !=.
VALUE is a string to search for in the body of the ticket

=cut

sub LimitContent {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'Content',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Ticket content'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}

# }}}

# {{{ sub LimitFilename

=head2 LimitFilename

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, LIKE, NOT LIKE or !=.
VALUE is a string to search for in the body of the ticket

=cut

sub LimitFilename {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'Filename',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Attachment filename'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}

# }}}
# {{{ sub LimitContentType

=head2 LimitContentType

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, LIKE, NOT LIKE or !=.
VALUE is a content type to search ticket attachments for

=cut

sub LimitContentType {
    my $self = shift;
    my %args = (@_);
    $self->Limit(
        FIELD       => 'ContentType',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Ticket content type'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}

# }}}

# }}}

# {{{ Limiting based on people

# {{{ sub LimitOwner

=head2 LimitOwner

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a user id.

=cut

sub LimitOwner {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        @_
    );

    my $owner = new RT::User( $self->CurrentUser );
    $owner->Load( $args{'VALUE'} );

    # FIXME: check for a valid $owner
    $self->Limit(
        FIELD       => 'Owner',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Owner'), $args{'OPERATOR'}, $owner->Name(), ),
    );

}

# }}}

# {{{ Limiting watchers

# {{{ sub LimitWatcher

=head2 LimitWatcher

  Takes a paramhash with the fields OPERATOR, TYPE and VALUE.
  OPERATOR is one of =, LIKE, NOT LIKE or !=.
  VALUE is a value to match the ticket\'s watcher email addresses against
  TYPE is the sort of watchers you want to match against. Leave it undef if you want to search all of them

=begin testing

my $t1 = RT::Ticket->new($RT::SystemUser);
$t1->Create(Queue => 'general', Subject => "LimitWatchers test", Requestors => \['requestor1@example.com']);

=end testing

=cut

sub LimitWatcher {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        VALUE    => undef,
        TYPE     => undef,
        @_
    );

    #build us up a description
    my ( $watcher_type, $desc );
    if ( $args{'TYPE'} ) {
        $watcher_type = $args{'TYPE'};
    }
    else {
        $watcher_type = "Watcher";
    }

    $self->Limit(
        FIELD       => $watcher_type,
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        TYPE        => $args{'TYPE'},
        DESCRIPTION => join( ' ',
            $self->loc($watcher_type),
            $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}

sub LimitRequestor {
    my $self = shift;
    my %args = (@_);
    $RT::Logger->error( "Tickets->LimitRequestor is deprecated  at ("
            . join( ":", caller )
            . ")" );
    $self->LimitWatcher( TYPE => 'Requestor', @_ );

}

# }}}

# }}}

# }}}

# {{{ Limiting based on links

# {{{ LimitLinkedTo

=head2 LimitLinkedTo

LimitLinkedTo takes a paramhash with two fields: TYPE and TARGET
TYPE limits the sort of link we want to search on

TYPE = { RefersTo, MemberOf, DependsOn }

TARGET is the id or URI of the TARGET of the link
(TARGET used to be 'TICKET'.  'TICKET' is deprecated, but will be treated as TARGET

=cut

sub LimitLinkedTo {
    my $self = shift;
    my %args = (
        TICKET   => undef,
        TARGET   => undef,
        TYPE     => undef,
        OPERATOR => '=',
        @_
    );

    $self->Limit(
        FIELD       => 'LinkedTo',
        BASE        => undef,
        TARGET      => ( $args{'TARGET'} || $args{'TICKET'} ),
        TYPE        => $args{'TYPE'},
        DESCRIPTION => $self->loc(
            "Tickets [_1] by [_2]",
            $self->loc( $args{'TYPE'} ),
            ( $args{'TARGET'} || $args{'TICKET'} )
        ),
        OPERATOR    => $args{'OPERATOR'},
    );
}

# }}}

# {{{ LimitLinkedFrom

=head2 LimitLinkedFrom

LimitLinkedFrom takes a paramhash with two fields: TYPE and BASE
TYPE limits the sort of link we want to search on


BASE is the id or URI of the BASE of the link
(BASE used to be 'TICKET'.  'TICKET' is deprecated, but will be treated as BASE


=cut

sub LimitLinkedFrom {
    my $self = shift;
    my %args = (
        BASE     => undef,
        TICKET   => undef,
        TYPE     => undef,
        OPERATOR => '=',
        @_
    );

    # translate RT2 From/To naming to RT3 TicketSQL naming
    my %fromToMap = qw(DependsOn DependentOn
        MemberOf  HasMember
        RefersTo  ReferredToBy);

    my $type = $args{'TYPE'};
    $type = $fromToMap{$type} if exists( $fromToMap{$type} );

    $self->Limit(
        FIELD       => 'LinkedTo',
        TARGET      => undef,
        BASE        => ( $args{'BASE'} || $args{'TICKET'} ),
        TYPE        => $type,
        DESCRIPTION => $self->loc(
            "Tickets [_1] [_2]",
            $self->loc( $args{'TYPE'} ),
            ( $args{'BASE'} || $args{'TICKET'} )
        ),
        OPERATOR    => $args{'OPERATOR'},
    );
}

# }}}

# {{{ LimitMemberOf
sub LimitMemberOf {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedTo(
        @_,
        TARGET => $ticket_id,
        TYPE   => 'MemberOf',
    );
}

# }}}

# {{{ LimitHasMember
sub LimitHasMember {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedFrom(
        @_,
        BASE => "$ticket_id",
        TYPE => 'HasMember',
    );

}

# }}}

# {{{ LimitDependsOn

sub LimitDependsOn {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedTo(
        @_,
        TARGET => $ticket_id,
        TYPE   => 'DependsOn',
    );

}

# }}}

# {{{ LimitDependedOnBy

sub LimitDependedOnBy {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedFrom(
        @_,
        BASE => $ticket_id,
        TYPE => 'DependentOn',
    );

}

# }}}

# {{{ LimitRefersTo

sub LimitRefersTo {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedTo(
        @_,
        TARGET => $ticket_id,
        TYPE   => 'RefersTo',
    );

}

# }}}

# {{{ LimitReferredToBy

sub LimitReferredToBy {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedFrom(
        @_,
        BASE => $ticket_id,
        TYPE => 'ReferredToBy',
    );
}

# }}}

# }}}

# {{{ limit based on ticket date attribtes

# {{{ sub LimitDate

=head2 LimitDate (FIELD => 'DateField', OPERATOR => $oper, VALUE => $ISODate)

Takes a paramhash with the fields FIELD OPERATOR and VALUE.

OPERATOR is one of > or <
VALUE is a date and time in ISO format in GMT
FIELD is one of Starts, Started, Told, Created, Resolved, LastUpdated

There are also helper functions of the form LimitFIELD that eliminate
the need to pass in a FIELD argument.

=cut

sub LimitDate {
    my $self = shift;
    my %args = (
        FIELD    => undef,
        VALUE    => undef,
        OPERATOR => undef,

        @_
    );

    #Set the description if we didn't get handed it above
    unless ( $args{'DESCRIPTION'} ) {
        $args{'DESCRIPTION'} = $args{'FIELD'} . " "
            . $args{'OPERATOR'} . " "
            . $args{'VALUE'} . " GMT";
    }

    $self->Limit(%args);

}

# }}}

sub LimitCreated {
    my $self = shift;
    $self->LimitDate( FIELD => 'Created', @_ );
}

sub LimitDue {
    my $self = shift;
    $self->LimitDate( FIELD => 'Due', @_ );

}

sub LimitStarts {
    my $self = shift;
    $self->LimitDate( FIELD => 'Starts', @_ );

}

sub LimitStarted {
    my $self = shift;
    $self->LimitDate( FIELD => 'Started', @_ );
}

sub LimitResolved {
    my $self = shift;
    $self->LimitDate( FIELD => 'Resolved', @_ );
}

sub LimitTold {
    my $self = shift;
    $self->LimitDate( FIELD => 'Told', @_ );
}

sub LimitLastUpdated {
    my $self = shift;
    $self->LimitDate( FIELD => 'LastUpdated', @_ );
}

#
# {{{ sub LimitTransactionDate

=head2 LimitTransactionDate (OPERATOR => $oper, VALUE => $ISODate)

Takes a paramhash with the fields FIELD OPERATOR and VALUE.

OPERATOR is one of > or <
VALUE is a date and time in ISO format in GMT


=cut

sub LimitTransactionDate {
    my $self = shift;
    my %args = (
        FIELD    => 'TransactionDate',
        VALUE    => undef,
        OPERATOR => undef,

        @_
    );

    #  <20021217042756.GK28744@pallas.fsck.com>
    #    "Kill It" - Jesse.

    #Set the description if we didn't get handed it above
    unless ( $args{'DESCRIPTION'} ) {
        $args{'DESCRIPTION'} = $args{'FIELD'} . " "
            . $args{'OPERATOR'} . " "
            . $args{'VALUE'} . " GMT";
    }

    $self->Limit(%args);

}

# }}}

# }}}

# {{{ Limit based on custom fields
# {{{ sub LimitCustomField

=head2 LimitCustomField

Takes a paramhash of key/value pairs with the following keys:

=over 4

=item CUSTOMFIELD - CustomField name or id.  If a name is passed, an additional parameter QUEUE may also be passed to distinguish the custom field.

=item OPERATOR - The usual Limit operators

=item VALUE - The value to compare against

=back

=cut

sub LimitCustomField {
    my $self = shift;
    my %args = (
        VALUE       => undef,
        CUSTOMFIELD => undef,
        OPERATOR    => '=',
        DESCRIPTION => undef,
        FIELD       => 'CustomFieldValue',
        QUOTEVALUE  => 1,
        @_
    );

    my $CF = RT::CustomField->new( $self->CurrentUser );
    if ( $args{CUSTOMFIELD} =~ /^\d+$/ ) {
        $CF->Load( $args{CUSTOMFIELD} );
    }
    else {
        $CF->LoadByNameAndQueue(
            Name  => $args{CUSTOMFIELD},
            Queue => $args{QUEUE}
        );
        $args{CUSTOMFIELD} = $CF->Id;
    }

    #If we are looking to compare with a null value.
    if ( $args{'OPERATOR'} =~ /^is$/i ) {
        $args{'DESCRIPTION'}
            ||= $self->loc( "Custom field [_1] has no value.", $CF->Name );
    }
    elsif ( $args{'OPERATOR'} =~ /^is not$/i ) {
        $args{'DESCRIPTION'}
            ||= $self->loc( "Custom field [_1] has a value.", $CF->Name );
    }

    # if we're not looking to compare with a null value
    else {
        $args{'DESCRIPTION'} ||= $self->loc( "Custom field [_1] [_2] [_3]",
            $CF->Name, $args{OPERATOR}, $args{VALUE} );
    }

    my $q = "";
    if ( $CF->Queue ) {
        my $qo = new RT::Queue( $self->CurrentUser );
        $qo->Load( $CF->Queue );
        $q = $qo->Name;
    }

    my @rest;
    @rest = ( ENTRYAGGREGATOR => 'AND' )
        if ( $CF->Type eq 'SelectMultiple' );

    $self->Limit(
        VALUE => $args{VALUE},
        FIELD => "CF."
            . (
              $q
            ? $q . ".{" . $CF->Name . "}"
            : $CF->Name
            ),
        OPERATOR    => $args{OPERATOR},
        CUSTOMFIELD => 1,
        @rest,
    );

    $self->{'RecalcTicketLimits'} = 1;
}

# }}}
# }}}

# {{{ sub _NextIndex

=head2 _NextIndex

Keep track of the counter for the array of restrictions

=cut

sub _NextIndex {
    my $self = shift;
    return ( $self->{'restriction_index'}++ );
}

# }}}

# }}}

# {{{ Core bits to make this a DBIx::SearchBuilder object

# {{{ sub _Init
sub _Init {
    my $self = shift;
    $self->{'table'}                   = "Tickets";
    $self->{'RecalcTicketLimits'}      = 1;
    $self->{'looking_at_effective_id'} = 0;
    $self->{'looking_at_type'}         = 0;
    $self->{'restriction_index'}       = 1;
    $self->{'primary_key'}             = "id";
    delete $self->{'items_array'};
    delete $self->{'item_map'};
    delete $self->{'columns_to_display'};
    $self->SUPER::_Init(@_);

    $self->_InitSQL;

}

# }}}

# {{{ sub Count
sub Count {
    my $self = shift;
    $self->_ProcessRestrictions() if ( $self->{'RecalcTicketLimits'} == 1 );
    return ( $self->SUPER::Count() );
}

# }}}

# {{{ sub CountAll
sub CountAll {
    my $self = shift;
    $self->_ProcessRestrictions() if ( $self->{'RecalcTicketLimits'} == 1 );
    return ( $self->SUPER::CountAll() );
}

# }}}

# {{{ sub ItemsArrayRef

=head2 ItemsArrayRef

Returns a reference to the set of all items found in this search

=cut

sub ItemsArrayRef {
    my $self = shift;
    my @items;

    unless ( $self->{'items_array'} ) {

        my $placeholder = $self->_ItemsCounter;
        $self->GotoFirstItem();
        while ( my $item = $self->Next ) {
            push( @{ $self->{'items_array'} }, $item );
        }
        $self->GotoItem($placeholder);
        $self->{'items_array'}
            = $self->ItemsOrderBy( $self->{'items_array'} );
    }
    return ( $self->{'items_array'} );
}

# }}}

# {{{ sub Next
sub Next {
    my $self = shift;

    $self->_ProcessRestrictions() if ( $self->{'RecalcTicketLimits'} == 1 );

    my $Ticket = $self->SUPER::Next();
    if ( ( defined($Ticket) ) and ( ref($Ticket) ) ) {

        if ( $Ticket->__Value('Status') eq 'deleted'
            && !$self->{'allow_deleted_search'} )
        {
            return ( $self->Next() );
        }

        # Since Ticket could be granted with more rights instead
        # of being revoked, it's ok if queue rights allow
        # ShowTicket.  It seems need another query, but we have
        # rights cache in Principal::HasRight.
        elsif ( $Ticket->CurrentUserHasRight('ShowTicket') )
        {
            return ($Ticket);
        }

        #If the user doesn't have the right to show this ticket
        else {
            return ( $self->Next() );
        }
    }

    #if there never was any ticket
    else {
        return (undef);
    }

}

# }}}

# }}}

# {{{ Deal with storing and restoring restrictions

# {{{ sub LoadRestrictions

=head2 LoadRestrictions

LoadRestrictions takes a string which can fully populate the TicketRestrictons hash.
TODO It is not yet implemented

=cut

# }}}

# {{{ sub DescribeRestrictions

=head2 DescribeRestrictions

takes nothing.
Returns a hash keyed by restriction id.
Each element of the hash is currently a one element hash that contains DESCRIPTION which
is a description of the purpose of that TicketRestriction

=cut

sub DescribeRestrictions {
    my $self = shift;

    my ( $row, %listing );

    foreach $row ( keys %{ $self->{'TicketRestrictions'} } ) {
        $listing{$row} = $self->{'TicketRestrictions'}{$row}{'DESCRIPTION'};
    }
    return (%listing);
}

# }}}

# {{{ sub RestrictionValues

=head2 RestrictionValues FIELD

Takes a restriction field and returns a list of values this field is restricted
to.

=cut

sub RestrictionValues {
    my $self  = shift;
    my $field = shift;
    map $self->{'TicketRestrictions'}{$_}{'VALUE'}, grep {
               $self->{'TicketRestrictions'}{$_}{'FIELD'}    eq $field
            && $self->{'TicketRestrictions'}{$_}{'OPERATOR'} eq "="
        }
        keys %{ $self->{'TicketRestrictions'} };
}

# }}}

# {{{ sub ClearRestrictions

=head2 ClearRestrictions

Removes all restrictions irretrievably

=cut

sub ClearRestrictions {
    my $self = shift;
    delete $self->{'TicketRestrictions'};
    $self->{'looking_at_effective_id'} = 0;
    $self->{'looking_at_type'}         = 0;
    $self->{'RecalcTicketLimits'}      = 1;
}

# }}}

# {{{ sub DeleteRestriction

=head2 DeleteRestriction

Takes the row Id of a restriction (From DescribeRestrictions' output, for example.
Removes that restriction from the session's limits.

=cut

sub DeleteRestriction {
    my $self = shift;
    my $row  = shift;
    delete $self->{'TicketRestrictions'}{$row};

    $self->{'RecalcTicketLimits'} = 1;

    #make the underlying easysearch object forget all its preconceptions
}

# }}}

# {{{ sub _RestrictionsToClauses

# Convert a set of oldstyle SB Restrictions to Clauses for RQL

sub _RestrictionsToClauses {
    my $self = shift;

    my $row;
    my %clause;
    foreach $row ( keys %{ $self->{'TicketRestrictions'} } ) {
        my $restriction = $self->{'TicketRestrictions'}{$row};

        #use Data::Dumper;
        #print Dumper($restriction),"\n";

        # We need to reimplement the subclause aggregation that SearchBuilder does.
        # Default Subclause is ALIAS.FIELD, and default ALIAS is 'main',
        # Then SB AND's the different Subclauses together.

        # So, we want to group things into Subclauses, convert them to
        # SQL, and then join them with the appropriate DefaultEA.
        # Then join each subclause group with AND.

        my $field = $restriction->{'FIELD'};
        my $realfield = $field;    # CustomFields fake up a fieldname, so
                                   # we need to figure that out

        # One special case
        # Rewrite LinkedTo meta field to the real field
        if ( $field =~ /LinkedTo/ ) {
            $realfield = $field = $restriction->{'TYPE'};
        }

        # Two special case
        # Handle subkey fields with a different real field
        if ( $field =~ /^(\w+)\./ ) {
            $realfield = $1;
        }

        die "I don't know about $field yet"
            unless ( exists $FIELD_METADATA{$realfield}
                or $restriction->{CUSTOMFIELD} );

        my $type = $FIELD_METADATA{$realfield}->[0];
        my $op   = $restriction->{'OPERATOR'};

        my $value = (
            grep    {defined}
                map { $restriction->{$_} } qw(VALUE TICKET BASE TARGET)
        )[0];

        # this performs the moral equivalent of defined or/dor/C<//>,
        # without the short circuiting.You need to use a 'defined or'
        # type thing instead of just checking for truth values, because
        # VALUE could be 0.(i.e. "false")

        # You could also use this, but I find it less aesthetic:
        # (although it does short circuit)
        #( defined $restriction->{'VALUE'}? $restriction->{VALUE} :
        # defined $restriction->{'TICKET'} ?
        # $restriction->{TICKET} :
        # defined $restriction->{'BASE'} ?
        # $restriction->{BASE} :
        # defined $restriction->{'TARGET'} ?
        # $restriction->{TARGET} )

        my $ea = $restriction->{ENTRYAGGREGATOR}
            || $DefaultEA{$type}
            || "AND";
        if ( ref $ea ) {
            die "Invalid operator $op for $field ($type)"
                unless exists $ea->{$op};
            $ea = $ea->{$op};
        }

        # Each CustomField should be put into a different Clause so they
        # are ANDed together.
        if ( $restriction->{CUSTOMFIELD} ) {
            $realfield = $field;
        }

        exists $clause{$realfield} or $clause{$realfield} = [];

        # Escape Quotes
        $field =~ s!(['"])!\\$1!g;
        $value =~ s!(['"])!\\$1!g;
        my $data = [ $ea, $type, $field, $op, $value ];

        # here is where we store extra data, say if it's a keyword or
        # something.  (I.e. "TYPE SPECIFIC STUFF")

        #print Dumper($data);
        push @{ $clause{$realfield} }, $data;
    }
    return \%clause;
}

# }}}

# {{{ sub _ProcessRestrictions

=head2 _ProcessRestrictions PARAMHASH

# The new _ProcessRestrictions is somewhat dependent on the SQL stuff,
# but isn't quite generic enough to move into Tickets_Overlay_SQL.

=cut

sub _ProcessRestrictions {
    my $self = shift;

    #Blow away ticket aliases since we'll need to regenerate them for
    #a new search
    delete $self->{'TicketAliases'};
    delete $self->{'items_array'};
    delete $self->{'item_map'};
    delete $self->{'raw_rows'};
    delete $self->{'rows'};
    delete $self->{'count_all'};

    my $sql = $self->Query;    # Violating the _SQL namespace
    if ( !$sql || $self->{'RecalcTicketLimits'} ) {

        #  "Restrictions to Clauses Branch\n";
        my $clauseRef = eval { $self->_RestrictionsToClauses; };
        if ($@) {
            $RT::Logger->error( "RestrictionsToClauses: " . $@ );
            $self->FromSQL("");
        }
        else {
            $sql = $self->ClausesToSQL($clauseRef);
            $self->FromSQL($sql) if $sql;
        }
    }

    $self->{'RecalcTicketLimits'} = 0;

}

=head2 _BuildItemMap

    # Build up a map of first/last/next/prev items, so that we can display search nav quickly

=cut

sub _BuildItemMap {
    my $self = shift;

    my $items = $self->ItemsArrayRef;
    my $prev  = 0;

    delete $self->{'item_map'};
    if ( $items->[0] ) {
        $self->{'item_map'}->{'first'} = $items->[0]->EffectiveId;
        while ( my $item = shift @$items ) {
            my $id = $item->EffectiveId;
            $self->{'item_map'}->{$id}->{'defined'} = 1;
            $self->{'item_map'}->{$id}->{prev}      = $prev;
            $self->{'item_map'}->{$id}->{next}      = $items->[0]->EffectiveId
                if ( $items->[0] );
            $prev = $id;
        }
        $self->{'item_map'}->{'last'} = $prev;
    }
}

=head2 ItemMap

Returns an a map of all items found by this search. The map is of the form

$ItemMap->{'first'} = first ticketid found
$ItemMap->{'last'} = last ticketid found
$ItemMap->{$id}->{prev} = the ticket id found before $id
$ItemMap->{$id}->{next} = the ticket id found after $id

=cut

sub ItemMap {
    my $self = shift;
    $self->_BuildItemMap()
        unless ( $self->{'items_array'} and $self->{'item_map'} );
    return ( $self->{'item_map'} );
}

=cut



}



# }}}

# }}}

=head2 PrepForSerialization

You don't want to serialize a big tickets object, as the {items} hash will be instantly invalid _and_ eat lots of space

=cut

sub PrepForSerialization {
    my $self = shift;
    delete $self->{'items'};
    $self->RedoSearch();
}

=head1 FLAGS

RT::Tickets supports several flags which alter search behavior:


allow_deleted_search  (Otherwise never show deleted tickets in search results)
looking_at_type (otherwise limit to type=ticket)

These flags are set by calling 

$tickets->{'flagname'} = 1;

BUG: There should be an API for this


=begin testing

# We assume that we've got some tickets hanging around from before.
ok( my $unlimittickets = RT::Tickets->new( $RT::SystemUser ) );
ok( $unlimittickets->UnLimit );
ok( $unlimittickets->Count > 0, "UnLimited tickets object should return tickets" );

=end testing

=cut

1;



