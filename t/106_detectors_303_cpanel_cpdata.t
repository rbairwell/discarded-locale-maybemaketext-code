#!perl
use strict;
use warnings;
use vars;
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Overrider();
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::Cpanel::CPData';
use Locale::MaybeMaketext::Tests::DetectorCpanelBase
  qw/do_cpanel_detector_compare get_mocked_loader check_detect_call check_new get_sut_for_class_with_mocked_loader/;

# These tests all mock the cPanel code so should be safe to use with or without cPanel.
# This is because it would be tricky to ensure the cPanel server is always in a testable state and
# that these tests are being executed from the "correct" placement (such as via WHM).

subtest_buffered( 'check_new',         sub () { check_new($CLASS); } );
subtest_buffered( 'check_detect_call', sub () { check_detect_call($CLASS); } );

subtest_buffered( 'reseller_whm: reseller_whm_modules_erroring',   \&reseller_whm_modules_erroring );
subtest_buffered( 'reseller_whm: reseller_whm_no_remote_user_env', \&reseller_whm_no_remote_user_env );

subtest_buffered( 'reseller_whm: reseller_whm_root_user',         \&reseller_whm_root_user );
subtest_buffered( 'reseller_whm: reseller_whm_no_appname',        \&reseller_whm_no_appname );
subtest_buffered( 'reseller_whm: reseller_whm_bad_appname',       \&reseller_whm_bad_appname );
subtest_buffered( 'reseller_whm: reseller_whm_cpuser_unreadable', \&reseller_whm_cpuser_unreadable );
subtest_buffered( 'reseller_whm: reseller_whm_data_not_blessed',  \&reseller_whm_data_not_blessed );
subtest_buffered( 'reseller_whm: reseller_whm_data_wrong_isa',    \&reseller_whm_data_wrong_isa );
subtest_buffered( 'reseller_whm: reseller_whm_cpdata_empty',      \&reseller_whm_cpdata_empty );
subtest_buffered( 'reseller_whm: reseller_whm_data_complete',     \&reseller_whm_data_complete );
subtest_buffered( 'not_reseller_locale_and_lang_already_exists',  \&not_reseller_locale_and_lang_already_exists );
subtest_buffered( 'not_reseller_locale_and_lang_invalid_exists',  \&not_reseller_locale_and_lang_invalid_exists );

SKIP: {
# Cpanel::ConfigFiles is needed for cpanel_needed_cpdata to work correctly as Cpanel::Config::HasCpUserFile references it.
    if ( !eval { require Cpanel::ConfigFiles; 1; } ) {
        skip( sprintf( 'Does not appear to be a cPanel server (Cpanel::ConfigFiles: Not available): %s', $@ ) );
    }
    subtest_buffered( 'cpanel_needed_cpdata', \&cpanel_needed_cpdata );
}
done_testing();

sub cpanel_needed_cpdata() {
    my @possible_whm_names = qw/whostmgr whm whostmgrd/;
    my @invalid_whm_names  = qw/cpanel cpaneld webmail webmaild/;

    # set the filepath for the config
    my $test_data_path =
      File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), qw/testdata var_cpanel_users/ );

    no warnings 'once';    ## no critic(TestingAndDebugging::ProhibitNoWarnings)

    # mock the remote user
    local $ENV{'REMOTE_USER'}   = 'mmtexample';
    local $INC{'Cpanel.pm'}     = 'Faked';
    local $Cpanel::App::appname = 'whostmgr';     ## no critic (Variables::ProhibitPackageVars)
    local $Cpanel::CPDATA       = undef;

    # used by Cpanel::Config::HasCpUserFile and Cpanel::Config::LoadCpUserFile
    # Default: /var/cpanel/users
    # Appends the username to the end
    # also appends .cache/username to end for cache file - so directory needs to be writable
    local $Cpanel::ConfigFiles::cpanel_users = $test_data_path;    ## no critic (Variables::ProhibitPackageVars)

    my $cache = Locale::MaybeMaketext::Cache->new();
    my $sut   = Locale::MaybeMaketext::Detectors::Cpanel::CPData->new(
        'cache'                   => $cache,
        'package_loader'          => Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache ),
        'language_code_validator' => Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache )
    );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => ['pa_pk'],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: Remote user is "mmtexample"',
            'Reseller WHM Cpdata: Cpanel::App::appname set to "whostmgr"',
            'TEST: Reseller WHM Cpdata: Package Loader: Loaded Cpanel::Config::HasCpUserFile',
            'Reseller WHM Cpdata: Has readable CpUser data file',
            'TEST: Reseller WHM Cpdata: Package Loader: Loaded Cpanel::Config::LoadCpUserFile::CurrentUser',
            'Reseller WHM Cpdata: Read 67 entries from CpData',
            'CpData{\'LOCALE\'} or CpData{\'LANG\'} already exists - no need to load',
            'Locale: Found 1 language: pa_pk',
            'Lang: No languages found',
            'Found 1 languages: pa_pk',
            'Language "pa_pk" in position 0: OK',
        ],
    );
    my $user = 'mmtexample';
    my @reasoning;
    for my $line ( @{ $results{'reasoning'} } ) {
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        $line =~ s/\A(Reseller WHM Cpdata: Package Loader:) (Loaded|Already loaded) "([^"]+)".*/TEST: $1 Loaded $3/g;
        push @reasoning, $line;
    }
    $results{'reasoning'} = \@reasoning;
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'cpanel_needed_cpdata: Should read our user configuration file'
    );
    return 1;
}

