
use Test::MockTime qw(set_fixed_time restore_time);
use DateTime;

use warnings;
use strict;
use RT::Test tests => undef;
use RT::User;
use Test::Warn;

use_ok('RT::Date');
{
    my $date = RT::Date->new(RT->SystemUser);
    isa_ok($date, 'RT::Date', "constructor returned RT::Date oject");
    $date = $date->new(RT->SystemUser);
    isa_ok($date, 'RT::Date', "constructor returned RT::Date oject");
}

{
    # set timezone in all places to UTC
    RT->SystemUser->UserObj->__Set(Field => 'Timezone', Value => 'UTC')
                                if RT->SystemUser->UserObj->Timezone;
    RT->Config->Set( Timezone => 'UTC' );
}

my $current_user;
{
    my $user = RT::User->new(RT->SystemUser);
    my($uid, $msg) = $user->Create(
        Name       => "date_api". rand(200),
        Lang       => 'en',
        Privileged => 1,
    );
    ok($uid, "user was created") or diag("error: $msg");
    $current_user = RT::CurrentUser->new($user);
}

{
    my $date = RT::Date->new( $current_user );
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
    is($date->Timezone('server'), 'UTC', "wasn't changed");

    RT->Config->Set( Timezone => 'Africa/Ouagadougou' );
    is($date->Timezone('server'),
       'Africa/Ouagadougou',
       "timezone of the RT server was changed");
    is($date->Timezone('user'),
       'Europe/Moscow',
       "in user context still returns user's timezone");

    $current_user->UserObj->__Set( Field => 'Timezone', Value => '');
    is_empty($current_user->UserObj->Timezone,
       "successfuly changed user's timezone");
    is($date->Timezone('user'),
       'Africa/Ouagadougou',
       "in user context returns timezone of the server if user's one is not defined");

    RT->Config->Set( Timezone => 'GMT' );
    is($date->Timezone('server'),
       'UTC',
       "timezone is GMT which one is alias for UTC");

    RT->Config->Set( Timezone => '' );
    is($date->Timezone('user'),
       'UTC',
       "user's and server's timzones are not defined, so UTC");
    is($date->Timezone('server'),
       'UTC',
       "timezone of the server is not defined so UTC");

    RT->Config->Set( Timezone => 'UTC' );
}

{
    my $date = RT::Date->new(RT->SystemUser);
    is($date->IsSet,0, "new date isn't set");
    is($date->Unix, 0, "new date returns 0 in Unix format");
    is($date->Get, '1970-01-01 00:00:00', "default is ISO format");
    warning_like {
        is($date->Get(Format =>'SomeBadFormat'),
           '1970-01-01 00:00:00',
           "don't know format, return ISO format");
    } qr/Invalid date formatter/;
    is($date->Get(Format =>'W3CDTF'),
       '1970-01-01T00:00:00Z',
       "W3CDTF format with defaults");
    is($date->Get(Format =>'RFC2822'),
       'Thu, 01 Jan 1970 00:00:00 +0000',
       "RFC2822 format with defaults");
    is($date->Get(Format =>'LocalizedDateTime'),
       'Thu, Jan 1, 1970 12:00:00 AM',
       "LocalizedDateTime format with defaults");

    is($date->ISO(Time => 0),
       '1970-01-01',
       "ISO format without time part");
    is($date->W3CDTF(Time => 0),
       '1970-01-01',
       "W3CDTF format without time part");
    is($date->RFC2822(Time => 0),
       'Thu, 01 Jan 1970',
       "RFC2822 format without time part");
    is($date->LocalizedDateTime(Time => 0),
       'Thu, Jan 1, 1970',
       "LocalizedDateTime format without time part");

    is($date->ISO(Date => 0),
       '00:00:00',
       "ISO format without date part");
    is($date->W3CDTF(Date => 0),
       '1970-01-01T00:00:00Z',
       "W3CDTF format is incorrect without date part");
    is($date->RFC2822(Date => 0),
       '00:00:00 +0000',
       "RFC2822 format without date part");
    is($date->LocalizedDateTime(Date => 0),
       '12:00:00 AM',
       "LocalizedDateTime format without date part");

    is($date->ISO(Date => 0, Seconds => 0),
       '00:00',
       "ISO format without date part and seconds");
    is($date->W3CDTF(Date => 0, Seconds => 0),
       '1970-01-01T00:00Z',
       "W3CDTF format without seconds, but we ship date part even if Date is false");
    is($date->RFC2822(Date => 0, Seconds => 0),
       '00:00 +0000',
       "RFC2822 format without date part and seconds");

    is($date->RFC2822(DayOfWeek => 0),
       '01 Jan 1970 00:00:00 +0000',
       "RFC2822 format without 'day of week' part");
    is($date->RFC2822(DayOfWeek => 0, Date => 0),
       '00:00:00 +0000',
       "RFC2822 format without 'day of week' and date parts(corner case test)");

    is($date->LocalizedDateTime(AbbrDay => 0),
       'Thursday, Jan 1, 1970 12:00:00 AM',
       "LocalizedDateTime format without abbreviation of day");
    is($date->LocalizedDateTime(AbbrMonth => 0),
       'Thu, January 1, 1970 12:00:00 AM',
       "LocalizedDateTime format without abbreviation of month");
    is($date->LocalizedDateTime(DateFormat => 'date_format_short'),
       '1/1/70 12:00:00 AM',
       "LocalizedDateTime format with non default DateFormat");
    is($date->LocalizedDateTime(TimeFormat => 'time_format_short'),
       'Thu, Jan 1, 1970 12:00 AM',
       "LocalizedDateTime format with non default TimeFormat");

    is($date->Date,
       '1970-01-01',
       "the default format for the 'Date' method is ISO");
    is($date->Date(Format => 'W3CDTF'),
       '1970-01-01',
       "'Date' method, W3CDTF format");
    is($date->Date(Format => 'RFC2822'),
       'Thu, 01 Jan 1970',
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
       '1970-01-01T00:00:00Z',
       "'Time' method, W3CDTF format, date part is required by w3c doc");
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
       'Thu, 01 Jan 1970 00:00:00 +0000',
       "'DateTime' method, RFC2822 format");
    is($date->DateTime(Date => 0, Time => 0),
       '1970-01-01 00:00:00',
       "the 'DateTime' method overrides both 'Date' and 'Time' arguments");
}


