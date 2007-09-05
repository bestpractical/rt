# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
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
# http://www.gnu.org/copyleft/gpl.html.
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
package RT::Model::Tickets;

use strict;
use warnings;

use RT::SQL;

# Import configuration data from the lexcial scope of __PACKAGE__ (or
# at least where those two Subroutines are defined.)

our (%FIELD_METADATA, %dispatch, %can_bundle);

# Lower Case version of columns, for case insensitivity
my %lcfields = map { ( lc($_) => $_ ) } (keys %FIELD_METADATA);

sub _initSQL {
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

sub _sql_limit {
  my $self = shift;
    my %args = (@_);
    if ($args{'column'} eq 'EffectiveId' &&
         (!$args{'alias'} || $args{'alias'} eq 'main' ) ) {
        $self->{'looking_at_effective_id'} = 1;
    }      
    
    if ($args{'column'} eq 'Type' &&
         (!$args{'alias'} || $args{'alias'} eq 'main' ) ) {
        $self->{'looking_at_type'} = 1;
    }

  # All SQL stuff goes into one SB subclause so we can deal with all
  # the aggregation
  $self->SUPER::limit(%args,
                      subclause => 'ticketsql');
}

sub _sql_join {
  # All SQL stuff goes into one SB subclause so we can deal with all
  # the aggregation
  my $this = shift;

  $this->join(@_,
		     subclause => 'ticketsql');
}

# Helpers
sub open_paren {
  $_[0]->SUPER::open_paren( 'ticketsql' );
}
sub close_paren {
  $_[0]->SUPER::close_paren( 'ticketsql' );
}

=head1 SQL Functions

=cut

=head2 Robert's Simple SQL Parser

Documentation In Progress

The Parser/Tokenizer is a relatively simple state machine that scans through a SQL WHERE clause type string extracting a token at a time (where a token is:

  value -> quoted string or number
  AGGREGator -> AND or OR
  KEYWORD -> quoted string or single word
  OPerator -> =,!=,LIKE,etc..
  PARENthesis -> open or close.

And that stream of tokens is passed through the "machine" in order to build up a structure that looks like:

       KEY OP value
  AND  KEY OP value
  OR   KEY OP value

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
            subclause       => '',
            entry_aggregator => $bundle[0]->{ea},
            subkey          => $bundle[0]->{subkey},
        );
    }
    else {
        my @args;
        foreach my $chunk (@bundle) {
            push @args, [
                $chunk->{key},
                $chunk->{op},
                $chunk->{val},
                subclause       => '',
                entry_aggregator => $chunk->{ea},
                subkey          => $chunk->{subkey},
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
    $callback{'open_paren'} = sub {
      $self->_close_bundle(@bundle); @bundle = ();
      $self->open_paren
    };
    $callback{'close_paren'} = sub {
      $self->_close_bundle(@bundle); @bundle = ();
      $self->close_paren;
    };
    $callback{'entry_aggregator'} = sub { $ea = $_[0] || '' };
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
                    subclause       => '',  # don't need anymore
                    entry_aggregator => $ea,
                    subkey          => $subkey,
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
      $sql .= $data->[0] unless $first; $first=0; # entry_aggregator
      $sql .= " '". $data->[2] . "' ";            # column
      $sql .= $data->[3] . " ";                   # operator
      $sql .= "'". $data->[4] . "' ";             # value
    }

    push @sql, " ( " . $sql . " ) ";
  }

  return join("AND",@sql);
}

=head2 from_sql

Convert a RT-SQL string into a set of SearchBuilder restrictions.

Returns (1, 'Status message') on success and (0, 'Error Message') on
failure.




=cut

sub from_sql {
    my ($self,$query) = @_;

    {
        # preserve first_row and show_rows across the clean_slate
        local ($self->{'first_row'}, $self->{'show_rows'});
        $self->clean_slate;
    }
    $self->_initSQL();

    return (1, $self->loc("No Query")) unless $query;

    $self->{_sql_query} = $query;
    eval { $self->_parser( $query ); };
    if ( $@ ) {
        $RT::Logger->error( $@ );
        return (0, $@);
    }

    # We only want to look at EffectiveId's (mostly) for these searches.
    unless ( exists $self->{_sql_looking_at}{'effectiveid'} ) {
        #TODO, we shouldn't be hard #coding the tablename to main.
        $self->SUPER::limit( column           => 'EffectiveId',
                             value           => 'main.id',
                             entry_aggregator => 'AND',
                             quote_value      => 0,
                           );
    }
    # FIXME: Need to bring this logic back in

    #      if ($self->_isLimited && (! $self->{'looking_at_effective_id'})) {
    #         $self->SUPER::limit( column => 'EffectiveId',
    #               operator => '=',
    #               quote_value => 0,
    #               value => 'main.id');   #TODO, we shouldn't be hard coding the tablename to main.
    #       }
    # --- This is hardcoded above.  This comment block can probably go.
    # Or, we need to reimplement the looking_at_effective_id toggle.

    # Unless we've explicitly asked to look at a specific Type, we need
    # to limit to it.
    unless ( $self->{looking_at_type} ) {
        $self->SUPER::limit( column => 'Type', value => 'ticket' );
    }

    # We don't want deleted tickets unless 'allow_deleted_search' is set
    unless( $self->{'allow_deleted_search'} ) {
        $self->SUPER::limit( column    => 'Status',
                             operator => '!=',
                             value => 'deleted',
                           );
    }

    # set SB's dirty flag
    $self->{'must_redo_search'} = 1;
    $self->{'RecalcTicketLimits'} = 0;                                           

    return (1, $self->loc("Valid Query"));
}

=head2 Query

Returns the query that this object was initialized with

=cut

sub Query {
    return ($_[0]->{_sql_query});
}



1;

=pod

=head2 Exceptions

Most of the RT code does not use Exceptions (die/eval) but it is used
in the TicketSQL code for simplicity and historical reasons.  Lest you
be worried that the dies will trigger user visible errors, all are
trapped via evals.

99% of the dies fall in subroutines called via from_sql and then parse.
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

   from_sql calls the parser

   The parser calls the _FooLimit routines to do Jifty::DBI
   limits.

And then the normal SearchBuilder/Ticket routines are used for
display/navigation.

=cut