sub not_reseller_locale_and_lang_invalid_exists() {
    my $sut;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    local $ENV{'REMOTE_USER'}       = undef;
    local $INC{'Cpanel.pm'}         = 'Faked';
    local $Cpanel::CPDATA{'LOCALE'} = sub { return 'test'; };
    local $Cpanel::CPDATA{'LANG'}   = \('hello');
    $overrider->override( 'require', sub { fail('require should not be called'); } );
    $overrider->override( 'Cpanel::Locale::Utils::User::init_cpdata_keys', sub { fail('should not be called'); } );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: No remote user environment variable',
            'CpData{\'LOCALE\'} or CpData{\'LANG\'} already exists - no need to load',
            'Locale: Expected scalar, got: CODE',
            'Lang: Expected scalar, got: SCALAR',
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'not_reseller_locale_and_lang_already_exists: Should use setup Cpanel::CPDATA to read both'
    );
    $overrider->reset_all();
    return 1;
}

sub not_reseller_locale_and_lang_already_exists() {
    my $sut;
    local $ENV{'REMOTE_USER'}       = undef;
    local $INC{'Cpanel.pm'}         = 'Faked';
    local $Cpanel::CPDATA{'LOCALE'} = 'en';
    local $Cpanel::CPDATA{'LANG'}   = 'de';
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override( 'require', sub { fail('require should not be called'); } );
    $overrider->override( 'Cpanel::Locale::Utils::User::init_cpdata_keys', sub { fail('should not be called'); } );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [ 'en', 'de' ],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: No remote user environment variable',
            'CpData{\'LOCALE\'} or CpData{\'LANG\'} already exists - no need to load',
            'Locale: Found 1 language: en',
            'Lang: Found 1 language: de',
            'Found 2 languages: en, de',
            'Language "en" in position 0: OK',
            'Language "de" in position 1: OK',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'not_reseller_locale_and_lang_already_exists: Should use setup Cpanel::CPDATA to read both'
    );
    local $Cpanel::CPDATA{'LANG'} = undef;
    %results  = $sut->detect();
    %expected = (
        'languages'         => ['en'],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: No remote user environment variable',
            'CpData{\'LOCALE\'} or CpData{\'LANG\'} already exists - no need to load',
            'Locale: Found 1 language: en',
            'Lang: No languages found',
            'Found 1 languages: en',
            'Language "en" in position 0: OK',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'not_reseller_locale_and_lang_already_exists: Should use setup Cpanel::CPDATA to read locale'

    );
    local $Cpanel::CPDATA{'LOCALE'} = undef;
    local $Cpanel::CPDATA{'LANG'}   = 'es_419';
    %results  = $sut->detect();
    %expected = (
        'languages'         => ['es_419'],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: No remote user environment variable',
            'CpData{\'LOCALE\'} or CpData{\'LANG\'} already exists - no need to load',
            'Locale: No languages found',
            'Lang: Found 1 language: es_419',
            'Found 1 languages: es_419',
            'Language "es_419" in position 0: OK',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'not_reseller_locale_and_lang_already_exists: Should use setup Cpanel::CPDATA to read lang'

    );
    local $Cpanel::CPDATA{'LOCALE'} = undef;
    local $Cpanel::CPDATA{'LANG'}   = 'simplified_chinese';
    %results  = $sut->detect();
    %expected = (
        'languages'         => ['zh_cn'],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: No remote user environment variable',
            'CpData{\'LOCALE\'} or CpData{\'LANG\'} already exists - no need to load',
            'Locale: No languages found',
            'Lang: Transformed old style language "simplified_chinese" to new style "zh_cn"',
            'Lang: Found 1 language: zh_cn',
            'Found 1 languages: zh_cn',
            'Language "zh_cn" in position 0: OK',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'not_reseller_locale_and_lang_already_exists: Should use setup Cpanel::CPDATA to read old-style lang'

    );
    $overrider->reset_all();
    return 1;
}

