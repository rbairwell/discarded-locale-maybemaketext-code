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
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::Cpanel::Cookies';
use Locale::MaybeMaketext::Tests::DetectorCpanelBase
  qw/do_cpanel_detector_compare check_detect_call check_new get_sut_for_class/;
use Locale::MaybeMaketext::Tests::Overrider();

# These tests all mock the cPanel code so should be safe to use with or without cPanel.
subtest_buffered( 'check_new',                      sub () { check_new($CLASS); } );
subtest_buffered( 'check_detect_call',              sub () { check_detect_call($CLASS); } );
subtest_buffered( 'check_no_http_cookie',           \&check_no_http_cookie );
subtest_buffered( 'check_cpanel_returns_no_cookie', \&check_cpanel_returns_no_cookie );

SKIP: {
    if ( !eval { require Cpanel::CPAN::Locale::Maketext::Utils; 1; } ) {
        skip(
            sprintf(
                'Does not appear to be a cPanel server (Cpanel::CPAN::Locale::Maketext::Utils: Not available): %s', $@
            )
        );
    }
    subtest_buffered(
        'cpanel_required_check_with_cookie_previously_extracted_no_locale',
        \&check_with_cookie_previously_extracted_no_locale
    );
    subtest_buffered( 'cpanel_required_check_with_cookie_no_locale', \&check_with_cookie_no_locale );
    subtest_buffered(
        'cpanel_required_check_with_cookie_with_locale_previously_extracted',
        \&check_with_cookie_with_locale_previously_extracted
    );
    subtest_buffered( 'cpanel_required_check_with_cookie_with_locale', \&check_with_cookie_with_locale );
}
done_testing();

sub check_with_cookie_with_locale() {
    my %results;

    local $INC{'Cpanel.pm'}   = 'Faked';
    local $ENV{'HTTP_COOKIE'} = 'timezone=America/Mexico_City; session_locale=spanish_utf8';
    local %Cpanel::Cookies    = ();    ## no critic (Variables::ProhibitPackageVars)
    my $sut = get_sut_for_class($CLASS);
    %results = $sut->detect();
    my %expected = (
        'languages'         => ['es'],
        'invalid_languages' => [],
        'reasoning'         => [
            'Extracting cookies',
            'TEST: Package Loader: Loaded Cpanel::Cookies',
            'Cookies extracted',
            'Got 2 cookie entries',
            'Found session_locale setting: spanish_utf8',
            'Found 1 languages: es',
            'Language "es" in position 0: OK',
        ],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_with_cookie_with_locale: Should match'
    );

    is(
        scalar(%Cpanel::Cookies),    ## no critic (Variables::ProhibitPackageVars)
        0,
        'check_with_cookie_with_locale: Cpanel::Cookies should remain unset'
    );
    return 1;
}

sub check_with_cookie_with_locale_previously_extracted() {
    my %results;

    local $INC{'Cpanel.pm'}   = 'Faked';
    local $ENV{'HTTP_COOKIE'} = 'timezone=Europe/London; session_locale=english_utf8';
    local %Cpanel::Cookies =    ## no critic (Variables::ProhibitPackageVars)
      ( 'timezone' => 'Europe/London', 'session_locale' => 'english_utf8' );

    my $sut = get_sut_for_class($CLASS);
    %results = $sut->detect();
    my %expected = (
        'languages'         => ['en'],
        'invalid_languages' => [],
        'reasoning'         => [
            'Using cPanel extracted cookies',
            'Got 2 cookie entries',
            'Found session_locale setting: english_utf8',
            'Found 1 languages: en',
            'Language "en" in position 0: OK'
        ],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_with_cookie_with_locale_previously_extracted: Should just return if no cookies'
    );
    my %expected_cookies = ( 'timezone' => 'Europe/London', 'session_locale' => 'english_utf8' );
    is(
        %Cpanel::Cookies,    ## no critic (Variables::ProhibitPackageVars)
        %expected_cookies,
        'check_with_cookie_with_locale_previously_extracted: Cpanel::Cookies not be changed'
    );
    return 1;
}

