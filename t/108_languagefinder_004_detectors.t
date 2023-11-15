#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use feature                              qw/signatures/;
no warnings qw/experimental::signatures/;
use Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests();

subtest_buffered( 'check_invalid_detectors_with_tilde',       \&check_invalid_detectors_with_tilde );
subtest_buffered( 'check_invalid_detectors_with_exclamation', \&check_invalid_detectors_with_exclamation );
subtest_buffered( 'check_invalid_detectors_default',          \&check_invalid_detectors_default );
subtest_buffered( 'check_working_detectors',                  \&check_working_detectors );

done_testing();

sub check_invalid_detectors_with_tilde() {
    for my $stage ( sort( get_invalid_detectors() ) ) {
        my %detectors = get_invalid_detectors($stage);
        for my $package ( sort( keys(%detectors) ) ) {
            my %cur_data = @{ $detectors{$package} };
            run_finder(
                sprintf( 'check_invalid_detectors_with_tilde: %s: %s', $stage, $package ),
                'configuration'                => [ sprintf( '~%s', $package ) ],
                'compare_messages_starts_with' => 1,
                'standardise_messages'         => 1,
                'message'                      => $cur_data{'message'},
                'reasoning'                    => _reasoning_for_stage(
                    'package'   => $package,
                    'label'     => 'ignore-errors',
                    'message'   => $cur_data{'message'},
                    'stage'     => $cur_data{'stage'},
                    'reasoning' => $cur_data{'reasoning'}
                )
            );
        }
    }
    return 1;
}

sub check_invalid_detectors_with_exclamation() {
    for my $stage ( sort( get_invalid_detectors() ) ) {
        my %detectors = get_invalid_detectors($stage);
        for my $package ( sort( keys(%detectors) ) ) {
            my @warnings = ();
            my $loaded   = 1;
            my %cur_data = @{ $detectors{$package} };
            if ( defined( $cur_data{'precheck_warnings'} ) ) {
                @warnings = @{ $cur_data{'precheck_warnings'} };
            }
            if ( defined( $cur_data{'findercheck_warnings'} ) ) {
                for ( @{ $cur_data{'findercheck_warnings'} } ) {
                    push @warnings, sprintf( 'Detector %s (warn-errors): %s', $package, $_ );
                }
            }
            for ( @{ $cur_data{'warnings'} } ) {
                push @warnings, sprintf( 'Detector %s (warn-errors): %s', $package, $_ );
            }

            run_finder(
                sprintf( 'check_invalid_detectors_with_exclamation: %s: %s', $stage, $package ),
                'configuration'                => [ sprintf( '!%s', $package ) ],
                'warnings'                     => \@warnings,
                'message'                      => $cur_data{'message'},
                'compare_messages_starts_with' => 1,
                'standardise_messages'         => 1,
                'reasoning'                    => _reasoning_for_stage(
                    'package'   => $package,
                    'label'     => 'warn-errors',
                    'message'   => $cur_data{'message'},
                    'stage'     => $cur_data{'stage'},
                    'reasoning' => $cur_data{'reasoning'}
                )
            );
        }
    }
    return 1;
}

sub check_invalid_detectors_default() {
    for my $stage ( sort( get_invalid_detectors() ) ) {
        my %detectors = get_invalid_detectors($stage);
        for my $package ( sort( keys(%detectors) ) ) {
            my @warnings = ();
            my $loaded   = 1;
            my %cur_data = @{ $detectors{$package} };
            run_finder(
                sprintf( 'check_invalid_detectors_default: %s: %s', $stage, $package ),
                'configuration' => [ sprintf( '%s', $package ) ],
                'dies'          => (
                    $cur_data{'dies'} ? sprintf( 'Detector %s (default): %s', $package, $cur_data{'dies'} ) : undef
                ),
                'message'                      => $cur_data{'message'},
                'compare_messages_starts_with' => 1,
                'standardise_messages'         => 1,
                'reasoning'                    => _reasoning_for_stage(
                    'package'   => $package,
                    'label'     => 'default',
                    'message'   => $cur_data{'message'},
                    'stage'     => $cur_data{'stage'},
                    'reasoning' => $cur_data{'reasoning'}
                )
            );
        }
    }
    return 1;
}

sub check_working_detectors() {
    my %detectors = get_working_detectors();
    for my $package ( sort( keys(%detectors) ) ) {
        my %cur_data = @{ $detectors{$package} };
        my %settings = (
            'configuration'                => [ sprintf( '%s', $package ) ],
            'compare_messages_starts_with' => 1,
            'standardise_messages'         => 1,
        );

        for ( keys(%cur_data) ) {
            if ( !defined( $settings{$_} ) ) {
                $settings{$_} = $cur_data{$_};
            }
        }
        run_finder( sprintf( 'check_working_detectors: %s', $package ), %settings );
    }
    return 1;
}

sub _reasoning_for_stage (%params) {
    for (qw/package label message stage/) {
        if ( !defined( $params{$_} ) ) {
            my @diag;
            for ( sort keys(%params) ) {
                push @diag, sprintf( 'Key: %s = %s', $_, $params{$_} );
            }
            fail( sprintf( 'Missing parameter: "%s" in call to _reasoning_for_stage', $_ ), @diag );
        }
    }
    my $package            = $params{'package'};
    my $label              = $params{'label'};
    my $message            = $params{'message'};
    my $stage              = $params{'stage'};
    my @returned_reasoning = ();
    if ( defined( $params{'reasoning'} ) ) {
        @returned_reasoning = @{ $params{'reasoning'} };
    }
    if ( $stage ne 'loading' && $stage ne 'processing' && $stage ne 'results' ) {
        fail( sprintf( 'Invalid stage: %s', $stage ) );
    }

    my @reasoning = ( sprintf( '>>> Detector %s (%s): Starting detector', $package, $label ) );
    if ( $stage eq 'loading' ) {
        push @reasoning, sprintf( 'XXX Detector %s (%s): During loading: %s', $package, $label, $message );
    }
    else {
        push @reasoning, sprintf( '    Detector %s (%s): Package loaded', $package, $label );
    }
    for (@returned_reasoning) {
        push @reasoning,
          sprintf( '    Detector %s (%s): Reasoning: %s', $package, $label, $_ );
    }
    if ( $stage eq 'processing' ) {
        push @reasoning,
          sprintf( 'XXX Detector %s (%s): During processing: %s', $package, $label, $message );
    }
    if ( $stage eq 'results' ) {
        push @reasoning,
          sprintf( 'XXX Detector %s (%s): During results processing: %s', $package, $label, $message );
    }
    @reasoning = (
        @reasoning,
        sprintf( '<<< Detector %s (%s): Exiting due to fault', $package, $label ),
        sprintf('Callback: Skipping as no valid languages'),
        sprintf('Failed to find any language settings/configurations accepted by the callback'),
    );
    return \@reasoning;
}

sub get_invalid_detectors ( $specifics = undef ) {
    return Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests::get_invalid_detectors($specifics);
}

sub get_working_detectors ( ) {
    return Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests::get_working_detectors();
}

sub run_finder ( $passed_name, %option_list ) {
    return Locale::MaybeMaketext::Tests::LanguageFinderProcessorTests::run_finder(
        $passed_name,
        %option_list
    );
}
