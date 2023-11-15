#!perl
use strict;
use warnings;
use vars;
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use subs 'stat';
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Overrider();
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale';
use Locale::MaybeMaketext::Tests::DetectorCpanelBase
  qw/do_cpanel_detector_compare check_detect_call check_new get_sut_for_class get_sut_for_class_with_mocked_validator/;

# These tests all mock the cPanel code so should be safe to use with or without cPanel.
subtest_buffered( 'check_new',         sub () { check_new($CLASS); } );
subtest_buffered( 'check_detect_call', sub () { check_detect_call($CLASS); } );

subtest_buffered( 'check_no_cpconf_file_not_exist',    \&check_no_cpconf_file_not_exist );
subtest_buffered( 'check_no_cpconf_file_not_file',     \&check_no_cpconf_file_not_file );
subtest_buffered( 'check_no_cpconf_file_not_readable', \&check_no_cpconf_file_not_readable );
subtest_buffered( 'check_file_fails_to_open',          \&check_file_fails_to_open );
subtest_buffered( 'check_file_fails_to_read',          \&check_file_fails_to_read );
subtest_buffered( 'check_file_fails_to_close',         \&check_file_fails_to_close );
subtest_buffered( 'check_file_readable',               \&check_file_readable );
subtest_buffered( 'check_file_readable_no_mocks',      \&check_file_readable_no_mocks );

# these require Cpanel
SKIP: {
    if ( !eval { require Cpanel::CPAN::Locale::Maketext::Utils; 1; } ) {
        skip(
            sprintf(
                'Does not appear to be a cPanel server (Cpanel::CPAN::Locale::Maketext::Utils: Not available): %s', $@
            )
        );
    }
}
done_testing();

sub check_no_cpconf_file_not_exist() {
    local $INC{'Cpanel.pm'} = 'Faked';
    local %main::CPCONF = ();
    my $fakename = 'M0ckedForNotExist';
    local $Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale::SERVER_LOCALE_FILE = $fakename;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_validator( $CLASS, $overrider );
    $overrider->mock_stat( $fakename, '-exists' );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'No cpconf found',
            sprintf(
                'Unable to load server locale file: File "%s" not found',
                $fakename
            ),
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_no_cpconf_file_not_exist: Check correct messaging if file does not exist'
    );
    return 1;
}

sub check_no_cpconf_file_not_file() {
    local $INC{'Cpanel.pm'} = 'Faked';
    local %main::CPCONF = ();
    my $fakename = 'M0ckedForNotFile';
    local $Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale::SERVER_LOCALE_FILE = $fakename;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_validator( $CLASS, $overrider );
    $overrider->mock_stat( $fakename, '-file' );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'No cpconf found',
            sprintf(
                'Unable to load server locale file: "%s" is not a file',
                $fakename
            ),
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_no_cpconf_file_not_file: Check correct messaging if file is a folder'
    );
    return 1;
}

sub check_no_cpconf_file_not_readable() {
    local $INC{'Cpanel.pm'} = 'Faked';
    local %main::CPCONF = ();
    my $fakename = 'M0ckedForNotReadable';
    local $Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale::SERVER_LOCALE_FILE = $fakename;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_validator( $CLASS, $overrider );
    $overrider->mock_stat( $fakename, '-readable' );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'No cpconf found',
            sprintf(
                'Unable to load server locale file: File "%s" is not readable by current user',
                $fakename
            ),
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_no_cpconf_file_not_file: Check correct messaging if file is not readable'
    );
    return 1;
}

sub check_file_fails_to_open() {
    local $INC{'Cpanel.pm'} = 'Faked';
    local %main::CPCONF = ();
    my $fakename = 'M0ckedForFailsToOpen';
    local $Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale::SERVER_LOCALE_FILE = $fakename;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_validator( $CLASS, $overrider );
    $overrider->mock_filesystem( $fakename, undef, '-open' );
    my %results = $sut->detect();

    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'No cpconf found',
            sprintf(
                'Unable to open server locale file "%s": Operation not permitted',
                $fakename
            ),
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_file_fails_to_open: Check correct messaging if file is not openable'
    );
    return 1;
}

sub check_file_fails_to_read() {
    local $INC{'Cpanel.pm'} = 'Faked';
    local %main::CPCONF = ();
    my $fakename = 'M0ckedForFailsToRead';
    local $Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale::SERVER_LOCALE_FILE = $fakename;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_validator( $CLASS, $overrider );
    $overrider->mock_filesystem( $fakename, undef, '-read' );
    my %results = $sut->detect();

    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'No cpconf found',
            sprintf(
                'Unable to read server locale file "%s": Input/output error',
                $fakename
            ),
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_file_fails_to_read: Check correct messaging if file is not readable'
    );
    return 1;
}

sub check_file_fails_to_close() {
    local $INC{'Cpanel.pm'} = 'Faked';
    local %main::CPCONF = ();
    my $fakename = 'M0ckedForFailsToClose';
    local $Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale::SERVER_LOCALE_FILE = $fakename;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_validator( $CLASS, $overrider );
    my $testdata  = 'testing';
    $overrider->mock_filesystem( $fakename, $testdata, '-close' );
    my %results = $sut->detect();

    my %expected = (
        'languages'         => [],
        'invalid_languages' => ['testing'],
        'reasoning'         => [
            'No cpconf found',
            sprintf(
                'Read %d bytes from server locale file "%s"',
                length($testdata), $fakename
            ),
            sprintf(
                'Unable to close server locale file "%s": Input/output error',
                $fakename
            ),
            sprintf( 'Found 1 languages: %s', $testdata ),
            sprintf( 'Mock failing %s',       $testdata ),
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_file_fails_to_close: Check correct messaging if file is not closable'
    );
    return 1;
}

sub check_file_readable() {
    local $INC{'Cpanel.pm'} = 'Faked';
    local %main::CPCONF = ();
    my $fakename = 'M0ckedForFailsToClose';
    local $Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale::SERVER_LOCALE_FILE = $fakename;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_validator( $CLASS, $overrider, ('en_gb') );
    my $testdata  = 'en_gb';
    $overrider->mock_filesystem( $fakename, $testdata );
    my %results = $sut->detect();

    my %expected = (
        'languages'         => ['en_gb'],
        'invalid_languages' => [],
        'reasoning'         => [
            'No cpconf found',
            sprintf(
                'Read %d bytes from server locale file "%s"',
                length($testdata), $fakename
            ),
            sprintf( 'Found 1 languages: %s', $testdata ),
            sprintf( 'Mock validating %s',    $testdata ),
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_file_readable: Check it is readable with mocks'
    );
    return 1;
}

sub check_file_readable_no_mocks() {
    local $INC{'Cpanel.pm'} = 'Faked';
    local %main::CPCONF = ();
    my $test_path = sprintf(
        '%s/%s',
        File::Spec->catdir(
            File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), qw/testdata var_cpanel_server_locale/
        ),
        'example'
    );
    local $Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale::SERVER_LOCALE_FILE = $test_path;
    my $sut               = get_sut_for_class( $CLASS, );
    my %results           = $sut->detect();
    my $expected_language = 'de_de';

    my %expected = (
        'languages'         => ['de_de'],
        'invalid_languages' => [],
        'reasoning'         => [
            'No cpconf found',
            sprintf(
                'Read %d bytes from server locale file "%s"',
                length($expected_language), $test_path
            ),
            sprintf( 'Found 1 languages: %s',           $expected_language ),
            sprintf( 'Language "%s" in position 0: OK', $expected_language ),
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'check_file_readable_no_mocks: Check it is readable without mocks'
    );
    return 1;
}
