use strict;
use warnings;

package RT::FM::Test;
use base qw(Test::More);

eval 'use RT::Test; 1'
    or Test::More::plan skip_all => 'requires 3.8 to run tests.  You may need to set PERL5LIB=/path/to/rt/lib';

sub import_extra {
    my $class = shift;
    my $args  = shift;

    # Spit out a plan (if we got one) *before* we load modules, in
    # case of compilation errors
    $class->builder->plan(@{$args})
      unless $class->builder->has_plan;

    Test::More->export_to_level(2);

    # Now, clobber Test::Builder::plan (if we got given a plan) so we
    # don't try to spit one out *again* later.  Test::Builder::Module 
    # plans for you in import
    if ($class->builder->has_plan) {
        no warnings 'redefine';
        *Test::Builder::plan = sub {};
    }

    {
        my ($ret, $msg) = $RT::Handle->InsertSchema(undef,'etc/');
        Test::More::ok($ret,"Created Schema: ".($msg||''));
        ($ret, $msg) = $RT::Handle->InsertACL(undef,'etc/');
        Test::More::ok($ret,"Created ACL: ".($msg||''));
    }

    RT->Config->Set('Plugins',qw(RT::FM));

}

1;