{ # positive timezone
    $current_user->UserObj->__Set( Field => 'Timezone', Value => 'Europe/Moscow');
    my $date = RT::Date->new( $current_user );
    $date->Set( Format => 'ISO', Timezone => 'utc', Value => '2005-01-01 15:10:00' );
    is($date->IsSet,1,"Date has been set");
    is($date->ISO( Timezone => 'user' ), '2005-01-01 18:10:00', "ISO");
    is($date->W3CDTF( Timezone => 'user' ), '2005-01-01T18:10:00+03:00', "W3C DTF");
    is($date->RFC2822( Timezone => 'user' ), 'Sat, 01 Jan 2005 18:10:00 +0300', "RFC2822");
    is($date->LocalizedDateTime( Timezone => 'user' ), 'Sat, Jan 1, 2005 6:10:00 PM', "LocalizedDateTime");

    # DST
    $date = RT::Date->new( $current_user );
    $date->Set( Format => 'ISO', Timezone => 'utc', Value => '2005-07-01 15:10:00' );
    is($date->ISO( Timezone => 'user' ), '2005-07-01 19:10:00', "ISO");
    is($date->W3CDTF( Timezone => 'user' ), '2005-07-01T19:10:00+04:00', "W3C DTF");
    is($date->RFC2822( Timezone => 'user' ), 'Fri, 01 Jul 2005 19:10:00 +0400', "RFC2822");
    is($date->LocalizedDateTime( Timezone => 'user' ), 'Fri, Jul 1, 2005 7:10:00 PM', "LocalizedDateTime");
}

{ # negative timezone
    $current_user->UserObj->__Set( Field => 'Timezone', Value => 'America/New_York');
    my $date = RT::Date->new( $current_user );
    $date->Set( Format => 'ISO', Timezone => 'utc', Value => '2005-01-01 15:10:00' );
    is($date->ISO( Timezone => 'user' ), '2005-01-01 10:10:00', "ISO");
    is($date->W3CDTF( Timezone => 'user' ), '2005-01-01T10:10:00-05:00', "W3C DTF");
    is($date->RFC2822( Timezone => 'user' ), 'Sat, 01 Jan 2005 10:10:00 -0500', "RFC2822");
    is($date->LocalizedDateTime( Timezone => 'user' ), 'Sat, Jan 1, 2005 10:10:00 AM', "LocalizedDateTime");

    # DST
    $date = RT::Date->new( $current_user );
    $date->Set( Format => 'ISO', Timezone => 'utc', Value => '2005-07-01 15:10:00' );
    is($date->ISO( Timezone => 'user' ), '2005-07-01 11:10:00', "ISO");
    is($date->W3CDTF( Timezone => 'user' ), '2005-07-01T11:10:00-04:00', "W3C DTF");
    is($date->RFC2822( Timezone => 'user' ), 'Fri, 01 Jul 2005 11:10:00 -0400', "RFC2822");
    is($date->LocalizedDateTime( Timezone => 'user' ), 'Fri, Jul 1, 2005 11:10:00 AM', "LocalizedDateTime");
}

