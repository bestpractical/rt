#
# Regular cron jobs for the rt package
#
0 * * * *	root	[ -d /var/cache/request-tracker/session ] && find /var/cache/request-tracker/session -type f -amin +600 -exec rm {} \;