sub reseller_whm_no_remote_user_env() {
    my $sut;
    local $ENV{'REMOTE_USER'} = undef;
    local $Cpanel::CPDATA     = undef;
    local $INC{'Cpanel.pm'}   = 'Faked';
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: No remote user environment variable',
            'Package Loader: Dummy load of Cpanel::Locale::Utils::User',
            'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
            'Locale: No languages found',
            'Lang: No languages found',
            'No languages found',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_no_remote_user_env: If no user, no need to do anything'
    );
    is( scalar( keys(%Cpanel::CPDATA) ), 0, 'reseller_whm_no_remote_user_env: CpData should be unchanged' );
    $overrider->reset_all();
    return 1;
}

sub reseller_whm_root_user() {
    my $sut;
    local $ENV{'REMOTE_USER'} = 'root';
    local $Cpanel::CPDATA     = undef;
    local $INC{'Cpanel.pm'}   = 'Faked';

    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );

    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: User is "root"',
            'Package Loader: Dummy load of Cpanel::Locale::Utils::User',
            'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
            'Locale: No languages found',
            'Lang: No languages found',
            'No languages found',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_root_user: If root user, no need to do anything'
    );

    is( scalar( keys(%Cpanel::CPDATA) ), 0, 'reseller_whm_root_user: CpData should be unchanged' );
    $overrider->reset_all();
    return 1;
}

sub reseller_whm_no_appname() {
    my $sut;
    local $ENV{'REMOTE_USER'}   = 'resellertestabc';
    local $Cpanel::CPDATA       = undef;
    local $INC{'Cpanel.pm'}     = 'Faked';
    local $Cpanel::App::appname = undef;               ## no critic (Variables::ProhibitPackageVars)
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: Remote user is "resellertestabc"',
            'Reseller WHM Cpdata: Cpanel::App::appname not set',
            'Package Loader: Dummy load of Cpanel::Locale::Utils::User',
            'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
            'Locale: No languages found',
            'Lang: No languages found',
            'No languages found',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_no_appname: No app name set'
    );

    is( scalar( keys(%Cpanel::CPDATA) ), 0, 'reseller_whm_no_appname: CpData should be unchanged' );
    $overrider->reset_all();
    return 1;
}

sub reseller_whm_bad_appname() {
    my $sut;
    local $ENV{'REMOTE_USER'}   = 'resellertestabc';
    local $Cpanel::CPDATA       = undef;
    local $INC{'Cpanel.pm'}     = 'Faked';
    local $Cpanel::App::appname = 'cpanel';            ## no critic (Variables::ProhibitPackageVars)
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: Remote user is "resellertestabc"',
            'Reseller WHM Cpdata: Cpanel::App::appname set to "cpanel"',
            'Package Loader: Dummy load of Cpanel::Locale::Utils::User',
            'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
            'Locale: No languages found',
            'Lang: No languages found',
            'No languages found',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_bad_appname: App name not set to whostmgr'
    );

    is( scalar( keys(%Cpanel::CPDATA) ), 0, 'reseller_whm_bad_appname: CpData should be unchanged' );
    $overrider->reset_all();
    return 1;
}

