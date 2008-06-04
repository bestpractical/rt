# Any configuration directives you include  here will override 
# RT's default configuration file, RT_Config.pm
#
# To include a directive here, just copy the equivalent statement
# from RT_Config.pm and change the value. We've included a single
# sample value below.
#
# This file is actually a perl module, so you can include valid
# perl code, as well.
#
# The converse is also true, if this file isn't valid perl, you're
# going to run into trouble. To check your SiteConfig file, use
# this comamnd:
#
#   perl -c /path/to/your/etc/RT_SiteConfig.pm

#Set(@Plugins,(qw(Extension-QuickDelete)));

Set( $DatabaseUser, 'rt_user' );
Set( $SendmailBounceArguments, '-f "<>"' );
Set( $Timezone, '' );
Set( $CorrespondAddress, 'kyoki+rtcorrespond@bestpractical.com' );
Set( $rtname, 'example.com' );
Set( $SendmailArguments, '-oi -t' );
Set( $Organization, 'example.com' );
Set( $MaxAttachmentSize, '10000000' );
Set( $DatabaseType, 'mysql' );
Set( $DatabasePassword, 'rt_pass' );
Set( $DatabaseAdmin, 'root' );
Set( $SendmailPath, '/usr/sbin/sendmail' );
Set( $MailCommand, 'sendmailpipe' );
Set( $DatabaseAdminPassword, 'arimasen' );
Set( $CommentAddress, 'kyoki+rtcomment@bestpractical.com' );
Set( $DatabaseHost, 'localhost' );
Set( $MinimumPasswordLength, '5' );
Set( $DatabaseName, 'rt3' );
Set( $OwnerEmail, 'kyoki@bestpractical.com' );
1;
