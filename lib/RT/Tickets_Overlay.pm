# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2004 Best Practical Solutions, LLC 
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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

=end testing

=cut

package RT::Tickets;

use strict;
no warnings qw(redefine);
use vars qw(@SORTFIELDS);
use RT::CustomFields;


# Configuration Tables:

# FIELDS is a mapping of searchable Field name, to Type, and other
# metadata.

my %FIELDS =
  ( Status	    => ['ENUM'],
    Queue	    => ['ENUM' => 'Queue',],
    Type	    => ['ENUM',],
    Creator	    => ['ENUM' => 'User',],
    LastUpdatedBy   => ['ENUM' => 'User',],
    Owner	    => ['ENUM' => 'User',],
    EffectiveId	    => ['INT',],
    id		    => ['INT',],
    InitialPriority => ['INT',],
    FinalPriority   => ['INT',],
    Priority	    => ['INT',],
    TimeLeft	    => ['INT',],
    TimeWorked	    => ['INT',],
    MemberOf	    => ['LINK' => To => 'MemberOf', ],
    DependsOn	    => ['LINK' => To => 'DependsOn',],
    RefersTo        => ['LINK' => To => 'RefersTo',],
    HasMember	    => ['LINK' => From => 'MemberOf',],
    DependentOn     => ['LINK' => From => 'DependsOn',],
    DependedOnBy     => ['LINK' => From => 'DependsOn',],
    ReferredToBy    => ['LINK' => From => 'RefersTo',],
#   HasDepender	    => ['LINK',],
#   RelatedTo	    => ['LINK',],
    Told	    => ['DATE' => 'Told',],
    Starts	    => ['DATE' => 'Starts',],
    Started	    => ['DATE' => 'Started',],
    Due		    => ['DATE' => 'Due',],
    Resolved	    => ['DATE' => 'Resolved',],
    LastUpdated	    => ['DATE' => 'LastUpdated',],
    Created	    => ['DATE' => 'Created',],
    Subject	    => ['STRING',],
    Content	    => ['TRANSFIELD',],
    ContentType	    => ['TRANSFIELD',],
    Filename        => ['TRANSFIELD',],
    TransactionDate => ['TRANSDATE',],
    Updated => ['TRANSDATE',],
    Requestor       => ['WATCHERFIELD' => 'Requestor',],
    Requestors       => ['WATCHERFIELD' => 'Requestor',],
    Cc              => ['WATCHERFIELD' => 'Cc',],
    AdminCc         => ['WATCHERFIELD' => 'AdminCC',],
    Watcher	    => ['WATCHERFIELD'],
    LinkedTo	    => ['LINKFIELD',],
    CustomFieldValue =>['CUSTOMFIELD',],
    CF              => ['CUSTOMFIELD',],
    RequestorGroup  => ['MEMBERSHIPFIELD' => 'Requestor',],
    CCGroup         => ['MEMBERSHIPFIELD' => 'Cc',],
    AdminCCGroup    => ['MEMBERSHIPFIELD' => 'AdminCc',],
    WatcherGroup    => ['MEMBERSHIPFIELD',],
  );

# Mapping of Field Type to Function
my %dispatch =
  ( ENUM	    => \&_EnumLimit,
    INT		    => \&_IntLimit,
    LINK	    => \&_LinkLimit,
    DATE	    => \&_DateLimit,
    STRING	    => \&_StringLimit,
    TRANSFIELD	    => \&_TransLimit,
    TRANSDATE	    => \&_TransDateLimit,
    WATCHERFIELD    => \&_WatcherLimit,
    MEMBERSHIPFIELD => \&_WatcherMembershipLimit,
    LINKFIELD	    => \&_LinkFieldLimit,
    CUSTOMFIELD    => \&_CustomFieldLimit,
  );
my %can_bundle =
  ( WATCHERFIELD => "yeps",
  );

# Default EntryAggregator per type
# if you specify OP, you must specify all valid OPs
my %DefaultEA = (
                 INT		=> 'AND',
                 ENUM		=> { '=' => 'OR',
				     '!='=> 'AND'
				   },
                 DATE		=> { '=' => 'OR',
				     '>='=> 'AND',
				     '<='=> 'AND',
				     '>' => 'AND',
				     '<' => 'AND'
				   },
                 STRING		=> { '=' => 'OR',
				     '!='=> 'AND',
				     'LIKE'=> 'AND',
				     'NOT LIKE'	=> 'AND'
				   },
                 TRANSFIELD	=> 'AND',
                 TRANSDATE	=> 'AND',
                 LINK           => 'OR',
                 LINKFIELD	=> 'AND',
                 TARGET		=> 'AND',
                 BASE		=> 'AND',
                 WATCHERFIELD	=> { '=' => 'OR',
				     '!='=> 'AND',
				     'LIKE'=> 'OR',
				     'NOT LIKE'	=> 'AND'
				   },

                 CUSTOMFIELD	=> 'OR',
                );


# Helper functions for passing the above lexically scoped tables above
# into Tickets_Overlay_SQL.
sub FIELDS   { return \%FIELDS   }
sub dispatch { return \%dispatch }
sub can_bundle { return \%can_bundle }

# Bring in the clowns.
require RT::Tickets_Overlay_SQL;

# {{{ sub SortFields

