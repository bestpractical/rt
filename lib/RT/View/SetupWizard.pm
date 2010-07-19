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

package RT::View::SetupWizard;
use Jifty::View::Declare -base;
use base qw/ Jifty::Plugin::SetupWizard::View::Helpers /;

sub setup_page (&) {
    my ($code) = @_;
    page { title => "RT Setup Wizard" } content {
        my $self = shift;
        h1 { _("RT Setup Wizard") };
        div {{ id is 'setupwizard' };
            form {
                $code->($self);
            };
        };
        show '_config_javascript';
    };
}

sub steps {
    return qw(
        index.html
        database
        root
        organization
        email
        web
        done
    );
}

template 'index.html' => setup_page {
    h2 { _("Welcome to RT!") };

    p {
        _("Let's get your RT install setup and ready to go.  We'll step you through a few steps to configure the basics.");
    };

    show 'buttons', for => 'index.html';

    p {
        outs_raw _("This setup wizard was activated by the presence of <tt>SetupMode: 1</tt> in one of your configuration files. If you are seeing this erroneously, you may restore normal operation by adjusting the <tt>etc/site_config.yml</tt> file to have <tt>SetupMode: 0</tt> set under <tt>framework</tt>.");
    };
};

template 'database' => setup_page {
    h2 { _("Configure your database") };
    
    p {{ class is 'warning' };
        _("RT may ask you, after saving the database settings, to login again as root with the default password.");
    };

    show 'database_widget';

    show 'buttons', for => 'database';
};

template 'root' => setup_page {
    h2 { _("Change the default root password") };

    p {
        _("It is very important that you change the password of RT's root user.  Leaving it as the default of 'password' is a serious security risk.");
    };

    my $user = RT::Model::User->new;
    $user->load_by_cols(name => 'root');

    my $action = $user->as_update_action( moniker => 'updateuser-root' );
    render_param( $action => 'password', ajax_validates => 0 );
    render_param(
        $action => 'password_confirm',
        label   => 'Confirm Password',
    );
    
    show 'buttons', for => 'root';
};

template 'organization' => setup_page {
    h2 { _("Tell RT about your organization") };

    p { _("Now tell RT just the very basics about your organization.") };

    show 'rt_config_fields' => qw( rtname organization time_zone );
    show 'buttons', for => 'organization';
};

template 'email' => setup_page {
    h2 { _("Configure the email setup") };

    p { _("One of the main ways to interact with RT is via email.  Setup the basics now.") };

    # XXX TODO: We should do a mail_command handler like the db chooser and then
    # show smtp/sendmail/etc specific options
    show 'rt_config_fields' => qw( owner_email correspond_address comment_address );
    show 'buttons', for => 'email';
};

template 'web' => setup_page {
    h2 { _("Configure the web setup") };

    p { _("RT needs to know a little bit about how you have it setup on your webserver.") };

    # XXX TODO: How can we set the jifty BaseUrl and Port without respawning
    # the current server
    show 'rt_config_fields' => qw( web_path logo_url );
    show 'buttons', for => 'web';
};

template 'done' => setup_page {
    my $self = shift;

    h2 { _("Setup complete!") };

    p {
        _(<<'EOT');
You probably want to turn off Setup Mode now and go see your new RT.  You'll
want to review the config generated for you in etc/site_config.yml and restart
RT.  Now would also be a good time to setup your mail server to hand off mail
to RT.
EOT
    };

    form_next_page( url => '/' );

    my $action = $self->config_field(
        field      => 'SetupMode',
        context    => '/framework',
        message    => 'Setup Mode is now turned off.',
        value_args => {
            render_as       => 'Hidden',
            default_value   => 0,
        },
    );

    form_submit( label => 'Turn off Setup Mode and go to RT' );
};

private template 'rt_config_fields' => sub {
    my $self = shift;

    my $config = new_action( class => 'RT::Action::ConfigSystem' );
    my $meta = $config->metadata;

    for my $field ( @_ ) {
        div {{ class is 'config-field' };
            render_param( $config => $field );
            div {{ class is 'doc' };
                outs_raw( $meta->{$field}{'doc'} )
            } if $meta->{$field} and defined $meta->{$field}{'doc'};
        };
    }
};

private template '_config_javascript' => sub {
    script {
        outs_raw(<<'JSEND');
jQuery(function() {
    jQuery('.config-field .widget').focus(
        function(){
            var thisdoc = jQuery(this).parent().parent().find(".doc");

            // Slide up everything else and slide down this doc
            jQuery('.config-field .doc').not(thisdoc).slideUp();
            thisdoc.slideDown();
        }
    );
    jQuery('.config-field .doc').hide();
    jQuery('.config-field .widget')[0].focus();
});
JSEND
    };
};

1;

