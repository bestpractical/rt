# This module is intended to be used to set RTFM options.
# It is loaded after RT_Config.pm
#
# This file is actually a perl module, so you can include valid
# perl code, as well.
#
# The converse is also true, if this file isn't valid perl, you're
# going to run into trouble. To check your SiteConfig file, use
# this comamnd:
#
#   perl -c /path/to/your/etc/RTFM_Config.pm

# Set this to 1 to display the RTFM interface on the Ticket Create page
# in addition to the Reply/Comment page.
# This will only work with 3.8.1 or greater

Set($RTFM_TicketCreate, 0);

1;
