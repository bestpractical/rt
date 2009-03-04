#!/usr/bin/perl

use warnings; use strict;
use Test::MockTime qw(set_fixed_time restore_time);
use RT::Test;

use Test::More tests => 165;

use RT::Model::User;
use Test::Warn;

use_ok('RT::DateTime');

set_fixed_time("2005-11-28T15:10:00Z");

{
    my $system = RT->system_user;
    my $date = RT::DateTime->now(current_user => $system);
    isa_ok($date, 'RT::DateTime', "constructor returned RT::DateTime oject");
    is($date->current_user, $system, "correctly set the datetime's current_user");
}

{
    # set time zone in all places to UTC
    RT->system_user->user_object->__set(column => 'time_zone', value => 'UTC')
                                if RT->system_user->user_object->time_zone;
    RT->config->set( TimeZone => 'UTC' );
}

my $current_user;
{
    my $user = RT::Model::User->new(current_user => RT->system_user);
    my($uid, $msg) = $user->create(
        name       => "date_api". rand(200),
        lang       => 'en',
        privileged => 1,
    );
    ok($uid, "user was Created") or diag("error: $msg");
    $current_user = RT::CurrentUser->new(id => $user->id);
}

{
    my $date = RT::DateTime->now(current_user => $current_user );
    is($date->time_zone->name, 'UTC', "dropped all timzones to UTC");
    is($date->set_time_zone('user')->time_zone->name, 'UTC', "dropped all timzones to UTC");
    is($date->set_time_zone('server')->time_zone->name, 'UTC', "dropped all timzones to UTC");

    $current_user->user_object->__set( column => 'time_zone', value => 'Europe/Moscow');
    is($current_user->user_object->time_zone,
       'Europe/Moscow',
       "successfuly changed user's time_zone");
    is($date->set_time_zone('user')->time_zone->name,
       'Europe/Moscow',
       "in user context returns user's time_zone");
    is($date->time_zone->name, 'Europe/Moscow', "we changed the timezone");
    is($date->set_time_zone('server')->time_zone->name, 'UTC', "wasn't changed");

    RT->config->set( TimeZone => 'Africa/Ouagadougou' );
    is($date->set_time_zone('server')->time_zone->name,
       'Africa/Ouagadougou',
       "time_zone of the RT server was changed");
    is($date->set_time_zone('user')->time_zone->name,
       'Europe/Moscow',
       "in user context still returns user's time_zone");
    is($date->time_zone->name, 'Europe/Moscow', "we changed the timezone");

    $current_user->user_object->__set( column => 'time_zone', value => '');
    is($current_user->user_object->time_zone,
       '',
       "successfuly changed user's time_zone");
    is($date->set_time_zone('user')->time_zone->name,
       'Africa/Ouagadougou',
       "in user context returns time zone of the server if user's one is not defined");
    is($date->time_zone->name, 'Africa/Ouagadougou', "we changed the timezone");

    RT->config->set( TimeZone => 'GMT' );
    is($date->set_time_zone('server')->time_zone->name,
       'UTC',
       "time zone is GMT which one is alias for UTC");

    RT->config->set( TimeZone => '' );
    is($date->time_zone->name, 'UTC', "dropped all timzones to UTC");
    is($date->set_time_zone('user')->time_zone->name,
       'UTC',
       "user's and server's timzones are not defined, so UTC");
    is($date->set_time_zone('server')->time_zone->name,
       'UTC',
       "time zone of the server is not defined so UTC");

    RT->config->set( TimeZone => 'UTC' );
}

