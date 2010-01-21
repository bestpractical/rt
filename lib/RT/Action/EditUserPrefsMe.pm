use strict;
use warnings;

package RT::Action::EditUserPrefsMe;
use base qw/RT::Action::UpdateUser RT::Action::EditUserPrefs/;
use Scalar::Defer qw/defer/;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'reset_auth_token' => render as 'InlineButton',
      label              is _('reset auth token'),
      hints              is _(
'All iCal feeds embed a secret token which authorizes you.  If the URL one of your iCal feeds got exposed to the outside world, you can get a new secret, <b>breaking all existing iCal feeds</b> below.'
      );
    param 'id' => render as 'hidden',
          default is defer { __PACKAGE__->user->id };
};

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    if ( $self->argument_value('reset_auth_token') ) {
        my ( $status, $msg ) = $self->user->generate_auth_token;
        Jifty->log->error($msg) unless $status;
        $self->result->message( _('Reset auth token') );
        return 1;
    }

    # now let's deal with columns
    $self->record( $self->user );
    $self->SUPER::take_action(@_);
    $self->report_success;

    return 1;
}

sub sections {
    return (
        {
            title  => 'Identity',
            fields => [qw/id name email real_name nickname lang time_zone/],
        },
        (
            RT->config->get('web_external_auth')
              && !RT->config->get('web_fallback_to_internal_auth')
            ? ()
            : {
                title  => 'Password',
                fields => [qw/password password_confirm/],
            },
        ),
        {
            title  => 'Phone numbers',
            fields => [
                qw/home_phone work_phone mobile_phone
                  pager_phone/
            ],
        },
        {
            title => 'Location',
            fields =>
              [qw/organization address1 address2 city state zip country/],
        },
        {
            title  => 'Signature',
            fields => [qw/signature/],
        },
        {
            title  => 'Secret authentication token',
            fields => [qw/reset_auth_token/],
        },
    );
}

1;
