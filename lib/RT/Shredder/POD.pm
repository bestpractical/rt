# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2022 Best Practical Solutions, LLC
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

package RT::Shredder::POD;

use strict;
use warnings;
use Pod::Simple::Text;
use Pod::Select;

sub plugin_html
{
    my ($file, $out_fh) = @_;
    my $parser = RT::Shredder::POD::HTML->new;
    $parser->select('SYNOPSIS', 'ARGUMENTS', 'USAGE');
    $parser->parse_from_file( $file, $out_fh );
    return;
}

sub plugin_cli
{
    my ($file, $out_fh, $no_name) = @_;
    my $parser = RT::Shredder::POD::Text->new;
    $parser->output_fh($out_fh);
    $parser->select('SYNOPSIS', 'ARGUMENTS', 'USAGE', ($no_name ? () : 'Name') );
    $parser->parse_file( $file );
    return;
}

sub shredder_cli
{
    my ($file, $out_fh) = @_;
    my $parser = RT::Shredder::POD::Text->new;
    $parser->output_fh($out_fh);
    $parser->select('NAME', 'SYNOPSIS', 'USAGE', 'OPTIONS');
    $parser->parse_file( $file );
    return;
}

# Extract the help for each argument from the plugin POD
# they must be on a =head2 line in the ARGUMENTS section of the POD
# the return value is a hashref:
#   keys are the argument names,
#   values are hash_refs: { name => <ucfirst argument name>,
#                           type => <from the head line>,
#                           help => <first paragraph from the POD>
#                         }
sub arguments_help {
    my ($file) = @_;

    my $text;
    open( my $io_handle, ">:scalar", \$text )
        or die "Can't open scalar for write: $!";
    my $parser = RT::Shredder::POD::HTML->new;
    $parser->select('ARGUMENTS');
    $parser->parse_from_file( $file, $io_handle );

    my $arguments_help = {};

    while( $text=~ m{<h4[^>]*>    # argument description starts with an h4 title
                       \s*(\S*)   #   argument name ($1)
                         \s*-\s*
                       ([^<]*)    #   argument type ($2)
                     </h4>\s*
                       (?:<p[^>]*>\s*
                       (.*?)      #   help: the first paragraph of the POD     ($3)
                     (?=</p>)
                       )?
                    }gsx
          ) {
        my( $arg, $arg_name, $type, $help)= ( lc( $1), $1, $2, $3 || '');
        $arguments_help->{$arg}= { name => $arg_name, type => $type, help => $help };
    }

    return $arguments_help;
}

1;

package RT::Shredder::POD::Text;
use base qw(Pod::Simple::Text);

sub new {
    my $self = shift;
    my $new = $self->SUPER::new(@_);
    $new->{'Suppress'} = 1;
    $new->{'InHead1'} = 0;
    $new->{'Selected'} = {};
    return $new;
}

sub select {
    my $self = shift;
    $self->{'Selected'}{$_} = 1 for @_;
    return;
}

sub handle_text {
    my $self = shift;

    if ($self->{'InHead1'} and exists $self->{'Selected'}{ $_[0] }) {
        $self->{'Suppress'} = 0;
    }

    return $self->SUPER::handle_text( @_ );
}

sub start_head1 {
    my $self = shift;

    $self->{'InHead1'} = 1;
    $self->{'Suppress'} = 1;

    return $self->SUPER::start_head1( @_ );
}

sub end_head1 {
    my $self = shift;

    $self->{'InHead1'} = 0;

    return $self->SUPER::end_head1( @_ );
}

sub emit_par {
    my $self = shift;

    if ($self->{'Suppress'}) {
        $self->{'Thispara'} = '';
        return;
    }

    return $self->SUPER::emit_par( @_ );
}

sub end_Verbatim {
    my $self = shift;

    if ($self->{'Suppress'}) {
        $self->{'Thispara'} = '';
        return;
    }

    return $self->SUPER::end_Verbatim( @_ );
}

1;

package RT::Shredder::POD::HTML;
use base qw(Pod::Select);

sub command
{
    my( $self, $command, $paragraph, $line_num ) = @_;

    my $tag;
    # =head1 => h3, =head2 => h4
    if ($command =~ /^head(\d+)$/) {
        my $h_level = $1 + 2;
        $tag = "h$h_level";
    }
    my $out_fh = $self->output_handle();
    my $expansion = $self->interpolate($paragraph, $line_num);
    $expansion =~ s/^\s+|\s+$//;
    $expansion = lc( $expansion );
    $expansion = ucfirst( $expansion );

    print $out_fh "<$tag class=\"rt-general-header1\">" if $tag eq 'h3';
    print $out_fh "<$tag class=\"rt-general-header2\">" if $tag eq 'h4';
    print $out_fh $expansion;
    print $out_fh "</$tag>" if $tag;
    print $out_fh "\n";
    return;
}

sub verbatim
{
    my ($self, $paragraph, $line_num) = @_;
    my $out_fh = $self->output_handle();
    print $out_fh "<pre class=\"rt-general-paragraph\">";
    print $out_fh $paragraph;
    print $out_fh "</pre>";
    print $out_fh "\n";
    return;
}

sub textblock {
    my ($self, $paragraph, $line_num) = @_;
    my $out_fh = $self->output_handle();
    my $expansion = $self->interpolate($paragraph, $line_num);
    $expansion =~ s/^\s+|\s+$//;
    print $out_fh "<p class=\"rt-general-paragraph\">";
    print $out_fh $expansion;
    print $out_fh "</p>";
    print $out_fh "\n";
    return;
}

sub interior_sequence {
    my ($self, $seq_command, $seq_argument) = @_;
    ## Expand an interior sequence; sample actions might be:
    return "<b>$seq_argument</b>" if $seq_command eq 'B';
    return "<i>$seq_argument</i>" if $seq_command eq 'I';
    return "<tt>$seq_argument</tt>" if $seq_command eq 'C';
    return "<span class=\"pod-sequence-$seq_command\">$seq_argument</span>";
}
1;
