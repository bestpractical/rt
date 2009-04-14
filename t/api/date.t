#!/usr/bin/perl

use warnings; use strict;
use Test::MockTime qw(set_fixed_time restore_time);
use RT::Test;

use Test::More tests => 94;

use RT::Model::User;
use Test::Warn;
use POSIX;
my $time_zone = strftime("%Z", localtime());

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
    Jifty->web->current_user($current_user);
}

{
    my $date = RT::DateTime->now;
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
    is($date->iso, '2005-11-28 15:10:00', "default is ISO format");
    ok(!$date->is_unset, "date is set");
    is($date->rfc2822,
       'Mon, 28 Nov 2005 15:10:00 +0000',
       "RFC2822 format with defaults");
}


{ # positive time zone
    $current_user->user_object->__set( column => 'time_zone', value => 'Europe/Moscow');
    my $date = RT::DateTime->new_from_string('2005-01-01 15:10:00');
    is($date->iso, '2005-01-01 15:10:00', "user timezone");
    is($date->iso(time_zone => 'system'), '2005-01-01 12:10:00', "system timezone");
    is($date->rfc2822( time_zone => 'user' ), 'Sat, 01 Jan 2005 15:10:00 +0300', "RFC2822 in user time zone");
    is($date->rfc2822( time_zone => 'server' ), 'Sat, 01 Jan 2005 12:10:00 +0000', "RFC2822 in server time zone");

    # DST
    $date = RT::DateTime->new_from_string('2005-07-01 15:10:00', time_zone => 'UTC');
    is($date->iso( time_zone => 'user' ), '2005-07-01 19:10:00', "ISO");
    is($date->rfc2822( time_zone => 'user' ), 'Fri, 01 Jul 2005 19:10:00 +0400', "RFC2822");

    is($date->iso( time_zone => 'server' ), '2005-07-01 15:10:00', "ISO");
    is($date->rfc2822( time_zone => 'server' ), 'Fri, 01 Jul 2005 15:10:00 +0000', "RFC2822");
}

{ # negative time zone
    $current_user->user_object->__set( column => 'time_zone', value => 'America/New_York');
    my $date = RT::DateTime->new_from_string('2005-01-01 15:10:00', time_zone => 'UTC');
    is($date->iso( time_zone => 'user' ), '2005-01-01 10:10:00', "ISO");
    is($date->rfc2822( time_zone => 'user' ), 'Sat, 01 Jan 2005 10:10:00 -0500', "RFC2822");

    # DST
    $date = RT::DateTime->new_from_string('2005-07-01 15:10:00', time_zone => 'UTC' );
    is($date->iso( time_zone => 'user' ), '2005-07-01 11:10:00', "ISO");
    is($date->rfc2822( time_zone => 'user' ), 'Fri, 01 Jul 2005 11:10:00 -0400', "RFC2822");
}

{ # setting value via from_epoch method
    my $date = RT::DateTime->from_epoch(epoch => 1, time_zone => 'UTC');
    is($date->time_zone->name, 'UTC', "time_zone set correctly");
    ok(!$date->is_unset, "date is set");
    is($date->iso, '1970-01-01 00:00:01', "correct value");

    $date = RT::DateTime->from_epoch(epoch => 1);
    is($date->time_zone->name, 'America/New_York', "time_zone defaults to user's");
    ok(!$date->is_unset, "date is set");
    is($date->iso, '1969-12-31 19:00:01', "correct value");
}

