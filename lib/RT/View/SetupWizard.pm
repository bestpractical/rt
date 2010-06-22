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

template 'index.html' => page { title => 'RT Setup Wizard' } content {
    h1 { _("RT Setup Wizard") };
    h2 { _("Welcome to RT!") };

    p {
        _("Let's get your RT install setup and ready to go.  We'll step you through a few steps to configure the basics.");
    };

    my $config = new_action(
        class   => 'RT::Action::ConfigSystem',
        moniker => 'sysconfig'
    );

    form { $config->next_page_button( url => 'database', label => 'Start' ) };

    p {
        outs_raw _("This setup wizard was activated by the presence of <tt>SetupMode: 1</tt> in one of your configuration files. If you are seeing this erroneously, you may restore normal operation by adjusting the <tt>etc/site_config.yml</tt> file to have <tt>SetupMode: 0</tt> set under <tt>framework</tt>.");
    };
};

template 'database' => page { title => 'RT Setup Wizard: Database' } content {
    h1 { _("RT Setup Wizard") };
    h2 { _("Database") };
    
    my $config = new_action(
        class   => 'RT::Action::ConfigSystem',
        moniker => 'sysconfig'
    );

    form {
        show 'database_widget';
        $config->next_page_button( url => 'web', label => 'Next step' );
    };
};

# web - base url, port, more RT stuff
# rt specific stuff
# turn off SetupMode in finalize


template 'basics' => sub {
    p { _("It is very important that you change the password to RT's root user. Leaving it as the default of 'password' is a serious security risk.") };

    my $user = RT::Model::User->new;
    $user->load_by_cols(name => 'root');

    my $password = $user->as_update_action;
    outs_raw( $password->form_field('password') );

    p { _("You may change basic information about your RT install.") };

    my $config = new_action( class => 'RT::Action::ConfigSystem' );
    my $meta = $config->metadata;
    for my $field (
        qw/rtname time_zone comment_address correspond_address sendmail_path
        owner_email/
      )
    {
        div {
            attr { class => 'hints' };
            outs_raw( $meta->{$field} && $meta->{$field}{doc} );
        };
        outs_raw( $config->form_field($field) );
    }
};

1;

