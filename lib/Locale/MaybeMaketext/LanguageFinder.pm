package Locale::MaybeMaketext::LanguageFinder;

# pragmas
use v5.20.0;
use strict;
use warnings;
use vars;
use utf8;

use autodie      qw/:all/;
use feature      qw/signatures/;
use Scalar::Util qw/blessed/;
use Carp         qw/croak carp/;
use Locale::MaybeMaketext::LanguageFinderProcessor();
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

sub new ( $self, %settings ) {
    my %needed = (
        'language_code_validator' => 'Locale::MaybeMaketext::LanguageCodeValidator',
        'alternatives'            => 'Locale::MaybeMaketext::Alternatives',
        'supers'                  => 'Locale::MaybeMaketext::Supers',
        'package_loader'          => 'Locale::MaybeMaketext::PackageLoader',
        'cache'                   => 'Locale::MaybeMaketext::Cache',
    );
    for my $field ( sort keys(%needed) ) {
        if ( !defined( $settings{$field} ) ) {
            croak( sprintf( 'Missing needed configuration setting "%s"', $field ) );
        }
        if ( !blessed( $settings{$field} ) ) {
            croak( sprintf( 'Configuration setting "%s" must be a blessed object', $field ) );
        }
        if ( !$settings{$field}->isa( $needed{$field} ) ) {
            croak(
                sprintf(
                    'Configuration setting "%s" must be an instance of "%s": got "%s"',
                    $field, $needed{$field}, ref( $settings{$field} )
                )
            );
        }
    }
    my $bless = bless {
        'cache'                   => $settings{'cache'}->get_namespaced('LanguageFinder'),
        'language_code_validator' => $settings{'language_code_validator'},
        'alternatives'            => $settings{'alternatives'},
        'supers'                  => $settings{'supers'},
        'package_loader'          => $settings{'package_loader'},
        '_base_cache'             => $settings{'cache'},
    }, $self;
    return $bless;
}

sub _get_cache ( $self, $cache_key ) {
    return wantarray ? $self->{'cache'}->get_cache($cache_key) : $self->{'cache'}->get_cache($cache_key);
}

sub _set_cache ( $self, $cache_key, @data ) {
    return $self->{'cache'}->set_cache( $cache_key, @data );
}

sub finder ( $self, %params ) {
    if ( ref($self) ne __PACKAGE__ ) {
        croak('finder should only be called via a blessed object');
    }
    if ( !defined( $params{'configuration'} ) || ref( $params{'configuration'} ) ne 'ARRAY' ) {
        croak('finder parameter "configuration" needs to be set as an array');
    }

    if ( defined( $params{'callback'} ) ) {
        if ( ref( $params{'callback'} ) ne 'CODE' ) {
            croak('finder parameter "callback", if used, needs to be set as code');
        }
    }
    else {
        $params{'callback'} = undef;
    }

    # optional settings.
    if ( defined( $params{'provided_languages'} ) && ref( $params{'provided_languages'} ) ne 'ARRAY' ) {
        croak('finder parameter "provided_languages" needs to be passed in either as undefined or as an array');
    }
    $params{'provided_languages'} //= [];
    if ( defined( $params{'previous_languages'} ) && ref( $params{'previous_languages'} ) ne 'ARRAY' ) {
        croak('finder parameter "previous_languages" needs to be passed in either as undefined or as an array');
    }
    $params{'previous_languages'} //= [];
    if ( exists( $params{'get_multiple'} ) && $params{'get_multiple'} !~ /\A[01]\z/ ) {
        croak(
            'finder parameter "get_multiple" needs to be passed in as either 1 (to get multiple) or 0/undefined (to stop on singular match)'
        );
    }
    $params{'get_multiple'} //= 0;

    my @configuration = $self->_configurations_explode_languages_array( @{ $params{'configuration'} } );

    # just sanity check the configuration before passing it on.
    my @checked = $self->set_configuration(@configuration);
    $params{'configuration'} = \@checked;
    my %results = Locale::MaybeMaketext::LanguageFinderProcessor->run(
        'language_code_validator' => $self->{'language_code_validator'},
        'alternatives'            => $self->{'alternatives'},
        'supers'                  => $self->{'supers'},
        'package_loader'          => $self->{'package_loader'},
        'cache'                   => $self->{'_base_cache'},
        'configuration'           => \@configuration,
        'callback'                => $params{'callback'},
        'provided_languages'      => $params{'provided_languages'},
        'previous_languages'      => $params{'previous_languages'},
        'get_multiple'            => $params{'get_multiple'}
    );
    return %results;
}

