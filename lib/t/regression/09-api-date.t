#!/usr/bin/perl

use Test::More qw/no_plan/;
#use Test::More tests => 25;

use warnings; use strict;
use RT;
RT::LoadConfig();
RT::Init();

use RT::User;

use_ok('RT::Date', "loaded RT::Date");
{
    my $date = RT::Date->new($RT::SystemUser);
    isa_ok($date, 'RT::Date', "constructor returned RT::Date oject");
}

{
    # set timezone in all places to UTC
    $RT::SystemUser->UserObj->__Set(Field => 'Timezone', Value => 'UTC')
                                if $RT::SystemUser->UserObj->Timezone;
    $RT::Timezone = 'UTC';
}

{
    my $user = RT::User->new($RT::SystemUser);
    my($uid, $msg) = $user->Create( Name => "date_api" . rand(200),
                                   Privileged => 1,
                                 );
    ok($uid, "user was created") or diag("error: $msg");
    my $current_user = new RT::CurrentUser($user);

    my $date = RT::Date->new($current_user);
    is($date->Timezone, 'UTC', "dropped all timzones to UTC");
    is($date->Timezone('user'), 'UTC', "dropped all timzones to UTC");
    is($date->Timezone('server'), 'UTC', "dropped all timzones to UTC");

    is($date->Timezone('unknown'), 'UTC', "with wrong context returns UTC");

    $current_user->UserObj->__Set( Field => 'Timezone', Value => 'Europe/Moscow');
    is($current_user->UserObj->Timezone,
       'Europe/Moscow',
       "successfuly changed user's timezone");
    is($date->Timezone('user'),
       'Europe/Moscow',
       "in user context returns user's timezone");
    is($date->Timezone, 'UTC', "the deafult value is always UTC");
    is($date->Timezone('server'), 'UTC', "wasn't changed");

    $RT::Timezone = 'Africa/Ouagadougou';
    is($date->Timezone('server'),
       'Africa/Ouagadougou',
       "timezone of the RT server was changed");
    is($date->Timezone('user'),
       'Europe/Moscow',
       "in user context still returns user's timezone");
    is($date->Timezone, 'UTC', "the deafult value is always UTC");
    
    $current_user->UserObj->__Set( Field => 'Timezone', Value => '');
    is($current_user->UserObj->Timezone,
       '',
       "successfuly changed user's timezone");
    is($date->Timezone('user'),
       'Africa/Ouagadougou',
       "in user context returns timezone of the server if user's one is not defined");
    is($date->Timezone, 'UTC', "the deafult value is always UTC");

    $RT::Timezone = '';
    is($date->Timezone, 'UTC', "dropped all timzones to UTC");
    is($date->Timezone('user'),
       'UTC',
       "user's and server's timzones are not defined, so UTC");
    is($date->Timezone('server'),
       'UTC',
       "timezone of the server is not defined so UTC");

    $RT::Timezone = 'UTC';
}

{
    my $date = RT::Date->new($RT::SystemUser);
    is($date->Unix, 0, "new date returns 0 in Unix format");
    is($date->Get, '1970-01-01 00:00:00', "default is ISO format");
    is($date->Get(Format =>'SomeBadFormat'),
       '1970-01-01 00:00:00',
       "don't know format, return ISO format");
    is($date->Get(Format =>'W3CDTF'),
       '1970-01-01T00:00:00Z',
       "W3CDTF format with defaults");
    is($date->Get(Format =>'RFC2822'),
       'Thu, 1 Jan 1970 00:00:00 +0000',
       "RFC2822 format with defaults");

    is($date->ISO(Time => 0),
       '1970-01-01',
       "ISO format without time part");
    is($date->W3CDTF(Time => 0),
       '1970-01-01',
       "W3CDTF format without time part");
    is($date->RFC2822(Time => 0),
       'Thu, 1 Jan 1970',
       "RFC2822 format without time part");

    is($date->ISO(Date => 0),
       '00:00:00',
       "ISO format without date part");
    is($date->W3CDTF(Date => 0),
       '00:00:00Z',
       "W3CDTF format without date part");
    is($date->RFC2822(Date => 0),
       '00:00:00 +0000',
       "RFC2822 format without date part");

    is($date->ISO(Date => 0, Seconds => 0),
       '00:00',
       "ISO format without date part and seconds");
    is($date->W3CDTF(Date => 0, Seconds => 0),
       '00:00Z',
       "W3CDTF format without date part and seconds");
    is($date->RFC2822(Date => 0, Seconds => 0),
       '00:00 +0000',
       "RFC2822 format without date part and seconds");

    is($date->RFC2822(DayOfWeek => 0),
       '1 Jan 1970 00:00:00 +0000',
       "RFC2822 format without 'day of week' part");
    is($date->RFC2822(DayOfWeek => 0, Date => 0),
       '00:00:00 +0000',
       "RFC2822 format without 'day of week' and date parts(corner case test)");

    is($date->Date,
       '1970-01-01',
       "the default format for the 'Date' method is ISO");
    is($date->Date(Format => 'W3CDTF'),
       '1970-01-01',
       "'Date' method, W3CDTF format");
    is($date->Date(Format => 'RFC2822'),
       'Thu, 1 Jan 1970',
       "'Date' method, RFC2822 format");
    is($date->Date(Time => 1),
       '1970-01-01',
       "'Date' method doesn't pass through 'Time' argument");
    is($date->Date(Date => 0),
       '1970-01-01',
       "'Date' method overrides 'Date' argument");

    is($date->Time,
       '00:00:00',
       "the default format for the 'Time' method is ISO");
    is($date->Time(Format => 'W3CDTF'),
       '00:00:00Z',
       "'Time' method, W3CDTF format");
    is($date->Time(Format => 'RFC2822'),
       '00:00:00 +0000',
       "'Time' method, RFC2822 format");
    is($date->Time(Date => 1),
       '00:00:00',
       "'Time' method doesn't pass through 'Date' argument");
    is($date->Time(Time => 0),
       '00:00:00',
       "'Time' method overrides 'Time' argument");

    is($date->DateTime,
       '1970-01-01 00:00:00',
       "the default format for the 'DateTime' method is ISO");
    is($date->DateTime(Format =>'W3CDTF'),
       '1970-01-01T00:00:00Z',
       "'DateTime' method, W3CDTF format");
    is($date->DateTime(Format =>'RFC2822'),
       'Thu, 1 Jan 1970 00:00:00 +0000',
       "'DateTime' method, RFC2822 format");
    is($date->DateTime(Date => 0, Time => 0),
       '1970-01-01 00:00:00',
       "the 'DateTime' method overrides both 'Date' and 'Time' arguments");
}

