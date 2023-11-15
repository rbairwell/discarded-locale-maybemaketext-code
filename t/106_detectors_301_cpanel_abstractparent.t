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
use Test2::Tools::Target 'Locale::MaybeMaketext::Detectors::Cpanel::AbstractParent';
use Locale::MaybeMaketext::Tests::DetectorCpanelBase qw/:all/;
use Locale::MaybeMaketext::Tests::Overrider();

subtest_buffered( 'check_new',              sub () { check_new($CLASS); } );
subtest_buffered( 'check_detect_call',      sub () { check_detect_call( $CLASS, 'detect' ); } );
subtest_buffered( 'check_detect_no_cpanel', \&check_detect_no_cpanel );
subtest_buffered( 'check_detect',           \&check_detect );

subtest_buffered( 'check_dummy_package',                \&check_dummy_package );
subtest_buffered( 'check_old_lang',                     \&check_old_lang );
subtest_buffered( 'check_validate_add_reasoning',       \&check_validate_add_reasoning );
subtest_buffered( 'check_load_package_and_run_in_eval', \&check_load_package_and_run_in_eval );
done_testing();

sub check_detect_no_cpanel() {
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_loader_and_validator( $CLASS, $overrider );
    my %results   = $sut->detect();
    my %expected  = (
        'languages'         => [],
        'invalid_languages' => [],
        'reasoning'         => ['Cpanel.pm does not appear loaded. Probably not on a cPanel system'],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_detect_no_cpanel: Should fail if no Cpanel'
    );
    print "------ End of check_detect_no_cpanel --------\n";
    return 1;
}

sub check_detect() {
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_loader_and_validator( $CLASS, $overrider );
    local $INC{'Cpanel.pm'} = 'Faked';
    my $dies = dies {
        $sut->detect();
    } || 'did not die';
    my $expected = 'METHOD run_detect NEEDS TO BE OVERRIDDEN IN MAIN/CHILD CLASS';
    starts_with(
        $dies, $expected,
        'check_detect: detect Should fail if not child class', 'Expected', $expected, 'Received', $dies
    );
    print "------ End of check_detect --------\n";
    return 1;
}

sub check_dummy_package() {
    my $test_package_name = 'Generated::For::Testing::AbstractParent::';
    my @chars             = ( 'a' .. 'z', '_', '0' .. '9' );
    for ( 1 ... 8 ) {    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers);
        $test_package_name .= $chars[ rand @chars ];
    }
    my $package_data =
      sprintf( 'package %s;' . "\n"
          . 'use parent q{%s};' . "\n"
          . 'sub run_detect(%s%s) { ' . "\n"
          . ' return ( \'languages\' => [\'en_nz\',\'invalid_language\'], \'reasoning\' => [\'Dummy Check\'] );' . "\n"
          . ' }'
          . "\n"
          . '1;', $test_package_name, $CLASS, q{$}, q{self}, );

    if ( !eval "$package_data" ) {    ## no critic (BuiltinFunctions::ProhibitStringyEval)
        fail( sprintf( 'Unable to create dummy package for testing: %s', ( $@ || $! || '[Unknown reasoning]' ) ) );
    }
    local $INC{'Cpanel.pm'} = 'Faked';

    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_loader_and_validator( $test_package_name, $overrider, ('en_nz') );
    my %results   = $sut->detect();
    my %expected  = (
        'languages'         => ['en_nz'],
        'invalid_languages' => ['invalid_language'],
        'reasoning'         => [
            'Dummy Check', 'Found 2 languages: en_nz, invalid_language', 'Mock validating en_nz',
            'Mock failing invalid_language'
        ],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_dummy_package: Should all match'
    );
    return 1;
}

