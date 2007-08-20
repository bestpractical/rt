package RT::Shredder::POD;

use strict;
use warnings;
use Pod::Select;

sub plugin_html
{
    my ($file, $out_fh) = @_;
    my $parser = new RT::Shredder::POD::HTML;
    $parser->select('ARGUMENTS', 'USAGE');
    $parser->parse_from_file( $file, $out_fh );
}

sub plugin_cli
{
    my ($file, $out_fh, $no_name) = @_;
    use Pod::PlainText;
    local @Pod::PlainText::ISA = ('Pod::Select', @Pod::PlainText::ISA);
    my $parser = new Pod::PlainText;
    $parser->select('SYNOPSIS', 'ARGUMENTS', 'USAGE');
    $parser->add_selection('NAME') unless $no_name;
    $parser->parse_from_file( $file, $out_fh );
}

sub shredder_cli
{
    my ($file, $out_fh) = @_;
    use Pod::PlainText;
    local @Pod::PlainText::ISA = ('Pod::Select', @Pod::PlainText::ISA);
    my $parser = new Pod::PlainText;
    $parser->select('NAME', 'SYNOPSIS', 'USAGE', 'OPTIONS');
    $parser->parse_from_file( $file, $out_fh );
}

package RT::Shredder::POD::HTML;
use base qw(Pod::Select);

sub command
{
    my( $self, $command, $paragraph, $line_num ) = @_;

    my $tag;
    if ($command =~ /^head(\d+)$/) { $tag = "h$1" }
    my $out_fh = $self->output_handle();
    my $expansion = $self->interpolate($paragraph, $line_num);
    $expansion =~ s/^\s+|\s+$//;

    print $out_fh "<$tag>" if $tag;
    print $out_fh $expansion;
    print $out_fh "</$tag>" if $tag;
    print $out_fh "\n";
}

sub verbatim
{
    my ($self, $paragraph, $line_num) = @_;
    my $out_fh = $self->output_handle();
    print $out_fh "<pre>";
    print $out_fh $paragraph;
    print $out_fh "</pre>";
    print $out_fh "\n";
}

sub textblock {
    my ($self, $paragraph, $line_num) = @_;
    my $out_fh = $self->output_handle();
    my $expansion = $self->interpolate($paragraph, $line_num);
    $expansion =~ s/^\s+|\s+$//;
    print $out_fh "<p>";
    print $out_fh $expansion;
    print $out_fh "</p>";
    print $out_fh "\n";
}

sub interior_sequence {
    my ($self, $seq_command, $seq_argument) = @_;
    ## Expand an interior sequence; sample actions might be:
    return "<b>$seq_argument</b>" if $seq_command eq 'B';
    return "<i>$seq_argument</i>" if $seq_command eq 'I';
    return "<span class=\"pod-sequence-$seq_command\">$seq_argument</span>";
}
1;
