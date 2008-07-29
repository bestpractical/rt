# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

package RT::Installer;
use strict;
use warnings;

require UNIVERSAL::require;
use Text::Naming::Convention qw/renaming/;

sub current_value {
    my $class = shift;
    my $type  = shift;
    $type = $class if !ref $class && $class && $class ne 'RT::Installer';

    return undef unless $type;
    return $RT::Installer
      && exists $RT::Installer->{config}{$type}
      ? $RT::Installer->{config}{$type}
      : scalar RT->config->get($type);
}

sub current_values {
    my $class = shift;
    my @types = @_;
    push @types, $class if !ref $class && $class && $class ne 'RT::Installer';

    return { map { $_ => current_value($_) } @types };
}

sub config_file {
    require File::Spec;
    return File::Spec->catfile( $RT::EtcPath, 'RT_SiteConfig.pm' );
}

sub save_config {
    my $class = shift;

    my $file = $class->config_file;

    my $content;

    {
        local $/;
        open my $fh, '<', $file or die $!;
        $content = <$fh>;
        $content =~ s/^\s*1;\s*$//m;
    }

    # make organization the same as rtname
    $RT::Installer->{config}{organization} =
      $RT::Installer->{config}{rtname};

    if ( open my $fh, '>', $file ) {
        for ( keys %{ $RT::Installer->{config} } ) {

            # we don't want to store root's password in config.
            next if $_ eq 'password';

            $RT::Installer->{config}{$_} = ''
              unless defined $RT::Installer->{config}{$_};

            if ( $_ ne 'rtname' && $_ !~ /[A-Z]/ ) {

                # we need to rename it to be UpperCamelCase
                $_ = renaming( $_, { convention => 'UpperCamelCase' } );
            }

            # remove obsolete settings we'll add later
            $content =~ s/^\s* set \s* \( \s* \$$_ .*$//xm;

            $content .= "set( \$$_, '$RT::Installer->{config}{$_}' );\n";
        }
        $content .= "1;\n";
        print $fh $content;
        close $fh;

        return ( 1, "Successfully saved configuration to $file." );
    }

    return ( 0, "Cannot save configuration to $file: $!" );
}

=head1 NAME

    RT::Installer - RT's Installer

=head1 SYNOPSYS

    use RT::Installer;
    my $meta = RT::Installer->meta;

=head1 DESCRIPTION

C<RT::Installer> class provides access to RT Installer Meta

=cut

1;