sub check_old_lang() {
    my %oldname_to_locale = (
        'turkish'                   => 'tr',
        'traditional_chinese'       => 'zh',
        'Traditional-Chinese'       => 'zh',
        'thai'                      => 'th',
        'swedish'                   => 'sv',
        'spanish_utf8'              => 'es',
        'spanish'                   => 'es',
        'slovenian'                 => 'sl',
        'simplified_chinese'        => 'zh_cn',
        'SIMPLIFIED-CHINESE'        => 'zh_cn',
        'russian'                   => 'ru',
        'romanian'                  => 'ro',
        'portuguese_utf8'           => 'pt',
        'portuguese'                => 'pt',
        'polish'                    => 'pl',
        'norwegian'                 => 'no',
        'korean'                    => 'ko',
        'japanese_shift_jis'        => 'ja',
        'japanese_euc_jp'           => 'ja',
        'japanese'                  => 'ja',
        'spanish_latinamerica'      => 'es_419',
        'iberian_spanish'           => 'es_es',
        'italian'                   => 'it',
        'indonesian'                => 'id',
        'hungarian'                 => 'hu',
        'german_utf8'               => 'de',
        'german'                    => 'de',
        'french_utf8'               => 'fr',
        'french'                    => 'fr',
        'finnish'                   => 'fi',
        'english_utf8'              => 'en',
        'english'                   => 'en',
        'dutch_utf8'                => 'nl',
        'dutch'                     => 'nl',
        'chinese'                   => 'zh',
        'bulgarian'                 => 'bg',
        'brazilian_portuguese_utf8' => 'pt_br',
        'brazilian_portuguese'      => 'pt_br',
        'arabic'                    => 'ar',
    );
    my @unchanged = qw/en fr invalid/;
    my $sut       = get_sut_for_class($CLASS);
    my @failures;
    for my $key ( keys(%oldname_to_locale) ) {
        if ( $sut->old_name_to_locale($key) ne $oldname_to_locale{$key} ) {
            push @failures, $key;
        }
    }
    for my $key (@unchanged) {
        if ( $sut->old_name_to_locale($key) ne $key ) {
            push @failures, $key;
        }
    }
    if (@failures) {
        fail( sprintf( 'check_old_lang: Failed to correctly handle: %s', join( ', ', @failures ) ) );
    }
    else {
        pass('check_old_lang: All languages changed appropriately');
    }
    return 1;
}

sub check_validate_add_reasoning() {
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();
    my $sut       = get_sut_for_class_with_mocked_loader_and_validator( $CLASS, $overrider, ('en_nz') );
    my %results   = $sut->validate_add_reasoning( [ 'en_gb', 'en_nz', 'invalid' ], [ 'One', 'Two', 'Three reasons' ] );
    my %expected  = (
        'languages'         => ['en_nz'],
        'invalid_languages' => [qw/en_gb invalid/],
        'reasoning'         => [
            'One',
            'Two',
            'Three reasons',
            'Found 3 languages: en_gb, en_nz, invalid',
            'Mock failing en_gb',
            'Mock validating en_nz',
            'Mock failing invalid'
        ],
    );
    do_cpanel_detector_compare(
        \%results, \%expected,
        'check_validate_add_reasoning: Should all match'
    );
    return 1;
}

sub check_load_package_and_run_in_eval() {
    my $overrider = Locale::MaybeMaketext::Tests::Overrider->new();

    # prevent load
    my $sut = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 0 );
    my @reasoning =
      $sut->load_package_and_run_in_eval( 'Invalid::Package::Name', sub { return ('Test'); }, ('nopackage') );
    my @expected = ( 'nopackage', 'Errored: Package Loader: Blocked under test conditions: Invalid::Package::Name' );
    is(
        @reasoning, @expected, 'check_load_package_and_run_in_eval: Handle unable to load package correctly',
        @reasoning
    );

    # now allow to load with no subroutine
    $sut       = get_sut_for_class_with_mocked_loader( $CLASS, $overrider, 1 );
    @reasoning = $sut->load_package_and_run_in_eval( 'Invalid::Package::Name', undef, ('nosub') );
    @expected  = ( 'nosub', 'Package Loader: Dummy load of Invalid::Package::Name' );
    is( @reasoning, @expected, 'check_load_package_and_run_in_eval: Handle valid load, no sub', @reasoning );

    # now invalid subroutine
    @reasoning = $sut->load_package_and_run_in_eval( 'Invalid::Package::Name', 'abc', ('invalidsub') );
    @expected  = (
        'invalidsub',
        'Package Loader: Dummy load of Invalid::Package::Name',
        'Invalid subroutine passed when loading Invalid::Package::Name',
    );
    is( @reasoning, @expected, 'check_load_package_and_run_in_eval: Handle valid load, invalid sub', @reasoning );

    # now subroutine throws error
    @reasoning = $sut->load_package_and_run_in_eval( 'Invalid::Package::Name', sub { croak('Ha ha!'); }, ('errorsub') );
    @expected  = (
        'errorsub', 'Package Loader: Dummy load of Invalid::Package::Name',
        'Errored: Ha ha!',
    );
    my @extracted_reasoning;
    for (@reasoning) {
        push @extracted_reasoning, $_ =~ s/!.*/!/r;
    }
    is(
        @extracted_reasoning, @expected, 'check_load_package_and_run_in_eval: Handle valid load, erroring sub',
        @extracted_reasoning
    );

    return 1;
}
