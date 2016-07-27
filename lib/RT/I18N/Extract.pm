# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

sub new {
    return bless {filecat => {}}, shift;
}

sub all {
    my $self = shift;
    my $merged = sub { $self->from($File::Find::name) };
    File::Find::find(
        { wanted => $merged, no_chdir => 1, follow => 1 },
        qw(bin sbin lib share html etc),
    );
    return $self->results;
}

sub from {
    my $self = shift;
    my ($file) = (@_);

    local $/;
    return if ( -d $file || !-e _ );

    my (undef, $dir, $file_only) = File::Spec->splitpath($file);
    local $_ = $file_only;
    return
      if ( $dir =~
        qr!lib/blib|lib/t/autogen|var|m4|local|share/fonts! );
    return if ( /\.(?:pot|po|bak|gif|png|psd|jpe?g|svg|css|js)$/ );
    return if ( /~|,D|,B$|extract-message-catalog$|tweak-template-locstring$/ );
    return if ( /StyleGuide.pod/ );
    return if ( /^[\.#]/ );
    return if ( -f "$file.in" );
    return if $file eq "lib/RT/I18N/Extract.pm";

    my $normalized = $file;
    $normalized =~ s'^\./'';
    $normalized =~ s'\.in$'';
    print "Looking at $normalized";

    unless (open _, '<', $file) {
        print "\n  Cannot open $file for reading ($!), skipping.\n\n";
        return;
    }

    my %FILECAT = %{$self->{filecat}};
    my $errors = 0;

    my $re_space_wo_nl = qr{(?!\n)\s};
    my $re_loc_suffix = qr{$re_space_wo_nl* \# $re_space_wo_nl* loc $re_space_wo_nl* $}mx;
    my $re_loc_qw_suffix = qr{$re_space_wo_nl* \# $re_space_wo_nl* loc_qw $re_space_wo_nl* $}mx;
    my $re_loc_paren_suffix = qr{$re_space_wo_nl* \# $re_space_wo_nl* loc \(\) $re_space_wo_nl* $}mx;
    my $re_loc_pair_suffix = qr{$re_space_wo_nl* \# $re_space_wo_nl* loc_pair $re_space_wo_nl* $}mx;
    my $re_loc_left_pair_suffix = qr{$re_space_wo_nl* \# $re_space_wo_nl* loc_left_pair $re_space_wo_nl* $}mx;
    my $re_delim = $RE{delimited}{-delim=>q{'"}}{-keep};

    $_ = <_>;

    # Mason filter: <&|/l>...</&> and <&|/l_unsafe>...</&>
    my $line = 1;
    while (m!\G(.*?<&\|/l(?:_unsafe)?(.*?)&>(.*?)</&>)!sg) {
        my ( $all, $vars, $str ) = ( $1, $2, $3 );
        $vars =~ s/[\n\r]//g;
        $line += ( $all =~ tr/\n/\n/ );
        $str =~ s/\\(['"\\])/$1/g;
        push @{ $FILECAT{$str} }, [ $normalized, $line, $vars ];
    }

    # Localization function: loc(...)
    $line = 1;
    pos($_) = 0;
    while (m/\G(.*?\bloc$RE{balanced}{-parens=>'()'}{-keep})/sg) {
        my ( $all, $match ) = ( $1, $2 );
        $line += ( $all =~ tr/\n/\n/ );

        my ( $vars, $str );
        next unless ( $match =~ /\(\s*($re_delim)(.*?)\s*\)$/so );

        my $interp = (substr($1,0,1) eq '"' ? 1 : 0);
        $str = substr( $1, 1, -1 );       # $str comes before $vars now
        $vars = $9;

        $vars =~ s/[\n\r]//g;
        $str  =~ s/\\(['"\\])/$1/g;

        push @{ $FILECAT{$str} }, [ $normalized, $line, $vars, $interp ];
    }

    my %seen;
    # Comment-based mark: "..." # loc
    $line = 1;
    pos($_) = 0;
    while (m/\G(.*?($re_delim)[ \{\}\)\],;]*$re_loc_suffix)/smgo) {
        my ( $all, $str ) = ( $1, $2 );
        $line += ( $all =~ tr/\n/\n/ );
        $seen{$line}++;
        unless ( defined $str ) {
            print "\n" unless $errors++;
            print "  Couldn't process loc at $normalized:$line:\n  $str\n";
            next;
        }
        my $interp = (substr($str,0,1) eq '"' ? 1 : 0);
        $str = substr($str, 1, -1);
        $str =~ s/\\(['"\\])/$1/g;
        push @{ $FILECAT{$str} }, [ $normalized, $line, '', $interp ];
    }

    # Comment-based mark for list to loc():  ("...", $foo, $bar)  # loc()
    $line = 1;
    pos($_) = 0;
    while (m/\G(.*? $RE{balanced}{-parens=>'()'}{-keep} [ \{\}\)\],;]* $re_loc_paren_suffix)/sgx) {
        my ( $all, $match ) = ( $1, $2 );
        $line += ( $all =~ tr/\n/\n/ );

        my ( $vars, $str );
        unless ( $match =~
                /\(\s*($re_delim)(.*?)\s*\)$/so ) {
            print "\n" unless $errors++;
            print "  Failed to match delimited against $match, line $line";
            next;
        }

        my $interp = (substr($1,0,1) eq '"' ? 1 : 0);
        $str = substr( $1, 1, -1 );       # $str comes before $vars now
        $vars = $9;
        $seen{$line}++;

        $vars =~ s/[\n\r]//g;
        $str  =~ s/\\(['"\\])/$1/g;

        push @{ $FILECAT{$str} }, [ $normalized, $line, $vars, $interp ];
    }

    # Comment-based qw mark: "qw(...)" # loc_qw
    $line = 1;
    pos($_) = 0;
    while (m/\G(.*?(?:qw\(([^)]+)\)[ \{\}\)\],;]*)?$re_loc_qw_suffix)/smgo) {
        my ( $all, $str ) = ( $1, $2 );
        $line += ( $all =~ tr/\n/\n/ );
        $seen{$line}++;
        unless ( defined $str ) {
            print "\n" unless $errors++;
            print "  Couldn't process loc_qw at $normalized:$line:\n  $str\n";
            next;
        }
        foreach my $value (split ' ', $str) {
            push @{ $FILECAT{$value} }, [ $normalized, $line, '' ];
        }
    }

    # Comment-based left pair mark: "..." => ... # loc_left_pair
    $line = 1;
    pos($_) = 0;
    while (m/\G(.*?(?:(\w+|$re_delim)\s*=>[^#\n]+?)?$re_loc_left_pair_suffix)/smgo) {
        my ( $all, $key ) = ( $1, $2 );
        $line += ( $all =~ tr/\n/\n/ );
        $seen{$line}++;
        unless ( defined $key ) {
            print "\n" unless $errors++;
            print "  Couldn't process loc_left_pair at $normalized:$line:\n  $key\n";
            next;
        }
        my $interp = (substr($key,0,1) eq '"' ? 1 : 0);
        $key =~ s/\\(['"\\])/$1/g if $key =~ s/^(['"])(.*)\1$/$2/g; # dequote potentially quoted string
        push @{ $FILECAT{$key} }, [ $normalized, $line, '', $interp ];
    }

    # Comment-based pair mark: "..." => "..." # loc_pair
    $line = 1;
    pos($_) = 0;
    while (m/\G(.*?(?:(\w+|$re_delim)\s*=>\s*($re_delim)[ \{\}\)\],;]*)?$re_loc_pair_suffix)/smgo) {
        my ( $all, $key, $val ) = ( $1, $2, $10 );
        $line += ( $all =~ tr/\n/\n/ );
        $seen{$line}++;
        unless ( defined $key && defined $val ) {
            print "\n" unless $errors++;
            print "  Couldn't process loc_pair at $normalized:$line:\n  $key\n  $val\n";
            next;
        }
        my $interp_key = (substr($key,0,1) eq '"' ? 1 : 0);
        $key =~ s/\\(['"\\])/$1/g if $key =~ s/^(['"])(.*)\1$/$2/g; # dequote potentially quoted string
        push @{ $FILECAT{$key} }, [ $normalized, $line, '', $interp_key ];

        my $interp_val = (substr($val,0,1) eq '"' ? 1 : 0);
        $val = substr($val, 1, -1);    # dequote always quoted string
        $val  =~ s/\\(['"\\])/$1/g;
        push @{ $FILECAT{$val} }, [ $normalized, $line, '', $interp_val ];
    }

    # Specific key  foo => "...", #loc{foo}
    $line = 1;
    pos($_) = 0;
    while (m/\G(.*?(\w+|$re_delim)\s*=>\s*($re_delim)(?-s:.*?)\#$re_space_wo_nl*loc\{\2\}$re_space_wo_nl*)$/smgo) {
        my ( $all, $key, $val ) = ( $1, $2, $10 );
        $line += ( $all =~ tr/\n/\n/ );
        $seen{$line}++;
        unless ( defined $key && defined $val ) {
            warn "Couldn't process loc_pair at $normalized:$line:\n  $key\n  $val\n";
            next;
        }
        $val = substr($val, 1, -1);    # dequote always quoted string
        $val  =~ s/\\(['"])/$1/g;
        push @{ $FILECAT{$val} }, [ $normalized, $line, '' ];
    }

    # Check for ones we missed
    $line = 1;
    pos($_) = 0;
    while (m/\G(.*? \# $re_space_wo_nl* (loc (_\w+|\(\)|{$re_delim})?) $re_space_wo_nl* $)/smgox) {
        my ($all, $loc_type) = ($1, $2);
        $line += ( $all =~ tr/\n/\n/ );
        next if $seen{$line};
        print "\n" unless $errors++;
        print "  $loc_type that did not match, line $line of $normalized\n";
    }

    if ($errors) {
        print "\n"
    } else {
        print "\r", " " x 100, "\r";
    }

    close (_);

    $self->{filecat} = \%FILECAT;
}

sub results {
    my $self = shift;
    return %{$self->{filecat}};
}

1;