sub reseller_whm_cpuser_unreadable() {
    my $sut;
    local $ENV{'REMOTE_USER'}   = 'resellertestabc';
    local $Cpanel::CPDATA       = undef;
    local $INC{'Cpanel.pm'}     = 'Faked';
    local $Cpanel::App::appname = 'whostmgr';          ## no critic (Variables::ProhibitPackageVars)
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override(
        'Cpanel::Config::HasCpUserFile::has_readable_cpuser_file',
        sub {
            is( $_[0], 'resellertestabc', 'reseller_whm_cpuser_unreadable: Should be passed "resellertestabc"' );
            return 0;
        }
    );
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: Remote user is "resellertestabc"',
            'Reseller WHM Cpdata: Cpanel::App::appname set to "whostmgr"',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::HasCpUserFile',
            'Reseller WHM Cpdata: CpUser data file unreadable',
            'Package Loader: Dummy load of Cpanel::Locale::Utils::User',
            'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
            'Locale: No languages found',
            'Lang: No languages found',
            'No languages found',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_cpuser_unreadable: CpUser data file unreadable'
    );
    is( scalar( keys(%Cpanel::CPDATA) ), 0, 'reseller_whm_cpuser_unreadable: CpData should be unchanged' );
    $overrider->reset_all();
    return 1;
}

sub reseller_whm_data_not_blessed() {
    my $sut;
    local $ENV{'REMOTE_USER'}   = 'resellertestabc';
    local $Cpanel::CPDATA       = undef;
    local $INC{'Cpanel.pm'}     = 'Faked';
    local $Cpanel::App::appname = 'whostmgr';          ## no critic (Variables::ProhibitPackageVars)
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override(
        'Cpanel::Config::HasCpUserFile::has_readable_cpuser_file',
        sub {
            is(
                $_[0], 'resellertestabc',
                'reseller_whm_data_not_blessed: Check readable should be passed "resellertestabc"'
            );
            return 1;
        }
    );
    my $dummy_object = q{abc};
    $overrider->override(
        'Cpanel::Config::LoadCpUserFile::CurrentUser::load',
        sub {
            is(
                $_[0], 'resellertestabc',
                'reseller_whm_data_not_blessed: Load should be passed "resellertestabc"'
            );
            return $dummy_object;
        }
    );
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: Remote user is "resellertestabc"',
            'Reseller WHM Cpdata: Cpanel::App::appname set to "whostmgr"',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::HasCpUserFile',
            'Reseller WHM Cpdata: Has readable CpUser data file',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::LoadCpUserFile::CurrentUser',
            'Reseller WHM Cpdata: Cpanel::Config::LoadCpUserFile::CurrentUser::load returned non-blessed item of type: scalar: abc',
            'Package Loader: Dummy load of Cpanel::Locale::Utils::User',
            'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
            'Locale: No languages found',
            'Lang: No languages found',
            'No languages found',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_data_not_blessed: Should handle not blessed item being returned'
    );
    is( scalar( keys(%Cpanel::CPDATA) ), 0, 'reseller_whm_data_not_blessed: CpData should be unchanged' );
    $overrider->reset_all();
    return 1;

}

sub reseller_whm_data_wrong_isa() {
    my $sut;
    local $ENV{'REMOTE_USER'}   = 'resellertestabc';
    local $Cpanel::CPDATA       = undef;
    local $INC{'Cpanel.pm'}     = 'Faked';
    local $Cpanel::App::appname = 'whostmgr';          ## no critic (Variables::ProhibitPackageVars)
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override(
        'Cpanel::Config::HasCpUserFile::has_readable_cpuser_file',
        sub {
            is(
                $_[0], 'resellertestabc',
                'reseller_whm_data_wrong_isa: Check readable should be passed "resellertestabc"'
            );
            return 1;
        }
    );
    my $dummy_object = bless { 'LOCALE' => 'es_419', 'OWNER' => 'root', 'CONTACTEMAIL' => q{} },
      'Testing::McTester::Dummy';
    $overrider->override(
        'Cpanel::Config::LoadCpUserFile::CurrentUser::load',
        sub {
            is(
                $_[0], 'resellertestabc',
                'reseller_whm_data_wrong_isa: Load should be passed "resellertestabc"'
            );
            return $dummy_object;
        }
    );
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: Remote user is "resellertestabc"',
            'Reseller WHM Cpdata: Cpanel::App::appname set to "whostmgr"',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::HasCpUserFile',
            'Reseller WHM Cpdata: Has readable CpUser data file',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::LoadCpUserFile::CurrentUser',
            'Reseller WHM Cpdata: Cpanel::Config::LoadCpUserFile::CurrentUser::load returned incorrect object type of: Testing::McTester::Dummy',
            'Package Loader: Dummy load of Cpanel::Locale::Utils::User',
            'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
            'Locale: No languages found',
            'Lang: No languages found',
            'No languages found',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_data_wrong_isa: Not right object type'
    );
    is(
        scalar( keys(%Cpanel::CPDATA) ), 0,
        'reseller_whm_data_wrong_isa: Not right object type: CpData should be unchanged'
    );

    $overrider->reset_all();
    return 1;
}

