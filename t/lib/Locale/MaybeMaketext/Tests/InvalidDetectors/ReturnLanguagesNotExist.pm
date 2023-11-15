package Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnLanguagesNotExist;
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
        'invalid_languages' => [],
        'reasoning'         => ['This is a test'],
    );
}

1;
