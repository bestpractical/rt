# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
package RT::Action::RuleManager;
use RT::Extension::RuleManager;
require RT::Action::Autoreply;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Action::Autoreply);

# {{{ sub Describe 
sub Describe  {
    my $self = shift;
    return(ref $self);
}
# }}}

# Evaluate all conditions from first to last.
sub Prepare {
    my $self = shift;
    my $rules = RT::Extension::RuleManager->rules;
    my @matched;
    foreach my $rule (@$rules) {
        next unless $self->MatchRule($rule);
        push @matched, $rule;
        last if $rule->Final;
    }

    if (@matched) {
        $self->{Matched} = \@matched;
        return 1;
    }
    else {
        return 0;
    }
}

sub MatchRule {
    my $self = shift;
    my $rule = shift;

    my $pattern = $rule->PrettyPattern;
    return 1 if $pattern eq '*';

    my $field = $rule->Field;
    my $val;
    if ($self->TransactionObj->can($field)) {
        $val = $self->TransactionObj->$field;
    }
    elsif (my $att = $self->TransactionObj->Attachments->First) {
        if ($att->can($field)) {
            $val = $att->$field;
        }
        else {
            $val = $att->GetHeader($field);
        }
    }
    else {
        return undef;
    }

    $pattern = quotemeta($pattern);
    $pattern =~ s/\\\*/.*/;
    $pattern =~ s/\\\?/./;

    return($val =~ /^$pattern$/);
}

sub Commit {
    my $self = shift;
    foreach my $rule (@{$self->{Matched} || []}) {
        my $handler = $rule->Handler;
        if ($handler eq 'Send no autoreply') {
            next; # Do nothing.
        }
        elsif ($handler eq "Set the ticket's owner as this user:") {
            $self->TicketObj->SetOwner($rule->Argument);
        }
        elsif ($handler eq 'Move the ticket to this queue:') {
            $self->TicketObj->SetQueue($rule->Argument);
        }
        elsif ($handler eq 'Send the autoreply in this template:') {
            local $self->{TemplateObj} = bless {
                user    => $self->CurrentUser,
                fetched => { content => 1, queue => 1 },
                values  => {
                    queue   => 0,
                    content => $rule->Argument,
                },
            } => 'RT::Template';

            $self->SUPER::Prepare;
            $self->SUPER::Commit(@_);
        }
        else {
            $RT::Logger->error("Unknown handler: $handler");
            next;
        }
    }
}

sub TemplateObj {
    my $self = shift;
    $self->{TemplateObj};
}

eval "require RT::Action::RuleManager_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/RuleManager_Vendor.pm});
eval "require RT::Action::RuleManager_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/RuleManager_Local.pm});

1;
