package Locale::MaybeMaketext::Tests::InvalidDetectors::ReturnLanguagesNotArrayWithNew;
use strict;
use warnings;
use vars;
use utf8;
use autodie qw/:all/;
use feature qw/signatures/;
use Carp    qw/croak/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

sub new ( $class, %settings ) {
    if ( $class ne __PACKAGE__ ) {
        croak( 'New passed incorrect setting for first parameter: ' . ref($class) ? ref($class) : 'scalar:' . $class );
    }
    for (qw/cache language_code_validator alternatives supers package_loader/) {
        if ( !defined( $settings{$_} ) ) {
            croak( 'Missing expected configuration in second parameter: ' . $_ );
        }
    }
    return bless {}, $class;
}

sub detect ($self) {
    return (
        'languages'         => 'hello',
        'invalid_languages' => [],
        'reasoning'         => ['This is a test'],
    );
}

1;
