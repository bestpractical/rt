package RT::Extension::RuleManager;
use strict;
use warnings;
use RT::Template;
use YAML::Syck '1.00';
use constant RuleManagerTemplate => 'Rule Manager Template';
use constant RuleClass => 'RT::Extension::RuleManager::Rule';
use constant FieldOptions => (
    'Subject', # loc
    'Sender',  # loc
    'Body',    # loc
);
use constant HandlerOptions => (
    'Send no autoreply',                    # loc
    'Send the autoreply in this template:', # loc
    "Set the ticket's owner as this user:", # loc
    'Move the ticket to this queue:',       # loc
);

sub create {
    my $self = shift;
    my %args = @_;
    my $rec = bless {
        map {
            $_ => defined $args{$_} ? $args{$_} : ''
        } RT::Extension::RuleManager::Rule::Fields()
    } => RuleClass;

    my $rules = $self->rules;
    $rec->{_root} = $rules;
    $rec->{_pos} = 0+@$rules;
    push @$rules, $rec;
    $self->_save($rules);

    return $rec;
}

sub load {
    my $self  = shift;
    my $id    = shift;
    my $rules = $self->rules;
    return undef if $id <= 0 or $id > @$rules;
    return $rules->[$id-1];
}

sub raise {
    my $self  = shift;
    my $id    = shift;
    my $rules = $self->rules;
    return undef if $id <= 1 or $id > @$rules;
    @{$rules}[$id-1, $id-2] = @{$rules}[$id-2, $id-1];
    $rules->[$id-1]{_pos} = $id-1;
    $rules->[$id-2]{_pos} = $id-2;
    $self->_save($rules);
    return $id;
}

sub delete {
    my $self  = shift;
    my $id    = shift;
    my $rules = $self->rules;
    return undef if $id <= 0 or $id > @$rules;
    splice @$rules, $id-1, 1;
    $self->_save($rules);
    return $id;
}

sub named {
    my $self = shift;
    my $name = shift;
    foreach my $rule (@{$self->rules}) {
        return $rule if $rule->Name eq $name;
    }
    return undef;
}

sub rules {
    my $self = shift;
    my $rules = $self->_load || [];
    for my $i (0..$#$rules) {
        $rules->[$i]{_pos} = $i;
        $rules->[$i]{_root} = $rules;
        bless $rules->[$i] => RuleClass;
    }
    return $rules;
}

sub _init_action {
    # This initializes the RT::Action we care about.
    # XXX - Override the "Autoreply" scrip by default?

    my $action = RT::ScripAction->new($RT::SystemUser);
    $action->LoadByCol( ExecModule => 'RuleManager' );
    if (!$action->Id) {
        $action->Create(
            Name        => 'Run Rule Manager',                                           # loc
            Description => 'Execute simple rules defined in the Rule Manager interface', # loc
            ExecModule  => 'RuleManager',
        );
    }
    return $action;
}

sub _load {
    my $self = shift;
    return Load($self->_template->Content);
}

sub _save {
    my $self = shift;
    my $rules = shift;

    $self->_init_action;

    my @to_save;
    foreach my $rule (@$rules) {
        my %this = %$rule;
        delete $this{_pos};
        delete $this{_root};
        push @to_save, \%this;
    }

    return $self->_template->SetContent(Dump(\@to_save));
}

# Find our own, special RT::Template.  If one does not exist, create it.
sub _template {
    my $self = shift;
    my $rule_manager_template = RT::Template->new($RT::SystemUser);
    $rule_manager_template->Load(RuleManagerTemplate);
    if (!$rule_manager_template->Id) {
        my $autoreply_template = RT::Template->new($RT::SystemUser);
        $autoreply_template->Load('Autoreply');
        $rule_manager_template->Create(
            Name        => RuleManagerTemplate,
            Description => RuleManagerTemplate,
            Content     => Dump([{
                Name        => 'Default Autoreply',
                Field       => 'Subject',
                Pattern     => '',
                Handler     => 'Send the autoreply in this template:',
                Argument    => $autoreply_template->Content,
                Final       => ''
            }]),
            Queue       => 0,
        );

        my $rule_manager_action = $self->_init_action;

        my $autoreply_action = RT::ScripAction->new($RT::SystemUser);
        $autoreply_action->Load('Autoreply To Requestors');

        if ($autoreply_action->Id and $autoreply_template->Id and $rule_manager_action->Id) {
            # Now usurp all Scrip settings to reset the ScripAction to ours.
            my $scrips = RT::Scrips->new($RT::SystemUser);
            $scrips->Limit(
                FIELD   => 'Template',
                VALUE   => $autoreply_template->Id,
            );
            $scrips->Limit(
                FIELD   => 'ScripAction',
                VALUE   => $autoreply_action->Id,
            );

            while (my $scrip = $scrips->Next) {
                $scrip->SetDescription('Default Autoreply via Rule Manager');
                $scrip->SetScripAction($rule_manager_action->Id);
                $scrip->SetTemplate($rule_manager_template->Id);
            }
        }
    }
    return $rule_manager_template;
}

package RT::Extension::RuleManager::Rule;

use constant Fields => qw( Name Field Pattern Handler Argument Final );

sub id { $_[0]{_pos}+1 }
sub Id { $_[0]{_pos}+1 }

sub UpdateRecordObject {
    my $self = shift;
    my $args = shift;
    my $updated;
    foreach my $field (Fields) {
        exists $args->{$field} or next;
        $updated ||= ($self->{$field} ne $args->{$field});
        $self->{$field} = $args->{$field};
    }
    RT::Extension::RuleManager->_save($self->{_root}) if $updated;
    return $updated;
}

sub PrettyArgument {
    my $self = shift;
    if ($self->Handler =~ /(\w+):$/) {
        if ($1 eq 'template') {
            my ($first_line, $rest) = split(/[\r\n]+/, $self->Argument, 2);
            chomp $first_line;
            if (length($first_line) > 40) {
                return substr($first_line, 0, 40) . '...';
            }
            elsif ($rest =~ /\S/) {
                return "$first_line...";
            }
            else {
                return $first_line;
            }
        }
        elsif ($1 eq 'user') {
            my $user = RT::User->new($RT::SystemUser);
            $user->Load($self->Argument);
            return $user->Name;
        }
        elsif ($1 eq 'queue') {
            my $queue = RT::Queue->new($RT::SystemUser);
            $queue->Load($self->Argument);
            return $queue->Name;
        }
        else {
            return $self->Argument;
        }
    }
    else {
        '';
    }
}

sub PrettyPattern {
    my $self = shift;
    my $pat = $self->Pattern;
    return '*' if $pat eq '';
    return "*$pat*" unless $pat =~ /[*?]/;
    return $pat;
}

BEGIN {
    no strict 'refs';
    no warnings 'uninitialized';
    eval join '', map {qq[
        sub $_ { \$_[0]{'$_'} }
        sub Set$_ {
            return if \$_[0]{'$_'} eq \$_[1];
            \$_[0]{'$_'} = \$_[1];
            RT::Extension::RuleManager->_save(\$_[0]{_root});
        }
    ]} Fields;
}

1;