warning_like
{ # bad format
    my $date = RT::Date->new(RT->SystemUser);
    $date->Set( Format => 'bad' );
    ok(!$date->IsSet, "bad format");
} qr{Unknown Date format: bad};


{ # setting value via Unix method
    my $date = RT::Date->new(RT->SystemUser);
    $date->Unix(1);
    is($date->ISO, '1970-01-01 00:00:01', "correct value");

    foreach (undef, 0, '', -5){
        $date->Unix(1);
        is($date->ISO, '1970-01-01 00:00:01', "correct value");
        is($date->IsSet,1,"Date has been set to a value");

        $date->Set(Format => 'unix', Value => $_);
        is($date->ISO, '1970-01-01 00:00:00', "Set a date to midnight 1/1/1970 GMT due to wrong call");
        is($date->Unix, 0, "unix is 0 => unset");
        is($date->IsSet,0,"Date has been unset");
    }

    foreach (undef, 0, '', -5){
        $date->Unix(1);
        is($date->ISO, '1970-01-01 00:00:01', "correct value");
        is($date->IsSet,1,"Date has been set to a value");

        $date->Unix($_);
        is($date->ISO, '1970-01-01 00:00:00', "Set a date to midnight 1/1/1970 GMT due to wrong call");
        is($date->Unix, 0, "unix is 0 => unset");
        is($date->IsSet,0,"Date has been unset");
    }
}

my $year = (localtime(time))[5] + 1900;

