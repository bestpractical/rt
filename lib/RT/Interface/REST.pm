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

package RT::Interface::REST;
use LWP::MediaTypes qw(guess_media_type);
use strict;
use warnings;
use RT;

use base 'Exporter';
our @EXPORT = qw(expand_list form_parse form_compose vpush vsplit process_attachments);

sub custom_field_spec {
    my $self    = shift;
    my $capture = shift;

    my $CF_name = '[^,]+';
    $CF_name = '(' . $CF_name . ')' if $capture;

    my $new_style = 'CF\.\{'.$CF_name.'\}';
    my $old_style = 'C(?:ustom)?F(?:ield)?-'.$CF_name;

    return '(?i:' . join('|', $new_style, $old_style) . ')';
}

sub field_spec {
    my $self    = shift;
    my $capture = shift;

    my $field = '[a-z][a-z0-9_-]*';
    $field = '(' . $field . ')' if $capture;

    my $custom_field = __PACKAGE__->custom_field_spec($capture);

    return '(?i:' . join('|', $field, $custom_field) . ')';
}

# WARN: this code is duplicated in bin/rt.in,
# change both functions at once
sub expand_list {
    my ($list) = @_;

    my @elts;
    foreach (split /\s*,\s*/, $list) {
        push @elts, /^(\d+)-(\d+)$/? ($1..$2): $_;
    }

    return map $_->[0], # schwartzian transform
        sort {
            defined $a->[1] && defined $b->[1]?
                # both numbers
                $a->[1] <=> $b->[1]
                :!defined $a->[1] && !defined $b->[1]?
                    # both letters
                    $a->[2] cmp $b->[2]
                    # mix, number must be first
                    :defined $a->[1]? -1: 1
        }
        map [ $_, (defined( /^(\d+)$/ )? $1: undef), lc($_) ],
        @elts;
}

