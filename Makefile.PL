use inc::Module::Install;

name        'RT';
version     '3.99_01';
license 'GPLv2';
requires    'Jifty' => '0.70824';

tests("t/*.t t/*/*.t");

WriteAll;
