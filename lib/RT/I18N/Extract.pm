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

package RT::I18N::Extract;

use strict;
use warnings;

use Regexp::Common;
use File::Spec;
use File::Find;
use Locale::PO;

sub new {
    return bless {
        results => {},
        errors  => [],
    }, shift;
}

sub all {
    my $self = shift;
    my $merged = sub { $self->from($File::Find::name) };
    File::Find::find(
        { wanted => $merged, no_chdir => 1, follow => 1 },
        grep {-d $_} qw(bin sbin lib share/html html etc),
    );
    return $self->results;
}

sub valid_to_extract {
    my $self = shift;
    my ($file) = @_;

    return unless -f $file;
    return if $file eq "lib/RT/StyleGuide.pod";
    return if $file eq "lib/RT/I18N/Extract.pm";
    return if $file =~ m{/[\.#][^/]*$} or $file =~ /\.bak$/;
    return if -f "$file.in";
    return 1;
}

sub from {
    my $self = shift;
    my ($file) = (@_);

    return unless $self->valid_to_extract($file);

    my $fh;
    unless (open $fh, '<', $file) {
        push @{$self->{errors}}, "$file:0: Cannot open for reading: $!";
        return;
    }
    my $contents = do { local $/; <$fh> };
    close $fh;

    # Provide the non-.in filename for the rest of error reporting and
    # POT file needs, as the .in file will not exist if looking in the
    # installed tree.
    $file =~ s/\.in$//;

    my %seen;
    my $line;

    my $_add = sub {
        my ($maybe_quoted, $key, $vars) = @_;
        $vars = '' unless defined $vars;

        $seen{$line}++;

        if ($maybe_quoted and $key =~ s/^(['"])(.*)\1$/$2/) {
            my $quote = $1;
            $key =~ s/\\(['"\\])/$1/g;

            if ($quote eq '"') {
                if ($key =~ /([\$\@]\w+)/) {
                    push @{$self->{errors}}, "$file:$line: Interpolated variable '$1' in \"$key\"";
                }
                if ($key =~ /\\n/) {
                    push @{$self->{errors}}, "$file:$line: Embedded newline in \"$key\"";
                }
            }
        }

        if ($key =~ /^\s/m || $key =~ /\s$/m) {
            push @{$self->{errors}}, "$file:$line: Extraneous whitespace in '$key'";
        }

        $vars =~ tr/\n\r//d;

        push @{ $self->{results}{$key} }, [ $file, $line, $vars ];
    };
    my $add = sub {$_add->(1, @_)};
    my $add_noquotes = sub {$_add->(0, @_)};

    my $extract = sub {
        my ($regex, $run) = @_;
        $line = 1;
        pos($contents) = 0;
        while ($contents =~ m!\G.*?$regex!sg) {
            my $match = substr($contents,$-[0],$+[0]-$-[0]);
            $line += ( $match =~ tr/\n/\n/ );
            $run->();
        }
    };

    my $ws = qr{[ ]*};
    my $punct = qr{[ \{\}\)\],;]*};
    my $quoted = $RE{delimited}{-delim=>q{'"}};

    # Mason filter: <&|/l&>...</&> and <&|/l_unsafe&>...</&>
    $extract->(qr! <&\|/l(?:_unsafe)?(.*?)&>  (.*?)  </&> !sox, sub {
        my ($key, $vars) = ($2, $1);
        if ($key =~ m! (<([%&]) .*? \2>) !sox) {
            push @{$self->{errors}}, "$file:$line: Mason content within loc: '$1'";
        }
        $add_noquotes->($key, $vars);
    });

    # Localization function: loc(...)
    $extract->(qr! \b loc
                   ( $RE{balanced}{-parens=>'()'} )
                 !sox, sub {
        # Re-parse what was in the parens for the string and optional arguments
        return unless "$1" =~ m! \( \s* ($quoted)  (.*?) \s* \) $ !sox;
        $add->($1, $2);
    });

    # Comment-based mark: "..." # loc
    $extract->(qr! ($quoted)      # Quoted string
                   $punct
                   $ws \# $ws loc
                   $ws $
                 !smox, sub {
        $add->($1);
    });

    # Comment-based mark for list to loc():  ("...", $foo, $bar)  # loc()
    $extract->(qr! ( $RE{balanced}{-parens=>'()'} )
                   $punct
                   $ws \# $ws loc \(\)
                   $ws $
                 !smox, sub {
        # Re-parse what was in the parens for the string and optional arguments
        return unless "$1" =~ m! \( \s* ($quoted)  (.*?) \s* \) $ !sox;
        $add->($1, $2);
    });

    # Comment-based qw mark: "qw(...)" # loc_qw
    $extract->(qr! qw \( ([^)]+) \)
                   $punct
                   $ws \# $ws loc_qw
                   $ws $
                 !smox, sub {
        $add_noquotes->($_) for split ' ', $1;
    });

    # Comment-based left pair mark: "..." => ... # loc_left_pair
    $extract->(qr! (\w+|$quoted)
                   \s* => [^#\n]+?
                   $ws \# $ws loc_left_pair
                   $ws $
                 !smox, sub {
        $add->($1);
    });

    # Comment-based pair mark: "..." => "..." # loc_pair
    $extract->(qr! (\w+|$quoted)
                   \s* => \s* ($quoted)
                   $punct
                   $ws \# $ws loc_pair
                   $ws $
                 !smox, sub {
        $add->($1);
        $add->($2);
    });

    # Specific key  foo => "...", #loc{foo}
    $extract->(qr! (\w+|$quoted)
                   \s* => \s* ($quoted)
                   (?-s: .*? ) \# $ws loc\{\1\}  # More lax about what matches before the #
                   $ws $
                 !smox, sub {
        $add->($2);
    });

    # Check for ones we missed
    $extract->(qr! \# $ws
                   (
                     loc
                     ( _\w+ | \(\) | {(\w+|$quoted)} )?
                   )
                   $ws $
                 !smox, sub {
        return if $seen{$line};
        push @{$self->{errors}}, "$file:$line: Localization comment '$1' did not match";
    });
}

sub results {
    my $self = shift;

    my %PO;
    for my $str ( sort keys %{$self->{results}} ) {
        my $entry = $self->{results}{$str};

        my $escape = sub { $_ = shift; s/\b_(\d+)/%$1/; $_ };
        $str =~ s/((?<!~)(?:~~)*)\[_(\d+)\]/$1%$2/g;
        $str =~ s/((?<!~)(?:~~)*)\[([A-Za-z#*]\w*),([^\]]+)\]/"$1%$2(".$escape->($3).")"/eg;
        $str =~ s/~([\[\]])/$1/g;

        my $po = Locale::PO->new(-msgid => $str, -msgstr => "");
        $po->reference( join ( ' ', sort map $_->[0].":".$_->[1], @{ $entry } ) );
        my %seen;
        my @vars;
        foreach my $find ( sort { $a->[2] cmp $b->[2] } grep { $_->[2] } @{ $entry } ) {
            my ( $file, $line, $var ) = @{$find};
            $var =~ s/^\s*,\s*//;
            $var =~ s/\s*$//;
            push @vars, "($var)" unless $seen{$var}++;
        }
        $po->automatic( join( "\n", @vars) );

        $PO{$po->msgid} = $po;
    }

    return %PO;
}

sub errors {
    my $self = shift;
    return @{$self->{errors}};
}

1;
