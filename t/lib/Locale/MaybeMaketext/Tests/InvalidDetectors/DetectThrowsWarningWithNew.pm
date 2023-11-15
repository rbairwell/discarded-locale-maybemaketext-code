package Locale::MaybeMaketext::Tests::InvalidDetectors::DetectThrowsWarningWithNew;
use strict;
use warnings;
use vars;
use utf8;
use autodie qw/:all/;
use feature qw/signatures/;
use Carp    qw/croak carp/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

sub new ( $class, %settings ) {
    return bless {}, $class;
}

sub detect ($self) {
    carp('Dummy warning');

    return (
        'languages'         => [qw/en_nz/],
        'invalid_languages' => [],
        'reasoning'         => ['This is a test'],
    );
}

1;
