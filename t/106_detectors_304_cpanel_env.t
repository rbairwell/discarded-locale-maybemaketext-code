#!perl
use strict;
use warnings;
use vars;
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::Cpanel::Env';
use Locale::MaybeMaketext::Tests::DetectorCpanelBase
  qw/do_cpanel_detector_compare check_detect_call check_new get_sut_for_class/;
use Locale::MaybeMaketext::Tests::Overrider();

# These tests all mock the cPanel code so should be safe to use with or without cPanel.
subtest_buffered( 'check_new',         sub () { check_new($CLASS); } );
subtest_buffered( 'check_detect_call', sub () { check_detect_call($CLASS); } );

subtest_buffered( 'check_no_locale',      \&check_no_locale );
subtest_buffered( 'check_bad_locale',     \&check_bad_locale );
subtest_buffered( 'check_invalid_locale', \&check_invalid_locale );
subtest_buffered( 'check_good_locale',    \&check_good_locale );
done_testing();

sub check_no_locale() {
    local $ENV{'CPANEL_SERVER_LOCALE'} = undef;
    local $INC{'Cpanel.pm'}            = 'Faked';
    my $sut      = get_sut_for_class($CLASS);
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [ 'No CPANEL_SERVER_LOCALE environment variable set', 'No languages found' ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_no_locale: Should not have anything'
    );
    return 1;
}

sub check_bad_locale() {
    local $ENV{'CPANEL_SERVER_LOCALE'} = 'some%garbage';
    local $INC{'Cpanel.pm'}            = 'Faked';
    my $sut      = get_sut_for_class($CLASS);
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning' => [ 'CPANEL_SERVER_LOCALE Failed regular expression check: some%garbage', 'No languages found' ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_bad_locale: Should reject non alphanumerics'
    );
    return 1;
}

sub check_invalid_locale() {
    local $ENV{'CPANEL_SERVER_LOCALE'} = 'not_a-language';
    local $INC{'Cpanel.pm'}            = 'Faked';
    my $sut      = get_sut_for_class($CLASS);
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => ['not_a-language'],
        'reasoning'         => [
            'Found CPANEL_SERVER_LOCALE: not_a-language',
            'Found 1 languages: not_a-language',
            'Language "not_a-language" in position 0: Bad singletons: Invalid singleton "a" - only "t" and "u" are accepted for extensions',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_invalid_locale: Should reject invalid locales'
    );
    return 1;
}

sub check_good_locale() {
    local $ENV{'CPANEL_SERVER_LOCALE'} = 'en-us';
    local $INC{'Cpanel.pm'}            = 'Faked';
    my $sut      = get_sut_for_class($CLASS);
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => ['en_us'],
        'invalid_languages' => [],
        'reasoning'         =>
          [ 'Found CPANEL_SERVER_LOCALE: en-us', 'Found 1 languages: en-us', 'Language "en-us" in position 0: OK' ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_good_locale: Should accept valid locales'
    );
    return 1;
}
