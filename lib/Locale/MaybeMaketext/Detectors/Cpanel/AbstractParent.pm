package Locale::MaybeMaketext::Detectors::Cpanel::AbstractParent;

use strict;
use warnings;
use vars;
use utf8;
use Carp         qw/croak carp/;
use Scalar::Util qw/blessed/;
use feature      qw/signatures/;
no warnings qw/experimental::signatures/;

sub new ( $class, %params ) {
    if ( ref($class) || !( $class->isa(__PACKAGE__) ) ) {
        croak(
            sprintf(
                'New passed incorrect setting for first parameter: %s',
                ref($class) ? ref($class) : ( 'scalar:' . $class )
            )
        );
    }
    my %needed = (
        'cache'                   => 'Locale::MaybeMaketext::Cache',
        'language_code_validator' => 'Locale::MaybeMaketext::LanguageCodeValidator',
        'package_loader'          => 'Locale::MaybeMaketext::PackageLoader',
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
    my $self = bless {
        'language_code_validator' => $params{'language_code_validator'},
        'package_loader'          => $params{'package_loader'},
        'cache'                   => $params{'cache'}->get_namespaced('Detector::Cpanel'),
        '_raw_cache'              => $params{'cache'}
    }, $class;

    return $self;

}

sub detect ($self) {
    if ( !blessed($self) || !( $self->isa(__PACKAGE__) ) ) {
        croak( sprintf( '%s should be passed an instance of its object %s', 'detect', __PACKAGE__ ) );
    }
    my ( @reasoning, @languages );
    my $working_cpanel = 0;

    # check we are on cPanel.
    if ( !defined( $INC{'Cpanel.pm'} ) ) {
        push @reasoning, 'Cpanel.pm does not appear loaded. Probably not on a cPanel system';
        return (
            'languages'         => [],
            'reasoning'         => \@reasoning,
            'invalid_languages' => [],
        );
    }
    my %data = $self->run_detect();
    return $self->validate_add_reasoning( $data{'languages'}, $data{'reasoning'} );
}

sub run_detect ($self) {
    croak('METHOD run_detect NEEDS TO BE OVERRIDDEN IN MAIN/CHILD CLASS');
}

sub old_name_to_locale ( $self, $possible_old_lang ) {

    # this list is slightly different from Cpanel::Locale::Utils::Legacy::_load_oldnames
    # as all the names are underscore separated for consistency.
    my %oldname_to_locale = (
        'turkish'                   => 'tr',
        'traditional_chinese'       => 'zh',
        'thai'                      => 'th',
        'swedish'                   => 'sv',
        'spanish_utf8'              => 'es',
        'spanish'                   => 'es',
        'slovenian'                 => 'sl',
        'simplified_chinese'        => 'zh_cn',
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
    my $lowered_underscored = lc( $possible_old_lang =~ tr/-/_/r );
    if ( defined( $oldname_to_locale{$lowered_underscored} ) ) {
        return $oldname_to_locale{$lowered_underscored};
    }
    return $possible_old_lang;
}

sub validate_add_reasoning ( $self, $langtagsref, $reasoningref ) {
    my @languages = @{$langtagsref};
    my $scalar    = scalar(@languages);
    my @reasoning = @{$reasoningref};
    if ( $scalar > 0 ) {
        push @reasoning, sprintf( 'Found %d languages: %s', $scalar, join( q{, }, @languages ) );
    }
    else {
        push @reasoning, 'No languages found';
    }
    my %lang_validated = $self->{'language_code_validator'}->dedup_multiple(@languages);
    @reasoning = ( @reasoning, @{ $lang_validated{'reasoning'} } );
    return (
        'languages'         => $lang_validated{'languages'},
        'reasoning'         => \@reasoning,
        'invalid_languages' => $lang_validated{'invalid_languages'}
    );
}

sub load_package_and_run_in_eval ( $self, $package_name, $subroutine, @reasoning ) {
    my $temp_error;
    if (
        !eval {
            my %load_results = $self->{'package_loader'}->attempt_package_load($package_name);
            my $exit         = 0;
            if ( $load_results{'status'} ) {
                push @reasoning, sprintf( 'Package Loader: %s', $load_results{'reasoning'} );
                if ( defined($subroutine) ) {
                    if ( ref($subroutine) eq 'CODE' ) {
                        @reasoning = ( @reasoning, $subroutine->() );
                        $exit      = 1;
                    }
                    else {
                        $temp_error = sprintf( 'Invalid subroutine passed when loading %s', $package_name );
                    }
                }
                else {
                    # no subroutine to execute.
                    $exit = 1;
                }
            }
            else {
                $temp_error = sprintf( 'Package Loader: %s', $load_results{'reasoning'} );
            }

            $exit;
        }
    ) {
        push @reasoning,
          sprintf( 'Errored: %s', ( $temp_error || $@ || $! || '[Unknown reasoning]' ) );
    }
    return @reasoning;
}

1;
