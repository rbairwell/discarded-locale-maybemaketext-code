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
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::Cpanel::I18N';
use Locale::MaybeMaketext::Tests::DetectorCpanelBase
  qw/do_cpanel_detector_compare check_detect_call check_new get_sut_for_class/;

# These tests all mock the cPanel code so should be safe to use with or without cPanel.
subtest_buffered( 'check_new',         sub () { check_new($CLASS); } );
subtest_buffered( 'check_detect_call', sub () { check_detect_call($CLASS); } );

# these require Cpanel
SKIP: {
    if ( !eval { require Cpanel::CPAN::Locale::Maketext::Utils; 1; } ) {
        skip(
            sprintf(
                'Does not appear to be a cPanel server (Cpanel::CPAN::Locale::Maketext::Utils: Not available): %s', $@
            )
        );
    }
    subtest_buffered( 'check_i18n_langtags_http', \&check_i18n_langtags_http );
    subtest_buffered( 'check_i18n_langtags_cgi',  \&check_i18n_langtags_cgi );
}
done_testing();

sub check_i18n_langtags_http() {
    my %results;
    local $INC{'Cpanel.pm'} = 'Faked';
    my $sut        = get_sut_for_class($CLASS);
    my @http_langs = (
        {
            'accept'            => 'fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5',
            'description'       => 'Example http accept lang',
            'invalid_languages' => [],
            'languages'         => [qw/fr_ch fr en de/],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',
                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 4 languages',
                'Found 4 languages: fr-ch, fr, en, de',
                'Language "fr-ch" in position 0: OK',
                'Language "fr" in position 1: OK',
                'Language "en" in position 2: OK',
                'Language "de" in position 3: OK',
            ]
        },
        {
            'accept'            => 'en;q=0.8, fr-CH, de;q=0.9, fr;q=0.7, *;q=0.5,zh-Hans;q=0.4',
            'description'       => 'Badly formatted http accept lang',
            'invalid_languages' => [],
            'languages'         => [qw/fr_ch de en fr zh_hans/],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',
                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 5 languages',
                'Found 5 languages: fr-ch, de, en, fr, zh-hans',
                'Language "fr-ch" in position 0: OK',
                'Language "de" in position 1: OK',
                'Language "en" in position 2: OK',
                'Language "fr" in position 3: OK',
                'Language "zh-hans" in position 4: OK',
            ]
        },
        {
            'accept'            => 'en',
            'description'       => 'Single language',
            'invalid_languages' => [],
            'languages'         => ['en'],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',
                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 1 languages',
                'Found 1 languages: en',
                'Language "en" in position 0: OK',
            ]
        },
        {
            'accept'            => q{},
            'description'       => 'Empty accept',
            'invalid_languages' => [],
            'languages'         => [],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',
                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 0 languages',
                'No languages found'
            ]
        },
        {
            'accept'            => undef,
            'description'       => 'Undefined accept',
            'invalid_languages' => [],
            'languages'         => [],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',
                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 0 languages',
                'No languages found'
            ]
        },
        {
            'accept'            => 'fr-CH, fr;q=0.2, madeupstuff, en-xx, en;q=0.8, de;q=0.7, xx, *;q=0.5, qab',
            'description'       => 'Example http accept lang with faulty bits',
            'invalid_languages' => [qw/madeupstuff en-xx qab/],
            'languages'         => [qw/fr_ch xx en de fr/],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',

                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 8 languages',
                'Found 8 languages: fr-ch, madeupstuff, en-xx, xx, qab, en, de, fr',
                'Language "fr-ch" in position 0: OK',
                'Language "madeupstuff" in position 1: Language code "madeupstuff" is an invalid length (11) - it should be between 2 and 3 inclusive',
                'Language "en-xx" in position 2: Region code "xx" is reserved for private use only',
                'Language "xx" in position 3: OK',
                'Language "qab" in position 4: Language codes qaa-qtz are reserved for private use only - includes "qab"',
                'Language "en" in position 5: OK',
                'Language "de" in position 6: OK',
                'Language "fr" in position 7: OK',
            ]
        },
    );
    for my $request_method (qw/GET POST/) {
        local $ENV{'REQUEST_METHOD'} = $request_method;
        for (@http_langs) {
            my %expected = %{$_};
            local $ENV{'HTTP_ACCEPT_LANGUAGE'} = $expected{'accept'};
            %results = $sut->detect();
            do_cpanel_detector_compare(
                \%results, \%expected,
                sprintf( 'check_i18n_langtags_http: %s: %s', $request_method, $expected{'description'} )
            );
        }
    }
    return 1;
}

sub check_i18n_langtags_cgi() {

    local $INC{'Cpanel.pm'} = 'Faked';
    my $sut = get_sut_for_class($CLASS);
    my %results;
    my @cgi_langs = (
        {
            'langcode'          => 'en_US.UTF-8',
            'description'       => 'American',
            'invalid_languages' => [],
            'languages'         => [qw/en_us/],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',

                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 1 languages',
                'Found 1 languages: en-us',
                'Language "en-us" in position 0: OK',
            ]
        },
        {
            'langcode'          => 'pt_BR',
            'description'       => 'Brazilian',
            'invalid_languages' => [],
            'languages'         => [qw/pt_br/],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',

                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 1 languages',
                'Found 1 languages: pt-br',
                'Language "pt-br" in position 0: OK',
            ]
        },
        {
            'langcode'          => 'it_IT.utf8@euro',
            'description'       => 'Italian',
            'invalid_languages' => [],
            'languages'         => [qw/it_it/],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',

                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 1 languages',
                'Found 1 languages: it-it',
                'Language "it-it" in position 0: OK',
            ]
        },
        {
            'langcode'          => 'C',
            'description'       => 'Undefined "C" language',
            'invalid_languages' => [],
            'languages'         => [],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',

                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 0 languages',
                'No languages found',
            ]
        },
        {
            'langcode'          => 'totalgarbage',
            'description'       => 'Total garbage',
            'invalid_languages' => [],
            'languages'         => [],
            'reasoning'         => [
                'TEST: Package Loader: Loaded Cpanel::CPAN::I18N::LangTags::Detect',

                'Cpanel::CPAN::I18N::LangTags::Detect::detect returned 0 languages',
                'No languages found',
            ]
        },
    );
    for my $env (qw/LANGUAGE LC_ALL LC_MESSAGES LANG/) {
        for (@cgi_langs) {
            my %expected = %{$_};
            local $ENV{$env} = $expected{'langcode'};
            %results = $sut->detect();
            do_cpanel_detector_compare(
                \%results, \%expected,
                sprintf( 'check_i18n_langtags_cgi: %s: %s', $env, $expected{'description'} )
            );
        }
    }
    return 1;
}
