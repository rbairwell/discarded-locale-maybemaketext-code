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
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::Http';
use Locale::MaybeMaketext::LanguageCodeValidator();
use Locale::MaybeMaketext::Cache();

subtest_buffered( 'check_call_params',             \&check_call_params );
subtest_buffered( 'check_no_http_accept_language', \&check_no_http_accept_language );
subtest_buffered( 'check_maintests',               \&check_maintests );
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
            $returned_object = Locale::MaybeMaketext::Detectors::Http::detect(%params);
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

sub check_no_http_accept_language() {
    my ( %results, @expected_langs, @expected_reasoning, $sut_desc );
    my %sut_settings = ( 'language_code_validator' =>
          Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => Locale::MaybeMaketext::Cache->new() ) );

    # test No HTTP_ACCEPT_LANGUAGE
    $sut_desc = "$CLASS: No language env. ";
    undef $ENV{'HTTP_ACCEPT_LANGUAGE'};
    @expected_langs     = ();
    @expected_reasoning = ('No HTTP_ACCEPT_LANGUAGE environment set');
    %results            = Locale::MaybeMaketext::Detectors::Http::detect(%sut_settings);
    is( \@{ $results{'languages'} }, \@expected_langs,     $sut_desc . 'Languages should be empty' );
    is( \@{ $results{'reasoning'} }, \@expected_reasoning, $sut_desc . 'Reasoning should state no env.' );
    return 1;
}

