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
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::Cpanel';
use Locale::MaybeMaketext::Tests::DetectorCpanelBase
  qw/do_cpanel_detector_compare check_detect_call check_new get_sut_for_class get_mocked_validator/;

subtest_buffered( 'check_new',                sub () { check_new($CLASS); } );
subtest_buffered( 'check_detect_call',        sub () { check_detect_call($CLASS); } );
subtest_buffered( 'check_all_working',        \&check_all_working );
subtest_buffered( 'check_all_fail_in_new',    \&check_all_fail_in_new );
subtest_buffered( 'check_all_fail_in_detect', \&check_all_fail_in_detect );
done_testing();

sub check_all_working() {
    my $overrider     = Locale::MaybeMaketext::Tests::Overrider->new();
    my $class_prefix  = 'Locale::MaybeMaketext::Detectors::Cpanel';
    my @check_classes = qw/Cookies CPData I18N Env ServerLocale/;
    my $cache         = Locale::MaybeMaketext::Cache->new();
    my $loader        = Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache );
    my $validator     = get_mocked_validator( $overrider, $cache, qw/en_gb/ );
    my $sut           = $CLASS->new(
        'cache'                   => $cache,
        'package_loader'          => $loader,
        'language_code_validator' => $validator,
    );
    local $INC{'Cpanel.pm'} = 'Faked';
    my @expected_reasoning;
    my @expected_validation;
    for my $class_to_mock (@check_classes) {
        my $full_class_to_mock = sprintf( '%s::%s', $class_prefix, $class_to_mock );
        $overrider->override(
            sprintf( '%s::%s::%s', $class_prefix, $class_to_mock, 'new' ),
            sub ( $class, %params ) {
                if ( $params{'cache'} != $cache ) {
                    croak( sprintf( 'Cache not passed correctly to %s', $full_class_to_mock ) );
                }
                if ( $params{'package_loader'} != $loader ) {
                    croak( sprintf( 'package_loader not passed correctly to %s', $full_class_to_mock ) );
                }
                if ( $params{'language_code_validator'} != $validator ) {
                    croak( sprintf( 'language_code_validator not passed correctly to %s', $full_class_to_mock ) );
                }
                return bless {}, $class;
            }
        );
        $overrider->override(
            sprintf( '%s::%s::%s', $class_prefix, $class_to_mock, 'run_detect' ),
            sub {
                my @languages = ( 'en_gb', $class_to_mock );
                my @reasoning = ( sprintf( 'Dummy check via %s', $class_to_mock ) );
                return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
            }
        );
        @expected_reasoning = (
            @expected_reasoning,
            (
                sprintf( 'TEST: Package Loader: Loaded %s', $full_class_to_mock ),
                sprintf( '  %s: Dummy check via %s',        $class_to_mock, $class_to_mock ),
                sprintf( '%s: Found 2 potential languages', $class_to_mock )
            )
        );
        @expected_validation = (
            @expected_validation,
            ( 'Mock validating en_gb', sprintf( 'Mock failing %s', $class_to_mock ) )
        );
    }
    my %results = $sut->detect();
    @expected_reasoning = (
        @expected_reasoning,
        'Found 10 languages: en_gb, Cookies, en_gb, CPData, en_gb, I18N, en_gb, Env, en_gb, ServerLocale',
        @expected_validation,
        'Removed 4 duplicates of "en_gb"',
    );
    my %expected = (
        'languages'         => [qw/en_gb/],
        'invalid_languages' => [qw/Cookies CPData I18N Env ServerLocale/],
        'reasoning'         => \@expected_reasoning,
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_all_working: Should all match'
    );
    $overrider->reset_all();
    return 1;
}

