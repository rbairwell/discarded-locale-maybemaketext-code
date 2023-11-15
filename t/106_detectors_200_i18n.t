#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext::Tests::Overrider();
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::I18N';
use Locale::MaybeMaketext::LanguageCodeValidator();
use Locale::MaybeMaketext::Cache();

subtest_buffered( 'check_call_params', \&check_call_params );
subtest_buffered( 'check_maintests',   \&check_maintests );
done_testing();

sub check_call_params() {
    my $code          = sub() { };
    my $dummy_blessed = bless {}, 'DummyTesting';
    my $returned_object;
    my %needed = ( 'language_code_validator' =>
          Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => Locale::MaybeMaketext::Cache->new() ) );
    my %built      = ();
    my $copy_built = sub ( $key, $new ) {
        my %return;
        for ( keys(%built) ) { $return{$_} = $built{$_}; }
        $return{$key} = $new;
        return \%return;
    };
    my @tests = (
        {
            'params'  => {},
            'message' => 'Missing needed configuration setting "language_code_validator"',
            'reason'  => 'Missing configuration settings',
        },
    );
    for my $key ( sort keys(%needed) ) {
        push @tests, {
            'params'  => $copy_built->( $key, 'abc' ),
            'message' =>
              sprintf( 'Configuration setting "%s" must be a blessed object: instead got %s', $key, 'scalar:abc' ),
            'reason' => sprintf( 'Checking %s is rejected if scalar', $key ),
          },
          {
            'params'  => $copy_built->( $key, $code ),
            'message' => sprintf( 'Configuration setting "%s" must be a blessed object: instead got %s', $key, 'CODE' ),
            'reason'  => sprintf( 'Checking %s is rejected if code', $key ),
          },
          {
            'params'  => $copy_built->( $key, $dummy_blessed ),
            'message' => sprintf(
                'Configuration setting "%s" must be an instance of "%s": got "%s"',
                $key,
                ref( $needed{$key} ),
                'DummyTesting'
            ),
            'reason' => sprintf( 'Checking %s is rejected if incorrect instance', $key ),
          };
        $built{$key} = $needed{$key};
    }
    for my $index ( 0 ... $#tests ) {
        my %test_data = %{ $tests[$index] };
        my %params    = %{ $test_data{'params'} };
        my $dies      = dies {
            $returned_object = undef;
            $returned_object = Locale::MaybeMaketext::Detectors::I18N::detect(%params);
        };
        starts_with(
            $dies,
            $test_data{'message'},
            sprintf( 'check_call_params: %s',     $test_data{'reason'} ),
            sprintf( 'Original dies message: %s', $dies ),
            sprintf( 'Expected dies message: %s', $test_data{'message'} )
        );

        is(
            $returned_object, undef,
            sprintf( 'check_call_params: %s: Should not have returned an object', $test_data{'reason'} )
        );
    }
    return 1;
}

sub check_maintests() {
    my $overrider    = Locale::MaybeMaketext::Tests::Overrider->new();
    my %sut_settings = ( 'language_code_validator' =>
          Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => Locale::MaybeMaketext::Cache->new() ) );
    $overrider->override(
        'I18N::LangTags::Detect::detect',
        sub : prototype() { return qw/en_us en i-something i-default fr_fr/; }
    );
    my %expected = (
        'languages' => [qw/en_us en i_default fr_fr/],
        'reasoning' => [
            'I18N::LangTags::Detect::detect returned 5 languages',
            'Language "en_us" in position 0: OK',
            'Language "en" in position 1: OK',
            'Language "i-something" in position 2: Failed regular expression match',
            'Language "i-default" in position 3: OK',
            'Language "fr_fr" in position 4: OK',

        ],
        'invalid_languages' => ['i-something'],
    );
    my %results = Locale::MaybeMaketext::Detectors::I18N::detect(%sut_settings);
    is( \%results, \%expected, 'i18n: Should match expected with overridden subroutine' );
    $overrider->reset_all();
    return 1;
}
