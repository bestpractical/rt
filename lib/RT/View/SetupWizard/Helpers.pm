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
use warnings;
use strict;

=head1 NAME

RT::View::SetupWizard::Helpers - Helpers for RT's setup wizard, inherits from
Jifty's SetupWizard plugin helpers

=cut

package RT::View::SetupWizard::Helpers;
use Jifty::View::Declare -base;
use base qw/ Jifty::Plugin::SetupWizard::View::Helpers /;

=head1 TEMPLATES

=head2 mail_widget

Provides a mail configuration widget for RT's setup wizard.  NOTE: this
configures RT's, not Jifty's, mailer.  Jifty's mail infrastructure is unused by
RT4 at the moment.

Much of it is based on the database config widget provided by Jifty's
SetupWizard plugin.

=cut

private template 'mail_widget' => sub {
    my $self = shift;
    # XXX: We've got to add a sane way to unquote stuff in onfoo handlers...
    my $onchange = 'Jifty.update('
                 . Jifty::JSON::encode_json({
                    actions          => {},
                    action_arguments => {},
                    fragments        => [
                        {
                            mode => 'Replace',
                            path => $self->fragment_for('mail_widget/PLACEHOLDER'),
                            region => Jifty->web->qualified_region('mail_command_details'),
                        },
                    ],
                    continuation     => undef,

                 })
                 . ', this)';

    $onchange =~ s/PLACEHOLDER/"+this.value+"/;

    $self->rt_config_field(
        field       => 'mail_command',
        doc_class   => 'static-doc',
        value_args  => {
            onchange => [$onchange]
        }
    );

    my $current_command = RT->config->get('mail_command');

    render_region(
        name => 'mail_command_details',
        path => $self->fragment_for("mail_widget/$current_command"),
    );
};

template 'mail_widget/sendmail' => sub {
    my $self = shift;
    $self->rt_config_field(
        field => [qw(
            sendmail_path
            sendmail_arguments
            sendmail_bounce_arguments
        )],
    );
};

template 'mail_widget/sendmailpipe' => sub {
    show 'sendmail';
};

template 'mail_widget/smtp' => sub {
    my $self = shift;
    $self->rt_config_field(
        field => [qw(
            smtp_server
            smtp_from
        )],
    );
};

template 'mail_widget/qmail' => sub {
    show 'other';
};

template 'mail_widget/other' => sub {
    my $self = shift;
    $self->rt_config_field( field => 'mail_params' );
};

=head1 METHODS

=head2 rt_config_field FIELD [FIELD2] [FIELD3]

Renders fields and doc of L<RT::Action::ConfigSystem> parameters.  Returns the
action created.

=cut

sub rt_config_field {
    my $self = shift;
    my %args = (
        field       => [],
        value_args  => {},
        doc_class   => '',
        @_
    );

    my $config = new_action( class => 'RT::Action::ConfigSystem' );
    my $meta = $config->metadata;

    $args{'field'} = [ $args{'field'} ]
        if not ref $args{'field'};

    for my $field ( @{$args{'field'}} ) {
        div {{ class is 'config-field' };
            render_param( $config => $field, %{ $args{'value_args'} } );
            div {{ class is join(' ', 'doc', $args{'doc_class'}) };
                outs_raw( $meta->{$field}{'doc'} )
            } if $meta->{$field} and defined $meta->{$field}{'doc'};
        };
    }

    return $config;
}

1;
