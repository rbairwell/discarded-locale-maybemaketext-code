#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use feature                            qw/signatures/;
no warnings qw/experimental::signatures/;
use Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests();

subtest_buffered( 'check_empty',             \&check_empty );
subtest_buffered( 'check_grandfathered',     \&check_grandfathered );
subtest_buffered( 'check_long_valid_supers', \&check_long_valid_supers );

done_testing();

sub check_empty {
    run_finder(
        'check_empty: Should be empty',
        'configuration' => [qw/supers/],
        'reasoning'     => [
            'Supers: No languages to make supers from',
            'Callback: Skipping as no valid languages',
            'Failed to find any language settings/configurations accepted by the callback'
        ]
    );
    return 1;
}

sub check_grandfathered {
    my @grandfathered = qw/en_gb_oed sgn_be_ft sgn_be_nl sgn-ch-de i_ami i-bnn i-default i-enochian i-hak zh-xiang/;
    for my $grand (@grandfathered) {
        my $to_match = ( lc( $grand =~ tr{-}{_}r ) =~ s/\s//gr );
        run_finder(
            sprintf( 'check_grandfathered: %s should not be touched', $grand ),
            'configuration'         => [ $grand, 'supers' ],
            'encountered_languages' => [$to_match],
            'rejected_languages'    => [$to_match],
            'callbacks'             => [ sprintf( 'Langcode 0: "%s"', $to_match ) ],
            'reasoning'             => [
                sprintf( '+++ Specified: Adding "%s" as a manual language', $to_match ),
                sprintf( '>>> Callback: Entering with languages: %s',       $to_match ),
                sprintf( '    Callback: %s: Did not return a result',       $to_match ),
                sprintf('<<< Callback matched 0 languages'),
                sprintf( '>>> Supers: Entering with languages %s', $to_match ),
                sprintf(
                    '    Supers: Whilst making supers: Language "%s" cannot have its "supers" extracted', $to_match
                ),
                sprintf( '    Supers: After making supers: Language "%s" in position 0: OK', $to_match ),
                sprintf(
                    '    Supers: From 1 languages generated 1 potential supers - of which 1 were valid looking unique languages and 0 were invalid'
                ),
                sprintf( '    Supers: Languages remained the same: %s', $to_match ),
                sprintf('<<< Supers: Exiting'),
                sprintf('Callback: Skipping as languages are the same'),
                sprintf('Failed to find any language settings/configurations accepted by the callback')
            ]
        );
    }
    return 1;
}

sub check_long_valid_supers {
    my @language_list = qw/en_brm_latn_gb_t_0thex_varin3a_u_some_x_test
      en_latn_gb_t_0thex_varin3a_u_some_x_test
      en_brm_gb_t_0thex_varin3a_u_some_x_test
      en_brm_latn_t_0thex_varin3a_u_some_x_test
      en_brm_latn_gb_t_0thex_varin3a_x_test
      en_gb_t_0thex_varin3a_u_some_x_test
      en_latn_t_0thex_varin3a_u_some_x_test
      en_brm_t_0thex_varin3a_u_some_x_test
      en_brm_latn_gb_t_0thex_varin3a_u_some
      en_brm_latn_gb_u_some_x_test
      en_latn_gb_t_0thex_varin3a_x_test
      en_brm_gb_t_0thex_varin3a_x_test
      en_brm_latn_t_0thex_varin3a_x_test
      en_t_0thex_varin3a_u_some_x_test
      en_latn_gb_t_0thex_varin3a_u_some
      en_brm_gb_t_0thex_varin3a_u_some
      en_brm_latn_t_0thex_varin3a_u_some
      en_latn_gb_u_some_x_test
      en_brm_gb_u_some_x_test
      en_gb_t_0thex_varin3a_x_test
      en_brm_latn_u_some_x_test
      en_latn_t_0thex_varin3a_x_test
      en_brm_t_0thex_varin3a_x_test
      en_brm_latn_gb_t_0thex_varin3a
      en_gb_t_0thex_varin3a_u_some
      en_latn_t_0thex_varin3a_u_some
      en_brm_t_0thex_varin3a_u_some
      en_gb_u_some_x_test
      en_latn_u_some_x_test
      en_brm_u_some_x_test
      en_t_0thex_varin3a_x_test
      en_brm_latn_gb_x_test
      en_brm_latn_gb_u_some
      en_latn_gb_t_0thex_varin3a
      en_brm_gb_t_0thex_varin3a
      en_brm_latn_t_0thex_varin3a
      en_t_0thex_varin3a_u_some
      en_u_some_x_test
      en_latn_gb_x_test
      en_brm_gb_x_test
      en_brm_latn_x_test
      en_latn_gb_u_some
      en_brm_gb_u_some
      en_gb_t_0thex_varin3a
      en_brm_latn_u_some
      en_latn_t_0thex_varin3a
      en_brm_t_0thex_varin3a
      en_gb_x_test
      en_latn_x_test
      en_brm_x_test
      en_gb_u_some
      en_latn_u_some
      en_brm_u_some
      en_t_0thex_varin3a
      en_brm_latn_gb
      en_x_test
      en_u_some
      en_latn_gb
      en_brm_gb
      en_brm_latn
      en_gb
      en_latn
      en_brm
      en/;
    my @expected_callbacks;
    my $index = 0;

    my $to_match           = 'en_brm_latn_gb_t_0thex_varin3a_u_some_x_test';    # note ordering
    my @expected_reasoning = (
        sprintf( '+++ Specified: Adding "%s" as a manual language', $to_match ),
        sprintf( '>>> Callback: Entering with languages: %s',       $to_match ),
        sprintf( '    Callback: %s: Did not return a result',       $to_match ),
        sprintf('<<< Callback matched 0 languages'),
        sprintf( '>>> Supers: Entering with languages %s', $to_match ),
    );
    my @reasonings_callback = ('    Callback: en_brm_latn_gb_t_0thex_varin3a_u_some_x_test: Skipping as already tried');
    for (@language_list) {
        push @expected_callbacks, sprintf( 'Langcode %d: "%s"', $index, $_ );
        push @expected_reasoning,
          sprintf( '    Supers: After making supers: Language "%s" in position %d: OK', $_, $index );
        if ( $index != 0 ) {
            push @reasonings_callback, sprintf( '    Callback: %s: Did not return a result', $_ );
        }
        $index++;
    }
    my $joined_langs = join( q{, }, @language_list );

    @expected_reasoning = (
        @expected_reasoning,
        (
            sprintf(
                '    Supers: From 1 languages generated %d potential supers - of which %d were valid looking unique languages and 0 were invalid',
                $index, $index
            ),
            '--- Supers: Removing existing languages: en_brm_latn_gb_t_0thex_varin3a_u_some_x_test',
            sprintf( '+++ Supers: Replacing languages with: %s', $joined_langs ),
            '<<< Supers: Exiting',
            sprintf( '>>> Callback: Entering with languages: %s', $joined_langs ),
        ),
        @reasonings_callback,
        (
            '<<< Callback matched 0 languages',
            'Failed to find any language settings/configurations accepted by the callback'
        ),
    );
    run_finder(
        'check_long_valid_supers: Should be processed',
        'configuration' => [qw/en_brm_latn_gb_t_varin3a_0thex_u_some_x_test supers/], # note slightly different ordering
        'encountered_languages' => \@language_list,
        'rejected_languages'    => \@language_list,
        'callbacks'             => \@expected_callbacks,
        'reasoning'             => \@expected_reasoning
    );
    return 1;
}

sub run_finder ( $passed_name, %option_list ) {
    return Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests::run_processor_directly(
        $passed_name,
        %option_list
    );
}
