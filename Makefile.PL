use inc::Module::Install;
RTx('RT-FM');
license('GPL version 2');
requires(perl  => 5.008);
requires('Text::WikiFormat');
requires(RT => '3.4.0');
&WriteAll;
