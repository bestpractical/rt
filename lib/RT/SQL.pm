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
my $re_value       = qr[\d+|NULL|$re_delim];
my $re_keyword     = qr[[{}\w\.]+|$re_delim];
my $re_op          = qr[=|!=|>=|<=|>|<|(?i:IS NOT)|(?i:IS)|(?i:NOT LIKE)|(?i:LIKE)]; # long to short
my $re_open_paren  = qr[\(];
my $re_close_paren = qr[\)];

sub ParseToArray {
    my ($tree, $node, @pnodes);
    $node = $tree = [];

    my %callback;
    $callback{'OpenParen'} = sub { push @pnodes, $node; $node = []; push @{ $pnodes[-1] }, $node };
    $callback{'CloseParen'} = sub { $node = pop @pnodes };
    $callback{'EntryAggregator'} = sub { push @$node, $_[0] };
    $callback{'Condition'} = sub { push @$node, { key => $_[0], op => $_[1], value => $_[2] } };

    Parse(shift, \%callback);
    return $tree;
}

sub Parse {
    my ($string, $cb) = @_;
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
            die "Wrong query, expecting a ", _BitmaskToString($want), " in '$tmp'";
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
            die "Query parser is lost";
        }

        $last = $current;
    } # while

    unless( !$last || $last & (CLOSE_PAREN | VALUE) ) {
        die "Incomplete query, last element (",
            _BitmaskToString($last),
            ") is not CLOSE_PAREN or VALUE in '$string'";
    }

    if( $depth ) {
        die "Incomplete query, $depth paren(s) isn't closed in '$string'";
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

1;