sub check_with_cookie_no_locale() {
    my %results;
    local $INC{'Cpanel.pm'}   = 'Faked';
    local $ENV{'HTTP_COOKIE'} = 'timezone=Europe/Berlin';
    local %Cpanel::Cookies    = ();                         ## no critic (Variables::ProhibitPackageVars)
    my $sut = get_sut_for_class($CLASS);
    %results = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Extracting cookies',
            'TEST: Package Loader: Loaded Cpanel::Cookies',
            'Cookies extracted',
            'Got 1 cookie entries',
            'No session_locale setting found in extracted cookies',
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_with_cookie_no_locale: Should just return if no locale'
    );

    is(
        scalar(%Cpanel::Cookies),    ## no critic (Variables::ProhibitPackageVars)
        0,
        'check_with_cookie_no_locale: Cpanel::Cookies should remain unset'
    );
    return 1;
}

sub check_with_cookie_previously_extracted_no_locale() {
    my %results;

    local $INC{'Cpanel.pm'}   = 'Faked';
    local $ENV{'HTTP_COOKIE'} = 'timezone=Europe/Berlin';
    local %Cpanel::Cookies    = ( 'timezone' => 'Europe/Paris' );    ## no critic (Variables::ProhibitPackageVars)
    my $sut = get_sut_for_class($CLASS);
    %results = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Using cPanel extracted cookies',
            'Got 1 cookie entries',
            'No session_locale setting found in extracted cookies',
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_with_cookie_previously_extracted_no_locale: Should just return if no locale'
    );
    my %expected_cookies = ( 'timezone' => 'Europe/Paris' );
    is(
        %Cpanel::Cookies,    ## no critic (Variables::ProhibitPackageVars)
        %expected_cookies,
        'check_with_cookie_previously_extracted_no_locale: Cpanel::Cookies not be changed'
    );
    return 1;
}

sub check_cpanel_returns_no_cookie() {
    my %results;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override( 'Cpanel::Cookies::get_cookie_hashref_from_string', sub { my %empty = (); return \%empty; } );
    $overrider->override(
        'Locale::MaybeMaketext::PackageLoader::attempt_package_load',
        sub ( $self, $package_name ) {
            return (
                'status'    => 1,
                'reasoning' => sprintf( 'Cpanel mocked: Mocked load of "%s"', $package_name )
            );
        }
    );
    local $INC{'Cpanel.pm'}   = 'Faked';
    local $ENV{'HTTP_COOKIE'} = 'timezone=Europe/Frankfurt';
    local %Cpanel::Cookies    = ();                            ## no critic (Variables::ProhibitPackageVars)
    my $sut = get_sut_for_class($CLASS);
    %results = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [
            'Extracting cookies',
            'Package Loader: Cpanel mocked: Mocked load of "Cpanel::Cookies"',
            'Cookies extracted',
            'No cookie entries extracted',
            'No languages found'
        ],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_cpanel_returns_no_cookie: Should just return if no cookie returned'
    );
    is(
        scalar(%Cpanel::Cookies),    ## no critic (Variables::ProhibitPackageVars)
        0,
        'check_cpanel_returns_no_cookie: Cpanel::Cookies should remain unset'
    );
    return 1;
}

sub check_no_http_cookie() {
    my %results;

    local $INC{'Cpanel.pm'}   = 'Faked';
    local $ENV{'HTTP_COOKIE'} = undef;
    local %Cpanel::Cookies    = ();        ## no critic (Variables::ProhibitPackageVars)
    my $sut = get_sut_for_class($CLASS);
    %results = $sut->detect();
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => [ 'No ENV{\'HTTP_COOKIE\'} set', 'No languages found' ],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_no_http_cookie: Should just return if no cookies'
    );
    is(
        scalar(%Cpanel::Cookies),    ## no critic (Variables::ProhibitPackageVars)
        0,
        'check_no_http_cookie: Cpanel::Cookies should remain unset'
    );
    return 1;
}
