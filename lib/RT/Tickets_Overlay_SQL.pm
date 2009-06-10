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
package RT::Tickets;

use strict;
use warnings;

# Import configuration data from the lexcial scope of __PACKAGE__ (or
# at least where those two Subroutines are defined.)

my %FIELD_METADATA = %{FIELDS()};
my %dispatch = %{dispatch()};
my %can_bundle = %{can_bundle()};

# Lower Case version of FIELDS, for case insensitivity
my %lcfields = map { ( lc($_) => $_ ) } (keys %FIELD_METADATA);

sub _InitSQL {
  my $self = shift;

  # How many of these do we actually still use?

  # Private Member Variales (which should get cleaned)
  $self->{'_sql_linksc'}        = 0;
  $self->{'_sql_watchersc'}     = 0;
  $self->{'_sql_keywordsc'}     = 0;
  $self->{'_sql_subclause'}     = "a";
  $self->{'_sql_first'}         = 0;
  $self->{'_sql_opstack'}       = [''];
  $self->{'_sql_linkalias'}    = undef;
  $self->{'_sql_transalias'}    = undef;
  $self->{'_sql_trattachalias'} = undef;
  $self->{'_sql_object_cf_alias'}  = undef;
  $self->{'_sql_depth'}         = 0;
  $self->{'_sql_localdepth'}    = 0;
  $self->{'_sql_query'}         = '';
  $self->{'_sql_looking_at'}    = {};
  $self->{'_sql_columns_to_display'} = [];

}

sub _SQLLimit {
  my $self = shift;
    my %args = (@_);
    if ($args{'FIELD'} eq 'EffectiveId' &&
         (!$args{'ALIAS'} || $args{'ALIAS'} eq 'main' ) ) {
        $self->{'looking_at_effective_id'} = 1;
    }      
    
    if ($args{'FIELD'} eq 'Type' &&
         (!$args{'ALIAS'} || $args{'ALIAS'} eq 'main' ) ) {
        $self->{'looking_at_type'} = 1;
    }

  # All SQL stuff goes into one SB subclause so we can deal with all
  # the aggregation
  $self->SUPER::Limit(%args,
                      SUBCLAUSE => 'ticketsql');
}

sub _SQLJoin {
  # All SQL stuff goes into one SB subclause so we can deal with all
  # the aggregation
  my $this = shift;

  $this->SUPER::Join(@_,
		     SUBCLAUSE => 'ticketsql');
}

# Helpers
sub _OpenParen {
  $_[0]->SUPER::_OpenParen( 'ticketsql' );
}
sub _CloseParen {
  $_[0]->SUPER::_CloseParen( 'ticketsql' );
}

=head1 SQL Functions

=cut

=head2 Robert's Simple SQL Parser

Documentation In Progress