{
    my $date = RT::DateTime->now(current_user => RT->system_user);
    is($date, '2005-11-28 15:10:00', "default is ISO format");
    is($date->w3cdtf, '2005-11-28T15:10:00Z', "W3CDTF format");

    is($date->rfc2822,
       'Mon, 28 Nov 2005 15:10:00 -0000',
       "RFC2822 format with defaults");

    is($date->iso(time => 0),
       '2005-11-28',
       "ISO format without time part");
    is($date->w3cdtf(time => 0),
       '2005-11-28',
       "W3CDTF format without time part");
    is($date->rfc2822(time => 0),
       'Mon, 28 Nov 2005',
       "RFC2822 format without time part");

    is($date->iso(date => 0),
       '15:10:00',
       "ISO format without date part");
    is($date->w3cdtf(date => 0),
       '2005-11-28T15:10:00Z',
       "W3CDTF format is incorrect without date part");
    is($date->rfc2822(date => 0),
       '15:10:00 -0000',
       "RFC2822 format without date part");

    is($date->iso(date => 0, seconds => 0),
       '00:00',
       "ISO format without date part and seconds");
    is($date->w3cdtf(date => 0, seconds => 0),
       '1970-01-01T00:00Z',
       "W3CDTF format without seconds, but we ship date part even if date is false");
    is($date->rfc2822(date => 0, seconds => 0),
       '00:00 +0000',
       "RFC2822 format without date part and seconds");

    is($date->rfc2822(day_of_week => 0),
       '1 Jan 1970 00:00:00 +0000',
       "RFC2822 format without 'day of week' part");
    is($date->rfc2822(day_of_week => 0, date => 0),
       '00:00:00 +0000',
       "RFC2822 format without 'day of week' and date parts(corner case test)");

    is($date->date,
       '1970-01-01',
       "the default format for the 'date' method is ISO");
    is($date->date(format => 'W3CDTF'),
       '1970-01-01',
       "'date' method, W3CDTF format");
    is($date->date(format => 'RFC2822'),
       'Thu, 1 Jan 1970',
       "'date' method, RFC2822 format");
    is($date->date(time => 1),
       '1970-01-01',
       "'date' method doesn't pass through 'time' argument");
    is($date->date(date => 0),
       '1970-01-01',
       "'date' method overrides 'date' argument");

    is($date->time,
       '00:00:00',
       "the default format for the 'time' method is ISO");
    is($date->time(format => 'W3CDTF'),
       '1970-01-01T00:00:00Z',
       "'time' method, W3CDTF format, date part is required by w3c doc");
    is($date->time(format => 'RFC2822'),
       '00:00:00 +0000',
       "'time' method, RFC2822 format");
    is($date->time(date => 1),
       '00:00:00',
       "'time' method doesn't pass through 'date' argument");
    is($date->time(time => 0),
       '00:00:00',
       "'time' method overrides 'time' argument");
}


{ # positive time zone
    $current_user->user_object->__set( column => 'time_zone', value => 'Europe/Moscow');
    my $date = RT::DateTime->now( current_user => $current_user );
    $date->set( format => 'ISO', time_zone => 'utc', value => '2005-01-01 15:10:00' );
    is($date->iso( time_zone => 'user' ), '2005-01-01 18:10:00', "ISO");
    is($date->w3cdtf( time_zone => 'user' ), '2005-01-01T18:10:00+03:00', "W3C DTF");
    is($date->rfc2822( time_zone => 'user' ), 'Sat, 1 Jan 2005 18:10:00 +0300', "RFC2822");

    # DST
    $date = RT::DateTime->now(current_user =>  $current_user );
    $date->set( format => 'ISO', time_zone => 'utc', value => '2005-07-01 15:10:00' );
    is($date->iso( time_zone => 'user' ), '2005-07-01 19:10:00', "ISO");
    is($date->w3cdtf( time_zone => 'user' ), '2005-07-01T19:10:00+04:00', "W3C DTF");
    is($date->rfc2822( time_zone => 'user' ), 'Fri, 1 Jul 2005 19:10:00 +0400', "RFC2822");
}

{ # negative time zone
    $current_user->user_object->__set( column => 'time_zone', value => 'America/New_York');
    my $date = RT::DateTime->now( current_user => $current_user );
    $date->set( format => 'ISO', time_zone => 'utc', value => '2005-01-01 15:10:00' );
    is($date->iso( time_zone => 'user' ), '2005-01-01 10:10:00', "ISO");
    is($date->w3cdtf( time_zone => 'user' ), '2005-01-01T10:10:00-05:00', "W3C DTF");
    is($date->rfc2822( time_zone => 'user' ), 'Sat, 1 Jan 2005 10:10:00 -0500', "RFC2822");

    # DST
    $date = RT::DateTime->now( current_user =>  $current_user );
    $date->set( format => 'ISO', time_zone => 'utc', value => '2005-07-01 15:10:00' );
    is($date->iso( time_zone => 'user' ), '2005-07-01 11:10:00', "ISO");
    is($date->w3cdtf( time_zone => 'user' ), '2005-07-01T11:10:00-04:00', "W3C DTF");
    is($date->rfc2822( time_zone => 'user' ), 'Fri, 1 Jul 2005 11:10:00 -0400', "RFC2822");
}

 # bad format
    my $date = RT::DateTime->now(current_user => RT->system_user);
    $date->set( format => 'bad' );
    is($date->epoch, undef, "bad format");


