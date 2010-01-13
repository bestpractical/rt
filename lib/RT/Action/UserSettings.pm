use strict;
use warnings;

package RT::Action::UserSettings;
use base qw/RT::Action Jifty::Action/;
use UNIVERSAL::require;
use Scalar::Util qw/looks_like_number/;
use Regexp::Common qw/Email::Address/;

# XXX system default's option is
#            {
#                display => _('use system default'),
#                value   => 'use_system_default'
#            }

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'default_queue' =>
      label is 'default queue',
      render as 'Select',
      available are defer {
        my $qs = RT::Model::QueueCollection->new;
        $qs->unlimit;
        my $ret = [
            {
                display => _('use system default'),
                value   => 'use_system_default'
            }
        ];
        while ( my $queue = $qs->next ) {
            next unless $queue->current_user_has_right("CreateTicket");
            push @$ret,
              {
                display => _($queue->name),
                value   => $queue->id
              };
        }
        return $ret;
      },
      default is defer {
        RT::Action::UserSettings->default_value('default_queue');
      };
    param 'username_format' =>
      label is 'username format',
      render as 'Select',
      available are [
        { display => _('use system default'),  value => 'use_system_default' },
        { display => _('Short usernames'),        value => 'concise' },
        { display => _('Name and email address'), value => 'verbose' },
      ],
      default is defer {
        RT::Action::UserSettings->default_value('username_format');
      };
    param 'web_default_stylesheet' =>
      label is 'theme',
      render as 'Select',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map {{ display => _($_), value => $_ }} qw/web2/
      ],
      default is defer {
        RT::Action::UserSettings->default_value('web_default_stylesheet');
      };
    param 'message_box_rich_text' =>
      label is 'WYSIWYG message composer',
      render as 'Radio',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map { { display => _($_), value => $_ } } 'yes', 'no',
      ],
      default is defer {
        RT::Action::UserSettings->default_value('message_box_rich_text');
      };
    param 'message_box_rich_text_height' =>
      label is 'WYSIWYG composer height',
      default is defer {
        RT::Action::UserSettings->default_value('message_box_rich_text_height');
      };
    param 'message_box_width' =>
      label is 'message box width',
      default is defer {
        RT::Action::UserSettings->default_value('message_box_width');
      };
    param 'message_box_height' =>
      label is 'message box height',
      default is defer {
        RT::Action::UserSettings->default_value('message_box_height');
      };

    # locale
    param 'date_time_format' =>
      label is 'date format',
      render as 'Select',
      available are defer {
        my $now = RT::DateTime->now;
        my $ret = [
            {
                display => _('use system default'),
                value   => 'use_system_default'
            }
        ];
        for my $name (qw/rfc2822 rfc2616 iso iCal /) {
            push @$ret,
              {
                value   => $name,
                display => "$name (" . $now->$name . ")"
              };
        }
        return $ret;
      },
      default is defer {
        RT::Action::UserSettings->default_value('date_time_format');
      };

    #mail
    param email_frequency =>
      label is 'email delivery',
      render as 'Select',
      available are defer {
        [
            {
                display => _('use system default'),
                value   => 'use_system_default'
            },
            map { { display => _($_), value => $_ } }
              'Individual messages',    #loc
              'Daily digest',           #loc
              'Weekly digest',          #loc
              'Suspended',              #loc
        ];
      },
      default is defer {
        RT::Action::UserSettings->default_value('email_frequency');
      };

    # rt at a glance
    param 'default_summary_rows' =>
      label is 'number of search results',
      default is defer {
        RT::Action::UserSettings->default_value('default_summary_rows');
      };

    # ticket display
    param 'max_inline_body' =>
      label is 'Maximum inline message length',
      default is defer {
        RT::Action::UserSettings->default_value('max_inline_body');
      };
    param 'oldest_transactions_first' =>
      label is 'Show oldest transactions first',
      render as 'Radio',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map { { display => _($_), value => $_ } } 'yes', 'no',
      ],
      default is defer {
        RT::Action::UserSettings->default_value('oldest_transactions_first');
      };
    param 'show_unread_message_notifications' =>
      label is 'Notify me of unread messages',
      render as 'Radio',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map { { display => _($_), value => $_ } } 'yes', 'no',
      ],
      default is defer {
        RT::Action::UserSettings->default_value(
            'show_unread_message_notifications');
      };
    param 'plain_text_pre' =>
      label is 'Use monospace font',
      hints is 'Use fixed-width font to display plaintext messages',
      render as 'Radio',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map { { display => _($_), value => $_ } } 'yes', 'no',
      ],
      default is defer {
        RT::Action::UserSettings->default_value('plain_text_pre');
      };
};

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $user = Jifty->web->current_user->user_object;
    my $pref = $user->preferences( RT->system ) || {};
    for my $arg ( $self->argument_names ) {
        if ( $self->has_argument($arg) ) {
            if ( $self->argument_value($arg) eq 'use_system_default' ) {
                delete $pref->{$arg};
            }
            else {
                $pref->{$arg} = $self->argument_value($arg);
            }
        }
    }
    $user->set_preferences( RT->system, $pref );
    $self->report_success if not $self->result->failure;

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message(_('Updated user settings'));
}

sub default_value {
    my $self = shift;
    my $name = shift;
    my $pref = Jifty->web->current_user->user_object->preferences( RT->system );
    if ( $pref && exists $pref->{$name} ) {
        return $pref->{$name};
    }
    else {
        return 'use_system_default';
    }
}

my %fields = (
    'General' => [
        qw/default_queue username_format web_default_stylesheet
          message_box_rich_text message_box_rich_text_height message_box_width
          message_box_height/
    ],
    'Locale'         => [qw/date_time_format/],
    Mail             => [qw/email_frequency/],
    'RT at a glance' => [
        qw/default_summary_rows max_inline_body oldest_transactions_first
          show_unread_message_notifications plain_text_pre/
    ],
);

sub fields {
    return %fields;
}

1;