sub check_maintests() {
    my ( %results, @expected_langs, @expected_reasoning, $sut_desc );
    my %sut_settings = ( 'language_code_validator' =>
          Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => Locale::MaybeMaketext::Cache->new() ) );
    my @test_provider = (
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Empty test "%s"',
            'source' => 'https://metacpan.org/release/YAPPO/HTTP-AcceptLanguage-0.02/source/t/01_languages.t',
            'accept' => q{},
            'expect' => q{},
            'failed' => q{},
        },
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Format error "%s"',
            'accept' => 'q=1',
            'expect' => q{},
            'failed' => 'q=1',
        },
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Language tag error "%s"',
            'accept' => q{!!},
            'expect' => q{},
            'failed' => q{!!},
        },
        {
            'accept' => 'en-!^',
            'expect' => q{},
            'failed' => 'en_!^',
        },
        {
            'accept' => '&^-~!',
            'expect' => q{},
            'failed' => '&^_~!',
        },
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Zero quality test "%s"',
            'accept' => 'en;q=0',
            'expect' => q{},
            'failed' => 'en',
        },
        {
            'accept' => 'en-us;q=0,ja;q=0,foo-bar-baz;q=0',
            'expect' => q{},
            'failed' => 'en_us ja foo_bar_baz',
        },
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Simple test "%s"',
            'accept' => 'en',
            'expect' => 'en'
        },
        {
            'accept' => 'en-US',
            'expect' => 'en_us'
        },
        {
            'accept' => q{*},
            'expect' => q{},
            'failed' => q{*},
        },
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Quality test "%s"',
            'accept' => 'en, ja;q=0.3, da;q=1',
            'expect' => 'en da ja'
        },
        {
            'accept' => 'en, ja;q=0.3, da;q=1, *;q=0.29, ch-tw',
            'expect' => 'en da ch_tw ja',
            'failed' => q{*},
        },
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Duplicate language test "%s"',
            'accept' => 'en, ja;q=0.3, en=0.1',
            'expect' => 'en ja',
            'failed' => 'en=0.1',
        },
        {
            'accept' => 'en, ja;q=0.3, en=0.1, en;q=1, en;q=1.0, en;q=1.00, en;q=1.000, en;q=1',
            'expect' => 'en ja',
            'failed' => 'en=0.1',
        },
        {
            'accept' => 'en;q=0.4, ja;q=0.3, ja;q=0.45, en;q=0.42, ja;q=0.1',
            'expect' => 'ja en'
        },
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Loose test "%s"',
            'accept' =>
              "en   \t , en;q=1., aaaaaaaaaaaaaaaaa, s.....dd, po;q=asda,\nja \t   ;  \t   q \t  =  \t  0.3, da;q=1.\t\t\t,  de;q=0.",
            'expect' => 'en po da ja',
            'failed' => 'aaaaaaaaaaaaaaaaa s.....dd de',
        },
        {
            'name'   => 'YAPPO/HTTP-Accept-Language: Special tags "%s"',
            'accept' => 'de-1996',
            'expect' => 'de_1996'
        },

        #{ # I don't believe this is a valid language tag.
        #    'accept' => 'luna1918',
        #    'expect' => 'luna1918'
        #},
        {
            'name'   => 'SupportPal Accept Language Parser Test "%s"',
            'source' => 'https://github.com/supportpal/accept-language-parser/blob/master/test/ParserTest.php',
            'accept' => 'en-GB;q=0.8',
            'expect' => 'en_gb'
        },
        {
            'accept' => 'en-GB',
            'expect' => 'en_gb'
        },
        {
            'accept' => 'en;q=0.8',
            'expect' => 'en'
        },
        {
            'accept' => 'az-AZ',
            'expect' => 'az_az'
        },
        {
            'accept' => 'fr-CA,fr;q=0.8',
            'expect' => 'fr_ca fr'
        },
        {
            'accept' => 'fr-150',
            'expect' => 'fr_150',
        },
        {
            'accept' => 'fr-CA,fr;q=0.8,en-US;q=0.6,en;q=0.4,*;q=0.1',
            'expect' => 'fr_ca fr en_us en',
            'failed' => q{*},
        },
        {
            'accept' => 'fr-CA, fr;q=0.8,  en-US;q=0.6,en;q=0.4,    *;q=0.1',
            'expect' => 'fr_ca fr en_us en',
            'failed' => q{*},
        },
        {
            'accept' => 'zh-Hant-cn;q=1, zh-cn;q=0.6, zh;q=0.4',
            'expect' => 'zh_hant_cn zh_cn zh'
        },
        {
            'name'   => 'MDN\'s examples of languages "%s"',
            'source' => 'https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Language',
            'accept' => 'fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5',
            'expect' => 'fr_ch fr en de',
            'failed' => q{*},
        },
    );
    my ( $joined, $joined_failures, $first_reasoning, %test_data, $last_encountered_name );
    for (@test_provider) {
        %test_data = %{$_};
        if ( defined( $test_data{'name'} ) ) {
            $last_encountered_name = $test_data{'name'};
        }
        $sut_desc = sprintf( '%s: ' . $last_encountered_name, $CLASS, $test_data{'accept'} );
        local $ENV{'HTTP_ACCEPT_LANGUAGE'} = $test_data{'accept'};
        %results = Locale::MaybeMaketext::Detectors::Http::detect(%sut_settings);
        $joined  = join( q{ }, @{ $results{'languages'} } );
        my $has_failures = scalar @{ $results{'invalid_languages'} } > 0;
        $joined_failures = $has_failures ? join( q{ }, @{ $results{'invalid_languages'} } ) : q{};
        $first_reasoning = $results{'reasoning'}[0] // q{};

        if (   ( $joined eq $test_data{'expect'} )
            && ( !defined( $test_data{'failed'} ) || $joined_failures eq $test_data{'failed'} )
            && ( $first_reasoning eq 'Processing HTTP_ACCEPT_LANGUAGE: ' . $test_data{'accept'} ) ) {
            pass( $sut_desc . '. Passed all tests' );
            if ( !defined( $test_data{'failed'} ) && $has_failures ) {
                note("Please consider adding the following 'failed' data: $joined_failures");
            }
        }
        else {
            is( $joined, $test_data{'expect'}, $sut_desc . '. Languages should match', %results{'reasoning'} );

            if ( defined( $test_data{'failed'} ) ) {

                is(
                    $joined_failures, $test_data{'failed'}, $sut_desc . '. Invalid languages should match',
                    %results{'reasoning'}
                );
            }
            elsif ($has_failures) {
                note("Please consider adding the following 'failed' data: $joined_failures");
            }
            is(
                $first_reasoning, 'Processing HTTP_ACCEPT_LANGUAGE: ' . $test_data{'accept'},
                $sut_desc . '. First reasoning line should be our input'
            );
        }
    }
    return 1;
}
