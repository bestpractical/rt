# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
use strict;
use warnings;

# Import configuration data from the lexcial scope of __PACKAGE__ (or
# at least where those two Subroutines are defined.)

my %FIELDS = %{FIELDS()};
my %dispatch = %{dispatch()};

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
  $self->{'_sql_transalias'}    = undef;
  $self->{'_sql_trattachalias'} = undef;
  $self->{'_sql_keywordalias'}  = undef;
  $self->{'_sql_depth'}         = 0;
  $self->{'_sql_localdepth'}    = 0;
  $self->{'_sql_query'}         = '';
  $self->{'_sql_looking_at'}    = {};

}

sub _SQLLimit {
  # All SQL stuff goes into one SB subclause so we can deal with all
  # the aggregation
  my $this = shift;
  $this->SUPER::Limit(@_,
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

sub _match {
  # Case insensitive equality
  my ($y,$x) = @_;
  return 1 if $x =~ /^$y$/i;
  #  return 1 if ((lc $x) eq (lc $y)); # Why isnt this equiv?
  return 0;
}

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
use constant PAREN => 8;
use constant KEYWORD => 16;
my @tokens = qw[VALUE AGGREG OP PAREN KEYWORD];

my $re_aggreg = qr[(?i:AND|OR)];
my $re_value  = qr[$RE{delimited}{-delim=>qq{\'\"}}|\d+];
my $re_keyword = qr[$RE{delimited}{-delim=>qq{\'\"}}|(?:\{|\}|\w|\.)+];
my $re_op     = qr[=|!=|>=|<=|>|<|(?i:IS NOT)|(?i:IS)|(?i:NOT LIKE)|(?i:LIKE)]; # long to short
my $re_paren  = qr'\(|\)';

sub _parser {
  my ($self,$string) = @_;
  my $want = KEYWORD | PAREN;
  my $last = undef;

  my $depth = 0;

  my ($ea,$key,$op,$value) = ("","","","");

  while ($string =~ /(
                      $re_aggreg
                      |$re_keyword
                      |$re_value
                      |$re_op
                      |$re_paren
                     )/igx ) {
    my $val = $1;
    my $current = 0;

    # Highest priority is last
    $current = OP      if _match($re_op,$val);
    $current = VALUE   if _match($re_value,$val);
    $current = KEYWORD if _match($re_keyword,$val) && ($want & KEYWORD);
    $current = AGGREG  if _match($re_aggreg,$val);
    $current = PAREN   if _match($re_paren,$val);

    unless ($current && $want & $current) {
      # Error
      # FIXME: I will only print out the highest $want value
      die "Error near ->$val<- expecting a ", $tokens[((log $want)/(log 2))], " in $string\n";
    }

    # State Machine:

    # Parens are highest priority
    if ($current & PAREN) {
      if ($val eq "(") {
        $depth++;
        $self->_OpenParen;

      } else {
        $depth--;
        $self->_CloseParen;
      }

      $want = KEYWORD | PAREN | AGGREG;
    }
    elsif ( $current & AGGREG ) {
      $ea = $val;
      $want = KEYWORD | PAREN;
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
      if ($key =~ /$RE{delimited}{-delim=>qq{\'\"}}/) {
        substr($key,0,1) = "";
        substr($key,-1,1) = "";
      }
      if ($val =~ /$RE{delimited}{-delim=>qq{\'\"}}/) {
        substr($val,0,1) = "";
        substr($val,-1,1) = "";
      }
      # Unescape escaped characters                                            
      $key =~ s!\\(.)!$1!g;                                                    
      $val =~ s!\\(.)!$1!g;     
      #    print "$ea Key=[$key] op=[$op]  val=[$val]\n";


   my $subkey;
   if ($key =~ /^(.+?)\.(.+)$/) {
     $key = $1;
     $subkey = $2;
   }

      my $class;
      my ($stdkey) = grep { /^$key$/i } (keys %FIELDS);
      if ($stdkey && exists $FIELDS{$stdkey}) {
        $class = $FIELDS{$key}->[0];
        $key = $stdkey;
      }
   # no longer have a default, since CF's are now a real class, not fallthrough
   # fixme: "default class" is not Generic.

 
   die "Unknown field: $key" unless $class;

      $self->{_sql_localdepth} = 0;
      die "No such dispatch method: $class"
        unless exists $dispatch{$class};
      my $sub = $dispatch{$class} || die;;
      $sub->(
             $self,
             $key,
             $op,
             $val,
             SUBCLAUSE =>  "",  # don't need anymore
             ENTRYAGGREGATOR => $ea || "",
             SUBKEY => $subkey,
            );

      $self->{_sql_looking_at}{lc $key} = 1;

      ($ea,$key,$op,$value) = ("","","","");

      $want = PAREN | AGGREG;
    } else {
      die "I'm lost";
    }

    $last = $current;
  } # while

  die "Incomplete query"
    unless (($want | PAREN) || ($want | KEYWORD));

  die "Incomplete Query"
    unless ($last && ($last | PAREN) || ($last || VALUE));

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
      $sql .= $data->[0] unless $first; $first=0;
      $sql .= " '". $data->[2] . "' ";
      $sql .= $data->[3] . " ";
      $sql .= "'". $data->[4] . "' ";
    }

    push @sql, " ( " . $sql . " ) ";
  }

  return join("AND",@sql);
}

=head2 FromSQL

Convert a RT-SQL string into a set of SearchBuilder restrictions.

Returns (1, 'Status message') on success and (0, 'Error Message') on
failure.

=cut

sub FromSQL {
  my ($self,$query) = @_;

  $self->CleanSlate;
  $self->_InitSQL();
  return (1,"No Query") unless $query;

  $self->{_sql_query} = $query;
  eval { $self->_parser( $query ); };
  $RT::Logger->error( $@ ) if $@;
  return(0,$@) if $@;

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
    $self->SUPER::Limit( FIELD => 'Type',
                         OPERATOR => '=',
                         VALUE => 'ticket');
  }

  # set SB's dirty flag
  $self->{'must_redo_search'} = 1;
  $self->{'RecalcTicketLimits'} = 0;                                           

  return (1,"Good Query");

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

