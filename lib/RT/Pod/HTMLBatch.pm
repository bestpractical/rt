use strict;
use warnings;

package RT::Pod::HTMLBatch;
use base 'Pod::Simple::HTMLBatch';

use List::MoreUtils qw/all/;

use RT::Pod::Search;
use RT::Pod::HTML;

sub new {
    my $self = shift->SUPER::new(@_);
    $self->verbose(0);

    # Per-page output options
    $self->css_flurry(0);          # No CSS
    $self->javascript_flurry(0);   # No JS
    $self->no_contents_links(1);   # No header/footer "Back to contents" links

    # TOC options
    $self->index(1);                    # Write a per-page TOC
    $self->contents_file("index.html"); # Write a global TOC

    $self->html_render_class('RT::Pod::HTML');
    $self->search_class('RT::Pod::Search');

    return $self;
}

sub classify {
    my $self = shift;
    my %info = (@_);

    my $is_install_doc = sub {
        my %page = @_;
        local $_ = $page{name};
        return 1 if /^(README|UPGRADING)/;
        return 1 if $_ eq "RT_Config";
        return 1 if $_ eq "web_deployment";
        return 1 if $page{infile} =~ m{^configure(\.ac)?$};
        return 0;
    };

    my $section = $info{infile} =~ m{/plugins/([^/]+)}      ? "05 Extension: $1"           :
                  $info{infile} =~ m{/local/}               ? '04 Local Documenation'      :
                  $is_install_doc->(%info)                  ? '00 Install and Upgrade '.
                                                                 'Documentation'           :
                  $info{infile} =~ m{/(docs|etc)/}          ? '01 User Documentation'      :
                  $info{infile} =~ m{/bin/}                 ? '02 Utilities (bin)'         :
                  $info{infile} =~ m{/sbin/}                ? '03 Utilities (sbin)'        :
                  $info{name}   =~ /^RT::Action/            ? '08 Actions'                 :
                  $info{name}   =~ /^RT::Condition/         ? '09 Conditions'              :
                  $info{name}   =~ /^RT(::|$)/              ? '07 Developer Documentation' :
                  $info{infile} =~ m{/devel/tools/}         ? '20 Utilities (devel/tools)' :
                                                              '06 Miscellaneous'           ;

    if ($info{infile} =~ m{/(docs|etc)/}) {
        $info{name} =~ s/_/ /g;
        $info{name} = join "/", map { ucfirst } split /::/, $info{name};
    }

    return ($info{name}, $section);
}

sub write_contents_file {
    my ($self, $to) = @_;
    return unless $self->contents_file;

    my $file = join "/", $to, $self->contents_file;
    open my $index, ">", $file
        or warn "Unable to open index file '$file': $!\n", return;

    my $pages = $self->_contents;
    return unless @$pages;

    # Classify
    my %toc;
    for my $page (@$pages) {
        my ($name, $infile, $outfile, $pieces) = @$page;

        my ($title, $section) = $self->classify(
            name    => $name,
            infile  => $infile,
        );

        (my $path = $outfile) =~ s{^\Q$to\E/?}{};

        push @{ $toc{$section} }, {
            name => $title,
            path => $path,
        };
    }

    # Write out index
    print $index "<dl class='superindex'>\n";

    for my $key (sort keys %toc) {
        next unless @{ $toc{$key} };

        (my $section = $key) =~ s/^\d+ //;
        print $index "<dt>", esc($section), "</dt>\n";
        print $index "<dd>\n";

        my @sorted = sort {
            my @names = map { $_->{name} } $a, $b;

            # Sort just the upgrading docs descending within everything else
            @names = reverse @names
                if all { /^UPGRADING-/ } @names;

            $names[0] cmp $names[1]
        } @{ $toc{$key} };

        for my $page (@sorted) {
            print $index "  <a href='", esc($page->{path}), "'>",
                                esc($page->{name}),
                           "</a><br>\n";
        }
        print $index "</dd>\n";
    }
    print $index '</dl>';

    close $index;
}

sub esc {
    Pod::Simple::HTMLBatch::esc(@_);
}

1;
