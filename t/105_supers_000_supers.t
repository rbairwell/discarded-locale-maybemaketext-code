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
use Test2::Tools::Target 'Locale::MaybeMaketext::Supers';
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::Supers();
use Locale::MaybeMaketext::LanguageCodeValidator();

my $sut             = $CLASS->new();
my $cache           = Locale::MaybeMaketext::Cache->new();
my $basic_validator = Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache, 'basic' => 1 );
my $full_validator  = Locale::MaybeMaketext::LanguageCodeValidator->new( 'cache' => $cache, 'basic' => 0 );

subtest_buffered( 'check_empty',             \&check_empty );
subtest_buffered( 'check_invalid_languages', \&check_invalid_languages );
subtest_buffered( 'check_grandfathered',     \&check_grandfathered );
subtest_buffered( 'check_valid_supers',      \&check_valid_supers );

done_testing();

sub check_empty {
    my $overrider    = Locale::MaybeMaketext::Tests::Overrider->new();
    my $croak_called = 0;
    $overrider->wrap(
        "${CLASS}::croak",
        sub ( $original_sub, @params ) { $croak_called = 1; return $original_sub->(@params); }
    );
    like(
        warning {
            is(
                \$sut->make_supers(), \(),
                'check_empty: Should return empty data if nothing provided'
            );
        },
        qr/\Amake_supers called with nothing/,
        'check_empty: Warning should be emitted if nothing passed'
    );
    $overrider->reset_all();
    return 1;

}

sub check_invalid_languages {
    like(
        warning {
            is(
                \$sut->make_supers( 'abc' => 'def' ), \(),
                'check_invalid_languages: Should return empty if invalid language passed (no code)'
            );
        },
        qr/\Amake_supers called with invalid language: no code/,
        'check_invalid_languages: Warning should be emitted if no code'
    );
    like(
        warning {
            is(
                \$sut->make_supers( 'code' => 'abc' ), \(),
                'check_invalid_languages: Should return empty if invalid language passed (no language)'
            );
        },
        qr/\Amake_supers called with invalid language: no language/,
        'check_invalid_languages: Warning should be emitted if no language'
    );
    like(
        warning {
            is(
                \$sut->make_supers( 'code' => 'abc', 'language' => 'def' ), \(),
                'check_invalid_languages: Should return empty if invalid language passed (no status)'
            );
        },
        qr/\Amake_supers called with invalid language: no status/,
        'check_invalid_languages: Warning should be emitted if no status'
    );
    like(
        warning {
            is(
                \$sut->make_supers( 'code' => 'abc', 'language' => 'def', 'status' => 0 ), \(),
                'check_invalid_languages: Should return empty if invalid language passed (invalid status)'
            );
        },
        qr/\Amake_supers called with invalid language: invalid status/,
        'check_invalid_languages: Warning should be emitted if invalid status'
    );
    return 1;
}

sub check_grandfathered {
    my @grandfathered = qw/en_gb_oed sgn_be_ft sgn_be_nl sgn-ch-de i_ami i-bnn i-default i-enochian i-hak zh-xiang/;

    for my $grand (@grandfathered) {
        like(
            warning {
                is(
                    \$sut->make_supers( 'code' => $grand, 'irregular' => $grand ), \(),
                    sprintf( 'check_grandfathered: No language for grandfathered %s', $grand )
                );
            },
            qr/\Amake_supers called with invalid language: no language/,
            sprintf( 'check_grandfathered: Warning should be emitted for grandfathered %s', $grand )
        );
    }
    return 1;
}

sub check_valid_supers {
    my %supers = (
        'Long one' => [
            'input' => [qw/en-brm-latn-gb-t-varin3a-0thex-u-some-x-test/],
            'basic' => [ 'en_latn_gb', 'en_gb', 'en_latn', 'en' ],
            'full'  => [

                'en_brm_latn_gb_t_0thex_varin3a_u_some_x_test', 'en_latn_gb_t_0thex_varin3a_u_some_x_test',
                'en_brm_gb_t_0thex_varin3a_u_some_x_test',      'en_brm_latn_t_0thex_varin3a_u_some_x_test',
                'en_brm_latn_gb_t_0thex_varin3a_x_test',        'en_gb_t_0thex_varin3a_u_some_x_test',
                'en_latn_t_0thex_varin3a_u_some_x_test',        'en_brm_t_0thex_varin3a_u_some_x_test',
                'en_brm_latn_gb_t_0thex_varin3a_u_some',        'en_brm_latn_gb_u_some_x_test',
                'en_latn_gb_t_0thex_varin3a_x_test',            'en_brm_gb_t_0thex_varin3a_x_test',
                'en_brm_latn_t_0thex_varin3a_x_test',           'en_t_0thex_varin3a_u_some_x_test',
                'en_latn_gb_t_0thex_varin3a_u_some',            'en_brm_gb_t_0thex_varin3a_u_some',
                'en_brm_latn_t_0thex_varin3a_u_some', 'en_latn_gb_u_some_x_test',  'en_brm_gb_u_some_x_test',
                'en_gb_t_0thex_varin3a_x_test',       'en_brm_latn_u_some_x_test', 'en_latn_t_0thex_varin3a_x_test',
                'en_brm_t_0thex_varin3a_x_test',      'en_brm_latn_gb_t_0thex_varin3a', 'en_gb_t_0thex_varin3a_u_some',
                'en_latn_t_0thex_varin3a_u_some',     'en_brm_t_0thex_varin3a_u_some',  'en_gb_u_some_x_test',
                'en_latn_u_some_x_test', 'en_brm_u_some_x_test', 'en_t_0thex_varin3a_x_test', 'en_brm_latn_gb_x_test',
                'en_brm_latn_gb_u_some', 'en_latn_gb_t_0thex_varin3a',      'en_brm_gb_t_0thex_varin3a',
                'en_brm_latn_t_0thex_varin3a', 'en_t_0thex_varin3a_u_some', 'en_u_some_x_test',  'en_latn_gb_x_test',
                'en_brm_gb_x_test',            'en_brm_latn_x_test',        'en_latn_gb_u_some', 'en_brm_gb_u_some',
                'en_gb_t_0thex_varin3a', 'en_brm_latn_u_some', 'en_latn_t_0thex_varin3a', 'en_brm_t_0thex_varin3a',
                'en_gb_x_test', 'en_latn_x_test', 'en_brm_x_test',   'en_gb_u_some', 'en_latn_u_some', 'en_brm_u_some',
                'en_t_0thex_varin3a', 'en_brm_latn_gb', 'en_x_test', 'en_u_some',    'en_latn_gb',     'en_brm_gb',
                'en_brm_latn',        'en_gb',          'en_latn',   'en_brm',       'en'
            ]
        ]
    );
    for my $label ( keys(%supers) ) {
        my %current = @{ $supers{$label} };

        for my $input ( @{ $current{'input'} } ) {

            my @expected_languages = @{ $current{'basic'} };
            my %parts              = $basic_validator->validate($input);
            my @got                = $sut->make_supers(%parts);
            is(
                \@got, \@expected_languages,
                sprintf( 'check_valid_supers: Basic: %s should return restricted supers', $label ), @got
            );
            @expected_languages = @{ $current{'full'} };
            %parts              = $full_validator->validate($input);
            @got                = $sut->make_supers(%parts);
            is(
                \@got,
                \@expected_languages,
                sprintf( 'check_valid_supers: Full: %s should return full supers', $label ), @got
            );
        }

    }
    return 1;
}