The Parser/Tokenizer is a relatively simple state machine that scans through a SQL WHERE clause type string extracting a token at a time (where a token is:

  VALUE -> quoted string or number
  AGGREGator -> AND or OR
  KEYWORD -> quoted string or single word
  OPerator -> =,!=,LIKE,etc..
  PARENthesis -> open or close.

And that stream of tokens is passed through the "machine" in order to build up a structure that looks like:

       KEY OP VALUE
  AND  KEY OP VALUE
  OR   KEY OP VALUE

That also deals with parenthesis for nesting.  (The parentheses are
just handed off the SearchBuilder)

=cut

use Regexp::Common qw /delimited/;

# States
use constant VALUE => 1;
use constant AGGREG => 2;
use constant OP => 4;
use constant OPEN_PAREN => 8;
use constant CLOSE_PAREN => 16;
use constant KEYWORD => 32;
my @tokens = qw[VALUE AGGREG OP OPEN_PAREN CLOSE_PAREN KEYWORD];

my $re_aggreg = qr[(?i:AND|OR)];
my $re_delim  = qr[$RE{delimited}{-delim=>qq{\'\"}}];
my $re_value  = qr[$re_delim|\d+|NULL];
my $re_keyword = qr[$re_delim|(?:\{|\}|\w|\.)+];
my $re_op     = qr[=|!=|>=|<=|>|<|(?i:IS NOT)|(?i:IS)|(?i:NOT LIKE)|(?i:LIKE)]; # long to short
my $re_open_paren  = qr'\(';
my $re_close_paren  = qr'\)';

sub _close_bundle
{
  my ($self, @bundle) = @_;
  return unless @bundle;
  if (@bundle == 1) {
    $bundle[0]->{dispatch}->(
                         $self,
                         $bundle[0]->{key},
                         $bundle[0]->{op},
                         $bundle[0]->{val},
                         SUBCLAUSE =>  "",
                         ENTRYAGGREGATOR => $bundle[0]->{ea},
                         SUBKEY => $bundle[0]->{subkey},
                        );
  } else {
    my @args;
    for my $chunk (@bundle) {
      push @args, [
          $chunk->{key},
          $chunk->{op},
          $chunk->{val},
          SUBCLAUSE =>  "",
          ENTRYAGGREGATOR => $chunk->{ea},
          SUBKEY => $chunk->{subkey},
      ];
    }
    $bundle[0]->{dispatch}->(
        $self, \@args,
    );
  }
}

sub _parser {
  my ($self,$string) = @_;
  my $want = KEYWORD | OPEN_PAREN;
  my $last = undef;

  my $depth = 0;
  my @bundle;

  my ($ea,$key,$op,$value) = ("","","","");

  # order of matches in the RE is important.. op should come early,
  # because it has spaces in it.  otherwise "NOT LIKE" might be parsed
  # as a keyword or value.





  while ($string =~ /(
                      $re_aggreg
                      |$re_op
                      |$re_keyword
                      |$re_value
                      |$re_open_paren
                      |$re_close_paren
                     )/iogx ) {
    my $val = $1;
    my $current = 0;

    # Highest priority is last
    $current = OP          if ($want & OP)          && $val =~ /^$re_op$/io;
    $current = VALUE       if ($want & VALUE)       && $val =~ /^$re_value$/io;
    $current = KEYWORD     if ($want & KEYWORD)     && $val =~ /^$re_keyword$/io;
    $current = AGGREG      if ($want & AGGREG)      && $val =~ /^$re_aggreg$/io;
    $current = OPEN_PAREN  if ($want & OPEN_PAREN)  && $val =~ /^$re_open_paren$/io;
    $current = CLOSE_PAREN if ($want & CLOSE_PAREN) && $val =~ /^$re_close_paren$/io;


    unless ($current && $want & $current) {
      # Error
      # FIXME: I will only print out the highest $want value
      die "Error near ->$val<- expecting a ", $tokens[((log $want)/(log 2))], " in $string\n";
    }

    # State Machine:

    #$RT::Logger->debug("We've just found a '$current' called '$val'");

    # Parens are highest priority
    if ($current & OPEN_PAREN) {
      $self->_close_bundle(@bundle);  @bundle = ();
      $depth++;
      $self->_OpenParen;

      $want = KEYWORD | OPEN_PAREN;
    }
    elsif ( $current & CLOSE_PAREN ) {
      $self->_close_bundle(@bundle);  @bundle = ();
      $depth--;
      $self->_CloseParen;

      $want = CLOSE_PAREN | AGGREG;
    }
    elsif ( $current & AGGREG ) {
      $ea = $val;
      $want = KEYWORD | OPEN_PAREN;
    }
    elsif ( $current & KEYWORD ) {
      $key = $val;
      $want = OP;
    }
    elsif ( $current & OP ) {
      $op = $val;
      $want = VALUE;
    }
    elsif ( $current & VALUE ) {
      $value = $val;

      # Remove surrounding quotes from $key, $val
      # (in future, simplify as for($key,$val) { action on $_ })
      if ($key =~ /$re_delim/o) {
        substr($key,0,1) = "";
        substr($key,-1,1) = "";
      }
      if ($val =~ /$re_delim/o) {
        substr($val,0,1) = "";
        substr($val,-1,1) = "";
      }
      # Unescape escaped characters
      $key =~ s!\\(.)!$1!g;
      $val =~ s!\\(.)!$1!g;
      #    print "$ea Key=[$key] op=[$op]  val=[$val]\n";
      
      # replace __CurrentUser__ with id
      $val = $self->CurrentUser->id if $val eq '__CurrentUser__';


   my $subkey = '';
   if ($key =~ /^(.+?)\.(.+)$/) {
     $key = $1;
     $subkey = $2;
   }

      my $class;
      if (exists $lcfields{lc $key}) {
        $key = $lcfields{lc $key};
        $class = $FIELD_METADATA{$key}->[0];
      }
   # no longer have a default, since CF's are now a real class, not fallthrough
   # fixme: "default class" is not Generic.

 
   die "Unknown field: $key" unless $class;

      $self->{_sql_localdepth} = 0;
      die "No such dispatch method: $class"
        unless exists $dispatch{$class};
      my $sub = $dispatch{$class} || die;;
      if ($can_bundle{$class} &&
          (!@bundle ||
            ($bundle[-1]->{dispatch} == $sub &&
             $bundle[-1]->{key} eq $key &&
             $bundle[-1]->{subkey} eq $subkey)))
      {
          push @bundle, {
              dispatch => $sub,
              key      => $key,
              op       => $op,
              val      => $val,
              ea       => $ea || "",
              subkey   => $subkey,
          };
      } else {
        $self->_close_bundle(@bundle);  @bundle = ();
        $sub->(
               $self,
               $key,
               $op,
               $val,
               SUBCLAUSE =>  "",  # don't need anymore
               ENTRYAGGREGATOR => $ea || "",
               SUBKEY => $subkey,
              );
      }

      $self->{_sql_looking_at}{lc $key} = 1;
  
      ($ea,$key,$op,$value) = ("","","","");
  
      $want = CLOSE_PAREN | AGGREG;
    } else {
      die "I'm lost";
    }

    $last = $current;
  } # while

  $self->_close_bundle(@bundle);  @bundle = ();

  die "Incomplete query"
    unless (($want | CLOSE_PAREN) || ($want | KEYWORD));

  die "Incomplete Query"
    unless ($last && ($last | CLOSE_PAREN) || ($last || VALUE));

  # This will never happen, because the parser will complain
  die "Mismatched parentheses"
    unless $depth == 0;

}


=head2 ClausesToSQL

=cut

sub ClausesToSQL {
  my $self = shift;
  my $clauses = shift;
  my @sql;

  for my $f (keys %{$clauses}) {
    my $sql;
    my $first = 1;

    # Build SQL from the data hash
    for my $data ( @{ $clauses->{$f} } ) {
      $sql .= $data->[0] unless $first; $first=0; # ENTRYAGGREGATOR
      $sql .= " '". $data->[2] . "' ";            # FIELD
      $sql .= $data->[3] . " ";                   # OPERATOR
      $sql .= "'". $data->[4] . "' ";             # VALUE
    }

    push @sql, " ( " . $sql . " ) ";
  }

  return join("AND",@sql);
}

=head2 FromSQL

Convert a RT-SQL string into a set of SearchBuilder restrictions.

Returns (1, 'Status message') on success and (0, 'Error Message') on
failure.


=begin testing

use RT::Tickets;
use strict;

my $tix = RT::Tickets->new($RT::SystemUser);
{
    my $query = "Status = 'open'";
    my ($status, $msg)  = $tix->FromSQL($query);
    ok ($status, "correct query") or diag("error: $msg");
}


my (@created,%created);
my $string = 'subject/content SQL test';
{
    my $t = RT::Ticket->new($RT::SystemUser);
    ok( $t->Create(Queue => 'General', Subject => $string), "Ticket Created");
    $created{ $t->Id }++; push @created, $t->Id;
}

{
    my $Message = MIME::Entity->build(
                     Subject     => 'this is my subject',
                     From        => 'jesse@example.com',
                     Data        => [ $string ],
            );

    my $t = RT::Ticket->new($RT::SystemUser);
    ok( $t->Create( Queue => 'General',
                    Subject => 'another ticket',
                    MIMEObj => $Message,
                    MemberOf => $created[0]
                  ),
        "Ticket Created"
    );
    $created{ $t->Id }++; push @created, $t->Id;
}

{
    my $query = ("Subject LIKE '$string' OR Content LIKE '$string'");
    my ($status, $msg) = $tix->FromSQL($query);
    ok ($status, "correct query") or diag("error: $msg");

    my $count = 0;
    while (my $tick = $tix->Next) {
        $count++ if $created{ $tick->id };
    }
    is ($count, scalar @created, "number of returned tickets same as entered");
}

{
    my $query = "id = $created[0] OR MemberOf = $created[0]";
    my ($status, $msg) = $tix->FromSQL($query);
    ok ($status, "correct query") or diag("error: $msg");

    my $count = 0;
    while (my $tick = $tix->Next) {
        $count++ if $created{ $tick->id };
    }
    is ($count, scalar @created, "number of returned tickets same as entered");
}


=end testing


=cut

sub FromSQL {
  my ($self,$query) = @_;

  {
    # preserve first_row and show_rows across the CleanSlate
    local($self->{'first_row'}, $self->{'show_rows'});
    $self->CleanSlate;
  }
  $self->_InitSQL();

  return (1,$self->loc("No Query")) unless $query;

  $self->{_sql_query} = $query;
  eval { $self->_parser( $query ); };
    if ($@) {
        $RT::Logger->error( "Query error in <<$query>>:\n$@" );
        return(0,$@);
    }
  # We only want to look at EffectiveId's (mostly) for these searches.
  unless (exists $self->{_sql_looking_at}{'effectiveid'}) {
  $self->SUPER::Limit( FIELD           => 'EffectiveId',
                     ENTRYAGGREGATOR => 'AND',
                     OPERATOR        => '=',
                     QUOTEVALUE      => 0,
                     VALUE           => 'main.id'
    );    #TODO, we shouldn't be hard #coding the tablename to main.
    }
  # FIXME: Need to bring this logic back in

  #      if ($self->_isLimited && (! $self->{'looking_at_effective_id'})) {
  #         $self->SUPER::Limit( FIELD => 'EffectiveId',
  #               OPERATOR => '=',
  #               QUOTEVALUE => 0,
  #               VALUE => 'main.id');   #TODO, we shouldn't be hard coding the tablename to main.
  #       }
  # --- This is hardcoded above.  This comment block can probably go.
  # Or, we need to reimplement the looking_at_effective_id toggle.

  # Unless we've explicitly asked to look at a specific Type, we need
  # to limit to it.
  unless ($self->{looking_at_type}) {
    $self->SUPER::Limit( FIELD => 'Type', OPERATOR => '=', VALUE => 'ticket');
  }

  # We don't want deleted tickets unless 'allow_deleted_search' is set
  unless( $self->{'allow_deleted_search'} ) {
    $self->SUPER::Limit(FIELD => 'Status',
                        OPERATOR => '!=',
                        VALUE => 'deleted');
  }


  # set SB's dirty flag
  $self->{'must_redo_search'} = 1;
  $self->{'RecalcTicketLimits'} = 0;                                           

  return (1,$self->loc("Valid Query"));

}

=head2 Query

Returns the query that this object was initialized with

=cut

sub Query {
    my $self = shift;
    return ($self->{_sql_query}); 
}



1;

=pod

=head2 Exceptions

Most of the RT code does not use Exceptions (die/eval) but it is used
in the TicketSQL code for simplicity and historical reasons.  Lest you
be worried that the dies will trigger user visible errors, all are
trapped via evals.

99% of the dies fall in subroutines called via FromSQL and then parse.
(This includes all of the _FooLimit routines in Tickets_Overlay.pm.)
The other 1% or so are via _ProcessRestrictions.

All dies are trapped by eval {}s, and will be logged at the 'error'
log level.  The general failure mode is to not display any tickets.

=head2 General Flow

Legacy Layer:

   Legacy LimitFoo routines build up a RestrictionsHash

   _ProcessRestrictions converts the Restrictions to Clauses
   ([key,op,val,rest]).

   Clauses are converted to RT-SQL (TicketSQL)

New RT-SQL Layer:

   FromSQL calls the parser

   The parser calls the _FooLimit routines to do DBIx::SearchBuilder
   limits.

And then the normal SearchBuilder/Ticket routines are used for
display/navigation.

=cut

