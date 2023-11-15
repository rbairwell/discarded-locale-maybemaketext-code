package Locale::MaybeMaketext::Detectors::I18N;

use strict;
use warnings;
use vars;
use utf8;
use I18N::LangTags::Detect;    # part of CORE
use Scalar::Util qw/blessed/;
use feature      qw/signatures/;
use Carp         qw/croak/;
no warnings qw/experimental::signatures/;

sub detect (%params) {

    my %needed = (
        'language_code_validator' => 'Locale::MaybeMaketext::LanguageCodeValidator',
    );
    for my $field ( sort keys(%needed) ) {
        if ( !defined( $params{$field} ) ) {
            croak( sprintf( 'Missing needed configuration setting "%s"', $field ) );
        }
        if ( !blessed( $params{$field} ) ) {
            croak(
                sprintf(
                    'Configuration setting "%s" must be a blessed object: instead got %s', $field,
                    ref( $params{$field} ) ? ref( $params{$field} ) : 'scalar:' . $params{$field}
                )
            );
        }
        if ( !$params{$field}->isa( $needed{$field} ) ) {
            croak(
                sprintf(
                    'Configuration setting "%s" must be an instance of "%s": got "%s"',
                    $field, $needed{$field}, ref( $params{$field} )
                )
            );
        }
    }

    # main code
    my ( @reasoning, @languages, @invalid_languages ) = ( (), (), () );
    @languages = I18N::LangTags::Detect::detect();
    push @reasoning, sprintf( 'I18N::LangTags::Detect::detect returned %d languages', scalar(@languages) );

    my %lang_validated = $params{'language_code_validator'}->validate_multiple(@languages);
    @reasoning = ( @reasoning, @{ $lang_validated{'reasoning'} } );
    return (
        'languages'         => $lang_validated{'languages'},
        'reasoning'         => \@reasoning,
        'invalid_languages' => $lang_validated{'invalid_languages'},
    );
}

1;
