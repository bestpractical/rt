use inc::Module::Install;
version_from('lib/RT/FM.pm');
license('GPL version 2');
requires(perl  => 5.008);
requires('Text::WikiFormat');
requires(RT => '3.4.0');
RTx(RTFM);
&WriteAll;