sub check_all_fail_in_new() {
    my $overrider     = Locale::MaybeMaketext::Tests::Overrider->new();
    my $class_prefix  = 'Locale::MaybeMaketext::Detectors::Cpanel';
    my @check_classes = qw/Cookies CPData I18N Env ServerLocale/;
    my $cache         = Locale::MaybeMaketext::Cache->new();
    my $loader        = Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache );
    my $validator     = get_mocked_validator( $overrider, $cache, qw/en_gb/ );
    my $sut           = $CLASS->new(
        'cache'                   => $cache,
        'package_loader'          => $loader,
        'language_code_validator' => $validator,
    );
    local $INC{'Cpanel.pm'} = 'Faked';
    my @expected_reasoning;
    my @expected_validation;
    for my $class_to_mock (@check_classes) {
        my $full_class_to_mock = sprintf( '%s::%s', $class_prefix, $class_to_mock );
        $overrider->override(
            sprintf( '%s::%s::%s', $class_prefix, $class_to_mock, 'new' ),
            sub ( $class, %params ) {
                croak( sprintf( 'Testing of %s->new failed!', $class_to_mock ) );
            }
        );
        $overrider->override(
            sprintf( '%s::%s::%s', $class_prefix, $class_to_mock, 'run_detect' ),
            sub {
                croak( sprintf( 'Should not get to this part of %s', $class_to_mock ) );
            }
        );
        @expected_reasoning = (
            @expected_reasoning,
            (
                sprintf( 'TEST: Package Loader: Loaded %s',                 $full_class_to_mock ),
                sprintf( 'Errored: Testing of %s->new failed! =TRUNCATED=', $class_to_mock ),
                sprintf( '%s: Found 0 potential languages',                 $class_to_mock )
            )
        );
    }
    my %results = $sut->detect();
    @expected_reasoning = (
        @expected_reasoning,
        'No languages found'
    );
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => \@expected_reasoning,
    );
    my @results_reasoning;

    for ( @{ $results{'reasoning'} } ) {
        push @results_reasoning, $_ =~ s/new failed! at .*/new failed! =TRUNCATED=/gsr;
    }
    $results{'reasoning'} = \@results_reasoning;

    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_all_fail_in_new: Should all match'
    );
    $overrider->reset_all();
    return 1;
}

sub check_all_fail_in_detect() {
    my $overrider     = Locale::MaybeMaketext::Tests::Overrider->new();
    my $class_prefix  = 'Locale::MaybeMaketext::Detectors::Cpanel';
    my @check_classes = qw/Cookies CPData I18N Env ServerLocale/;
    my $cache         = Locale::MaybeMaketext::Cache->new();
    my $loader        = Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache );
    my $validator     = get_mocked_validator( $overrider, $cache, qw/en_gb/ );
    my $sut           = $CLASS->new(
        'cache'                   => $cache,
        'package_loader'          => $loader,
        'language_code_validator' => $validator,
    );
    local $INC{'Cpanel.pm'} = 'Faked';
    my @expected_reasoning;
    my @expected_validation;
    for my $class_to_mock (@check_classes) {
        my $full_class_to_mock = sprintf( '%s::%s', $class_prefix, $class_to_mock );
        $overrider->override(
            sprintf( '%s::%s::%s', $class_prefix, $class_to_mock, 'new' ),
            sub ( $class, %params ) {
                if ( $params{'cache'} != $cache ) {
                    croak( sprintf( 'Cache not passed correctly to %s', $full_class_to_mock ) );
                }
                if ( $params{'package_loader'} != $loader ) {
                    croak( sprintf( 'package_loader not passed correctly to %s', $full_class_to_mock ) );
                }
                if ( $params{'language_code_validator'} != $validator ) {
                    croak( sprintf( 'language_code_validator not passed correctly to %s', $full_class_to_mock ) );
                }
                return bless {}, $class;
            }
        );
        $overrider->override(
            sprintf( '%s::%s::%s', $class_prefix, $class_to_mock, 'run_detect' ),
            sub {
                croak( sprintf( 'Testing of %s->run_detect failed!', $class_to_mock ) );
            }
        );
        @expected_reasoning = (
            @expected_reasoning,
            (
                sprintf( 'TEST: Package Loader: Loaded %s',                        $full_class_to_mock ),
                sprintf( 'Errored: Testing of %s->run_detect failed! =TRUNCATED=', $class_to_mock ),
                sprintf( '%s: Found 0 potential languages',                        $class_to_mock )
            )
        );
    }
    my %results = $sut->detect();
    @expected_reasoning = (
        @expected_reasoning,
        'No languages found'
    );
    my %expected = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => \@expected_reasoning,
    );
    my @results_reasoning;

    for ( @{ $results{'reasoning'} } ) {
        push @results_reasoning, $_ =~ s/run_detect failed! at .*/run_detect failed! =TRUNCATED=/gsr;
    }
    $results{'reasoning'} = \@results_reasoning;

    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_all_fail_in_detect: Should all match'
    );
    $overrider->reset_all();
    return 1;
}
