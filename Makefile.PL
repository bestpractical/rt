use inc::Module::Install;
RTx('RT-FM');
name('RTFM');
license('GPL version 2');
perl_version('5.008003');
#version_from('lib/RT/FM.pm');
all_from('lib/RT/FM.pm');
requires(
    RT                => '3.004002',
    Text::WikiFormat  => 0,
    Tree::Simple      => 0,
    HTML::TreeBuilder => 0,
    Time::ParseDate   => 0,
    HTML::FormatText  => 0,
);
auto_install();

WriteAll();