@SORTFIELDS = qw(id Status
		 Queue Subject
         Owner Created Due Starts Started
         Told
		 Resolved LastUpdated Priority TimeWorked TimeLeft);

=head2 SortFields

Returns the list of fields that lists of tickets can easily be sorted by

=cut

sub SortFields {
	my $self = shift;
	return(@SORTFIELDS);
}


# }}}


# BEGIN SQL STUFF *********************************

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
  my ($sb,$field,$op,$value,@rest) = @_;

  # SQL::Statement changes != to <>.  (Can we remove this now?)
  $op = "!=" if $op eq "<>";

  die "Invalid Operation: $op for $field"
    unless $op eq "=" or $op eq "!=";

  my $meta = $FIELDS{$field};
  if (defined $meta->[1]) {
    my $class = "RT::" . $meta->[1];
    my $o = $class->new($sb->CurrentUser);
    $o->Load( $value );
    $value = $o->Id;
  }
  $sb->_SQLLimit( FIELD => $field,
	      VALUE => $value,
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
  my ($sb,$field,$op,$value,@rest) = @_;

  die "Invalid Operator $op for $field"
    unless $op =~ /^(=|!=|>|<|>=|<=)$/;

  $sb->_SQLLimit(
	     FIELD => $field,
	     VALUE => $value,
	     OPERATOR => $op,
	     @rest,
	    );
}


=head2 _LinkLimit

Handle fields which deal with links between tickets.  (MemberOf, DependsOn)

Meta Data:
  1: Direction (From,To)
  2: Link Type (MemberOf, DependsOn,RefersTo)

=cut

sub _LinkLimit {
  my ($sb,$field,$op,$value,@rest) = @_;

  die "Op must be ="
    unless $op eq "=";

  my $meta = $FIELDS{$field};
  die "Incorrect Meta Data for $field"
    unless (defined $meta->[1] and defined $meta->[2]);

  $sb->{_sql_linkalias} = $sb->NewAlias ('Links')
    unless defined $sb->{_sql_linkalias};

  $sb->_OpenParen();

  $sb->_SQLLimit(
	     ALIAS => $sb->{_sql_linkalias},
	     FIELD =>   'Type',
	     OPERATOR => '=',
	     VALUE => $meta->[2],
	     @rest,
	    );

  if ($meta->[1] eq "To") {
    my $matchfield = ( $value  =~ /^(\d+)$/ ? "LocalTarget" : "Target" );

    $sb->_SQLLimit(
	       ALIAS => $sb->{_sql_linkalias},
	       ENTRYAGGREGATOR => 'AND',
	       FIELD =>   $matchfield,
	       OPERATOR => '=',
	       VALUE => $value ,
	      );

    #If we're searching on target, join the base to ticket.id
    $sb->_SQLJoin( ALIAS1 => 'main', FIELD1 => $sb->{'primary_key'},
	       ALIAS2 => $sb->{_sql_linkalias},	 FIELD2 => 'LocalBase');

  } elsif ( $meta->[1] eq "From" ) {
    my $matchfield = ( $value  =~ /^(\d+)$/ ? "LocalBase" : "Base" );

    $sb->_SQLLimit(
	       ALIAS => $sb->{_sql_linkalias},
	       ENTRYAGGREGATOR => 'AND',
	       FIELD =>   $matchfield,
	       OPERATOR => '=',
	       VALUE => $value ,
	      );

    #If we're searching on base, join the target to ticket.id
    $sb->_SQLJoin( ALIAS1 => 'main',     FIELD1 => $sb->{'primary_key'},
	       ALIAS2 => $sb->{_sql_linkalias}, FIELD2 => 'LocalTarget');

  } else {
    die "Invalid link direction '$meta->[1]' for $field\n";
  }

  $sb->_CloseParen();

}

=head2 _DateLimit

Handle date fields.  (Created, LastTold..)

Meta Data:
  1: type of link.  (Probably not necessary.)

=cut

