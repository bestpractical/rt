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

use strict;
use warnings;

package RT::Pod::HTML;
use base 'Pod::Simple::XHTML';

use HTML::Entities qw//;

__PACKAGE__->_accessorize(
    "batch"
);

sub new {
    my $self = shift->SUPER::new(@_);
    $self->index(1);
    $self->anchor_items(1);
    return $self;
}

sub decode_entities {
    my $self = shift;
    return HTML::Entities::decode_entities($_[0]);
}

sub perldoc_url_prefix { "http://metacpan.org/module/" }

sub html_header { '' }
sub html_footer {
    my $self = shift;
    my $toc  = "../" x ($self->batch_mode_current_level - 1);
    return '<a href="./' . $toc . '">&larr; Back to index</a>';
}

sub start_F {
    $_[0]{'scratch_F'} = $_[0]{'scratch'};
    $_[0]{'scratch'}   = "";
}
sub end_F   {
    my $self = shift;
    my $text = $self->{scratch};
    my $file = $self->decode_entities($text);

    if (my $local = $self->resolve_local_link($file)) {
        $text = qq[<a href="$local">$text</a>];
    }

    $self->{'scratch'} = delete $self->{scratch_F};
    $self->{'scratch'} .= "<i>$text</i>";
}

sub _end_head {
    my $self = shift;
    $self->{scratch} = '<a href="#___top">' . $self->{scratch} . '</a>';
    return $self->SUPER::_end_head(@_);
}

sub handle_text {
    my ( $self, $text ) = @_;
    if ( $self->{in_pod} && $self->{scratch} =~ /<a .*href=".+".*>/ && $text =~ /^"(.+)" in docs$/ ) {

        # Tweak default text for local links under docs/, so
        # q{"customizing/search_result_columns.pod/Column Map" in docs} becomes
        # q{"Column Map Callback" in customizing/search_result_columns.pod}
        #
        # q{"customizing/search_result_columns.pod" in docs} becomes
        # q{docs/customizing/search_result_columns.pod}

        my $section = $1;
        if ( $section =~ qr!(.+\.pod)/(.+)! ) {
            $text = qq{"$2" in docs/$1};
        }
        else {
            $text = "docs/$section";
        }
    }
    $self->SUPER::handle_text( $text );
}

sub resolve_pod_page_link {
    my $self = shift;
    my ($name, $section) = @_;

    # Only try to resolve local links if we're in batch mode and are linking
    # outside the current document.
    return $self->SUPER::resolve_pod_page_link(@_)
        unless $self->batch_mode and $name;

    my $local = $self->resolve_local_link($name, $section);

    return $local
        ? $local
        : $self->SUPER::resolve_pod_page_link(@_);
}

sub resolve_local_link {
    my $self = shift;
    my ($name, $section) = @_;

    $name .= ""; # stringify name, it may be an object

    if ( $name eq 'docs' ) {
        if ( $section =~ qr!(.+\.pod)/(.+)! ) {

            # support L<docs/writing_extensions.pod/Callbacks>
            $name .= '/' . $1;
            $section = $2;
        }
        else {
            # support L<docs/dashboards_reporting.pod>
            $name .= '/' . $section;
            undef $section;
        }
    }

    $section = defined $section
        ? '#' . $self->idify($section, 1)
        : '';

    my $local;
    if ($name =~ /^RT(::(?!Extension::|Authen::(?!ExternalAuth))|$)/ or $self->batch->found($name)) {
        $local = join "/",
                  map { $self->encode_entities($_) }
                split /::/, $name;
    }
    elsif ($name =~ /^rt([-_]|$)/) {
        $local = $self->encode_entities($name);
    }
    elsif ($name =~ /^(\w+)_Config(\.pm)?$/) {
        $name  = "$1_Config";
        $local = "$1_Config";
    }
    elsif ($name eq 'README') {
        # We process README separately in devel/tools/rt-static-docs
        $local = $name;
    }
    elsif ($name =~ /^UPGRADING.*/) {
        # If an UPGRADING file is referred to anywhere else (such as
        # templates.pod) we won't have seen UPGRADING yet and will treat
        # it as a non-local file.
        $local = $name;
    }
    # These matches handle links that look like filenames, such as those we
    # parse out of F<> tags.
    elsif (   $name =~ m{^(?:lib/)(RT/[\w/]+?)\.pm$}
           or $name =~ m{^(?:docs/)(.+?)\.pod$})
    {
        $name  = join "::", split '/', $1;
        $local = join "/",
                  map { $self->encode_entities($_) }
                split /\//, $1;
    }

    if ($local) {
        # Resolve links correctly by going up
        my $found = $self->batch->found($name);
        my $depth = $self->batch_mode_current_level
                  + ($found ? -1 : 1);
        return ($depth ? "../" x $depth : "") . ($found ? "" : "rt/latest/") . "$local.html$section";
    } else {
        return;
    }
}

sub batch_mode_page_object_init {
    my ($self, $batch, $module, $infile, $outfile, $depth) = @_;
    $self->SUPER::batch_mode_page_object_init(@_[1..$#_]);
    $self->batch( $batch );
    return $self;
}

1;