{ # set+ISO format
    my $date = RT::DateTime->new_from_string('weird date');
    isa_ok($date, 'RT::DateTime');
    is($date, 'unset', "unparseable date returns an 'unset' RT::DateTime");
    ok($date->is_unset, "unparseable date is_unset");

    $date = RT::DateTime->new_from_string('2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    TODO: {
        local $TODO = "YYYY-DD-MM hh:mm:ss+00 not handled yet";
        $date = RT::DateTime->new_from_string('2005-11-28 15:10:00+00');
        is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss+00");
    };

    TODO: {
        local $TODO = "DD-MM hh:mm:ss not handled yet";
        $date = RT::DateTime->new_from_string('11-28 15:10:00');
        is($date->iso, '2005-11-28 15:10:00', "DD-MM hh:mm:ss");
    };

    TODO: {
        local $TODO = "DD-MM hh:mm:ss+00 not handled yet";
        $date = RT::DateTime->new_from_string('11-28 15:10:00+00');
        is($date->iso, '2005-11-28 15:10:00', "DD-MM hh:mm:ss+00");
    };

    $date = RT::DateTime->new_from_string('20051128151000');
    is($date->iso, '2005-11-28 15:10:00', "YYYYDDMMhhmmss");

    TODO: {
        local $TODO = "DDMMhhmmss not handled yet";
        $date = RT::DateTime->new_from_string('1128151000');
        is($date->iso, '2005-11-28 15:10:00', "DDMMhhmmss");
    };

    $date = RT::DateTime->new_from_string('2005112815:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYYDDMMhh:mm:ss");

    TODO: {
        local $TODO = "DDMMhh:mm:ss not handled yet";
        $date = RT::DateTime->new_from_string('112815:10:00');
        is($date->iso, '2005-11-28 15:10:00', "DDMMhh:mm:ss");
    };

    $date = RT::DateTime->new_from_string('2005-13-28 15:10:00');
    ok($date->is_unset, "wrong month value");

    $date = RT::DateTime->new_from_string('2005-00-28 15:10:00');
    ok($date->is_unset, "wrong month value");

    $date = RT::DateTime->new_from_string('1960-01-28 15:10:00');
    is($date->iso, '1960-01-28 15:10:00', "we can support pre-1970s dates now");
}

{ # set+datemanip format(time::ParseDate)
    RT->config->set( TimeZone => 'Europe/Moscow' );
    my $date = RT::DateTime->new_from_string('2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");
    is($date->iso(time_zone => 'server'), '2005-11-28 23:10:00', "YYYY-DD-MM hh:mm:ss");

    RT->config->set( TimeZone => 'UTC' );
    $date = RT::DateTime->new_from_string('2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");
    is($date->iso(time_zone => 'server'), '2005-11-28 20:10:00', "YYYY-DD-MM hh:mm:ss");

    $current_user->user_object->__set( column => 'time_zone', value => 'Europe/Moscow');
    $date = RT::DateTime->new_from_string('2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");
    is($date->iso(time_zone => 'server'), '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");
}

{
    RT->config->set( TimeZone => 'Europe/Moscow' );
    my $date = RT::DateTime->new_from_string('2005-11-28 15:10:00');
    is($date->time_zone->name, 'Europe/Moscow');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $date = RT::DateTime->new_from_string('2005-11-28 15:10:00', time_zone => 'UTC' );
    is($date->iso, '2005-11-28 18:10:00', "YYYY-DD-MM hh:mm:ss");

  SKIP: {
        skip 'current timezone is not EDT', 2 unless $time_zone eq 'EDT';

        # relative dates
        $date = RT::DateTime->new_from_string('now');
        is( $date->iso, '2005-11-28 10:10:00', "YYYY-DD-MM hh:mm:ss" );

        $date = RT::DateTime->new_from_string('1 day ago');
        is( $date->iso, '2005-11-27 13:10:00', "YYYY-DD-MM hh:mm:ss" );
    }

    RT->config->set( TimeZone => 'UTC' );
    $date = RT::DateTime->new_from_string('2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $current_user->user_object->__set( column => 'time_zone', value => 'Europe/Moscow');
    $date = RT::DateTime->new_from_string('2005-11-28 15:10:00');
    is($date->iso, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");
    $date = RT::DateTime->new_from_string('2005-11-28 15:10:00', time_zone => 'server' );
    is($date->iso, '2005-11-28 18:10:00', "YYYY-DD-MM hh:mm:ss");
    $date = RT::DateTime->new_from_string('2005-11-28 15:10:00', time_zone => 'UTC' );
    is($date->iso, '2005-11-28 18:10:00', "YYYY-DD-MM hh:mm:ss");
}

{ # stringification
    $current_user->user_object->__set( column => 'time_zone', value => '');
    my $date = RT::DateTime->from_epoch(epoch => 0);
    is($date, "unset", "epoch 0 returns 'unset'");

    RT->config->set( DateTimeFormat => '%a %b %d %H:%M:%S %Y');
    $date = RT::DateTime->from_epoch(epoch => 1);
    is($date, 'Thu Jan 01 00:00:01 1970', "correct string");

    RT->config->set( DateTimeFormat => '%a, %d %b %Y %H:%M:%S %z' );
    is($date, 'Thu, 01 Jan 1970 00:00:01 +0000', "correct string");

    RT->config->set( DateTimeFormat => '%a, %d %b %Y %H:%M %z' );
    is($date, 'Thu, 01 Jan 1970 00:00 +0000', "correct string");
}

{ # RT::DateTime::Duration

    is(RT::DateTime::Duration->new(seconds => 1), '1 sec', '1 sec');
    is(RT::DateTime::Duration->new(seconds => 59), '59 sec', '59 sec');

    TODO: {
        local $TODO = "DateTime::Duration doesn't convert between units that are not constant factors of another";
        is(RT::DateTime::Duration->new(seconds => 60), '1 min', '1 min');
        is(RT::DateTime::Duration->new(seconds => 60*119), '119 min', '119 min');
        is(RT::DateTime::Duration->new(seconds => 60*60*2-1), '120 min', '120 min');
        is(RT::DateTime::Duration->new(seconds => 60*60*2), '2 hours', '2 hours');
        is(RT::DateTime::Duration->new(seconds => 60*60*2), '2 hours', '2 hours');
        is(RT::DateTime::Duration->new(seconds => 60*60*48-1), '48 hours', '48 hours');
        is(RT::DateTime::Duration->new(seconds => 60*60*48), '2 days', '2 days');
        is(RT::DateTime::Duration->new(seconds => 60*60*24*14-1), '14 days', '14 days');
        is(RT::DateTime::Duration->new(seconds => 60*60*24*14), '2 weeks', '2 weeks');
        is(RT::DateTime::Duration->new(seconds => 60*60*24*7*8-1), '8 weeks', '8 weeks');
        is(RT::DateTime::Duration->new(seconds => 60*60*24*61), '2 months', '2 months');
        is(RT::DateTime::Duration->new(seconds => 60*60*24*365-1), '12 months', '12 months');
        is(RT::DateTime::Duration->new(seconds => 60*60*24*366), '1 years', '1 years');

        is(RT::DateTime::Duration->new(seconds => -1), '1 sec ago', '1 sec ago');
    }
}

{ # difference
    my $date = RT::DateTime->now;
    my $duration = RT::DateTime->now - $date;
    like($duration, qr/^\d+ sec$/, 'close enough');
}

{ # age
    my $date = RT::DateTime->now(current_user => RT->system_user);
    my $diff = $date->age;
    like($diff, qr/^(0 sec|[1-5] sec ago)$/, 'close enough');
}

#TODO: AsString
#TODO: RFC2822 with time zones

exit(0);

