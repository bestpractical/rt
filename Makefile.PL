use inc::Module::Install;
RTx('RT-FM');
name('RTFM');
version_from('lib/RT/FM.pm');
license('GPL version 2');
requires(perl  => 5.008);
requires('Text::WikiFormat');
requires(RT => '3.4.2',
    Tree::Simple => 0,
    HTML::TreeBuilder => 0,
    Time::ParseDate => 0,
    HTML::FormatText => 0,
    YAML => 0

);
&WriteAll;
