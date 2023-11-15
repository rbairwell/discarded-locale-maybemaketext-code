#!perl
## no critic (RegularExpressions::ProhibitComplexRegexes)
use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Locale::MaybeMaketext::Tests::Base qw/:all/;
use Locale::MaybeMaketext::Tests::Overrider();
use Time::HiRes();
use feature qw/signatures/;
no warnings qw/experimental::signatures/;
use Test2::Tools::Target 'Locale::MaybeMaketext::Cache';
use Locale::MaybeMaketext::Cache;

subtest_buffered( 'check_namespacing',          \&check_namespacing );
subtest_buffered( 'check_not_exists',           \&check_not_exists );
subtest_buffered( 'check_set_get_hash',         \&check_set_get_hash );
subtest_buffered( 'check_set_get_single_entry', \&check_set_get_single_entry );
subtest_buffered( 'check_set_get_array',        \&check_set_get_array );
subtest_buffered( 'check_remove',               \&check_remove );
subtest_buffered( 'check_no_overlaps',          \&check_no_overlaps );
done_testing();

sub check_namespacing {
    my $sut = $CLASS->new();
    like(
        dies { $sut->set_cache( 'test', 'data' ); } || 'undef',
        qr/\ANo namespace configured/,
        'set_cache should error if no namespace set'
    );
    like(
        dies { $sut->remove_cache('test'); } || 'undef',
        qr/\ANo namespace configured/,
        'remove_cache should error if no namespace set'
    );
    like(
        dies { $sut->get_cache_entry_time('test'); } || 'undef',
        qr/\ANo namespace configured/,
        'get_cache_entry_time should error if no namespace set'
    );
    like(
        dies { $sut->get_cache('test'); } || 'undef',
        qr/\ANo namespace configured/,
        'get_cache should error if no namespace set'
    );
    my $namespaced = $sut->get_namespaced('PackageTest');
    like(
        dies { $namespaced->get_namespaced('test'); } || 'undef',
        qr/\AAlready running within a namespace/,
        'get_namespaced should error if namespace already set'
    );
    is(
        $sut->get_namespaced('PackageTest'), $namespaced,
        'get_namespaced should return identical entries for same entry'
    );
    return 1;
}

sub check_not_exists {
    my @test_data;
    my $croak_called = 0;
    my $sut          = $CLASS->new()->get_namespaced('TestSuite');
    my $overrider    = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->wrap(
        "${CLASS}::croak",
        sub ( $original_sub, @params ) { $croak_called = 1; return $original_sub->(@params); }
    );
    is( $sut->get_cache('testing'), 0, 'cache: Key should not exist' );

    like(
        dies { @test_data = $sut->get_cache('testing'); } || 'failed to die',
        qr/\AAttempt to access non-existent cache key for "testing" in namespace "TestSuite" /,
        'check_not_exists: Should die if attempt is made at accessing non-existent key'
    );
    is( $croak_called, 1, 'check_not_exists: Should have called croak' );
    is(
        $sut->get_cache_entry_time('testing'), 0,
        'check_not_exists: Should be no timestamp set'
    );
    $overrider->reset_all();
    return 1;
}

sub _check_entry_time ( $sut, $key ) {
    my $current_time = Time::HiRes::time();
    my $cache_time   = $sut->get_cache_entry_time($key);
    ok( $cache_time > 0, 'cache: Timestamp should be greater than zero' );
    ok(
        abs( $current_time - $cache_time ) < 5,    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
        'cache: Timestamp should be within 5 seconds',
        (
            'current_time' => $current_time, 'cache_time' => $cache_time,
            'difference'   => abs( $current_time - $cache_time )
        )
    );
    return 1;
}

