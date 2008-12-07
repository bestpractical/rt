package RT::Ruleset;
use strict;
use warnings;

use base 'Class::Accessor::Fast';
use UNIVERSAL::require;

__PACKAGE__->mk_accessors(qw(Name Rules));

my @RULE_SETS;

sub FindAllRules {
    my ($class, %args) = @_;
    return [
        grep { $_->Prepare }
        map { $_->new(CurrentUser => $RT::SystemUser, %args) }
        grep { $_->_Stage eq $args{Stage} }
        map { @{$_->Rules} } @RULE_SETS
    ];
}

sub CommitRules {
    my ($class, $rules) = @_;
    $_->Commit
        for @$rules;
}

sub Add {
    my ($class, %args) = @_;
    for (@{$args{Rules}}) {
        $_->require or die $UNIVERSAL::require::ERROR;
    }
    push @RULE_SETS, $class->new(\%args);
}

1;