sub reseller_whm_cpdata_empty() {
    my $sut;
    local $ENV{'REMOTE_USER'}   = 'resellertestabc';
    local $Cpanel::CPDATA       = undef;
    local $INC{'Cpanel.pm'}     = 'Faked';
    local $Cpanel::App::appname = 'whostmgr';          ## no critic (Variables::ProhibitPackageVars)
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override(
        'Cpanel::Config::HasCpUserFile::has_readable_cpuser_file',
        sub {
            is(
                $_[0], 'resellertestabc',
                'reseller_whm_cpdata_empty: Check readable should be passed "resellertestabc"'
            );
            return 1;
        }
    );
    my $dummy_object = bless {}, 'Cpanel::Config::CpUser::Object';
    $overrider->override(
        'Cpanel::Config::LoadCpUserFile::CurrentUser::load',
        sub {
            is( $_[0], 'resellertestabc', 'reseller_whm_cpdata_empty: Load should be passed "resellertestabc"' );
            $dummy_object;
        }
    );
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: Remote user is "resellertestabc"',
            'Reseller WHM Cpdata: Cpanel::App::appname set to "whostmgr"',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::HasCpUserFile',
            'Reseller WHM Cpdata: Has readable CpUser data file',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::LoadCpUserFile::CurrentUser',
            'Reseller WHM Cpdata: Unable to read CpData',
            'Package Loader: Dummy load of Cpanel::Locale::Utils::User',
            'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
            'Locale: No languages found',
            'Lang: No languages found',
            'No languages found',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_cpdata_empty: Unable to read CpData'
    );
    is( scalar( keys(%Cpanel::CPDATA) ), 0, 'reseller_whm_cpdata_empty: CpData should be unchanged' );
    $overrider->reset_all();
    return 1;
}

sub reseller_whm_data_complete() {
    my $sut;
    local $ENV{'REMOTE_USER'}   = 'resellertestabc';
    local $Cpanel::CPDATA       = undef;
    local $INC{'Cpanel.pm'}     = 'Faked';
    local $Cpanel::App::appname = 'whostmgr';          ## no critic (Variables::ProhibitPackageVars)
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override(
        'Cpanel::Config::HasCpUserFile::has_readable_cpuser_file',
        sub {
            is(
                $_[0], 'resellertestabc',
                'reseller_whm_data_complete: Check readable should be passed "resellertestabc"'
            );
            return 1;
        }
    );
    my %mocked_cpdata = ( 'LOCALE' => 'es_419', 'OWNER' => 'root', 'CONTACTEMAIL' => 'tester@example.com' );
    my @dummy_keys    = sort( keys(%mocked_cpdata) );
    my $expect_scalar = scalar(@dummy_keys);
    my $dummy_object  = bless \%mocked_cpdata, 'Cpanel::Config::CpUser::Object';

    $overrider->override(
        'Cpanel::Config::LoadCpUserFile::CurrentUser::load',
        sub {
            is( $_[0], 'resellertestabc', 'reseller_whm_data_complete: Load should be passed "resellertestabc"' );
            return $dummy_object;
        }
    );
    $overrider->override(
        'Cpanel::Locale::Utils::User::init_cpdata_keys',
        sub { return; }
    );
    $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    my %results  = $sut->detect();
    my %expected = (
        'languages'         => ['es_419'],
        'invalid_languages' => [],
        'reasoning'         => [
            'Reseller WHM Cpdata: Remote user is "resellertestabc"',
            'Reseller WHM Cpdata: Cpanel::App::appname set to "whostmgr"',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::HasCpUserFile',
            'Reseller WHM Cpdata: Has readable CpUser data file',
            'Reseller WHM Cpdata: Package Loader: Dummy load of Cpanel::Config::LoadCpUserFile::CurrentUser',
            sprintf( 'Reseller WHM Cpdata: Read %d entries from CpData', $expect_scalar ),
            'CpData{\'LOCALE\'} or CpData{\'LANG\'} already exists - no need to load',
            'Locale: Found 1 language: es_419',
            'Lang: No languages found',
            'Found 1 languages: es_419',
            'Language "es_419" in position 0: OK',
        ],
    );
    do_cpanel_detector_compare(
        \%results,
        \%expected,
        'reseller_whm_data_complete: Read CpData correctly'
    );
    is( scalar( keys(%Cpanel::CPDATA) ), 0, 'reseller_whm_data_complete: CpData should be unchanged' );
    $overrider->reset_all();
    return 1;
}

