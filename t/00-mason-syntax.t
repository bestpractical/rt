#!/usr/bin/perl

use strict;
use warnings;

use RT::Test nodb => 1;


use File::Find;
find( {
    no_chdir => 1,
    wanted   => sub {
        return if /(?:\.(?:jpe?g|png|gif|rej)|\~)$/i;
        return if m{/\.[^/]+\.swp$}; # vim swap files
        return unless -f $_;
        local ($@);
        ok( eval { compile_file($_) }, "Compiled $File::Find::name ok: $@");
    },
}, RT::Test::get_relocatable_dir('../share/html'));

use HTML::Mason;
use HTML::Mason::Compiler;
use HTML::Mason::Compiler::ToObject;
BEGIN { require RT::Test; }
use Encode qw(decode_utf8);

sub compile_file {
    my $file = shift;

    my $text = decode_utf8(RT::Test->file_content($file));

    my $compiler = new HTML::Mason::Compiler::ToObject;
    $compiler->compile(
        comp_source => $text,
        name => 'my',
        comp_path => 'my',
    );
    return 1;
}