# Returns a reference to an array of parsed forms.
sub form_parse {
    my $state = 0;
    my @forms = ();
    my @lines = split /\n/, $_[0];
    my ($c, $o, $k, $e) = ("", [], {}, "");
    my $field = __PACKAGE__->field_spec;

    LINE:
    while (@lines) {
        my $line = shift @lines;

        next LINE if $line eq '';

        if ($line eq '--') {
            # We reached the end of one form. We'll ignore it if it was
            # empty, and store it otherwise, errors and all.
            if ($e || $c || @$o) {
                push @forms, [ $c, $o, $k, $e ];
                $c = ""; $o = []; $k = {}; $e = "";
            }
            $state = 0;
        }
        elsif ($state != -1) {
            if ($state == 0 && $line =~ /^#/) {
                # Read an optional block of comments (only) at the start
                # of the form.
                $state = 1;
                $c = $line;
                while (@lines && $lines[0] =~ /^#/) {
                    $c .= "\n".shift @lines;
                }
                $c .= "\n";
            }
            elsif ($state <= 1 && $line =~ /^($field):(?:\s+(.*))?$/i) {
                # Read a field: value specification.
                my $f  = $1;
                my @v  = ($2);
                $v[0] = '' unless defined $v[0];

                # Read continuation lines, if any.
                while (@lines && ($lines[0] eq '' || $lines[0] =~ /^\s+/)) {
                    push @v, shift @lines;
                }
                pop @v while (@v && $v[-1] eq '');

                # Strip longest common leading indent from text.
                my $ws = ("");
                foreach my $ls (map {/^(\s+)/} @v[1..$#v]) {
                    $ws = $ls if (!$ws || length($ls) < length($ws));
                }
                s/^$ws// foreach @v;

                shift @v while (@v && $v[0] eq '');

                push(@$o, $f) unless exists $k->{$f};
                vpush($k, $f, join("\n", @v));

                $state = 1;
            }
            elsif ($line =~ /^#/) {
                # We've found a syntax error, so we'll reconstruct the
                # form parsed thus far, and add an error marker. (>>)
                $state = -1;
                $e = form_compose([[ "", $o, $k, "" ]]);
                $e.= $line =~ /^>>/ ? "$line\n" : ">> $line\n";
            }
        }
        else {
            # We saw a syntax error earlier, so we'll accumulate the
            # contents of this form until the end.
            $e .= "$line\n";
        }
    }
    push(@forms, [ $c, $o, $k, $e ]) if ($e || $c || @$o);

    foreach my $l (keys %$k) {
        $k->{$l} = vsplit($k->{$l}) if (ref $k->{$l} eq 'ARRAY');
    }

    return \@forms;
}

# Returns text representing a set of forms.
sub form_compose {
    my ($forms) = @_;
    my (@text);

    foreach my $form (@$forms) {
        my ($c, $o, $k, $e) = @$form;
        my $text = "";

        if ($c) {
            $c =~ s/\n*$/\n/;
            $text = "$c\n";
        }
        if ($e) {
            $text .= $e;
        }
        elsif ($o) {
            my (@lines);

            foreach my $key (@$o) {
                my ($line, $sp);
                my @values = (ref $k->{$key} eq 'ARRAY') ?
                               @{ $k->{$key} } :
                                  $k->{$key};

                $sp = " "x(length("$key: "));
                $sp = " "x4 if length($sp) > 16;

                foreach my $v (@values) {
                    $v = '' unless defined $v;
                    if ( $v =~ /\n/) {
                        $v =~ s/^/$sp/gm;
                        $v =~ s/^$sp//;

                        if ($line) {
                            push @lines, "$line\n\n";
                            $line = "";
                        }
                        elsif (@lines && $lines[-1] !~ /\n\n$/) {
                            $lines[-1] .= "\n";
                        }
                        push @lines, "$key: $v\n\n";
                    }
                    elsif ($line &&
                           length($line)+length($v)-rindex($line, "\n") >= 70)
                    {
                        $line .= ",\n$sp$v";
                    }
                    else {
                        $line = $line ? "$line, $v" : "$key: $v";
                    }
                }

                $line = "$key:" unless @values;
                if ($line) {
                    if ($line =~ /\n/) {
                        if (@lines && $lines[-1] !~ /\n\n$/) {
                            $lines[-1] .= "\n";
                        }
                        $line .= "\n";
                    }
                    push @lines, "$line\n";
                }
            }

            $text .= join "", @lines;
        }
        else {
            chomp $text;
        }
        push @text, $text;
    }

    return join "\n--\n\n", @text;
}

# Add a value to a (possibly multi-valued) hash key.
sub vpush {
    my ($hash, $key, $val) = @_;
    my @val = ref $val eq 'ARRAY' ? @$val : $val;

    if (exists $hash->{$key}) {
        unless (ref $hash->{$key} eq 'ARRAY') {
            my @v = $hash->{$key} ne '' ? $hash->{$key} : ();
            $hash->{$key} = \@v;
        }
        push @{ $hash->{$key} }, @val;
    }
    else {
        $hash->{$key} = $val;
    }
}

# "Normalise" a hash key that's known to be multi-valued.
sub vsplit {
    my ($val, $strip) = @_;
    my @words;
    my @values = map {split /\n/} (ref $val eq 'ARRAY' ? @$val : $val);

    foreach my $line (@values) {
        while ($line =~ /\S/) {
            $line =~ s/^
                       \s*   # Trim leading whitespace
                       (?:
                           (")   # Quoted string
                           ((?>[^\\"]*(?:\\.[^\\"]*)*))"
                       |
                           (')   # Single-quoted string
                           ((?>[^\\']*(?:\\.[^\\']*)*))'
                       |
                           q\{(.*?)\}  # A perl-ish q{} string; this does
                                     # no paren balancing, however, and
                                     # only exists for back-compat
                       |
                           (.*?)     # Anything else, until the next comma
                       )
                       \s*   # Trim trailing whitespace
                       (?:
                           \Z  # Finish at end-of-line
                       |
                           ,   # Or a comma
                       )
                      //xs or last; # There should be no way this match
                                    # fails, but add a failsafe to
                                    # prevent infinite-looping if it
                                    # somehow does.
            my ($quote, $quoted) = ($1 ? ($1, $2) : $3 ? ($3, $4) : ('', $5 || $6));
            # Only unquote the quote character, or the backslash -- and
            # only if we were originally quoted..
            if ($5) {
                $quoted =~ s/([\\'])/\\$1/g;
                $quote = "'";
            }
            if ($strip) {
                $quoted =~ s/\\([\\$quote])/$1/g if $quote;
                push @words, $quoted;
            } else {
                push @words, "$quote$quoted$quote";
            }
        }
    }
    return \@words;
}

sub process_attachments {
    my $entity = shift;
    my @list = @_;
    return 1 unless @list;

    my $m = $HTML::Mason::Commands::m;
    my $cgi = $m->cgi_object;

    my $i = 1;
    foreach my $e ( @list ) {

        my $fh = $cgi->upload("attachment_$i");
        return (0, "No attachment for $e") unless $fh;

        local $/=undef;

        my $file = $e;
        $file =~ s#^.*[\\/]##;

        my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );

        my $buf;
        while (sysread($fh, $buf, 8192)) {
            syswrite($tmp_fh, $buf);
        }

        my $info = $cgi->uploadInfo($fh);
        # If Content-ID exists for attachment then we need multipart/related
        # to be able to refer to this Content-Id in core of mime message
        if($info->{'Content-ID'}) {
            $entity->head->set('Content-Type', 'multipart/related');
        }
        my $new_entity = $entity->attach(
            Path => $tmp_fn,
            Type => $info->{'Content-Type'} || guess_media_type($tmp_fn),
            Filename => $file,
            Disposition => $info->{'Content-Disposition'} || "attachment",
            'Content-ID' => $info->{'Content-ID'},
        );
        $new_entity->bodyhandle->{'_dirty_hack_to_save_a_ref_tmp_fh'} = $tmp_fh;
        $i++;
    }
    return (1);
}

RT::Base->_ImportOverlays();

1;

=head1 NAME

  RT::Interface::REST - helper functions for the REST interface.

=head1 SYNOPSIS

  Only the REST should use this module.
