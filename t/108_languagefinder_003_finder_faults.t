#!perl
## no critic (RegularExpressions::ProhibitComplexRegexes)
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use feature                              qw/signatures/;
no warnings qw/experimental::signatures/;
use Test2::Tools::Target 'Locale::MaybeMaketext::LanguageFinder';
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::LanguageCodeValidator();
use Locale::MaybeMaketext::Alternatives();
use Locale::MaybeMaketext::Supers();
use Locale::MaybeMaketext::PackageLoader();

subtest_buffered( 'check_blessed_only',        \&check_blessed_only );
subtest_buffered( 'check_configuration_array', \&check_configuration_array );

subtest_buffered( 'check_provided_languages', \&check_provided_languages );
subtest_buffered( 'check_previous_languages', \&check_previous_languages );
subtest_buffered( 'check_callback',           \&check_callback );
subtest_buffered( 'check_get_multiple',       \&check_get_multiple );
subtest_buffered( 'check_bad_configuration',  \&check_bad_configuration );
subtest_buffered( 'check_call_syntax',        \&check_call_syntax );
done_testing();

sub check_call_syntax() {
    like(
        dies {
            Locale::MaybeMaketext::LanguageFinder::finder( 'test', 'test' => 'test' );
        } || 'Did not die',
        qr/\Afinder should only be called via a blessed object/,
        'check_call_syntax: finder'
    );
    return 1;
}

sub check_bad_configuration() {
    my $sut = _get_sut();
    like(
        dies {
            $sut->finder(
                'configuration'      => [qw/die empty fr/],
                'callback'           => sub { },
                'provided_languages' => [],
                'get_multiple'       => 0
            );
        } || 'Did not die',
        qr/\AInvalid position of keyword "die": it must be in the last position if used/,
        'check_bad_configuration: die used in first position'
    );

    # check we have restored it and appropriate checks are carried out.
    like(
        dies {
            $sut->finder(
                'configuration'      => ['en_cdcdcdcdsdssds'],
                'callback'           => sub { },
                'provided_languages' => [],
                'get_multiple'       => 0
            );
        } || 'Did not die',
        qr/\AInvalid looking language passed: "en_cdcdcdcdsdssds" - Failed regular expression match \(found in position 1 of 1\)/,
        'check_bad_configuration: Mismatched contents'
    );
    return 1;
}

sub check_get_multiple() {
    my $sut = _get_sut();
    my $msg =
        'finder parameter "get_multiple" needs to be passed in as either 1 '
      . '(to get multiple) or 0/undefined (to stop on singular match)';

    # get_multiple is optional
    like(
        dies {
            $sut->finder(
                'configuration' => [], 'callback' => sub { }, 'provided_languages' => [],
                'get_multiple'  => 'hello'
            );
        } || 'Did not die',
        qr/\A\Q$msg\E/,
        'check_get_multiple: Passed in scalar'
    );
    like(
        dies {
            $sut->finder(
                'configuration' => [], 'callback' => sub { }, 'provided_languages' => [],
                'get_multiple'  => 2
            );
        } || 'Did not die',
        qr/\A\Q$msg\E/,
        'check_get_multiple: Passed in invalid parameter'
    );
    return 1;
}

sub check_callback() {
    my $sut = _get_sut();
    like(
        dies {
            $sut->finder(
                'callback'      => 'tester',
                'configuration' => [], 'provided_languages' => []
            );
        } || 'Did not die',
        qr/\Afinder parameter "callback", if used, needs to be set as code/,
        'check_callback: Passed in scalar'
    );
    return 1;
}

sub check_previous_languages() {
    my $sut = _get_sut();

    # previous languages are optional
    like(
        dies {
            $sut->finder(
                'configuration'      => [], 'callback' => sub { }, 'provided_languages' => [],
                'previous_languages' => 'hello'
            );
        } || 'Did not die',
        qr/\Afinder parameter "previous_languages" needs to be passed in either as undefined or as an array/,
        'check_previous_languages: Passed in scalar'
    );
    return 1;
}

sub check_provided_languages() {
    my $sut = _get_sut();

    # provided languages are optional
    like(
        dies {
            $sut->finder( 'configuration' => [], 'callback' => sub { }, 'provided_languages' => 'hello' );
        } || 'Did not die',
        qr/\Afinder parameter "provided_languages" needs to be passed in either as undefined or as an array/,
        'check_provided_languages: Passed in scalar'
    );
    return 1;
}

sub check_configuration_array() {
    my $sut = _get_sut();
    like(
        dies {
            $sut->finder( 'a' => 'b', 'c' => 'd', 'callback' => sub { }, 'provided_languages' => [] );
        } || 'Did not die',
        qr/\Afinder parameter "configuration" needs to be set as an array/,
        'check_configuration_array: No configuration'
    );
    like(
        dies {
            $sut->finder( 'configuration' => 'hello', 'callback' => sub { }, 'provided_languages' => [] );
        } || 'Did not die',
        qr/\Afinder parameter "configuration" needs to be set as an array/,
        'check_configuration_array: Passed in scalar'
    );
    return 1;
}

sub check_blessed_only() {
    my $expect = 'Odd name/value argument for subroutine \'Locale::MaybeMaketext::LanguageFinder::finder\' at';
    my $dies   = dies { Locale::MaybeMaketext::LanguageFinder::finder( 'a' => 'b', 'c' => 'd' ); } || 'Did not die';
    starts_with(
        $dies, $expect, 'check_blessed_only: Singleton: Check with just parameters',
        'Got', $dies,   'Expected', $expect
    );
    $expect = 'finder should only be called via a blessed object';
    $dies =
      dies { Locale::MaybeMaketext::LanguageFinder::finder( $CLASS, 'a' => 'b', 'c' => 'd' ); } || 'Did not die';
    starts_with(
        $dies, $expect, 'check_blessed_only: Singleton: Pass in fake class name',
        'Got', $dies,   'Expected', $expect
    );

    return 1;
}

sub _get_sut() {
    my $cache     = Locale::MaybeMaketext::Cache->new();
    my $validator = Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache );
    return $CLASS->new(
        'language_code_validator' => $validator,
        'alternatives'            => Locale::MaybeMaketext::Alternatives->new( 'cache' => $cache ),
        'supers'                  => Locale::MaybeMaketext::Supers->new( 'language_code_validator' => $validator ),
        'package_loader'          => Locale::MaybeMaketext::PackageLoader->new( 'cache' => $cache ),
        'cache'                   => $cache,
    );
}