{
    # setting value via Unix method
    my $date = RT::Date->new($RT::SystemUser);
    $date->Unix(1);
    is($date->ISO, '1970-01-01 00:00:01', "set value new value");

    # TODO: other Set* methods
}

{
    my $date = RT::Date->new($RT::SystemUser);
    
    $date->Unix(0);
    $date->AddSeconds;
    is($date->ISO, '1970-01-01 00:00:00', "nothing changed");
    $date->AddSeconds(0);
    is($date->ISO, '1970-01-01 00:00:00', "nothing changed");
    
    $date->Unix(0);
    $date->AddSeconds(5);
    is($date->ISO, '1970-01-01 00:00:05', "added five seconds");
    $date->AddSeconds(-2);
    is($date->ISO, '1970-01-01 00:00:03', "substracted two seconds");
    
    $date->Unix(0);
    $date->AddSeconds(3661);
    is($date->ISO, '1970-01-01 01:01:01', "added one hour, minute and a second");

    TODO: {
        local $TODO = "BUG or subject to change Date handling to support unix time <= 0";
        $date->Unix(0);
        $date->AddSeconds(-2);
        ok($date->Unix > 0);
    }

    $date->Unix(0);
    $date->AddDay;
    is($date->ISO, '1970-01-02 00:00:00', "added one day");
    $date->AddDays(2);
    is($date->ISO, '1970-01-04 00:00:00', "added two days");
    $date->AddDays(-1);
    is($date->ISO, '1970-01-03 00:00:00', "substructed one day");
    
    $date->Unix(0);
    $date->AddDays(31);
    is($date->ISO, '1970-02-01 00:00:00', "added one month");
}

{
    my $date = RT::Date->new($RT::SystemUser);

    my $unix = 1129084200; # 2005-10-12 02:30:00 UTC
    my $iso  = "2005-10-12 02:30:00";
    $date->Unix($unix);
    is($date->ISO, $iso, "correct date and time");

    $date->SetToMidnight;
    is($date->ISO, '2005-10-12 00:00:00', "correct midnight date and time");
    TODO: {
        local $TODO = "'SetToMidnight' method should support 'Timezone' argumnet";
        my $user = RT::User->new($RT::SystemUser);
        my($uid, $msg) = $user->Create( Name => "date_api" . rand(200),
                                        Timezone => 'Europe/Moscow',
                                        Privileged => 1,
                                      );
        ok($uid, "user was created") or diag("error: $msg");
        my $current_user = new RT::CurrentUser($user);
        is($current_user->UserObj->Timezone,
           'Europe/Moscow',
           "user has own timezone");
        
        my $date = RT::Date->new($current_user);

        $date->Unix($unix);
        is($date->ISO, $iso, "correct date and time");

        $date->SetToMidnight( Timezone => 'user' );
        is($date->ISO, '2005-10-11 20:00:00', "correct midnight date and time");
    }
}

{
    my $user = RT::User->new($RT::SystemUser);
    my($uid, $msg) = $user->Create( Name => "date_api" . rand(200),
                                    Lang => 'en',
                                    Privileged => 1,
                                  );
    ok($uid, "user was created") or diag("error: $msg");
    my $current_user = new RT::CurrentUser($user);

    my $date = RT::Date->new($current_user);
    is($date->AsString, "Not set", "AsString returns 'Not set'");

    $RT::DateTimeFormat = '';
    $date->Unix(1);
    is($date->AsString, 'Thu Jan 01 00:00:01 1970', "correct string");
    is($date->AsString(Date => 0), '00:00:01', "correct string");
    is($date->AsString(Time => 0), 'Thu Jan 01 1970', "correct string");
    
    $RT::DateTimeFormat = 'RFC2822';
    $date->Unix(1);
    is($date->AsString, 'Thu, 1 Jan 1970 00:00:01 +0000', "correct string");

    $RT::DateTimeFormat = { Format => 'RFC2822', Seconds => 0 };
    $date->Unix(1);
    is($date->AsString, 'Thu, 1 Jan 1970 00:00 +0000', "correct string");
    is($date->AsString(Seconds => 1), 'Thu, 1 Jan 1970 00:00:01 +0000', "correct string");
}

#TODO: Set
#TODO: SetToNow
#TODO: Diff
#TODO: DiffAsString
#TODO: DurationAsString
#TODO: AgeAsString
#TODO: AsString
#TODO: GetWeekday
#TODO: GetMonth
#TODO: RFC2822 with Timezones

exit(0);

