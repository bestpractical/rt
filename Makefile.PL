use inc::Module::Install;
RTx('RT-FM');
name('RTFM');
version_from('lib/RT/FM.pm');
license('GPL version 2');
requires(
    perl              => 5.008,
    RT                => '3.4.2',
    Text::WikiFormat  => 0,
    Tree::Simple      => 0,
    HTML::TreeBuilder => 0,
    Time::ParseDate   => 0,
    HTML::FormatText  => 0,
    YAML              => 0,
);
auto_install();
&WriteAll;
