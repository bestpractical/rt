use utf8;

# Any configuration directives you include  here will override
# RT's default configuration file, RT_Config.pm
#
# To include a directive here, just copy the equivalent statement
# from RT_Config.pm and change the value. We've included a single
# sample value below.
#
# If this file includes non-ASCII characters, it must be encoded in
# UTF-8.
#
# This file is actually a perl module, so you can include valid
# perl code, as well.
#
# The converse is also true, if this file isn't valid perl, you're
# going to run into trouble. To check your SiteConfig file, use
# this command:
#
#   perl -c /path/to/your/etc/RT_SiteConfig.pm
#
# You must restart your webserver after making changes to this file.
#

# You may also split settings into separate files under the etc/RT_SiteConfig.d/
# directory.  All files ending in ".pm" will be parsed, in alphabetical order,
# after this file is loaded.

Set( $rtname, 'example.com');

# You must install Plugins on your own, this is only an example
# of the correct syntax to use when activating them:
#     Plugin( "RT::Authen::ExternalAuth" );

1;
