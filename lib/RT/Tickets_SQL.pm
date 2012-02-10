# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
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

package RT::Tickets;

use strict;
use warnings;


use RT::SQL;
use Regexp::Common qw/delimited/;

# Import configuration data from the lexcial scope of __PACKAGE__ (or
# at least where those two Subroutines are defined.)

our (%FIELD_METADATA, %dispatch, %can_bundle);

# Lower Case version of FIELDS, for case insensitivity
my %lcfields = map { ( lc($_) => $_ ) } (keys %FIELD_METADATA);

sub _InitSQL {
  my $self = shift;

  # Private Member Variables (which should get cleaned)
  $self->{'_sql_transalias'}    = undef;
  $self->{'_sql_trattachalias'} = undef;
  $self->{'_sql_cf_alias'}  = undef;
  $self->{'_sql_object_cfv_alias'}  = undef;
  $self->{'_sql_watcher_join_users_alias'} = undef;
  $self->{'_sql_query'}         = '';
  $self->{'_sql_looking_at'}    = {};
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

sub _close_bundle {
    my ($self, @bundle) = @_;
    return unless @bundle;

    if ( @bundle == 1 ) {
        $bundle[0]->{'dispatch'}->(
            $self,
            $bundle[0]->{'key'},
            $bundle[0]->{'op'},
            $bundle[0]->{'val'},
            SUBCLAUSE       => '',
            ENTRYAGGREGATOR => $bundle[0]->{ea},
            SUBKEY          => $bundle[0]->{subkey},
        );
    }
    else {
        my @args;
        foreach my $chunk (@bundle) {
            push @args, [
                $chunk->{key},
                $chunk->{op},
                $chunk->{val},
                SUBCLAUSE       => '',
                ENTRYAGGREGATOR => $chunk->{ea},
                SUBKEY          => $chunk->{subkey},
            ];
        }
        $bundle[0]->{dispatch}->( $self, \@args );
    }
}

sub _parser {
    my ($self,$string) = @_;
    my @bundle;
    my $ea = '';

    my %callback;
    $callback{'OpenParen'} = sub {
      $self->_close_bundle(@bundle); @bundle = ();
      $self->_OpenParen
    };
    $callback{'CloseParen'} = sub {
      $self->_close_bundle(@bundle); @bundle = ();
      $self->_CloseParen;
    };
    $callback{'EntryAggregator'} = sub { $ea = $_[0] || '' };
    $callback{'Condition'} = sub {
        my ($key, $op, $value) = @_;

        # key has dot then it's compound variant and we have subkey
        my $subkey = '';
        ($key, $subkey) = ($1, $2) if $key =~ /^([^\.]+)\.(.+)$/;

        # normalize key and get class (type)
        my $class;
        if (exists $lcfields{lc $key}) {
            $key = $lcfields{lc $key};
            $class = $FIELD_METADATA{$key}->[0];
        }
        die "Unknown field '$key' in '$string'" unless $class;

        # replace __CurrentUser__ with id
        $value = $self->CurrentUser->id if $value eq '__CurrentUser__';


        unless( $dispatch{ $class } ) {
            die "No dispatch method for class '$class'"
        }
        my $sub = $dispatch{ $class };

        if ( $can_bundle{ $class }
             && ( !@bundle
                  || ( $bundle[-1]->{dispatch}  == $sub
                       && $bundle[-1]->{key}    eq $key
                       && $bundle[-1]->{subkey} eq $subkey
                     )
                )
           )
        {
            push @bundle, {
                dispatch => $sub,
                key      => $key,
                op       => $op,
                val      => $value,
                ea       => $ea,
                subkey   => $subkey,
            };
        }
        else {
            $self->_close_bundle(@bundle); @bundle = ();
            $sub->( $self, $key, $op, $value,
                    SUBCLAUSE       => '',  # don't need anymore
                    ENTRYAGGREGATOR => $ea,
                    SUBKEY          => $subkey,
                  );
        }
        $self->{_sql_looking_at}{lc $key} = 1;
        $ea = '';
    };
    RT::SQL::Parse($string, \%callback);
    $self->_close_bundle(@bundle); @bundle = ();
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




=cut

sub FromSQL {
    my ($self,$query) = @_;

    {
        # preserve first_row and show_rows across the CleanSlate
        local ($self->{'first_row'}, $self->{'show_rows'});
        $self->CleanSlate;
    }
    $self->_InitSQL();

    return (1, $self->loc("No Query")) unless $query;
    $self->{_sql_query} = $query;

    ( my $ret, $query ) = $self->PrepareSQL( $query );
    return ( $ret, $query ) unless $ret;

    eval { $self->_parser( $query ); };
    if ( $@ ) {
        $RT::Logger->error( $@ );
        return (0, $@);
    }

    # We only want to look at EffectiveId's (mostly) for these searches.
    unless ( exists $self->{_sql_looking_at}{'effectiveid'} ) {
        #TODO, we shouldn't be hard #coding the tablename to main.
        $self->SUPER::Limit( FIELD           => 'EffectiveId',
                             VALUE           => 'main.id',
                             ENTRYAGGREGATOR => 'AND',
                             QUOTEVALUE      => 0,
                           );
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
    unless ( $self->{looking_at_type} ) {
        $self->SUPER::Limit( FIELD => 'Type', VALUE => 'ticket' );
    }

    # We don't want deleted tickets unless 'allow_deleted_search' is set
    unless( $self->{'allow_deleted_search'} ) {
        $self->SUPER::Limit( FIELD    => 'Status',
                             OPERATOR => '!=',
                             VALUE => 'deleted',
                           );
    }

    # set SB's dirty flag
    $self->{'must_redo_search'} = 1;
    $self->{'RecalcTicketLimits'} = 0;                                           

    return (1, $self->loc("Valid Query"));
}

=head2 PrepareSQL

Prepare the query.

Returns (1, $query ) on success and (0, 'Error Message') on failure.

=cut

sub PrepareSQL {
    my $self = shift;
    my $query = shift;

    my $config = RT->Config->Get('FullTextSearch') || {};
    if ( $config->{Indexed} && RT->Config->Get('DatabaseType') eq 'mysql' ) {

      # mysql doesn't bother asking sphinx if there are different query clauses.
      # I guess it's because mysql thinks there can't be a field who can meet
      # both "query='foo'' and "query='bar'", so it returns empty set directly.
      # that's why we combine those query into one here.
      # currently only continuous content queries are supported.

        my $re_delim = $RE{delimited}{ -delim => qq{\'\"} };
        my $re_content =
          '(?:^|\s+)Content\s+(?:(NOT)\s+)?LIKE\s+(' . $re_delim . ')';
        my $first_escaped;
        while ( $query =~ /($re_content\s+(AND|OR)\s*$re_content)/i ) {
            my $whole      = $1;
            my $first_neg  = $2;
            my $first      = $3;
            my $rel        = $4;
            my $second_neg = $5;
            my $second     = $6;
            $rel = $rel =~ /and/i ? '&' : '|';

            my $first_quote = substr $first, 0, 1;
            $first =~ s!^$first_quote!!;
            $first =~ s!$first_quote$!!;

            if ( !$first_escaped ) {
                $first =~ s/(&|\||!|-|\(|\))/\\$1/g;
                $first = "!($first)" if $first_neg;
            }

            # we will quote value with '
            $first =~ s!'!\\'!g if $first_quote eq '"';

            my $second_quote = substr $second, 0, 1;
            $second =~ s!^$second_quote!!;
            $second =~ s!$second_quote$!!;
            $second =~ s/(&|\||!|-|\(|\))/\\$1/g;
            $second = "!($second)" if $second_neg;

            # we will quote value with '
            $second =~ s!'!\\'!g if $second_quote eq '"';

            $query =~ s!\Q$whole!Content LIKE '($first$rel$second)'!;

            $self->{_sql_sphinx_mode} = 'boolean';
            $first_escaped = 1;
        }

        if ( $query =~ /$re_content.*$re_content/s ) {
            return ( 0, $self->loc("Incontinuous Content queries") );
        }
        elsif ( $query =~ /$re_content/ && $1 ) {
            return ( 0, $self->loc("Single NOT operator is not supported") );
        }
    }
    return ( 1, $query );
}

=head2 Query

Returns the query that this object was initialized with

=cut

sub Query {
    return ($_[0]->{_sql_query});
}

{
my %inv = (
    '=' => '!=', '!=' => '=', '<>' => '=',
    '>' => '<=', '<' => '>=', '>=' => '<', '<=' => '>',
    'is' => 'IS NOT', 'is not' => 'IS',
    'like' => 'NOT LIKE', 'not like' => 'LIKE',
    'matches' => 'NOT MATCHES', 'not matches' => 'MATCHES',
    'startswith' => 'NOT STARTSWITH', 'not startswith' => 'STARTSWITH',
    'endswith' => 'NOT ENDSWITH', 'not endswith' => 'ENDSWITH',
);

my %range = map { $_ => 1 } qw(> >= < <=);

sub ClassifySQLOperation {
    my $self = shift;
    my $op = shift;

    my $is_negative = 0;
    if ( $op eq '!=' || $op =~ /\bNOT\b/i ) {
        $is_negative = 1;
    }

    my $is_null = 0;
    if ( 'is not' eq lc($op) || 'is' eq lc($op) ) {
        $is_null = 1;
    }

    return ($is_negative, $is_null, $inv{lc $op}, $range{lc $op});
} }

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