{ # setting value via Unix method
    my $date = RT::DateTime->now(current_user => RT->system_user);
    $date->epoch(1);
    is($date->iso, '1970-01-01 00:00:01', "correct value");

    foreach (undef, 0, ''){
        $date->epoch(1);
        is($date->iso, '1970-01-01 00:00:01', "correct value");

        $date->set(format => 'unix', value => $_);
        is($date->iso, '1970-01-01 00:00:00', "Set a date to midnight 1/1/1970 GMT due to wrong call");
        is($date->epoch, 0, "unix is 0 => unset");
    }
}

my $year = (localtime(time))[5] + 1900;

{ # set+ISO format
    my $date = RT::DateTime->now(current_user => RT->system_user);
    my $return =   $date->set(format => 'ISO', value => 'weird date');
    is ($return, undef, "The set failed. returned undef");
    is($date->epoch, undef, "date was wrong => unix == 0");

    # XXX: ISO format has more feature than we suport
    # http://www.cl.cam.ac.uk/~mgk25/iso-time.html

    $date->set(format => 'ISO', value => '2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $date->set(format => 'ISO', value => '2005-11-28 15:10:00+00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss+00");

    $date->set(format => 'ISO', value => '11-28 15:10:00');
    is($date->iso, $year .'-11-28 15:10:00', "DD-MM hh:mm:ss");

    $date->set(format => 'ISO', value => '11-28 15:10:00+00');
    is($date->iso, $year .'-11-28 15:10:00', "DD-MM hh:mm:ss+00");

    $date->set(format => 'ISO', value => '20051128151000');
    is($date->iso, '2005-11-28 15:10:00', "YYYYDDMMhhmmss");

    $date->set(format => 'ISO', value => '1128151000');
    is($date->iso, $year .'-11-28 15:10:00', "DDMMhhmmss");

    $date->set(format => 'ISO', value => '2005112815:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYYDDMMhh:mm:ss");

    $date->set(format => 'ISO', value => '112815:10:00');
    is($date->iso, $year .'-11-28 15:10:00', "DDMMhh:mm:ss");

    $date->set(format => 'ISO', value => '2005-13-28 15:10:00');
    is($date->epoch, 0, "wrong month value");

    $date->set(format => 'ISO', value => '2005-00-28 15:10:00');
    is($date->epoch, 0, "wrong month value");

    $date->set(format => 'ISO', value => '1960-01-28 15:10:00');
    is($date->epoch, 0, "too old, we don't support");
}

{ # set+datemanip format(time::ParseDate)
    my $date = RT::DateTime->now(current_user => RT->system_user);
    $date->set(format => 'unknown', value => 'weird date');
    is($date->epoch, 0, "date was wrong");

    RT->config->set( TimeZone => 'Europe/Moscow' );
    $date->set(format => 'datemanip', value => '2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");

    RT->config->set( TimeZone => 'UTC' );
    $date->set(format => 'datemanip', value => '2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $current_user->user_object->__set( column => 'time_zone', value => 'Europe/Moscow');
    $date = RT::DateTime->now( current_user => $current_user );
    $date->set(format => 'datemanip', value => '2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");
}

{ # set+unknown format(time::ParseDate)
    my $date = RT::DateTime->now(current_user => RT->system_user);
    $date->set(format => 'unknown', value => 'weird date');
    is($date->epoch, 0, "date was wrong");

    RT->config->set( TimeZone => 'Europe/Moscow' );
    $date->set(format => 'unknown', value => '2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");

    $date->set(format => 'unknown', value => '2005-11-28 15:10:00', time_zone => 'utc' );
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    # relative dates
    $date->set(format => 'unknown', value => 'now');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $date->set(format => 'unknown', value => '1 day ago');
    is($date->iso, '2005-11-27 15:10:00', "YYYY-DD-MM hh:mm:ss");

    RT->config->set( TimeZone => 'UTC' );
    $date->set(format => 'unknown', value => '2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $current_user->user_object->__set( column => 'time_zone', value => 'Europe/Moscow');
    $date = RT::DateTime->now( current_user => $current_user );
    $date->set(format => 'unknown', value => '2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");
    $date->set(format => 'unknown', value => '2005-11-28 15:10:00', time_zone => 'server' );
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");
    $date->set(format => 'unknown', value => '2005-11-28 15:10:00', time_zone => 'utc' );
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");
}

{ # SetToMidnight
    my $date = RT::DateTime->now(current_user => RT->system_user);

    RT->config->set( TimeZone => 'Europe/Moscow' );
    $date->set(format => 'ISO', value => '2005-11-28 15:10:00');
    $date->set_to_midnight;
    is($date->iso, '2005-11-28 00:00:00', "default is utc");
    $date->set(format => 'ISO', value => '2005-11-28 15:10:00');
    $date->set_to_midnight(time_zone => 'utc');
    is($date->iso, '2005-11-28 00:00:00', "utc context");
    $date->set(format => 'ISO', value => '2005-11-28 15:10:00');
    $date->set_to_midnight(time_zone => 'user');
    is($date->iso, '2005-11-27 21:00:00', "user context, user has no preference, fallback to server");
    $date->set(format => 'ISO', value => '2005-11-28 15:10:00');
    $date->set_to_midnight(time_zone => 'server');
    is($date->iso, '2005-11-27 21:00:00', "server context");

    $current_user->user_object->__set( column => 'time_zone', value => 'Europe/Moscow');
    $date = RT::DateTime->now(current_user =>  $current_user );
    $date->set(format => 'ISO', value => '2005-11-28 15:10:00');
    $date->set_to_midnight;
    is($date->iso, '2005-11-28 00:00:00', "default is utc");
    $date->set(format => 'ISO', value => '2005-11-28 15:10:00');
    $date->set_to_midnight(time_zone => 'utc');
    is($date->iso, '2005-11-28 00:00:00', "utc context");
    $date->set(format => 'ISO', value => '2005-11-28 15:10:00');
    $date->set_to_midnight(time_zone => 'user');
    is($date->iso, '2005-11-27 21:00:00', "user context");
    $date->set_to_midnight(time_zone => 'server');
    is($date->iso, '2005-11-27 21:00:00', "server context");

    RT->config->set( TimeZone => 'UTC' );
}

{ # set_to_now
    my $date = RT::DateTime->now(current_user => RT->system_user);
    my $time = time;
    $date->set_to_now;
    ok($date->epoch >= $time, 'close enough');
    ok($date->epoch < $time+5, 'difference is less than five seconds');
}

{
    my $date = RT::DateTime->now(current_user => RT->system_user);
    
    $date->epoch(0);
    $date->add_seconds;
    is($date->iso, '1970-01-01 00:00:00', "nothing changed");
    $date->add_seconds(0);
    is($date->iso, '1970-01-01 00:00:00', "nothing changed");
    
    $date->epoch(0);
    $date->add_seconds(5);
    is($date->iso, '1970-01-01 00:00:05', "added five seconds");
    $date->add_seconds(-2);
    is($date->iso, '1970-01-01 00:00:03', "substracted two seconds");
    
    $date->epoch(0);
    $date->add_seconds(3661);
    is($date->iso, '1970-01-01 01:01:01', "added one hour, minute and a second");

# XXX: TODO, doesn't work with Test::Warn
#    TODO: {
#        local $TODO = "BUG or subject to change Date handling to support unix time <= 0";
#        $date->epoch(0);
#        $date->add_seconds(-2);
#        ok($date->epoch > 0);
#    }

    $date->epoch(0);
    $date->add_day;
    is($date->iso, '1970-01-02 00:00:00', "added one day");
    $date->add_days(2);
    is($date->iso, '1970-01-04 00:00:00', "added two days");
    $date->add_days(-1);
    is($date->iso, '1970-01-03 00:00:00', "substructed one day");
    
    $date->epoch(0);
    $date->add_days(31);
    is($date->iso, '1970-02-01 00:00:00', "added one month");
}

{
    $current_user->user_object->__set( column => 'time_zone', value => '');
    my $date = RT::DateTime->now(current_user =>  $current_user );
    is($date->as_string, "Not set", "as_string returns 'Not set'");

    RT->config->set( DateTimeFormat => '');
    $date->epoch(1);
    is($date->as_string, 'Thu Jan 01 00:00:01 1970', "correct string");
    is($date->as_string(date => 0), '00:00:01', "correct string");
    is($date->as_string(time => 0), 'Thu Jan 01 1970', "correct string");
    is($date->as_string(date => 0, time => 0), 'Thu Jan 01 00:00:01 1970', "invalid input");

    RT->config->set( DateTimeFormat => 'RFC2822' );
    $date->epoch(1);
    is($date->as_string, 'Thu, 1 Jan 1970 00:00:01 +0000', "correct string");

    RT->config->set( DateTimeFormat => { format => 'RFC2822', seconds => 0 } );
    $date->epoch(1);
    is($date->as_string, 'Thu, 1 Jan 1970 00:00 +0000', "correct string");
    is($date->as_string(seconds => 1), 'Thu, 1 Jan 1970 00:00:01 +0000', "correct string");
}

{ # DurationAsString
    my $date = RT::DateTime->now(current_user => RT->system_user);

    is($date->duration_as_string(1), '1 sec', '1 sec');
    is($date->duration_as_string(59), '59 sec', '59 sec');
    is($date->duration_as_string(60), '1 min', '1 min');
    is($date->duration_as_string(60*119), '119 min', '119 min');
    is($date->duration_as_string(60*60*2-1), '120 min', '120 min');
    is($date->duration_as_string(60*60*2), '2 hours', '2 hours');
    is($date->duration_as_string(60*60*48-1), '48 hours', '48 hours');
    is($date->duration_as_string(60*60*48), '2 days', '2 days');
    is($date->duration_as_string(60*60*24*14-1), '14 days', '14 days');
    is($date->duration_as_string(60*60*24*14), '2 weeks', '2 weeks');
    is($date->duration_as_string(60*60*24*7*8-1), '8 weeks', '8 weeks');
    is($date->duration_as_string(60*60*24*61), '2 months', '2 months');
    is($date->duration_as_string(60*60*24*365-1), '12 months', '12 months');
    is($date->duration_as_string(60*60*24*366), '1 years', '1 years');

    is($date->duration_as_string(-1), '1 sec ago', '1 sec ago');
}

{ # DiffAsString
    my $date = RT::DateTime->now(current_user => RT->system_user);
    is($date->diff_as_string(1), '', 'no diff, wrong input');
    is($date->diff_as_string(-1), '', 'no diff, wrong input');
    is($date->diff_as_string('qwe'), '', 'no diff, wrong input');

    $date->epoch(2);
    is($date->diff_as_string(-1), '', 'no diff, wrong input');

    is($date->diff_as_string(3), '1 sec ago', 'diff: 1 sec ago');
    is($date->diff_as_string(1), '1 sec', 'diff: 1 sec');

    my $ndate = RT::DateTime->now(current_user => RT->system_user);
    is($date->diff_as_string($ndate), '', 'no diff, wrong input');
    $ndate->epoch(3);
    is($date->diff_as_string($ndate), '1 sec ago', 'diff: 1 sec ago');
}

{ # Diff
    my $date = RT::DateTime->now(current_user => RT->system_user);
    $date->set_to_now;
    my $diff = $date->diff;
    ok($diff <= 0, 'close enought');
    ok($diff > -5, 'close enought');
}

{ # AgeAsString
    my $date = RT::DateTime->now(current_user => RT->system_user);
    $date->set_to_now;
    my $diff = $date->age;
    like($diff, qr/^(0 sec|[1-5] sec ago)$/, 'close enought');
}

{ # GetWeekday
    my $date = RT::DateTime->now(current_user => RT->system_user);
    is($date->get_weekday(7),  '',    '7 and greater are invalid');
    is($date->get_weekday(6),  'Sat', '6 is Saturday');
    is($date->get_weekday(0),  'Sun', '0 is Sunday');
    is($date->get_weekday(-1), 'Sat', '-1 is Saturday');
    is($date->get_weekday(-7), 'Sun', '-7 is Sunday');
    is($date->get_weekday(-8), '',    '-8 and lesser are invalid');
}

{ # GetMonth
    my $date = RT::DateTime->now(current_user => RT->system_user);
    is($date->get_month(12),  '',     '12 and greater are invalid');
    is($date->get_month(11),  'Dec', '11 is December');
    is($date->get_month(0),   'Jan', '0 is January');
    is($date->get_month(-1),  'Dec', '11 is December');
    is($date->get_month(-12), 'Jan', '0 is January');
    is($date->get_month(-13),  '',    '-13 and lesser are invalid');
}

#TODO: AsString
#TODO: RFC2822, W3CDTF with time zones

exit(0);

