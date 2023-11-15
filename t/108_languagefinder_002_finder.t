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
use Test2::Tools::Target 'Locale::MaybeMaketext::LanguageFinder';
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::LanguageCodeValidator();
use Locale::MaybeMaketext::Alternatives();
use Locale::MaybeMaketext::Supers();
use Locale::MaybeMaketext::PackageLoader();
use Locale::MaybeMaketext::Detectors::I18N();

subtest_buffered( 'check_no_optionals',             \&check_no_optionals );
subtest_buffered( 'check_optionals_with_multiples', \&check_optionals_with_multiples );
done_testing();

sub check_optionals_with_multiples() {
    my $sut = _get_sut();
    my @callback_log;
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $callback  = sub ($language) {
        push @callback_log, $language;
        if ( $language eq 'i_default' || $language eq 'en_nz' || $language eq 'tlh' ) {
            return 1;
        }
        return 0;
    };
    $overrider->override(
        'Locale::MaybeMaketext::Detectors::I18N::detect',
        sub (%settings) {
            return (
                'languages'         => [qw/de_dd en-nz fr-fx invalid/],
                'reasoning'         => [qw/Dummy languages/],
                'invalid_languages' => [],
            );
        }
    );
    my @configuration = [
        qw/provided en_gb en_us supers alternatives empty en_gb previous
          fr_fr i_klingon supers alternatives
          en_latn_gb_boont_t_extended_sequence_x_private
          Locale::MaybeMaketext::Detectors::I18N
          alternatives supers i_default die/
    ];
    my %results = $sut->finder(
        'configuration'      => @configuration,
        'callback'           => $callback,
        'previous_languages' => [qw/i-default/],
        'provided_languages' => [qw/pt-br pt/],
        'get_multiple'       => 1,
    );

    my %expected = (
        'previous_languages' => [qw/i-default/],
        'rejected_languages' => [
            qw/pt_br pt en_gb en_us en fr_fr i_klingon fr fr_fx
              en_latn_gb_boont_t_extended_sequence_x_private de_dd
              en_latn_gb_boont_t_extended_sequence de_de
              en_latn_gb_t_extended_sequence en_gb_t_extended_sequence
              en_latn_t_extended_sequence en_t_extended_sequence
              en_latn_gb en_latn de/
        ],
        'provided_languages'    => [qw/pt-br pt/],
        'invalid_languages'     => [qw/invalid/],
        'get_multiple'          => 1,
        'matched_languages'     => [qw/i_default tlh en_nz/],
        'encountered_languages' => [
            qw/pt_br pt en_gb en_us en i_default fr_fr i_klingon fr fr_fx tlh
              en_latn_gb_boont_t_extended_sequence_x_private de_dd en_nz
              en_latn_gb_boont_t_extended_sequence de_de en_latn_gb_t_extended_sequence
              en_gb_t_extended_sequence en_latn_t_extended_sequence
              en_t_extended_sequence en_latn_gb en_latn de/
        ],
        'configuration' => @configuration,
    );
    for ( sort( keys(%expected) ) ) {
        is(
            $results{$_}, $expected{$_}, sprintf( 'check_optionals_with_multiples: Checking %s', $_ ),
            'Received:',  $results{$_},  'Expected:', $expected{$_}, 'Reasoning:', $results{'reasoning'}
        );
    }
    is(
        \@callback_log,
        [
            qw/pt_br pt en_gb en_us en i_default fr_fr i_klingon fr
              fr_fx tlh en_latn_gb_boont_t_extended_sequence_x_private de_dd
              en_nz en_latn_gb_boont_t_extended_sequence de_de
              en_latn_gb_t_extended_sequence en_gb_t_extended_sequence
              en_latn_t_extended_sequence en_t_extended_sequence en_latn_gb en_latn de/
        ],
        'check_optionals_with_multiples: Checking callbacks',
        @callback_log
    );
    $overrider->reset_all();
    return 1;
}

sub check_no_optionals() {
    my $sut = _get_sut();
    my @callback_log;

    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $callback  = sub ($language) {
        push @callback_log, $language;
        if ( $language eq 'i_default' ) {
            return 1;
        }
        return 0;
    };
    $overrider->override(
        'Locale::MaybeMaketext::Detectors::I18N::detect',
        sub (%settings) {
            return (
                'languages'         => [qw/de_dd en-nz fr-fx invalid/],
                'reasoning'         => [qw/Dummy languages/],
                'invalid_languages' => [],
            );
        }
    );
    my @configuration = [
        qw/en_gb en_us supers alternatives empty fr_fr i_klingon supers alternatives Locale::MaybeMaketext::Detectors::I18N alternatives i_default die/
    ];
    my %results = $sut->finder(
        'configuration' => @configuration,
        'callback'      => $callback
    );
    my %expected = (
        'previous_languages'    => [],
        'rejected_languages'    => [qw/en_gb en_us en fr_fr i_klingon fr fr_fx tlh de_dd en_nz de_de/],
        'provided_languages'    => [],
        'invalid_languages'     => [qw/invalid/],
        'get_multiple'          => 0,
        'matched_languages'     => [qw/i_default/],
        'encountered_languages' => [qw/en_gb en_us en fr_fr i_klingon fr fr_fx tlh de_dd en_nz de_de i_default/],
        'configuration'         => @configuration,
    );
    for ( sort( keys(%expected) ) ) {
        is( $results{$_}, $expected{$_}, sprintf( 'check_no_optionals: Checking %s', $_ ), $results{$_} );
    }
    is(
        \@callback_log, [qw/en_gb en_us en fr_fr i_klingon fr fr_fx tlh de_dd en_nz de_de i_default/],
        'check_no_optionals: Checking callbacks', @callback_log
    );
    $overrider->reset_all();
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

