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

package RT::Pod::Simple::HTMLBatch;
use base Pod::Simple::HTMLBatch;

=over

Override to set some different options in the Pod::Simple::Search
object. Probably would be better if Pod::Simple::HTMLBatch
just took a prepped object as an optional param.

=cut

sub modnames2paths {   # return a hashref mapping modulenames => paths
    my($self, $dirs) = @_;

    my $m2p;
    {
        my $search = $self->search_class->new;
        DEBUG and print "Searching via $search\n";
        $search->verbose(1) if DEBUG > 10;
        $search->laborious(1); # Added to find scripts in bin and sbin
        $search->limit_re(qr/(?<!\.in)$/); # Filter out .in files
        $search->progress( $self->progress->copy->goal(0) ) if $self->progress;
        $search->shadows(0);    # don't bother noting shadowed files
        $search->inc(     $dirs ? 0      :  1 );
        $search->survey(  $dirs ? @$dirs : () );
        $m2p = $search->name2path;
        die "What, no name2path?!" unless $m2p;
    }

    $self->muse("That's odd... no modules found!") unless keys %$m2p;
    if ( DEBUG > 4 ) {
        print "Modules found (name => path):\n";
        foreach my $m (sort {lc($a) cmp lc($b)} keys %$m2p) {
            print "  $m  $$m2p{$m}\n";
        }
        print "(total ",     scalar(keys %$m2p), ")\n\n";
    } elsif ( DEBUG ) {
        print      "Found ", scalar(keys %$m2p), " modules.\n";
    }
    $self->muse( "Found ", scalar(keys %$m2p), " modules." );

    # return the Foo::Bar => /whatever/Foo/Bar.pod|pm hashref
    return $m2p;
}

=over

Modified to create hash entries for the documentation sections
we want based on where they came from. These entries can then
be used to create the TOC page.

=cut

sub _prep_contents_breakdown {
    my($self) = @_;
    my $contents = $self->_contents;
    my %toplevel;          # maps  lctoplevelbit => [all submodules]
    my %toplevel_form_freq;     # ends up being  'foo' => 'Foo'
    # (mapping anycase forms to most freq form)

    foreach my $entry (@$contents) {
        my $toplevel;

        # First, look for specific sections we want docs for and create entries
        # for them.

        if ( $entry->[1] =~ /\/docs\// ) {
            $toplevel = "RT User Documentation";
            ++$toplevel_form_freq{'user_docs'}{$toplevel};
            push @{ $toplevel{'user_docs'} }, $entry;
        }
        elsif ( $entry->[1] =~ /\/bin\// ){
            $toplevel = "RT Utilities (bin)";
            ++$toplevel_form_freq{'bin_docs'}{$toplevel};
            push @{ $toplevel{'bin_docs'} }, $entry;
        }
        elsif ( $entry->[1] =~ /\/sbin\// ){
            $toplevel = "RT Utilities (sbin)";
            ++$toplevel_form_freq{'sbin_docs'}{$toplevel};
            push @{ $toplevel{'sbin_docs'} }, $entry;
        }
        elsif ( $entry->[3][1] eq 'Action' ){
            $toplevel = "RT Actions";
            ++$toplevel_form_freq{'action_docs'}{$toplevel};
            push @{ $toplevel{'action_docs'} }, $entry;
        }
        elsif ( $entry->[3][1] eq 'Condition' ){
            $toplevel = "RT Conditions";
            ++$toplevel_form_freq{'condition_docs'}{$toplevel};
            push @{ $toplevel{'condition_docs'} }, $entry;
        }
        elsif ( $entry->[1] =~ /\/lib\// ) {
            $toplevel = "RT Developer Documentation";
            ++$toplevel_form_freq{'dev_docs'}{$toplevel};
            push @{ $toplevel{'dev_docs'} }, $entry;
        }
        else {
            # Catch everything else
            my $toplevel =
              $entry->[0] =~ m/^perl\w*$/ ? 'perl_core_docs'
                # group all the perlwhatever docs together
                : $entry->[3][0] # normal case
                  ;
            ++$toplevel_form_freq{ lc $toplevel }{ $toplevel };
            push @{ $toplevel{ lc $toplevel } }, $entry;
            push @$entry, lc($entry->[0]); # add a sort-order key to the end
        }
    }

    foreach my $toplevel (keys %toplevel) {
        my $fgroup = $toplevel_form_freq{$toplevel};
        $toplevel_form_freq{$toplevel} =
          (
           sort { $fgroup->{$b} <=> $fgroup->{$a}  or  $a cmp $b }
           keys %$fgroup
           # This hash is extremely unlikely to have more than 4 members, so this
           # sort isn't so very wasteful
          )[0];
    }

    return(\%toplevel, \%toplevel_form_freq) if wantarray;
    return \%toplevel;
}

=over

Add more control over the order of sections in the TOC file.

=cut

sub _write_contents_middle {
    my($self, $Contents, $outfile, $toplevel2submodules, $toplevel_form_freq) = @_;

    $self->format_link_text($toplevel2submodules->{user_docs});

    # Build the sections of the TOC in the order we want
    my @toc_sections = qw(user_docs bin_docs sbin_docs dev_docs action_docs condition_docs);
    foreach my $section ( @toc_sections ){
        $self->_write_content_subsection($Contents, $outfile, $toplevel2submodules,
                                         $section, $toplevel_form_freq->{$section});
    }
}

=over

Remove the outer loop since we are calling each section deliberately in the
order we want. Still use the main logic to write the content of inner sections.

=cut

sub _write_content_subsection {
    my($self, $Contents, $outfile, $toplevel2submodules, $section, $section_title) = @_;

    my @downlines = sort {$a->[0] cmp $b->[0]}
      @{ $toplevel2submodules->{$section} };

    printf $Contents qq[<dt><a name="%s">%s</a></dt>\n<dd>\n],
      Pod::Simple::HTML::esc( $section, $section_title )
        ;

    my($path, $name);
    foreach my $e (@downlines) {
        $name = $e->[0];
        $path = join( "/", '.', Pod::Simple::HTML::esc( @{$e->[3]} ) )
          . ($HTML_EXTENSION || $Pod::Simple::HTML::HTML_EXTENSION);
        print $Contents qq{  <a href="$path">}, Pod::Simple::HTML::esc($name), "</a>&nbsp;&nbsp;\n";
    }
    print $Contents "</dd>\n\n";
    return 1;
}

=head2 format_link_text

Apply some formatting to the visible links for user documentation.

=cut

sub format_link_text {
    my ($self, $content) = @_;

    foreach my $entry ( @{$content} ){
        $entry->[0] =~ s/_/ /g;
        $entry->[0] = join '/', map {ucfirst} split /::/, $entry->[0];
    }

}

1;
