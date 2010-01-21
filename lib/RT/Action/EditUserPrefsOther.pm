use strict;
use warnings;

package RT::Action::EditUserPrefsOther;
use base qw/RT::Action::EditUserPrefs/;

sub name {
    return RT->system;
}

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'default_queue' =>
      label is _('default queue'),
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
        __PACKAGE__->default_value('default_queue');
      };
    param 'username_format' =>
      label is _('username format'),
      render as 'Select',
      available are [
        { display => _('use system default'),  value => 'use_system_default' },
        { display => _('Short usernames'),        value => 'concise' },
        { display => _('Name and email address'), value => 'verbose' },
      ],
      default is defer {
        __PACKAGE__->default_value('username_format');
      };
    param 'web_default_stylesheet' =>
      label is _('theme'),
      render as 'Select',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map {{ display => _($_), value => $_ }} qw/web2/
      ],
      default is defer {
        __PACKAGE__->default_value('web_default_stylesheet');
      };
    param 'message_box_rich_text' =>
      label is _('WYSIWYG message composer'),
      render as 'Radio',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map { { display => _($_), value => $_ } } 'yes', 'no',
      ],
      default is defer {
        __PACKAGE__->default_value('message_box_rich_text');
      };
    param 'message_box_rich_text_height' =>
      label is _('WYSIWYG composer height'),
      default is defer {
        __PACKAGE__->default_value('message_box_rich_text_height');
      };
    param 'message_box_width' =>
      label is _('message box width'),
      default is defer {
        __PACKAGE__->default_value('message_box_width');
      };
    param 'message_box_height' =>
      label is _('message box height'),
      default is defer {
        __PACKAGE__->default_value('message_box_height');
      };

    # locale
    param 'date_time_format' =>
      label is _('date format'),
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
        __PACKAGE__->default_value('date_time_format');
      };

    #mail
    param email_frequency =>
      label is _('email delivery'),
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
        __PACKAGE__->default_value('email_frequency');
      };

    # rt at a glance
    param 'default_summary_rows' =>
      label is _('number of search results'),
      default is defer {
        __PACKAGE__->default_value('default_summary_rows');
      };

    # ticket display
    param 'max_inline_body' =>
      label is _('Maximum inline message length'),
      default is defer {
        __PACKAGE__->default_value('max_inline_body');
      };
    param 'oldest_transactions_first' =>
      label is _('Show oldest transactions first'),
      render as 'Radio',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map { { display => _($_), value => $_ } } 'yes', 'no',
      ],
      default is defer {
        __PACKAGE__->default_value('oldest_transactions_first');
      };
    param 'show_unread_message_notifications' =>
      label is _('Notify me of unread messages'),
      render as 'Radio',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map { { display => _($_), value => $_ } } 'yes', 'no',
      ],
      default is defer {
        __PACKAGE__->default_value(
            'show_unread_message_notifications');
      };
    param 'plain_text_pre' =>
      label is _('Use monospace font'),
      hints is 'Use fixed-width font to display plaintext messages',
      render as 'Radio',
      available are [
        { display => _('use system default'), value => 'use_system_default' },
        map { { display => _($_), value => $_ } } 'yes', 'no',
      ],
      default is defer {
        __PACKAGE__->default_value('plain_text_pre');
      };
    param 'preferred_key' =>
      label is _('Preferred key'),
      render as 'Select',
    available are defer {
        require RT::Crypt::GnuPG;
        my $d;
        my %res = RT::Crypt::GnuPG::get_keys_for_encryption(
            __PACKAGE__->user->email );
        # move the preferred key to the top of the list
        my @keys = map {
            $_->{'fingerprint'} eq ( __PACKAGE__->user->preferred_key || '' )
              ? do { $d = $_; () }
              : $_
        } @{ $res{'info'} };

        @keys = sort { $b->{'trust_level'} <=> $a->{'trust_level'} } @keys;

        unshift @keys, $d if defined $d;
        [
            map {
                {
                    display => $_->{'fingerprint'},
                    value   => $_->{'fingerprint'} . ' '
                      . _( 'trust: %1', $_->{'trust_terse'} )
                }
              } @keys
        ];
    },
    default is defer {
        __PACKAGE__->user->preferred_key;
    };
};

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $pref = $self->user->preferences( $self->name ) || {};
    for my $arg ( $self->argument_names ) {
        if ( $self->has_argument($arg) ) {
            if ( $arg eq 'preferred_key' ) {
                my ( $status, $msg ) = $self->user->set_attribute(
                    name    => 'preferred_key',
                    content => $self->argument_value('preferred_key'),
                );
                Jifty->log->error($msg) unless $status;
            }
            elsif ( $self->argument_value($arg) eq 'use_system_default' ) {
                delete $pref->{$arg};
            }
            else {
                $pref->{$arg} = $self->argument_value($arg);
            }
        }
    }
    my ( $status, $msg ) = $self->user->set_preferences( $self->name, $pref );
    Jifty->log->error($msg) unless $status;
    $self->report_success;

    return 1;
}

sub default_value {
    my $self = shift;
    my $name = shift;
    my $pref = $self->user->preferences( $self->name );
    if ( $pref && exists $pref->{$name} ) {
        return $pref->{$name};
    }
    else {
        return 'use_system_default';
    }
}

sub sections {
    my @sections = (
        {
            title  => 'General',
            fields => [
                qw/default_queue username_format web_default_stylesheet
                  message_box_rich_text message_box_rich_text_height message_box_width
                  message_box_height/
            ]
        },
        {
            title  => 'Locale',
            fields => [qw/date_time_format/]
        },
        {
            title  => 'Mail',
            fields => => [qw/email_frequency/]
        },
        {
            title  => 'RT at a glance',
            fields => [
                qw/default_summary_rows max_inline_body oldest_transactions_first
                  show_unread_message_notifications plain_text_pre/
            ]
        },
    );
    if ( RT->config->get('gnupg')->{'enable'} ) {
        push @sections,
          {
            title  => 'Cryptography',
            values => [qw/preferred_key/]
          };
    }
    return @sections;
}


1;