sub _configurations_validate_detector ( $self, $item ) {
    my $first_character = substr( $item, 0, 1 );
    my $package         = $item;
    my $label;

    # Tilde ~ indicates "maybe use this package if available, if not, don't worry/warn/error"
    # Exclamation mark ! "use this package if available, raise warning if not available"
    if ( $first_character eq q{~} ) {
        $package = substr( $item, 1 );
        $label   = sprintf( 'Detector %s (ignore-errors)', $package );
    }
    elsif ( $first_character eq q{!} ) {

        $package = substr( $item, 1 );
        $label   = sprintf( 'Detector %s (warn-errors)', $package );
    }
    else {
        $label = sprintf( 'Detector %s (default)', $package );
    }

    my %detector_results = $self->_is_detector( $label, $first_character, $package );

    # return quietly if succeed or if we are a "maybe".
    if ( $detector_results{'status'} || $first_character eq q{~} ) {
        return 1;
    }
    my $text = $detector_results{'reasoning'};
    if ( $first_character eq q{!} ) {
        carp($text);
        return 1;
    }
    croak($text);
}

sub _configurations_explode_languages_array ( $self, @list_of_actions ) {
    my @settings;
    for my $item (@list_of_actions) {
        my $ref = ref($item);
        if ( $ref eq 'ARRAY' ) {
            my %langresults = $self->{'language_code_validator'}->validate_multiple( @{$item} );
            if ( @{ $langresults{'invalid_languages'} } ) {
                croak(
                    sprintf(
                        'Invalid looking language code passed in array: "%s"',
                        join( q{", "}, @{ $langresults{'invalid_languages'} } )
                    )
                );
            }
            if ( @{ $langresults{'languages'} } ) {
                @settings = ( @settings, @{ $langresults{'languages'} } );
            }
        }
        else {
            push @settings, $item;
        }
    }
    return @settings;
}

sub _is_detector ( $self, $label, $first_character, $item ) {
    my $cache_key = sprintf( '_is_detector.%s.%s', $first_character, $item );
    if ( $self->_get_cache($cache_key) ) {
        my %cached = $self->_get_cache($cache_key);
        return %cached;
    }

    # doesn't even look like a package
    my $package_name_valid = $self->{'package_loader'}->is_valid_package_name($item);
    if ( !$package_name_valid ) {
        return $self->_set_cache(
            $cache_key,
            (
                'status' => 0, 'reasoning' => sprintf( '%s: Checking detector: Invalid package name %s', $label, $item )
            )
        );
    }
    my %load_result = $self->{'package_loader'}->attempt_package_load($item);
    if ( !$load_result{'status'} ) {
        return $self->_set_cache(
            $cache_key,
            (
                'status'    => 0,
                'reasoning' =>
                  sprintf( '%s: Checking detector: %s', $label, $load_result{'reasoning'} || '[Missing reasoning]' )
            )
        );
    }

    my $has_detect = 0;
    if (
        !eval {

            # does the package support "detect"
            if ( $item->can('detect') ) { $has_detect = 1; }
            1;
        }
    ) {
        # it errored
        return $self->_set_cache(
            $cache_key,
            (
                'status'    => 0,
                'reasoning' => sprintf(
                    '%s: Checking detector: When subroutine "detect" was checked, error message was received: "%s"',
                    $label,
                    ( $@ || $! || '[Unknown reasoning]' )
                )
            )
        );
    }
    if ( !$has_detect ) {
        return $self->_set_cache(
            $cache_key,
            (
                'status'    => 0,
                'reasoning' => sprintf( '%s: Checking detector: No "detect" subroutine found', $label )
            )
        );
    }
    return $self->_set_cache(
        $cache_key,
        (
            'status'    => 1,
            'reasoning' => 'passed'
        )
    );
}

