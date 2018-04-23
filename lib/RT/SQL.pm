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

package RT::SQL;

use strict;
use warnings;


# States
use constant VALUE       => 1;
use constant AGGREG      => 2;
use constant OP          => 4;
use constant OPEN_PAREN  => 8;
use constant CLOSE_PAREN => 16;
use constant KEYWORD     => 32;
my @tokens = qw[VALUE AGGREGATOR OPERATOR OPEN_PAREN CLOSE_PAREN KEYWORD];

use Regexp::Common qw /delimited/;
my $re_aggreg      = qr[(?i:AND|OR)];
my $re_delim       = qr[$RE{delimited}{-delim=>qq{\'\"}}];
my $re_value       = qr[[+-]?\d+|(?i:NULL)|$re_delim];
my $re_keyword     = qr[[{}\w\.]+|$re_delim];
my $re_op          = qr[=|!=|>=|<=|>|<|(?i:IS NOT)|(?i:IS)|(?i:NOT LIKE)|(?i:LIKE)|(?i:NOT STARTSWITH)|(?i:STARTSWITH)|(?i:NOT ENDSWITH)|(?i:ENDSWITH)]; # long to short
my $re_open_paren  = qr[\(];
my $re_close_paren = qr[\)];

sub ParseToArray {
    my ($string) = shift;

    my ($tree, $node, @pnodes);
    $node = $tree = [];

    my %callback;
    $callback{'OpenParen'} = sub { push @pnodes, $node; $node = []; push @{ $pnodes[-1] }, $node };
    $callback{'CloseParen'} = sub { $node = pop @pnodes };
    $callback{'EntryAggregator'} = sub { push @$node, $_[0] };
    $callback{'Condition'} = sub { push @$node, { key => $_[0], op => $_[1], value => $_[2] } };

    Parse($string, \%callback);
    return $tree;
}

sub Parse {
    my ($string, $cb) = @_;
    my $loc = sub {HTML::Mason::Commands::loc(@_)};
    $string = '' unless defined $string;

    my $want = KEYWORD | OPEN_PAREN;
    my $last = 0;

    my $depth = 0;
    my ($key,$op,$value) = ("","","");

    # order of matches in the RE is important.. op should come early,
    # because it has spaces in it.    otherwise "NOT LIKE" might be parsed
    # as a keyword or value.

    while ($string =~ /(
                        $re_aggreg
                        |$re_op
                        |$re_keyword
                        |$re_value
                        |$re_open_paren
                        |$re_close_paren
                       )/iogx )
    {
        my $match = $1;

        # Highest priority is last
        my $current = 0;
        $current = OP          if ($want & OP)          && $match =~ /^$re_op$/io;
        $current = VALUE       if ($want & VALUE)       && $match =~ /^$re_value$/io;
        $current = KEYWORD     if ($want & KEYWORD)     && $match =~ /^$re_keyword$/io;
        $current = AGGREG      if ($want & AGGREG)      && $match =~ /^$re_aggreg$/io;
        $current = OPEN_PAREN  if ($want & OPEN_PAREN)  && $match =~ /^$re_open_paren$/io;
        $current = CLOSE_PAREN if ($want & CLOSE_PAREN) && $match =~ /^$re_close_paren$/io;


        unless ($current && $want & $current) {
            my $tmp = substr($string, 0, pos($string)- length($match));
            $tmp .= '>'. $match .'<--here'. substr($string, pos($string));
            my $msg = $loc->("Wrong query, expecting a [_1] in '[_2]'", _BitmaskToString($want), $tmp);
            return $cb->{'Error'}->( $msg ) if $cb->{'Error'};
            die $msg;
        }

        # State Machine:

        # Parens are highest priority
        if ( $current & OPEN_PAREN ) {
            $cb->{'OpenParen'}->();
            $depth++;
            $want = KEYWORD | OPEN_PAREN;
        }
        elsif ( $current & CLOSE_PAREN ) {
            $cb->{'CloseParen'}->();
            $depth--;
            $want = AGGREG;
            $want |= CLOSE_PAREN if $depth;
        }
        elsif ( $current & AGGREG ) {
            $cb->{'EntryAggregator'}->( $match );
            $want = KEYWORD | OPEN_PAREN;
        }
        elsif ( $current & KEYWORD ) {
            $key = $match;
            $want = OP;
        }
        elsif ( $current & OP ) {
            $op = $match;
            $want = VALUE;
        }
        elsif ( $current & VALUE ) {
            $value = $match;

            # Remove surrounding quotes and unescape escaped
            # characters from $key, $match
            for ( $key, $value ) {
                if ( /$re_delim/o ) {
                    substr($_,0,1) = "";
                    substr($_,-1,1) = "";
                }
                s!\\(.)!$1!g;
            }

            $cb->{'Condition'}->( $key, $op, $value );

            ($key,$op,$value) = ("","","");
            $want = AGGREG;
            $want |= CLOSE_PAREN if $depth;
        } else {
            my $msg = $loc->("Query parser is lost");
            return $cb->{'Error'}->( $msg ) if $cb->{'Error'};
            die $msg;
        }

        $last = $current;
    } # while

    unless( !$last || $last & (CLOSE_PAREN | VALUE) ) {
        my $msg = $loc->("Incomplete query, last element ([_1]) is not close paren or value in '[_2]'",
                         _BitmaskToString($last),
                         $string);
        return $cb->{'Error'}->( $msg ) if $cb->{'Error'};
        die $msg;
    }

    if( $depth ) {
        my $msg = $loc->("Incomplete query, [quant,_1,unclosed paren,unclosed parens] in '[_2]'", $depth, $string);
        return $cb->{'Error'}->( $msg ) if $cb->{'Error'};
        die $msg;
    }
}

sub _BitmaskToString {
    my $mask = shift;

    my @res;
    for( my $i = 0; $i<@tokens; $i++ ) {
        next unless $mask & (1<<$i);
        push @res, $tokens[$i];
    }

    my $tmp = join ', ', splice @res, 0, -1;
    unshift @res, $tmp if $tmp;
    return join ' or ', @res;
}

RT::Base->_ImportOverlays();

1;
