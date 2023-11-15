#!perl

use strict;
use warnings;
use vars;
use File::Basename();
use File::Spec();
use lib File::Spec->catdir( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ), q/lib/ );
use Test2::Tools::Target 'Locale::MaybeMaketext';

# To enable debugging in the Cpanel translations, add this begin block before the Base install.
#BEGIN {
#    *Cpanel::CPAN::Locale::Maketext::DEBUG             = sub () { 1; };
#}
use Locale::MaybeMaketext::Tests::Base qw/:all/;

my ( $lh, $sut );

# Checks if we can use the Cpanel Maketext Utils
SKIP: {
    if ( !eval { require Cpanel::CPAN::Locale::Maketext::Utils; 1; } ) {
        skip("Cpanel::CPAN::Locale::Maketext::Utils: Not available: $@");
    }

    $sut = 'Cpanel::CPAN::Locale::Maketext::Utils';

    # setup
    Locale::MaybeMaketext->maybe_maketext_reset();
    my %returned_hash;
    my @returned_array;
    my @expected_array = ($sut);
    my %expected_hash;
    @returned_array = Locale::MaybeMaketext::maybe_maketext_set_only_specified_localizers($sut);
    is( \@returned_array, \@expected_array, "$sut: Our localizers should be set" );
    %expected_hash = ( 'main' => 'Testing::Abcdef' );
    %returned_hash = Locale::MaybeMaketext->maybe_maketext_add_text_domains( 'main' => 'Testing::Abcdef' );
    is( \%returned_hash, \%expected_hash, "$sut: Text domains should match", %returned_hash );

    # set our language finder configuration
    Locale::MaybeMaketext->maybe_maketext_set_language_configuration('provided');

    # start
    can_ok( $CLASS, ['get_handle'], "$sut: Should support core methods" );

    # here is where the language gets set
    ok( $lh = Locale::MaybeMaketext->get_handle(qw/en-us fr-fr es-pt/), "$sut: Should get a handle" );
    can_ok( $lh, ['maketext'], "$sut: Should support maketext" );
    check_isas(
        $lh, [ $sut, 'Cpanel::CPAN::Locale::Maketext::Utils', 'Cpanel::CPAN::Locale::Maketext' ],
        "$sut: Checking isas"
    );

    is(
        $lh->maketext( 'This is a test translation [_1] for [_2]', 'passed', $CLASS ),
        "Yee haaa $CLASS!! Test translation passed!", "$sut: Checking translation",
    );
    is(
        Locale::MaybeMaketext->maybe_maketext_get_name_of_localizer(), $sut,
        "$sut: Localizer should be as set"
    );
    is( $lh->maybe_maketext_get_locale(), 'Testing::Abcdef', "$sut: Locale should be as set" );
    my $reasoning = join( q{, }, $lh->maybe_maketext_get_language_reasoning() );
    starts_with(
        $reasoning,
        'Language "en-us" in position 0: OK',
        "$sut: Check language reasoning",
        $reasoning
    );
    is(
        join( q{, }, Locale::MaybeMaketext->maybe_maketext_get_localizer_reasoning() ),
        "Found 1 possible localizers, Set localizer to $sut",
        "$sut: Check localizer reasoning"
    );
}
done_testing();
