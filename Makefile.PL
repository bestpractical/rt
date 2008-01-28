use inc::Module::Install;

name        'RT';
version     '0.01';
requires    'Jifty' => '0.70824';

tests("t/*.t t/*/*.t");

WriteAll;
