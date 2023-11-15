#!perl
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q{lib} );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use feature                            qw/signatures/;
no warnings qw/experimental::signatures/;
use Test2::Tools::Target 'Locale::MaybeMaketext::Alternatives';
use Locale::MaybeMaketext::Cache();
use Locale::MaybeMaketext::Alternatives;

my @test_data = (
    [ 'language' => 'aam', 'expected' => [ 'aam', 'aas' ], 'comment' => 'language change' ],
    [ 'language' => 'de',  'region'   => 'dd', 'expected' => [ 'de_dd', 'de_de' ], 'comment' => 'region change' ],
    [
        'language' => 'ar', 'extlang' => 'afb', 'expected' => [ 'ar_afb', 'afb' ],
        'comment'  => 'language and extlang to language (via fulls)'
    ],
    [
        'language' => 'ar', 'extlang' => 'afb', 'region' => 'ar', 'expected' => [ 'ar_afb_ar', 'afb_ar' ],
        'comment'  => 'language and extlang to language (via fulls)'
    ],
    [ 'irregular' => 'en_gb_oed', 'expected' => [ 'en_gb_oxendict', 'en_gb_oed' ], 'comment' => 'irregular oed' ],
    [
        'language' => 'zkb', 'region' => 'dd', 'expected' => [ 'zkb_dd', 'zkb_de', 'kjh_dd', 'kjh_de' ],
        'comment'  => 'language and region change'
    ],
    [ 'irregular' => 'i_klingon', 'expected' => [ 'i_klingon', 'tlh' ], 'comment' => 'irregular klingon' ],

);

my $cache     = Locale::MaybeMaketext::Cache->new();
my $sut       = $CLASS->new( 'cache' => $cache );
my $our_cache = $cache->get_namespaced('Alternatives');
for (@test_data) {
    my %test_row = @{$_};
    my $expected = [ sort( @{ $test_row{'expected'} } ) ];
    my @got      = $sut->find_alternatives(%test_row);
    my $comment  = $test_row{'comment'} || 'Expected matches for: ' . join( ', ', @{$expected} );
    subtest_buffered(
        $comment,
        sub {
            my $cache_key = _join_parts(%test_row);
            is(
                $our_cache->get_cache( 'find_alternatives' . $cache_key ),
                1,
                'Should not be cached'
            );
            is(
                [ sort(@got) ], $expected,
                'Before cache',
                'got', @got, 'expected', @{$expected}
            );
            is(
                $our_cache->get_cache( 'find_alternatives' . $cache_key ),
                1,
                'Should be cached'
            );
            my @from_cache = $our_cache->get_cache( 'find_alternatives' . $cache_key );
            is( [ sort(@from_cache) ], $expected, 'Cache should match' );
            my $cache_time = $our_cache->get_cache_entry_time( 'find_alternatives' . $cache_key );
            @got = $sut->find_alternatives(%test_row);
            is(
                [ sort(@got) ], $expected,
                '(during cache check)',
                'got', @got, 'expected', @{$expected}
            );
            is(
                $our_cache->get_cache_entry_time( 'find_alternatives' . $cache_key ),
                $cache_time,
                'cache should be unchanged'
            );

            return 1;
        }
    );

}

sub _join_parts (%myparts) {
    my @wanted_fields;
    for (qw/language extlang script region variant extension irregular regular/) {
        if ( defined( $myparts{$_} ) ) { push @wanted_fields, $myparts{$_}; }
    }
    return join( '_', @wanted_fields );
}

done_testing();
