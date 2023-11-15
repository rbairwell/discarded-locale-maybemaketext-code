#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext::Tests::Overrider();
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests();

subtest_buffered( 'check_empty',     \&check_empty );
subtest_buffered( 'check_languages', \&check_languages );

done_testing();

sub check_empty {
    run_finder(
        'check_empty: Should be empty',
        'configuration' => [qw/alternatives/],
        'reasoning'     => [
            'Alternatives: No languages to make alternatives from',
            'Callback: Skipping as no valid languages',
            'Failed to find any language settings/configurations accepted by the callback'
        ]
    );
    return 1;

}

sub check_languages() {
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->override(
        'Locale::MaybeMaketext::Alternatives::find_alternatives',
        sub ( $class, %parts ) {
            if   ( ( $parts{'region'} || q{} ) eq 'us' ) { return qw/en_txn_latn_us invalid/ }
            else                                         { return qw/en_gb/; }
        }
    );
    run_finder(
        'check_languages: Should reject invalid languages and pass valid ones',
        'configuration'         => [qw/en-gb en-txn-latn-us alternatives/],
        'invalid_languages'     => [qw/invalid/],
        'encountered_languages' => [qw/en_gb en_txn_latn_us/],
        'rejected_languages'    => [qw/en_gb en_txn_latn_us/],
        'callbacks'             => [ 'Langcode 0: "en_gb"', 'Langcode 1: "en_txn_latn_us"' ],
        'reasoning'             => [
            sprintf( '+++ Specified: Adding "%s" as a manual language', 'en_gb' ),
            sprintf( '>>> Callback: Entering with languages: %s',       'en_gb' ),
            sprintf( '    Callback: %s: Did not return a result',       'en_gb' ),
            sprintf('<<< Callback matched 0 languages'),
            sprintf( '+++ Specified: Adding "%s" as a manual language', 'en_txn_latn_us' ),
            sprintf( '>>> Callback: Entering with languages: %s',       'en_gb, en_txn_latn_us' ),
            sprintf( '    Callback: %s: Skipping as already tried',     'en_gb' ),
            sprintf( '    Callback: %s: Did not return a result',       'en_txn_latn_us' ),
            sprintf('<<< Callback matched 0 languages'),
            sprintf( '>>> Alternatives: Entering with languages: %s',  'en_gb, en_txn_latn_us' ),
            sprintf( '    Alternatives: No alternatives found for %s', 'en_gb' ),
            sprintf(
                '    Alternatives: From %s, got the following alternatives: %s', 'en_txn_latn_us',
                'en_txn_latn_us, invalid'
            ),
            sprintf(
                '    Alternatives: Found %d potential languages: %s',
                3,    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
                'en_gb, en_txn_latn_us, invalid'
            ),
            sprintf( '    Alternatives: Language "%s" in position %d: OK', 'en_gb',          0 ),
            sprintf( '    Alternatives: Language "%s" in position %d: OK', 'en_txn_latn_us', 1 ),
            sprintf(
                '    Alternatives: Language "%s" in position %d: Language code "%s" is an invalid length (%d) - it should be between 2 and 3 inclusive',
                'invalid', 2, 'invalid', 7    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
            ),

            sprintf('<<< Alternatives: Returned validated languages same as input'),
            sprintf('Callback: Skipping as languages are the same'),
            sprintf('Failed to find any language settings/configurations accepted by the callback'),
        ]
    );
    $overrider->reset_all();
    return 1;

}

sub run_finder ( $passed_name, %option_list ) {
    return Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests::run_processor_directly(
        $passed_name,
        %option_list
    );
}