{ # set+ISO format
    my $date = RT::Date->new(RT->SystemUser);
    warning_like {
        $date->Set(Format => 'ISO', Value => 'weird date');
    } qr/Couldn't parse date 'weird date' as a ISO format/;
    ok(!$date->IsSet, "date was wrong => unix == 0");

    # XXX: ISO format has more feature than we suport
    # http://www.cl.cam.ac.uk/~mgk25/iso-time.html

    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00');
    is($date->ISO, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00+00');
    is($date->ISO, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss+00");

    $date->Set(Format => 'ISO', Value => '11-28 15:10:00');
    is($date->ISO, $year .'-11-28 15:10:00', "DD-MM hh:mm:ss");

    $date->Set(Format => 'ISO', Value => '11-28 15:10:00+00');
    is($date->ISO, $year .'-11-28 15:10:00', "DD-MM hh:mm:ss+00");

    $date->Set(Format => 'ISO', Value => '20051128151000');
    is($date->ISO, '2005-11-28 15:10:00', "YYYYDDMMhhmmss");

    $date->Set(Format => 'ISO', Value => '1128151000');
    is($date->ISO, $year .'-11-28 15:10:00', "DDMMhhmmss");

    $date->Set(Format => 'ISO', Value => '2005112815:10:00');
    is($date->ISO, '2005-11-28 15:10:00', "YYYYDDMMhh:mm:ss");

    $date->Set(Format => 'ISO', Value => '112815:10:00');
    is($date->ISO, $year .'-11-28 15:10:00', "DDMMhh:mm:ss");

    warning_like {
        $date->Set(Format => 'ISO', Value => '2005-13-28 15:10:00');
    } qr/Invalid date/;
    ok(!$date->IsSet, "wrong month value");

    warning_like {
        $date->Set(Format => 'ISO', Value => '2005-00-28 15:10:00');
    } qr/Invalid date/;
    ok(!$date->IsSet, "wrong month value");

    $date->Set(Format => 'ISO', Value => '1960-01-28 15:10:00');
    ok(!$date->IsSet, "too old, we don't support");
}

{ # set+datemanip format(Time::ParseDate)
    my $date = RT::Date->new(RT->SystemUser);

    RT->Config->Set( Timezone => 'Europe/Moscow' );
    $date->Set(Format => 'datemanip', Value => '2005-11-28 15:10:00');
    is($date->ISO, '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");

    RT->Config->Set( Timezone => 'UTC' );
    $date->Set(Format => 'datemanip', Value => '2005-11-28 15:10:00');
    is($date->ISO, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $current_user->UserObj->__Set( Field => 'Timezone', Value => 'Europe/Moscow');
    $date = RT::Date->new( $current_user );
    $date->Set(Format => 'datemanip', Value => '2005-11-28 15:10:00');
    is($date->ISO, '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");
}

{ # set+unknown format(Time::ParseDate)
    my $date = RT::Date->new(RT->SystemUser);
    warnings_like {
        $date->Set(Format => 'unknown', Value => 'weird date');
    } [ qr{Couldn't parse date 'weird date' by Time::ParseDate},
        qr{Couldn't parse date 'weird date' by DateTime::Format::Natural}
      ];
    ok(!$date->IsSet, "date was wrong");

    RT->Config->Set( Timezone => 'Europe/Moscow' );
    $date->Set(Format => 'unknown', Value => '2005-11-28 15:10:00');
    is($date->ISO, '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");

    $date->Set(Format => 'unknown', Value => '2005-11-28 15:10:00', Timezone => 'utc' );
    is($date->ISO, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    # test relative dates
    {
        set_fixed_time("2005-11-28T15:10:00Z");
        $date->Set(Format => 'unknown', Value => 'now');
        is($date->ISO, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

        $date->Set(Format => 'unknown', Value => '1 day ago');
        is($date->ISO, '2005-11-27 15:10:00', "YYYY-DD-MM hh:mm:ss");
        restore_time();
    }

    RT->Config->Set( Timezone => 'UTC' );
    $date->Set(Format => 'unknown', Value => '2005-11-28 15:10:00');
    is($date->ISO, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");

    $current_user->UserObj->__Set( Field => 'Timezone', Value => 'Europe/Moscow');
    $date = RT::Date->new( $current_user );
    $date->Set(Format => 'unknown', Value => '2005-11-28 15:10:00');
    is($date->ISO, '2005-11-28 12:10:00', "YYYY-DD-MM hh:mm:ss");
    $date->Set(Format => 'unknown', Value => '2005-11-28 15:10:00', Timezone => 'server' );
    is($date->ISO, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");
    $date->Set(Format => 'unknown', Value => '2005-11-28 15:10:00', Timezone => 'utc' );
    is($date->ISO, '2005-11-28 15:10:00', "YYYY-DD-MM hh:mm:ss");
}

{ # 'tomorrow 10am' with TZ
    $current_user->UserObj->__Set( Field => 'Timezone', Value => 'Europe/Moscow');

    set_fixed_time("2012-06-14T15:10:00Z"); # 14th in UTC and Moscow
    my $date = RT::Date->new( $current_user );
    $date->Set(Format => 'unknown', Value => 'tomorrow 10am');
    is($date->ISO, '2012-06-15 06:00:00', "YYYY-DD-MM hh:mm:ss");

    set_fixed_time("2012-06-13T23:10:00Z"); # 13th in UTC and 14th in Moscow
    $date = RT::Date->new( $current_user );
    $date->Set(Format => 'unknown', Value => 'tomorrow 10am');
    is($date->ISO, '2012-06-15 06:00:00', "YYYY-DD-MM hh:mm:ss");

    $current_user->UserObj->__Set( Field => 'Timezone', Value => 'US/Hawaii');

    set_fixed_time("2012-06-14T20:10:00Z"); # 14th in UTC and Hawaii
    $date = RT::Date->new( $current_user );
    $date->Set(Format => 'unknown', Value => 'tomorrow 10am');
    is($date->ISO, '2012-06-15 20:00:00', "YYYY-DD-MM hh:mm:ss");

    set_fixed_time("2012-06-15T05:10:00Z"); # 15th in UTC and 14th in Hawaii
    $date = RT::Date->new( $current_user );
    $date->Set(Format => 'unknown', Value => 'tomorrow 10am');
    is($date->ISO, '2012-06-15 20:00:00', "YYYY-DD-MM hh:mm:ss");

    restore_time();
}

{ # SetToMidnight
    my $date = RT::Date->new(RT->SystemUser);

    RT->Config->Set( Timezone => 'Europe/Moscow' );
    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00');
    $date->SetToMidnight;
    is($date->ISO, '2005-11-28 00:00:00', "default is utc");
    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00');
    $date->SetToMidnight(Timezone => 'utc');
    is($date->ISO, '2005-11-28 00:00:00', "utc context");
    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00');
    $date->SetToMidnight(Timezone => 'user');
    is($date->ISO, '2005-11-27 21:00:00', "user context, user has no preference, fallback to server");
    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00');
    $date->SetToMidnight(Timezone => 'server');
    is($date->ISO, '2005-11-27 21:00:00', "server context");

    $current_user->UserObj->__Set( Field => 'Timezone', Value => 'Europe/Moscow');
    $date = RT::Date->new( $current_user );
    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00');
    $date->SetToMidnight;
    is($date->ISO, '2005-11-28 00:00:00', "default is utc");
    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00');
    $date->SetToMidnight(Timezone => 'utc');
    is($date->ISO, '2005-11-28 00:00:00', "utc context");
    $date->Set(Format => 'ISO', Value => '2005-11-28 15:10:00');
    $date->SetToMidnight(Timezone => 'user');
    is($date->ISO, '2005-11-27 21:00:00', "user context");
    $date->SetToMidnight(Timezone => 'server');
    is($date->ISO, '2005-11-27 21:00:00', "server context");

    RT->Config->Set( Timezone => 'UTC' );
}

{ # SetToNow
    my $date = RT::Date->new(RT->SystemUser);
    my $time = time;
    $date->SetToNow;
    ok($date->Unix >= $time, 'close enough');
    ok($date->Unix < $time+5, 'difference is less than five seconds');
}

{
    my $date = RT::Date->new(RT->SystemUser);
    
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

# XXX: TODO, doesn't work with Test::Warn
#    TODO: {
#        local $TODO = "BUG or subject to change Date handling to support unix time <= 0";
#        $date->Unix(0);
#        $date->AddSeconds(-2);
#        ok($date->Unix > 0);
#    }

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

    $date->Unix(0);
    $date->AddDays(0);
    is($date->ISO, '1970-01-01 00:00:00', "added no days");

    $date->Unix(0);
    $date->AddDays();
    is($date->ISO, '1970-01-02 00:00:00', "added one day with no argument");
}

{
    $current_user->UserObj->__Set( Field => 'Timezone', Value => '');
    my $date = RT::Date->new( $current_user );
    is($date->AsString, "Not set", "AsString returns 'Not set'");

    RT->Config->Set( DateTimeFormat => '');
    $date->Unix(1);
    is($date->AsString, 'Thu Jan 01 00:00:01 1970', "correct string");
    is($date->AsString(Date => 0), '00:00:01', "correct string");
    is($date->AsString(Time => 0), 'Thu Jan 01 1970', "correct string");
    is($date->AsString(Date => 0, Time => 0), 'Thu Jan 01 00:00:01 1970', "invalid input");

    RT->Config->Set( DateTimeFormat => 'RFC2822' );
    $date->Unix(1);
    is($date->AsString, 'Thu, 01 Jan 1970 00:00:01 +0000', "correct string");

    RT->Config->Set( DateTimeFormat => { Format => 'RFC2822', Seconds => 0 } );
    $date->Unix(1);
    is($date->AsString, 'Thu, 01 Jan 1970 00:00 +0000', "correct string");
    is($date->AsString(Seconds => 1), 'Thu, 01 Jan 1970 00:00:01 +0000', "correct string");
}

{ # DurationAsString
    my $date = RT::Date->new(RT->SystemUser);

    is($date->DurationAsString(1), '1 second', '1 sec');
    is($date->DurationAsString(59), '59 seconds', '59 sec');
    is($date->DurationAsString(60), '1 minute', '1 min');
    is($date->DurationAsString(60*119), '119 minutes', '119 min');
    is($date->DurationAsString(60*60*2-1), '120 minutes', '120 min');
    is($date->DurationAsString(60*60*2), '2 hours', '2 hours');
    is($date->DurationAsString(60*60*48-1), '48 hours', '48 hours');
    is($date->DurationAsString(60*60*48), '2 days', '2 days');
    is($date->DurationAsString(60*60*24*14-1), '14 days', '14 days');
    is($date->DurationAsString(60*60*24*14), '2 weeks', '2 weeks');
    is($date->DurationAsString(60*60*24*7*8-1), '8 weeks', '8 weeks');
    is($date->DurationAsString(60*60*24*61), '2 months', '2 months');
    is($date->DurationAsString(60*60*24*365-1), '12 months', '12 months');
    is($date->DurationAsString(60*60*24*366), '1 year', '1 year');

    is($date->DurationAsString(-1), '1 second ago', '1 sec ago');
}

{ # DiffAsString
    my $date = RT::Date->new(RT->SystemUser);
    is($date->DiffAsString(1), '', 'no diff, wrong input');
    is($date->DiffAsString(-1), '', 'no diff, wrong input');
    is($date->DiffAsString('qwe'), '', 'no diff, wrong input');

    $date->Unix(2);
    is($date->DiffAsString(-1), '', 'no diff, wrong input');

    is($date->DiffAsString(3), '1 second ago', 'diff: 1 sec ago');
    is($date->DiffAsString(1), '1 second', 'diff: 1 sec');

    my $ndate = RT::Date->new(RT->SystemUser);
    is($date->DiffAsString($ndate), '', 'no diff, wrong input');
    $ndate->Unix(3);
    is($date->DiffAsString($ndate), '1 second ago', 'diff: 1 sec ago');
}

{ # Diff
    my $date = RT::Date->new(RT->SystemUser);
    $date->SetToNow;
    my $diff = $date->Diff;
    ok($diff <= 0, 'close enought');
    ok($diff > -5, 'close enought');
}

{ # AgeAsString
    my $date = RT::Date->new(RT->SystemUser);
    $date->SetToNow;
    my $diff = $date->AgeAsString;
    like($diff, qr/^(0 seconds|(1 second|[2-5] seconds) ago)$/, 'close enought');
}

{ # GetWeekday
    my $date = RT::Date->new(RT->SystemUser);
    is($date->GetWeekday(7),  '',    '7 and greater are invalid');
    is($date->GetWeekday(6),  'Sat', '6 is Saturday');
    is($date->GetWeekday(0),  'Sun', '0 is Sunday');
    is($date->GetWeekday(-1), 'Sat', '-1 is Saturday');
    is($date->GetWeekday(-7), 'Sun', '-7 is Sunday');
    is($date->GetWeekday(-8), '',    '-8 and lesser are invalid');
}

{ # GetMonth
    my $date = RT::Date->new(RT->SystemUser);
    is($date->GetMonth(12),  '',     '12 and greater are invalid');
    is($date->GetMonth(11),  'Dec', '11 is December');
    is($date->GetMonth(0),   'Jan', '0 is January');
    is($date->GetMonth(-1),  'Dec', '11 is December');
    is($date->GetMonth(-12), 'Jan', '0 is January');
    is($date->GetMonth(-13),  '',    '-13 and lesser are invalid');
}

{
    # set unknown format: edge cases
    my $date = RT::Date->new(RT->SystemUser);
    $date->Set( Value => 0, Format => 'unknown' );
    ok( !$date->IsSet, "unix is 0 with Value => 0, Format => 'unknown'" );

    $date->Set( Value => '', Format => 'unknown' );
    ok( !$date->IsSet, "unix is 0 with Value => '', Format => 'unknown'" );

    $date->Set( Value => ' ', Format => 'unknown' );
    ok( !$date->IsSet, "unix is 0 with Value => ' ', Format => 'unknown'" );
}

{
    # set+unknown format(DateTime::Format::Natural)
    my $date = RT::Date->new(RT->SystemUser);
    warnings_like {
        $date->Set(Format => 'unknown', Value => 'another weird date');
    } [ qr{Couldn't parse date 'another weird date' by Time::ParseDate},
        qr{Couldn't parse date 'another weird date' by DateTime::Format::Natural}
      ], 'warning for "another weird date"';
    ok(!$date->IsSet, "date was wrong");
    RT->Config->Set( AmbiguousDayInPast => 0 );
    RT->Config->Set( AmbiguousDayInFuture => 0 );
    RT->Config->Set( Timezone => 'Asia/Shanghai' );
    set_fixed_time("2015-11-28T15:10:00Z");
    warnings_like {
        $date->Set(Format => 'unknown', Value => 'Apr');
    } qr{Couldn't parse date 'Apr' by Time::ParseDate}, "warning by Time::ParseDate";
    is($date->ISO, '2015-03-31 16:00:00', "April in the past");

    warnings_like {
        $date->Set(Format => 'unknown', Value => 'Monday');
    } qr{Couldn't parse date 'Monday' by Time::ParseDate}, "warning by Time::ParseDate";
    is($date->ISO, '2015-11-22 16:00:00', "Monday in the past");

    RT->Config->Set( AmbiguousDayInFuture => 1 );
    warnings_like {
        $date->Set(Format => 'unknown', Value => 'Apr');
    } qr{Couldn't parse date 'Apr' by Time::ParseDate}, "warning by Time::ParseDate";
    is($date->ISO, '2016-03-31 16:00:00', "April in the future");
}

#TODO: AsString
#TODO: RFC2822, W3CDTF with Timezones

done_testing;
