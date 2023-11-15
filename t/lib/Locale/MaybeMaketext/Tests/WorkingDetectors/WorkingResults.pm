package Locale::MaybeMaketext::Tests::WorkingDetectors::WorkingResults;
use strict;
use warnings;
use vars;
use utf8;
use autodie qw/:all/;
use feature qw/signatures/;
use Carp    qw/croak/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

sub detect (%settings) {
    for (qw/cache language_code_validator alternatives supers package_loader/) {
        if ( !defined( $settings{$_} ) ) {
            croak( 'Missing expected configuration in first parameter: ' . $_ );
        }
    }
    return (
        'languages'         => [qw/fr_fr en_nz en_us/],
        'invalid_languages' => [qw/i-default gc qk_kng ld_sd/],
        'reasoning'         => [ 'Got working results _without_new', 'Should have 3 success, 4 fails and 2 messages' ],
    );
}

1;