sub check_set_get_hash {
    my %output;
    my %test_data = ( 'a' => 'b', '9wsfs' => 'dsadas' );
    my $key       = 'testerhash';
    my $sut       = $CLASS->new()->get_namespaced('TestSuite');
    %output = $sut->set_cache( $key, %test_data );
    is( \%output,              \%test_data, 'check_set_get_hash: Setter should return value' );
    is( $sut->get_cache($key), 1,           'check_set_get_hash: Key should now exist' );
    %output = ();
    %output = $sut->get_cache($key);
    is( \%output, \%test_data, 'check_set_get_hash: Getter should return value' );
    _check_entry_time( $sut, $key );
    return 1;
}

# luckily we can pass in an array to the cache system (which expects a hash) and still get an array out!
sub check_set_get_single_entry {
    my @output;
    my @test_data = qw/test/;
    my $key       = 'testsingle';
    my $sut       = $CLASS->new()->get_namespaced('TestSuite');

    @output = $sut->set_cache( $key, @test_data );
    is( \@output,              \@test_data, 'check_set_get_single_entry: Setter should return value' );
    is( $sut->get_cache($key), 1,           'check_set_get_single_entry: Key should now exist' );
    @output = ();
    @output = $sut->get_cache($key);
    is( \@output, \@test_data, 'check_set_get_single_entry: Getter should return value' );
    _check_entry_time( $sut, $key );
    return 1;
}

# luckily we can pass in an array to the cache system (which expects a hash) and still get an array out!
sub check_set_get_array {
    my @output;
    my @test_data = qw/words go here for testing purposes/;
    my $key       = 'testerarray';
    my $sut       = $CLASS->new()->get_namespaced('TestSuite');

    @output = $sut->set_cache( $key, @test_data );
    is( \@output,              \@test_data, 'check_set_get_array: Setter should return value' );
    is( $sut->get_cache($key), 1,           'check_set_get_array: Key should now exist' );
    @output = ();
    @output = $sut->get_cache($key);
    is( \@output, \@test_data, 'check_set_get_array: Getter should return value' );
    _check_entry_time( $sut, $key );
    return 1;
}

sub check_remove {
    my %output;
    my $sut          = $CLASS->new()->get_namespaced('TestSuite');
    my $croak_called = 0;
    my $overrider    = Locale::MaybeMaketext::Tests::Overrider->new();
    $overrider->wrap(
        "${CLASS}::croak",
        sub ( $original_sub, @params ) { $croak_called = 1; return $original_sub->(@params); }
    );
    my %test_data = ( 'a' => 'b', '9wsfs' => 'dsadas' );
    $sut->set_cache( 'tester', %test_data );

    # now remove
    %output = $sut->remove_cache('tester');
    is( \%output,                  \%test_data, 'check_remove: Removing should return previous value' );
    is( $sut->get_cache('tester'), 0,           'check_remove: Key should no longer exist' );
    like(
        dies { %output = $sut->get_cache('tester'); },
        qr/\AAttempt to access non-existent cache key for "tester" /,
        'check_remove: Should die if attempt is made at accessing removed key'
    );
    is( $croak_called, 1, 'check_remove: Call should have gone through croak' );
    is(
        $sut->get_cache_entry_time('tester'), 0,
        'check_remove: Should be no timestamp set for deleted/removed key'
    );
    $croak_called = 0;
    like(
        dies { $sut->remove_cache('tester'); },
        qr/\AAttempt to delete non-existent cache key for "tester" /,
        'check_remove: Should die if attempt deleting key which does not exist'
    );
    is( $croak_called, 1, 'check_remove: Call should have gone through croak' );
    $overrider->reset_all();
    return 1;
}

sub check_no_overlaps {
    my $base = $CLASS->new();

    my $sut = $base->get_namespaced('TestSuite');

    my $sut2      = $base->get_namespaced('SomethingeElse');
    my %test_data = ( 'a' => 'b', '9wsfs' => 'dsadas' );
    $sut->set_cache( 'tester', %test_data );
    is( $sut->get_cache('tester'),  1, 'TestSuite should have entry' );
    is( $sut2->get_cache('tester'), 0, 'SomethingeElse should not' );

    return 1;
}