sub reseller_whm_modules_erroring() {
    my $overrider        = Locale::MaybeMaketext::Tests::Overrider->new();
    my %mocked_cpdata    = ( 'LOCALE' => 'es_419', 'OWNER' => 'root', 'CONTACTEMAIL' => 'tester@example.com' );
    my $dummy_object     = bless \%mocked_cpdata, 'Cpanel::Config::CpUser::Object';
    my %mockable_modules = (
        'Cpanel::Config::HasCpUserFile' => [
            'method'   => 'Cpanel::Config::HasCpUserFile::has_readable_cpuser_file',
            'value'    => sub { return 1; },
            'passtext' => ['Reseller WHM Cpdata: Has readable CpUser data file']
        ],
        'Cpanel::Config::LoadCpUserFile::CurrentUser' => [
            'method'   => 'Cpanel::Config::LoadCpUserFile::CurrentUser::load',
            'value'    => sub { return $dummy_object; },
            'passtext' => []
        ],
    );
    my @mock_order = ( 'Cpanel::Config::HasCpUserFile', 'Cpanel::Config::LoadCpUserFile::CurrentUser' );
    for my $current_fail (@mock_order) {
        local $ENV{'REMOTE_USER'}   = 'resellertestabc';
        local $Cpanel::CPDATA       = undef;
        local $INC{'Cpanel.pm'}     = 'Faked';
        local $Cpanel::App::appname = 'whostmgr';          ## no critic (Variables::ProhibitPackageVars)

        my @expected_reasoning = (
            'Reseller WHM Cpdata: Remote user is "resellertestabc"',
            'Reseller WHM Cpdata: Cpanel::App::appname set to "whostmgr"'
        );
        my $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );

        # override the package loader again.
        $overrider->override(
            'Locale::MaybeMaketext::PackageLoader::attempt_package_load',
            sub ( $self, $package_name ) {
                if ( $package_name eq $current_fail ) {
                    return (
                        'status'    => 0,
                        'reasoning' => sprintf( 'Reseller WHM loader mock: Mocked failure of "%s"', $package_name )
                    );
                }
                elsif ( defined( $mockable_modules{$package_name} ) ) {
                    my %override = @{ $mockable_modules{$package_name} };
                    $overrider->override(
                        $override{'method'},
                        $override{'value'}
                    );
                    @expected_reasoning = (
                        @expected_reasoning,
                        sprintf(
                            'Reseller WHM Cpdata: Package Loader: Reseller WHM loader mock: Mocked load "%s"',
                            $package_name
                        ),
                        @{ $override{'passtext'} },
                    );
                    return (
                        'status'    => 1,
                        'reasoning' => sprintf( 'Reseller WHM loader mock: Mocked load "%s"', $package_name )
                    );
                }
                elsif ( $package_name eq 'Cpanel::Locale::Utils::User' ) {
                    $overrider->override(
                        'Cpanel::Locale::Utils::User::init_cpdata_keys',
                        sub { return; }
                    );
                    return (
                        'status'    => 1,
                        'reasoning' => sprintf( 'Reseller WHM loader mock: Mocked load "%s"', $package_name )
                    );
                }
                return (
                    'status'    => 1,
                    'reasoning' => sprintf( 'Reseller WHM loader mock: Blocked load "%s"', $package_name )
                );
            }
        );

        my %results  = $sut->detect();
        my %expected = (
            'languages'         => [],
            'invalid_languages' => [],
            'reasoning'         => [
                @expected_reasoning,
                sprintf(
                    'Reseller WHM Cpdata: Errored: Package Loader: Reseller WHM loader mock: Mocked failure of "%s"',
                    $current_fail
                ),
                'Package Loader: Reseller WHM loader mock: Mocked load "Cpanel::Locale::Utils::User"',
                'Cpanel::Locale::Utils::User::init_cpdata_keys setup',
                'Locale: No languages found',
                'Lang: No languages found',
                'No languages found',
            ],
        );
        do_cpanel_detector_compare(
            \%results,
            \%expected,
            sprintf( 'reseller_whm_modules_erroring: Checking failure of %s', $current_fail )
        );
    }
    $overrider->reset_all();
    return 1;
}