sub _DateLimit {
  my ($sb,$field,$op,$value,@rest) = @_;

  die "Invalid Date Op: $op"
     unless $op =~ /^(=|>|<|>=|<=)$/;

  my $meta = $FIELDS{$field};
  die "Incorrect Meta Data for $field"
    unless (defined $meta->[1]);

  require Time::ParseDate;
  use POSIX 'strftime';

  # FIXME: Replace me with RT::Date( Type => 'unknown' ...)
  my $time = Time::ParseDate::parsedate( $value,
			UK => $RT::DateDayBeforeMonth,
			PREFER_PAST => $RT::AmbiguousDayInPast,
			PREFER_FUTURE => !($RT::AmbiguousDayInPast),
                        FUZZY => 1
				       );

  if ($op eq "=") {
    # if we're specifying =, that means we want everything on a
    # particular single day.  in the database, we need to check for >
    # and < the edges of that day.

    my $daystart = strftime("%Y-%m-%d %H:%M",
			    gmtime($time - ( $time % 86400 )));
    my $dayend   = strftime("%Y-%m-%d %H:%M",
			    gmtime($time + ( 86399 - $time % 86400 )));

    $sb-> _OpenParen;

    $sb->_SQLLimit(
		   FIELD => $meta->[1],
		   OPERATOR => ">=",
		   VALUE => $daystart,
		   @rest,
		  );

    $sb->_SQLLimit(
		   FIELD => $meta->[1],
		   OPERATOR => "<=",
		   VALUE => $dayend,
		   @rest,
		   ENTRYAGGREGATOR => 'AND',
		  );

    $sb-> _CloseParen;

  } else {
    $value = strftime("%Y-%m-%d %H:%M", gmtime($time));
    $sb->_SQLLimit(
		   FIELD => $meta->[1],
		   OPERATOR => $op,
		   VALUE => $value,
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
  my ($sb,$field,$op,$value,@rest) = @_;

  # FIXME:
  # Valid Operators:
  #  =, !=, LIKE, NOT LIKE

  $sb->_SQLLimit(
	     FIELD => $field,
	     OPERATOR => $op,
	     VALUE => $value,
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
  my ($sb,$field,$op,$value,@rest) = @_;

  # See the comments for TransLimit, they apply here too

  $sb->{_sql_transalias} = $sb->NewAlias ('Transactions')
    unless defined $sb->{_sql_transalias};
  $sb->{_sql_trattachalias} = $sb->NewAlias ('Attachments')
    unless defined $sb->{_sql_trattachalias};


  # Join Transactions To Attachments
  $sb->_OpenParen;

  #Search for the right field
  $sb->_SQLLimit(ALIAS => $sb->{_sql_trattachalias},
		 FIELD =>    'Created',
		 OPERATOR => $op,
		 VALUE =>    $value,
		 CASESENSITIVE => 0,
		 @rest
		);

  $sb->_SQLJoin( ALIAS1 => $sb->{_sql_trattachalias}, FIELD1 => 'TransactionId',
	     ALIAS2 => $sb->{_transalias}, FIELD2 => 'id');

  # Join Transactions to Tickets
  $sb->_SQLJoin( ALIAS1 => 'main', FIELD1 => $sb->{'primary_key'}, # UGH!
	     ALIAS2 => $sb->{_sql_transalias}, FIELD2 => 'ObjectId');

  $sb->Limit( ALIAS => $sb->{_sql_transalias}, FIELD => 'ObjectType', VALUE => 'RT::Ticket');


  my $d = new RT::Date( $sb->CurrentUser );
  $d->Set( Format => 'ISO', Value => $value);
   $value = $d->ISO;

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

  my ($self,$field,$op,$value,@rest) = @_;

  $self->{_sql_transalias} = $self->NewAlias ('Transactions')
    unless defined $self->{_sql_transalias};
  $self->{_sql_trattachalias} = $self->NewAlias ('Attachments')
    unless defined $self->{_sql_trattachalias};


    $self->_OpenParen;

  #Search for the right field
  $self->_SQLLimit(ALIAS => $self->{_sql_trattachalias},
		 FIELD =>    $field,
		 OPERATOR => $op,
		 VALUE =>    $value,
		 CASESENSITIVE => 0,
		 @rest
		);


  $self->_SQLJoin( ALIAS1 => $self->{_sql_trattachalias}, FIELD1 => 'TransactionId',
	     ALIAS2 => $self->{_sql_transalias}, FIELD2 => 'id');

  # Join Transactions to Tickets
  $self->_SQLJoin( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'}, # Why not use "id" here?
	     ALIAS2 => $self->{_sql_transalias}, FIELD2 => 'ObjectId');

    $self->Limit( ALIAS => $self->{_sql_transalias}, FIELD => 'ObjectType', VALUE => 'RT::Ticket', ENTRYAGGREGATOR => 'AND');


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

    $self->_OpenParen;

    # Find out what sort of watcher we're looking for
    my $fieldname;
    if (ref $field) {
        $fieldname = $field->[0]->[0]; 
    } else {
        $fieldname = $field;
    }
    my $meta = $FIELDS{$fieldname};
    my $type = ( defined $meta->[1] ? $meta->[1] : undef );


    # We only want _one_ clause for all of requestors, cc, admincc
    # It's less flexible than what we used to do, but now it sort of actually works. (no huge cartesian products that hose the db)
    my $groups       = $self->{'watcherlimit_'.('global')."_groups"} ||=  $self->NewAlias('Groups');
    my $groupmembers = $self->{'watcherlimit_'.('global')."_groupmembers"} ||=  $self->NewAlias('CachedGroupMembers');
    my $users        = $self->{'watcherlimit_'.('global')."_users"} ||= $self->NewAlias('Users');


    # Use regular joins instead of SQL joins since we don't want the joins inside ticketsql or we get a huge cartesian product
    $self->Limit( ALIAS => $groups, FIELD => 'Domain', VALUE => 'RT::Ticket-Role', ENTRYAGGREGATOR => 'AND');
    $self->Join( ALIAS1 => $groups, FIELD1 => 'Instance', ALIAS2 => 'main', FIELD2 => 'id');
    $self->Join( ALIAS1 => $groups, FIELD1 => 'id', ALIAS2 => $groupmembers, FIELD2 => 'GroupId');
    $self->Join( ALIAS1 => $groupmembers, FIELD1 => 'MemberId', ALIAS2 => $users, FIELD2 => 'id');
    

    # If we're looking for multiple watchers of a given type,
    # TicketSQL will be handing it to us as an array of clauses in
    # $field
    if ( ref $field ) {    # gross hack
        $self->_OpenParen;
        for my $chunk (@$field) {
            ( $field, $op, $value, %rest ) = @$chunk;
            $self->_SQLLimit(
                ALIAS         => $users,
                FIELD         => $rest{SUBKEY} || 'EmailAddress',
                VALUE         => $value,
                OPERATOR      => $op,
                CASESENSITIVE => 0,
                %rest);
        }
        $self->_CloseParen;
    }
    else {
        $self->_SQLLimit(
            ALIAS         => $users,
            FIELD         => $rest{SUBKEY} || 'EmailAddress',
            VALUE         => $value,
            OPERATOR      => $op,
            CASESENSITIVE => 0,
            %rest);
    }

    $self->_SQLLimit( ALIAS => $groups, FIELD => 'Type', VALUE => $type, ENTRYAGGREGATOR => 'AND') if ($type); 

    $self->_CloseParen;
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
  my ($self,$field,$op,$value,@rest) = @_;
  my %rest = @rest;

  $self->_OpenParen;

  my $groups	    = $self->NewAlias('Groups');
  my $groupmembers  = $self->NewAlias('CachedGroupMembers');
  my $users	    = $self->NewAlias('Users');
  my $memberships   = $self->NewAlias('CachedGroupMembers');

  if (ref $field) { # gross hack
    my @bundle = @$field;
    $self->_OpenParen;
    for my $chunk (@bundle) {
      ($field,$op,$value,@rest) = @$chunk;
      $self->_SQLLimit(ALIAS => $memberships,
   		   FIELD => 'GroupId',
   		   VALUE           => $value,
   		   OPERATOR        => $op,
   		   @rest,
   		  );
    }
    $self->_CloseParen;
  } else {
     $self->_SQLLimit(ALIAS => $memberships,
   		   FIELD => 'GroupId',
   		   VALUE           => $value,
   		   OPERATOR        => $op,
   		   @rest,
   		  );
  }

  # {{{ Tie to groups for tickets we care about
  $self->_SQLLimit(ALIAS => $groups,
		   FIELD => 'Domain',
		   VALUE => 'RT::Ticket-Role',
		   ENTRYAGGREGATOR => 'AND');

  $self->Join(ALIAS1 => $groups, FIELD1 => 'Instance',
	      ALIAS2 => 'main',   FIELD2 => 'id');
  # }}}

  # If we care about which sort of watcher
  my $meta = $FIELDS{$field};
  my $type = ( defined $meta->[1] ? $meta->[1] : undef );

  if ( $type ) {
    $self->_SQLLimit(ALIAS => $groups,
		     FIELD => 'Type',
		     VALUE => $type,
		     ENTRYAGGREGATOR => 'AND');
  }

  $self->Join (ALIAS1 => $groups,  FIELD1 => 'id',
	       ALIAS2 => $groupmembers, FIELD2 => 'GroupId');

  $self->Join( ALIAS1 => $groupmembers, FIELD1 => 'MemberId',
	       ALIAS2 => $users, FIELD2 => 'id');

  $self->Join( ALIAS1 => $memberships, FIELD1 => 'MemberId',
	       ALIAS2 => $users, FIELD2 => 'id');

 $self->_CloseParen;

}


sub _LinkFieldLimit {
  my $restriction;
  my $self;
  my $LinkAlias;
  my %args;
  if ($restriction->{'TYPE'}) {
    $self->SUPER::Limit(ALIAS => $LinkAlias,
			ENTRYAGGREGATOR => 'AND',
			FIELD =>   'Type',
			OPERATOR => '=',
			VALUE =>    $restriction->{'TYPE'} );
  }

   #If we're trying to limit it to things that are target of
  if ($restriction->{'TARGET'}) {
    # If the TARGET is an integer that means that we want to look at
    # the LocalTarget field. otherwise, we want to look at the
    # "Target" field
    my ($matchfield);
    if ($restriction->{'TARGET'} =~/^(\d+)$/) {
      $matchfield = "LocalTarget";
    } else {
      $matchfield = "Target";
    }
    $self->SUPER::Limit(ALIAS => $LinkAlias,
			ENTRYAGGREGATOR => 'AND',
			FIELD =>   $matchfield,
			OPERATOR => '=',
			VALUE =>    $restriction->{'TARGET'} );
    #If we're searching on target, join the base to ticket.id
    $self->_SQLJoin( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'},
		 ALIAS2 => $LinkAlias,
		 FIELD2 => 'LocalBase');
  }
  #If we're trying to limit it to things that are base of
  elsif ($restriction->{'BASE'}) {
    # If we're trying to match a numeric link, we want to look at
    # LocalBase, otherwise we want to look at "Base"
    my ($matchfield);
    if ($restriction->{'BASE'} =~/^(\d+)$/) {
      $matchfield = "LocalBase";
    } else {
      $matchfield = "Base";
    }

    $self->SUPER::Limit(ALIAS => $LinkAlias,
			ENTRYAGGREGATOR => 'AND',
			FIELD => $matchfield,
			OPERATOR => '=',
			VALUE =>    $restriction->{'BASE'} );
    #If we're searching on base, join the target to ticket.id
    $self->_SQLJoin( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'},
		 ALIAS2 => $LinkAlias,
		 FIELD2 => 'LocalTarget')
  }
}


=head2 KeywordLimit

Limit based on Keywords

Meta Data:
  none

=cut

sub _CustomFieldLimit {
    my ( $self, $_field, $op, $value, @rest ) = @_;

  my %rest = @rest;
  my $field = $rest{SUBKEY} || die "No field specified";

  # For our sanity, we can only limit on one queue at a time
  my $queue = 0;

    if ( $field =~ /^(.+?)\.{(.+)}$/ ) {
    $queue =  $1;
    $field = $2;
   }
    $field = $1 if $field =~ /^{(.+)}$/; # trim { }



# If we're trying to find custom fields that don't match something, we want tickets
# where the custom field has no value at all

    my $null_columns_ok;
    if ( ( $op =~ /^IS$/i ) or ( $op =~ /^NOT LIKE$/i ) or ( $op eq '!=' ) ) {
        $null_columns_ok = 1;
    }

    my $cfid = 0;
    if ($queue) {

    my $q = RT::Queue->new( $self->CurrentUser );
    $q->Load($queue) if ($queue);

    my $cf;
    if ( $q->id ) {
        $cf = $q->CustomField($field);
    }
    else {
        $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->LoadByNameAndQueue( Queue => '0', Name => $field );
    }

     $cfid = $cf->id;

    }


    my $TicketCFs;

  # Perform one Join per CustomField
    if ( $self->{_sql_object_cf_alias}{$cfid} ) {
    $TicketCFs = $self->{_sql_object_cf_alias}{$cfid};
  }
    else {
        $TicketCFs = $self->{_sql_object_cf_alias}{$cfid} = $self->Join(
            TYPE   => 'left',
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'ObjectCustomFieldValues',
            FIELD2 => 'ObjectId'
        );

    $self->Limit(
        LEFTJOIN        => $TicketCFs,
        FIELD => 'ObjectType',
        VALUE => ref($self->NewItem), # we want a single item, not a collection
        ENTRYAGGREGATOR => 'AND'
    );

    if ($cfid) {
    $self->Limit(
        LEFTJOIN        => $TicketCFs,
        FIELD           => 'CustomField',
        VALUE           => $cfid,
        ENTRYAGGREGATOR => 'AND'
    );
    } else {
    my $cfalias = $self->Join(
        ALIAS1        => $TicketCFs,
        FIELD1           => 'CustomField',
        TABLE2          => 'CustomFields',
        FIELD2          => 'id'
    );
    $self->Limit(
        LEFTJOIN        => $cfalias,
        FIELD           => 'Name',
        VALUE           => $field,
    );


    }
    }

    $self->_OpenParen if ($null_columns_ok);

    $self->_SQLLimit(
        ALIAS      => $TicketCFs,
        FIELD      => 'Content',
        OPERATOR   => $op,
        VALUE      => $value,
        QUOTEVALUE => 1,
        @rest
    );
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
    $self->_CloseParen if ($null_columns_ok);

}


# End Helper Functions

# End of SQL Stuff -------------------------------------------------

# {{{ Limit the result set based on content

# {{{ sub Limit

=head2 Limit

Takes a paramhash with the fields FIELD, OPERATOR, VALUE and DESCRIPTION
Generally best called from LimitFoo methods

=cut
sub Limit {
    my $self = shift;
    my %args = ( FIELD => undef,
		 OPERATOR => '=',
		 VALUE => undef,
		 DESCRIPTION => undef,
		 @_
	       );
    $args{'DESCRIPTION'} = $self->loc(
	"[_1] [_2] [_3]", $args{'FIELD'}, $args{'OPERATOR'}, $args{'VALUE'}
    ) if (!defined $args{'DESCRIPTION'}) ;

    my $index = $self->_NextIndex;

    #make the TicketRestrictions hash the equivalent of whatever we just passed in;

    %{$self->{'TicketRestrictions'}{$index}} = %args;

    $self->{'RecalcTicketLimits'} = 1;

    # If we're looking at the effective id, we don't want to append the other clause
    # which limits us to tickets where id = effective id
    if ($args{'FIELD'} eq 'EffectiveId') {
        $self->{'looking_at_effective_id'} = 1;
    }

    if ($args{'FIELD'} eq 'Type') {
        $self->{'looking_at_type'} = 1;
    }

    return ($index);
}

# }}}




=head2 FreezeLimits

Returns a frozen string suitable for handing back to ThawLimits.

=cut

sub _FreezeThawKeys {
    'TicketRestrictions',
    'restriction_index',
    'looking_at_effective_id',
    'looking_at_type'
}

# {{{ sub FreezeLimits

sub FreezeLimits {
	my $self = shift;
	require Storable;
	require MIME::Base64;
	MIME::Base64::base64_encode(
	    Storable::freeze(
		\@{$self}{$self->_FreezeThawKeys}
	    )
	);
}

# }}}

=head2 ThawLimits

Take a frozen Limits string generated by FreezeLimits and make this tickets
object have that set of limits.

=cut
# {{{ sub ThawLimits

sub ThawLimits {
	my $self = shift;
	my $in = shift;
	
	#if we don't have $in, get outta here.
	return undef unless ($in);

    	$self->{'RecalcTicketLimits'} = 1;

	require Storable;
	require MIME::Base64;

	#We don't need to die if the thaw fails.
	@{$self}{$self->_FreezeThawKeys} = eval {
	    @{Storable::thaw( MIME::Base64::base64_decode($in) )};
	};
	
	$RT::Logger->error( $@ ) if $@;

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
    my %args = (VALUE => undef,
		OPERATOR => '=',
		@_);

    #TODO  VALUE should also take queue names and queue objects
    #TODO FIXME why are we canonicalizing to name, not id, robrt?
    if ($args{VALUE} =~ /^\d+$/) {
      my $queue = new RT::Queue($self->CurrentUser);
      $queue->Load($args{'VALUE'});
      $args{VALUE} = $queue->Name;
    }

    # What if they pass in an Id?  Check for isNum() and convert to
    # string.

    #TODO check for a valid queue here

    $self->Limit (FIELD => 'Queue',
		  VALUE => $args{VALUE},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Queue'), $args{'OPERATOR'}, $args{VALUE},
		  ),
		 );

}
# }}}

# {{{ sub LimitStatus

=head2 LimitStatus

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a status.

=cut

sub LimitStatus {
    my $self = shift;
    my %args = ( OPERATOR => '=',
                  @_);
    $self->Limit (FIELD => 'Status',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Status'), $args{'OPERATOR'}, $self->loc($args{'VALUE'})
		  ),
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
    my %args = (OPERATOR => '=',
		VALUE => undef,
		@_);
    $self->Limit (FIELD => 'Type',
                  VALUE => $args{'VALUE'},
                  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Type'), $args{'OPERATOR'}, $args{'Limit'},
		  ),
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
    $self->Limit (FIELD => 'Subject',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Subject'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    my %args = (OPERATOR => '=',
                @_);

    $self->Limit (FIELD => 'id',
                  VALUE => $args{'VALUE'},
                  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Id'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    $self->Limit (FIELD => 'Priority',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Priority'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    $self->Limit (FIELD => 'InitialPriority',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Initial Priority'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    $self->Limit (FIELD => 'FinalPriority',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Final Priority'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    $self->Limit (FIELD => 'TimeWorked',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Time worked'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    $self->Limit (FIELD => 'TimeLeft',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Time left'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    $self->Limit (FIELD => 'Content',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Ticket content'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    $self->Limit (FIELD => 'Filename',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Attachment filename'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    $self->Limit (FIELD => 'ContentType',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Ticket content type'), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
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
    my %args = ( OPERATOR => '=',
                 @_);

    my $owner = new RT::User($self->CurrentUser);
    $owner->Load($args{'VALUE'});
    # FIXME: check for a valid $owner
    $self->Limit (FIELD => 'Owner',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => join(
		   ' ', $self->loc('Owner'), $args{'OPERATOR'}, $owner->Name(),
		  ),
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
    my %args = ( OPERATOR => '=',
		 VALUE => undef,
		 TYPE => undef,
		@_);


    #build us up a description
    my ($watcher_type, $desc);
    if ($args{'TYPE'}) {
	$watcher_type = $args{'TYPE'};
    }
    else {
	$watcher_type = "Watcher";
    }

    $self->Limit (FIELD => $watcher_type,
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  TYPE => $args{'TYPE'},
		  DESCRIPTION => join(
		   ' ', $self->loc($watcher_type), $args{'OPERATOR'}, $args{'VALUE'},
		  ),
		 );
}


sub LimitRequestor {
    my $self = shift;
    my %args = (@_);
  my ($package, $filename, $line) = caller;
    $RT::Logger->error("Tickets->LimitRequestor is deprecated. please rewrite call at  $package - $filename: $line");
    $self->LimitWatcher(TYPE => 'Requestor', @_);

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
		TICKET => undef,
		TARGET => undef,
		TYPE => undef,
		 @_);

    $self->Limit(
		 FIELD => 'LinkedTo',
		 BASE => undef,
		 TARGET => ($args{'TARGET'} || $args{'TICKET'}),
		 TYPE => $args{'TYPE'},
		 DESCRIPTION => $self->loc(
		   "Tickets [_1] by [_2]", $self->loc($args{'TYPE'}), ($args{'TARGET'} || $args{'TICKET'})
		  ),
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
    my %args = ( BASE => undef,
		 TICKET => undef,
		 TYPE => undef,
		 @_);

    # translate RT2 From/To naming to RT3 TicketSQL naming
    my %fromToMap = qw(DependsOn DependentOn
		       MemberOf  HasMember
		       RefersTo  ReferredToBy);

    my $type = $args{'TYPE'};
    $type = $fromToMap{$type} if exists($fromToMap{$type});

    $self->Limit( FIELD => 'LinkedTo',
		  TARGET => undef,
		  BASE => ($args{'BASE'} || $args{'TICKET'}),
		  TYPE => $type,
		  DESCRIPTION => $self->loc(
		   "Tickets [_1] [_2]", $self->loc($args{'TYPE'}), ($args{'BASE'} || $args{'TICKET'})
		  ),
		);
}


# }}}

# {{{ LimitMemberOf
sub LimitMemberOf {
    my $self = shift;
    my $ticket_id = shift;
    $self->LimitLinkedTo ( TARGET=> "$ticket_id",
			   TYPE => 'MemberOf',
			  );

}
# }}}

# {{{ LimitHasMember
sub LimitHasMember {
    my $self = shift;
    my $ticket_id =shift;
    $self->LimitLinkedFrom ( BASE => "$ticket_id",
			     TYPE => 'HasMember',
			     );

}
# }}}

# {{{ LimitDependsOn

sub LimitDependsOn {
    my $self = shift;
    my $ticket_id = shift;
    $self->LimitLinkedTo ( TARGET => "$ticket_id",
                           TYPE => 'DependsOn',
			   );

}

# }}}

# {{{ LimitDependedOnBy

sub LimitDependedOnBy {
    my $self = shift;
    my $ticket_id = shift;
    $self->LimitLinkedFrom (  BASE => "$ticket_id",
                               TYPE => 'DependentOn',
			     );

}

# }}}


# {{{ LimitRefersTo

sub LimitRefersTo {
    my $self = shift;
    my $ticket_id = shift;
    $self->LimitLinkedTo ( TARGET => "$ticket_id",
                           TYPE => 'RefersTo',
			   );

}

# }}}

# {{{ LimitReferredToBy

sub LimitReferredToBy {
    my $self = shift;
    my $ticket_id = shift;
    $self->LimitLinkedFrom (  BASE=> "$ticket_id",
                               TYPE => 'ReferredTo',
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
                  FIELD => undef,
		  VALUE => undef,
		  OPERATOR => undef,

                  @_);

    #Set the description if we didn't get handed it above
    unless ($args{'DESCRIPTION'} ) {
	$args{'DESCRIPTION'} = $args{'FIELD'} . " " .$args{'OPERATOR'}. " ". $args{'VALUE'} . " GMT"
    }

    $self->Limit (%args);

}

# }}}




sub LimitCreated {
    my $self = shift;
    $self->LimitDate( FIELD => 'Created', @_);
}
sub LimitDue {
    my $self = shift;
    $self->LimitDate( FIELD => 'Due', @_);

}
sub LimitStarts {
    my $self = shift;
    $self->LimitDate( FIELD => 'Starts', @_);

}
sub LimitStarted {
    my $self = shift;
    $self->LimitDate( FIELD => 'Started', @_);
}
sub LimitResolved {
    my $self = shift;
    $self->LimitDate( FIELD => 'Resolved', @_);
}
sub LimitTold {
    my $self = shift;
    $self->LimitDate( FIELD => 'Told', @_);
}
sub LimitLastUpdated {
    my $self = shift;
    $self->LimitDate( FIELD => 'LastUpdated', @_);
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
                  FIELD => 'TransactionDate',
		  VALUE => undef,
		  OPERATOR => undef,

                  @_);

    #  <20021217042756.GK28744@pallas.fsck.com>
    #    "Kill It" - Jesse.

    #Set the description if we didn't get handed it above
    unless ($args{'DESCRIPTION'} ) {
	$args{'DESCRIPTION'} = $args{'FIELD'} . " " .$args{'OPERATOR'}. " ". $args{'VALUE'} . " GMT"
    }

    $self->Limit (%args);

}

# }}}

# }}}

# {{{ Limit based on custom fields
# {{{ sub LimitCustomField

=head2 LimitCustomField

Takes a paramhash of key/value pairs with the following keys:

=over 4

=item CUSTOMFIELD - CustomField name or id.  If a name is passed, an additional
parameter QUEUE may also be passed to distinguish the custom field.

=item OPERATOR - The usual Limit operators

=item VALUE - The value to compare against

=back

=cut

sub LimitCustomField {
    my $self = shift;
    my %args = ( VALUE        => undef,
                 CUSTOMFIELD   => undef,
                 OPERATOR      => '=',
                 DESCRIPTION   => undef,
                 FIELD         => 'CustomFieldValue',
                 QUOTEVALUE    => 1,
                 @_ );

    my $CF = RT::CustomField->new( $self->CurrentUser );
    if ( $args{CUSTOMFIELD} =~ /^\d+$/) {
	$CF->Load( $args{CUSTOMFIELD} );
    }
    else {
	$CF->LoadByNameAndQueue( Name => $args{CUSTOMFIELD}, Queue => $args{QUEUE} );
	$args{CUSTOMFIELD} = $CF->Id;
    }

    #If we are looking to compare with a null value.
    if ( $args{'OPERATOR'} =~ /^is$/i ) {
      $args{'DESCRIPTION'} ||= $self->loc("Custom field [_1] has no value.", $CF->Name);
    }
    elsif ( $args{'OPERATOR'} =~ /^is not$/i ) {
      $args{'DESCRIPTION'} ||= $self->loc("Custom field [_1] has a value.", $CF->Name);
    }

    # if we're not looking to compare with a null value
    else {
        $args{'DESCRIPTION'} ||= $self->loc("Custom field [_1] [_2] [_3]",  $CF->Name , $args{OPERATOR} , $args{VALUE});
    }

    my $q = "";
    if ($CF->Queue) {
      my $qo = new RT::Queue( $self->CurrentUser );
      $qo->load( $CF->Queue );
      $q = $qo->Name;
    }

    my @rest;
    @rest = ( ENTRYAGGREGATOR => 'AND' )
      if ($CF->Type eq 'SelectMultiple');

    $self->Limit( VALUE => $args{VALUE},
		  FIELD => "CF.".( $q
			     ? $q . ".{" . $CF->Name . "}"
			     : $CF->Name
			   ),
		  OPERATOR => $args{OPERATOR},
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
    return ($self->{'restriction_index'}++);
}
# }}}

# }}}

# {{{ Core bits to make this a DBIx::SearchBuilder object

# {{{ sub _Init
sub _Init  {
    my $self = shift;
    $self->{'table'} = "Tickets";
    $self->{'RecalcTicketLimits'} = 1;
    $self->{'looking_at_effective_id'} = 0;
    $self->{'looking_at_type'} = 0;
    $self->{'restriction_index'} =1;
    $self->{'primary_key'} = "id";
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
  $self->_ProcessRestrictions() if ($self->{'RecalcTicketLimits'} == 1 );
  return($self->SUPER::Count());
}
# }}}

# {{{ sub CountAll
sub CountAll {
  my $self = shift;
  $self->_ProcessRestrictions() if ($self->{'RecalcTicketLimits'} == 1 );
  return($self->SUPER::CountAll());
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
            push ( @{ $self->{'items_array'} }, $item );
        }
        $self->GotoItem($placeholder);
        $self->{'items_array'} = $self->ItemsOrderBy($self->{'items_array'});
    }
    return ( $self->{'items_array'} );
}
# }}}

# {{{ sub Next
sub Next {
	my $self = shift;
 	
	$self->_ProcessRestrictions() if ($self->{'RecalcTicketLimits'} == 1 );

	my $Ticket = $self->SUPER::Next();
	if ((defined($Ticket)) and (ref($Ticket))) {

    	    #Make sure we _never_ show deleted tickets
	    #TODO we should be doing this in the where clause.
	    #but you can't do multiple clauses on the same field just yet :/

	    if ($Ticket->__Value('Status') eq 'deleted') {
		return($self->Next());
	    }
            # Since Ticket could be granted with more rights instead
            # of being revoked, it's ok if queue rights allow
            # ShowTicket.  It seems need another query, but we have
            # rights cache in Principal::HasRight.
  	    elsif ($Ticket->QueueObj->CurrentUserHasRight('ShowTicket') ||
                   $Ticket->CurrentUserHasRight('ShowTicket')) {
		return($Ticket);
	    }

	    #If the user doesn't have the right to show this ticket
	    else {	
		return($self->Next());
	    }
	}
	#if there never was any ticket
	else {
		return(undef);
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

sub DescribeRestrictions  {
    my $self = shift;

    my ($row, %listing);

    foreach $row (keys %{$self->{'TicketRestrictions'}}) {
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
    my $self = shift;
    my $field = shift;
    map $self->{'TicketRestrictions'}{$_}{'VALUE'},
      grep {
             $self->{'TicketRestrictions'}{$_}{'FIELD'} eq $field
             && $self->{'TicketRestrictions'}{$_}{'OPERATOR'} eq "="
           }
        keys %{$self->{'TicketRestrictions'}};
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
    $self->{'looking_at_type'} = 0;
    $self->{'RecalcTicketLimits'} =1;
}

# }}}

# {{{ sub DeleteRestriction

=head2 DeleteRestriction

Takes the row Id of a restriction (From DescribeRestrictions' output, for example.
Removes that restriction from the session's limits.

=cut


sub DeleteRestriction {
    my $self = shift;
    my $row = shift;
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
  foreach $row (keys %{$self->{'TicketRestrictions'}}) {
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
    my $realfield = $field;	# CustomFields fake up a fieldname, so
                                # we need to figure that out

    # One special case
    # Rewrite LinkedTo meta field to the real field
    if ($field =~ /LinkedTo/) {
      $realfield = $field = $restriction->{'TYPE'};
    }

    # Two special case
    # Handle subkey fields with a different real field
    if ($field =~ /^(\w+)\./) {
      $realfield = $1;
    }

    die "I don't know about $field yet"
      unless (exists $FIELDS{$realfield} or $restriction->{CUSTOMFIELD});

    my $type = $FIELDS{$realfield}->[0];
    my $op   = $restriction->{'OPERATOR'};

    my $value = ( grep { defined }
		  map { $restriction->{$_} } qw(VALUE TICKET BASE TARGET))[0];

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

    my $ea = $restriction->{ENTRYAGGREGATOR} || $DefaultEA{$type} || "AND";
    if ( ref $ea ) {
      die "Invalid operator $op for $field ($type)"
	unless exists $ea->{$op};
      $ea = $ea->{$op};
    }

    # Each CustomField should be put into a different Clause so they
    # are ANDed together.
    if ($restriction->{CUSTOMFIELD}) {
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
    push @{$clause{$realfield}}, $data;
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
 
    my $sql = $self->{_sql_query}; # Violating the _SQL namespace
    if (!$sql||$self->{'RecalcTicketLimits'}) {
      #  "Restrictions to Clauses Branch\n";
      my $clauseRef = eval { $self->_RestrictionsToClauses; };
      if ($@) {
	$RT::Logger->error( "RestrictionsToClauses: " . $@ );
	$self->FromSQL("");
      } else {
	$sql = $self->ClausesToSQL($clauseRef);
	$self->FromSQL($sql);
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
    my $prev = 0 ;

    delete $self->{'item_map'};
    if ($items->[0]) {
        $self->{'item_map'}->{'first'} = $items->[0]->EffectiveId;
        while (my $item = shift @$items ) {
            my $id = $item->EffectiveId;
            $self->{'item_map'}->{$id}->{'defined'} = 1;
            $self->{'item_map'}->{$id}->{prev}  = $prev;
            $self->{'item_map'}->{$id}->{next}  = $items->[0]->EffectiveId if ($items->[0]);
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
    $self->_BuildItemMap() unless ($self->{'items_array'} and $self->{'item_map'});
    return ($self->{'item_map'});
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

1;