sub set_configuration ( $self, @list_of_actions ) {

    # all variables declared on a method level as the lookups need access to them as well.
    my ( %lookup, %results, %languages_since_last_empty );    # hashes
    my ( $item,   $ref,     $normalized_item );               # scalar strings
    my ($position);                                           # numerics
    my (@settings);                                           # arrays
    if ( !@list_of_actions || scalar(@list_of_actions) < 1 ) {
        croak('set_configuration: Invalid call: Must be passed a list of actions');
    }
    @list_of_actions = $self->_configurations_explode_languages_array(@list_of_actions);
    $position        = 0;

    # lookup used to reduce if/elsif/else branches.
    %lookup = (
        '_add_item' => sub {
            push @settings, $item;
            return 1;
        },
        'empty' => sub {
            push @settings, $item;
            %languages_since_last_empty = ();
            return 1;
        },
        'die' => sub {

            # die finishes so pointless having any further actions
            if ( $position != scalar(@list_of_actions) ) {
                croak(
                    sprintf(
                            'Invalid position of keyword "%s": it must be in the last position if used '
                          . '(found in position %d of %d)', $item, $position, scalar(@list_of_actions)
                    )
                );
            }
            push @settings, $item;
            return 0;
        },
    );
    $lookup{'provided'} = $lookup{'supers'} = $lookup{'alternatives'} = $lookup{'previous'} =
      $lookup{'_add_item'};    # all these are the same

    # loop through actions.
    for (@list_of_actions) {
        $position++;
        $item = $_;
        $ref  = ref($item);
        if ( $ref eq q{} ) {

            # lower case, change dashes to underscores and remove spaces.
            # luckily this can be used for our lookups and language code checks as well.
            $normalized_item = ( lc( $item =~ tr{-}{_}r ) =~ s/\s//gr );

            # perform a lookup check
            if ( substr( $normalized_item, 0, 1 ) ne '_' && $lookup{$normalized_item} ) {
                if ( $lookup{$normalized_item}->() == 0 ) {
                    last;
                }
                next;
            }

            # see if it is a language
            if ( $normalized_item =~ /\A[[:lower:]\d_]{2,}\z/ ) {

                # looks like it /could/ be a language code - let's do a more indepth check
                my %langresults = $self->{'language_code_validator'}->validate($normalized_item);
                if ( $langresults{'status'} != 1 ) {
                    croak(
                        sprintf(
                            'Invalid looking language passed: "%s" - %s (found in position %d of %d)',
                            $item, $langresults{'reasoning'}, $position, scalar(@list_of_actions)
                        )
                    );
                }
                if ( $languages_since_last_empty{ $langresults{'code'} } ) {
                    croak(
                        sprintf(
                            'Duplicate language passed: "%s" (found in position %d of %d) already set in position %d',
                            $item, $position, scalar(@list_of_actions),
                            $languages_since_last_empty{ $langresults{'code'} }
                        )
                    );
                }
                $languages_since_last_empty{ $langresults{'code'} } = $position;
                push @settings, $langresults{'code'};

                next;
            }
            if ( index( $item, q{::} ) >= 0 ) {
                if ( $self->_configurations_validate_detector($item) == 1 ) {
                    push @settings, $item;
                    next;
                }
            }
        }
        croak(
            sprintf(
                'Unrecognised language configuration setting: "%s" (found in position %d of %d)',
                ( $ref eq q{} ? $item : "[Type $ref]" ), $position, scalar(@list_of_actions)
            )
        );

    }
    if ( !@settings ) {
        croak('No valid language configuration provided');
    }
    return @settings;
}

1;
