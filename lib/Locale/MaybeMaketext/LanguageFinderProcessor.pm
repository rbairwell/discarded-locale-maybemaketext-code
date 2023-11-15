package Locale::MaybeMaketext::LanguageFinderProcessor;

# pragmas
use v5.20.0;
use strict;
use warnings;
use vars;
use utf8;
use Data::Dumper;
use autodie      qw/:all/;
use feature      qw/signatures/;
use Scalar::Util qw/blessed/;
use Carp         qw/croak carp/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

# mainly provided
my ( $cache,         $language_code_validator, $alternatives,       $supers,             $package_loader );
my ( @configuration, $callback,                @provided_languages, @previous_languages, $get_multiple );

# mainly internal
my ( %lookups, %dependencies_for_others );

# mainly output
my (
    @reasoning,             @invalid_languages, @languages, @matched_languages,
    @encountered_languages, %tried_languages,   @rejected_languages
);

sub run ( $self, %params ) {
    _cleardown();
    _setup_dependencies(%params);
    _setup_settings(%params);
    _setup_lookups();
    _loop();
    my @deduped_encountered = _dedup_preserve_order(@encountered_languages);
    my @deduped_rejected    = _dedup_preserve_order(@rejected_languages);
    return (
        'matched_languages'     => \@matched_languages,
        'rejected_languages'    => \@deduped_rejected,
        'encountered_languages' => \@deduped_encountered,
        'invalid_languages'     => \@invalid_languages,
        'reasoning'             => \@reasoning,
        'provided_languages'    => \@provided_languages,
        'previous_languages'    => \@previous_languages,
        'get_multiple'          => $get_multiple,
        'configuration'         => \@configuration,

    );
}

sub _cleardown() {
    ( $cache,         $language_code_validator, $alternatives,       $supers,             $package_loader ) = undef;
    ( @configuration, $callback,                @provided_languages, @previous_languages, $get_multiple )   = undef;

    # mainly internal
    ( %lookups, %dependencies_for_others ) = ();

    # mainly output
    (
        @reasoning,             @invalid_languages, @languages, @matched_languages,
        @encountered_languages, %tried_languages,   @rejected_languages
    ) = ();
    return 1;

}

sub _setup_dependencies (%params) {

    # dependencies
    my %needed = (
        'language_code_validator' => 'Locale::MaybeMaketext::LanguageCodeValidator',
        'alternatives'            => 'Locale::MaybeMaketext::Alternatives',
        'supers'                  => 'Locale::MaybeMaketext::Supers',
        'package_loader'          => 'Locale::MaybeMaketext::PackageLoader',
        'cache'                   => 'Locale::MaybeMaketext::Cache',
    );
    for my $field ( sort keys(%needed) ) {
        if ( !defined( $params{$field} ) ) {
            croak( sprintf( 'Missing needed configuration setting "%s"', $field ) );
        }
        if ( !blessed( $params{$field} ) ) {
            croak(
                sprintf(
                    'Configuration setting "%s" must be a blessed object: instead got %s', $field,
                    ref( $params{$field} ) ? ref( $params{$field} ) : 'scalar: ' . $params{$field}
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
    $cache                   = $params{'cache'}->get_namespaced('LanguageFinderProcessor');
    $language_code_validator = $params{'language_code_validator'};
    $alternatives            = $params{'alternatives'};
    $supers                  = $params{'supers'};
    $package_loader          = $params{'package_loader'};
    for (qw/cache language_code_validator alternatives supers package_loader/) {
        $dependencies_for_others{$_} = $params{$_};
    }
    return 1;
}

sub _setup_settings (%params) {

    if ( !defined( $params{'configuration'} ) || ref( $params{'configuration'} ) ne 'ARRAY' ) {
        croak('Parameter "configuration" needs to be set as an array');
    }
    @configuration = @{ $params{'configuration'} };

    if ( defined( $params{'callback'} ) ) {
        if ( ref( $params{'callback'} ) ne 'CODE' ) {
            croak('Parameter "callback", if used, needs to be set as code');
        }
        $callback = $params{'callback'};
    }
    else {
        $callback = undef;
    }

    # optional settings.
    if ( defined( $params{'provided_languages'} ) ) {
        if ( ref( $params{'provided_languages'} ) ne 'ARRAY' ) {
            croak('Parameter "provided_languages" needs to be passed in either as undefined or as an array');
        }
        @provided_languages = @{ $params{'provided_languages'} };
    }
    if ( defined( $params{'previous_languages'} ) ) {
        if ( ref( $params{'previous_languages'} ) ne 'ARRAY' ) {
            croak('Parameter "previous_languages" needs to be passed in either as undefined or as an array');
        }
        @previous_languages = @{ $params{'previous_languages'} };
    }
    if ( exists( $params{'get_multiple'} ) && $params{'get_multiple'} !~ /\A[01]\z/ ) {
        croak(
            'Parameter "get_multiple" needs to be passed in as either 1 (to get multiple) or 0/undefined (to stop on singular match)'
        );
    }
    $get_multiple = $params{'get_multiple'} || 0;
    return 1;
}

sub _setup_lookups() {
    %lookups = (
        'die' => sub() {
            if ($get_multiple) {

                # die is only allowed in the last position so no special handling is required.
                push @reasoning, 'Die: Die command encountered';
                return;
            }
            croak('No language found (and \'die\' set)');
        },
        'empty'        => sub() { push @reasoning, 'Empty: Emptying stored languages'; @languages = (); return; },
        'provided'     => sub() { return _add_provided(); },
        'supers'       => sub() { return _add_supers(); },
        'alternatives' => sub() { return _add_alternatives(); },
        'previous'     => sub() { return _add_previous(); },
    );
    return 1;
}

sub _add_supers() {
    if ( !@languages ) {
        push @reasoning, 'Supers: No languages to make supers from';
        return;
    }
    push @reasoning, sprintf( '>>> Supers: Entering with languages %s', join( q{, }, @languages ) );
    my @supers;

    for my $curlang (@languages) {
        my %parts = $language_code_validator->validate($curlang);

        # grandfathered in ones can not be supered.
        if ( !defined( $parts{'language'} ) ) {
            push @supers, $curlang;
            push @reasoning,
              sprintf( '    Supers: Whilst making supers: Language "%s" cannot have its "supers" extracted', $curlang );
            next;
        }
        @supers = ( @supers, $supers->make_supers(%parts) );
    }
    my %langresults = _validate_dedupe_multiple(@supers);

    for ( @{ $langresults{'reasoning'} } ) {
        push @reasoning, '    Supers: After making supers: ' . $_;
    }
    push @reasoning, sprintf(
        '    Supers: From %d languages generated %d potential supers - of which %d were valid looking unique languages and %d were invalid',
        scalar(@languages),
        scalar(@supers),
        scalar @{ $langresults{'languages'} },
        scalar @{ $langresults{'invalid_languages'} },
    );
    if ( @languages eq @{ $langresults{'languages'} } ) {
        push @reasoning, sprintf( '    Supers: Languages remained the same: %s', join( q{, }, @languages ) );
    }
    else {
        push @reasoning,
          sprintf( '--- Supers: Removing existing languages: %s', join( q{, }, @languages ) );
        push @reasoning,
          sprintf( '+++ Supers: Replacing languages with: %s', join( q{, }, @{ $langresults{'languages'} } ) );

        # full replace
        @languages = @{ $langresults{'languages'} };
    }
    @invalid_languages = _dedup_preserve_order( @invalid_languages, @{ $langresults{'invalid_languages'} } );
    push @reasoning, '<<< Supers: Exiting';
    return 1;
}

sub _validate_dedupe_multiple (@langcodes) {
    my %langresults = $language_code_validator->dedup_multiple(@langcodes);
    @encountered_languages = ( @encountered_languages, @{ $langresults{'languages'} } );
    return %langresults;
}

sub _add_alternatives() {
    if ( !@languages ) {
        push @reasoning, 'Alternatives: No languages to make alternatives from';
        return;
    }
    push @reasoning, sprintf( '>>> Alternatives: Entering with languages: %s', join( q{, }, @languages ) );
    my @alts = ();
    for my $curlang (@languages) {
        my %parts = $language_code_validator->validate($curlang);
        if ( $parts{'status'} == 0 ) {
            push @reasoning, sprintf( '    Alternatives: Skipping %s as not valid', $curlang );
            next;
        }
        my @results = $alternatives->find_alternatives(%parts);
        if ( scalar(@results) == 1 && $results[0] eq $curlang ) {
            push @reasoning, sprintf( '    Alternatives: No alternatives found for %s', $curlang );
        }
        else {
            push @reasoning,
              sprintf(
                '    Alternatives: From %s, got the following alternatives: %s', $curlang,
                join( q{, }, @results )
              );
        }
        @alts = ( @alts, @results );
    }
    push @reasoning,
      sprintf( '    Alternatives: Found %d potential languages: %s', scalar(@alts), join( q{, }, @alts ) );
    my %langresults = _validate_dedupe_multiple(@alts);
    for ( @{ $langresults{'reasoning'} } ) {
        push @reasoning, sprintf( '    Alternatives: %s', $_ );
    }
    @invalid_languages = _dedup_preserve_order( @invalid_languages, @{ $langresults{'invalid_languages'} } );
    if ( @languages eq @{ $langresults{'languages'} } ) {
        push @reasoning, '<<< Alternatives: Returned validated languages same as input';
        return;
    }
    push @reasoning, sprintf( '--- Alternatives: Removing existing languages: %s', join( q{, }, @languages ) );
    @languages = @{ $langresults{'languages'} };    # replace
    push @reasoning,
      sprintf( '+++ Alternatives: Replacing languages wtih: %s', join( q{, }, @languages ) );
    push @reasoning, sprintf(
        '<<< Alternatives: Found %d alternatives of which %d came back valid: %s', scalar(@alts),
        scalar( @{ $langresults{'languages'} } ), join( q{, }, @{ $langresults{'languages'} } )
    );
    return 1;
}

sub _add_previous() {
    if ( !@previous_languages ) {
        push @reasoning, 'Previous: No languages previous used';
        return;
    }
    my %langresults = _validate_dedupe_multiple(@previous_languages);
    push @reasoning, sprintf(
        '+++ Previous: Found %d valid looking languages and %d invalid looking',
        scalar @{ $langresults{'languages'} },
        scalar @{ $langresults{'invalid_languages'} }
    );
    @languages         = _dedup_preserve_order( @languages,         @{ $langresults{'languages'} } );
    @invalid_languages = _dedup_preserve_order( @invalid_languages, @{ $langresults{'invalid_languages'} } );
    return 1;
}

sub _add_provided() {
    if ( !@provided_languages ) {
        push @reasoning, 'Provided: No provided languages to add';
        return;
    }
    my %langresults = _validate_dedupe_multiple(@provided_languages);
    @languages         = _dedup_preserve_order( @languages,         @{ $langresults{'languages'} } );
    @invalid_languages = _dedup_preserve_order( @invalid_languages, @{ $langresults{'invalid_languages'} } );
    push @reasoning, sprintf(
        '+++ Provided: Found %d valid looking languages and %d invalid looking',
        scalar @{ $langresults{'languages'} },
        scalar @{ $langresults{'invalid_languages'} }
    );
    return 1;
}

sub _loop() {
    for my $setting (@configuration) {
        my @prior = @languages;
        my $ref   = ref($setting);
        if ( $ref ne q{} ) {
            croak( sprintf( 'Unrecognised language configuration option of type "%s"', $ref ) );
        }
        _switch($setting);
        if ( scalar(@languages) == 0 ) {
            push @reasoning, 'Callback: Skipping as no valid languages';
        }
        elsif ( @prior eq @languages ) {
            push @reasoning, 'Callback: Skipping as languages are the same';
        }
        else {
            if ( _send_to_callback() && !$get_multiple ) {
                last;
            }

        }
    }
    if ( !@matched_languages ) {
        push @reasoning, 'Failed to find any language settings/configurations accepted by the callback';
        return 0;
    }
    @matched_languages = _dedup_preserve_order(@matched_languages);
    push @reasoning,
      sprintf(
        'Found %d languages acceptable to the callback: %s', scalar(@matched_languages),
        join( ', ', @matched_languages )
      );
    return 1;

}

sub _dedup_preserve_order (@array) {
    my ( @output, %status );
    for (@array) {
        if ( !$status{$_} ) {
            $status{$_} = 1;
            push @output, $_;
        }
    }
    return @output;
}

sub _no_callback() {
    my $matched = 0;
    push @reasoning, sprintf( '>>> Callback: No callback defined for languages: %s', join( q{, }, @languages ) );
    for my $curlang (@languages) {
        if ( ref($curlang) ne q{} ) {
            croak( sprintf( 'Received curlang of type %s - expected scalar string', ref($curlang) ) );
        }
        if ( $tried_languages{$curlang} ) {
            push @reasoning, sprintf( '    Callback: %s: (Undef callback): Skipping as already tried', $curlang );
            next;
        }
        $tried_languages{$curlang} = 1;
        push @reasoning,         sprintf( '    Callback: %s: (Undef callback): Accepting', $curlang );
        push @matched_languages, $curlang;
        $matched++;
        if ($get_multiple) {
            next;
        }
        else {
            last;
        }
    }
    push @reasoning, sprintf( '<<< Callback: (Undef callback): matched %s languages', $matched );
    return $matched;
}

sub _send_to_callback() {
    if ( !defined($callback) ) {
        return _no_callback();
    }
    my $callback_result;
    my $matched = 0;
    push @reasoning, sprintf( '>>> Callback: Entering with languages: %s', join( q{, }, @languages ) );
    for my $curlang (@languages) {
        if ( ref($curlang) ne q{} ) {
            croak( sprintf( 'Received curlang of type %s - expected scalar string', ref($curlang) ) );
        }
        if ( $tried_languages{$curlang} ) {
            push @reasoning, sprintf( '    Callback: %s: Skipping as already tried', $curlang );
            next;
        }
        $tried_languages{$curlang} = 1;

        # expect callback to either return 1/true, throw error or
        # to return null/undef/0/false. errors will be logged as warnings (and undef returned)
        if (
            !eval {
                $callback_result = $callback->($curlang);
                1;
            }
        ) {
            my $err = ( ( $@ || $! || '[Unknown reasoning]' ) );
            carp( sprintf( 'Callback: %s: the following error occured: %s', $curlang, $err ) );
            push @reasoning,          sprintf( 'XXX Callback: %s: Errored: %s', $curlang, $err );
            push @rejected_languages, $curlang;
            next;
        }
        if ( defined($callback_result) ) {
            if ($callback_result) {
                push @reasoning,         sprintf( '    Callback: %s: MATCHED', $curlang );
                push @matched_languages, $curlang;
                $matched++;
                if ($get_multiple) {
                    next;
                }
                else {
                    last;
                }
            }
            else {
                push @reasoning,
                  sprintf(
                    '    Callback: %s: Returned non-true return value: %s', $curlang,
                    ( ref($callback_result) ? '[Ref Type:' . ref($callback_result) . q{]} : $callback_result )
                  );
                push @rejected_languages, $curlang;
                next;
            }
        }

        # only reaches here if callback_result is not defined
        push @rejected_languages, $curlang;
        push @reasoning,          sprintf( '    Callback: %s: Did not return a result', $curlang );
    }
    push @reasoning, sprintf( '<<< Callback matched %s languages', $matched );
    return $matched;
}

sub _switch ($setting) {
    my $label = $setting;
    if ( defined( $lookups{$setting} ) ) {
        $lookups{$setting}->();
        return 1;
    }

    # detector
    if ( index( $setting, q{::} ) >= 0 ) {
        _use_detector($setting);

        return 1;
    }

    # fallback
    my %langresults = $language_code_validator->validate($setting);
    if ( $langresults{'status'} == 1 ) {
        push @reasoning,             sprintf( '+++ Specified: Adding "%s" as a manual language', $langresults{'code'} );
        push @languages,             $langresults{'code'};
        push @encountered_languages, $langresults{'code'};
        return 1;
    }
    croak(
        sprintf(
            'Unrecognised language configuration option: "%s" (%s) when trying to find languages.',
            $setting, $langresults{'reasoning'}
        )
    );
}

sub _use_detector ($detector_name) {
    my $first_character = substr( $detector_name, 0, 1 );
    my $package         = $detector_name;
    my $label           = $package;

    # Tilde ~ indicates "maybe use this package if available, if not, don't worry/warn/error"
    # Exclamation mark ! "use this package if available, raise warning if not available"
    if ( $first_character eq q{~} ) {
        $package = substr( $detector_name, 1 );
        $label   = sprintf( 'Detector %s (ignore-errors)', $package );
    }
    elsif ( $first_character eq q{!} ) {

        $package = substr( $detector_name, 1 );
        $label   = sprintf( 'Detector %s (warn-errors)', $package );
    }
    else {
        $label = sprintf( 'Detector %s (default)', $package );
    }
    push @reasoning, sprintf( '>>> %s: Starting detector', $label );
    my %load_result = $package_loader->attempt_package_load($package);
    if ( !$load_result{'status'} ) {
        return _detector_log_carp_or_croak(
            $first_character, $label,
            sprintf( 'During loading: %s', $load_result{'reasoning'} || '[Unknown reason]' )
        );
    }
    push @reasoning, sprintf( '    %s: Package loaded', $label );
    my %detector_ran_results;
    if (
        !eval {
            ## no critic (ErrorHandling::RequireCarping)
            my $can = _detector_check_can_detect($package) || die('No "detect" subroutine found');
            %detector_ran_results =
                _detector_check_can_new($package)
              ? _detector_run_detect_with_new( $package, $can )
              : _detector_run_detect_without_new( $package, $can );

            if ( !$detector_ran_results{'status'} ) {
                die( $detector_ran_results{'reasoning'} || '[Unknown reason]' );
            }
            if ( !$detector_ran_results{'result'} ) {
                die('Invalid return from "detect". Nothing returned');
            }
            1;
        }
    ) {
        my $err = ( $@ || $! || '[Unknown reasoning]' );
        return _detector_log_carp_or_croak(
            $first_character, $label,
            sprintf( 'During processing: %s', $err )
        );
    }
    my %check_results = _use_detector_check_result( $label, \%{ $detector_ran_results{'result'} } );
    if ( $check_results{'status'} ) {
        return;
    }
    return _detector_log_carp_or_croak(
        $first_character, $label,
        sprintf( 'During results processing: %s', $check_results{'reasoning'} || '[Unknown]' )
    );
}

sub _detector_log_carp_or_croak ( $first_character, $label, $reasoning ) {

    # nothing, so error/die.
    if ( $first_character eq q{} ) {
        croak( sprintf( '%s: %s', $label, $reasoning ) );
    }
    push @reasoning, sprintf( 'XXX %s: %s', $label, $reasoning );
    push @reasoning, sprintf( '<<< %s: Exiting due to fault', $label );

    # log/warn
    if ( $first_character eq q{!} ) {
        carp( sprintf( '%s: %s', $label, $reasoning ) );
    }
    return;
}

sub _detector_check_can_detect ($package) {
## no critic (ErrorHandling::RequireCarping)
    my $local_death = 0;
    local $SIG{__DIE__} =
      sub { $local_death ? die( $_[0] ) : die( sprintf( 'Error during check_can_detect: "%s"', $_[0] ) ); };

    local $SIG{__WARN__} = sub { $local_death = 1; die( sprintf( 'Warning during check_can_detect: "%s"', $_[0] ) ); };

    my $can = $package->can('detect');
    if ( !$can ) {
        return 0;
    }
    return $can;
}

sub _detector_check_can_new ($package) {
## no critic (ErrorHandling::RequireCarping)
    my $local_death = 0;
    local $SIG{__DIE__} =
      sub { $local_death ? die( $_[0] ) : die( sprintf( 'Error during check_can_new: "%s"', $_[0] ) ); };

    local $SIG{__WARN__} =
      sub { $local_death = 1; die( sprintf( 'Warning during check_can_new: "%s"', $_[0] ) ); };

    my $can = $package->can('new');
    if ( !$can ) {
        return 0;
    }
    return $can;
}

sub _detector_run_detect_without_new ( $package, $detect_can ) {

## no critic (ErrorHandling::RequireCarping)
    my $local_death = 0;

    local $SIG{__DIE__} =
      sub { $local_death ? croak( $_[0] ) : croak( sprintf( 'Error during run_detect_without_new: "%s"', $_[0] ) ); };
    local $SIG{__WARN__} =
      sub { $local_death = 1; croak( sprintf( 'Warning during run_detect_without_new: "%s"', $_[0] ) ); };
    my @result_array = $detect_can->(%dependencies_for_others);
    my $scalar       = scalar(@result_array);
    if ( $scalar == 0 ) {
        die('Invalid return from "detect". No data returned.');
    }
    if ( $scalar % 2 ) {
        die(
            sprintf(
                'Invalid return from "detect". Expected a hash to be returned, got what appears to be %s',
                ref( $result_array[0] ) || 'scalar'
            )
        );
    }
    my %result = @result_array;
    return ( 'status' => 1, 'result' => \%result );
}

sub _detector_run_detect_with_new ( $package, $detect_can ) {

## no critic (ErrorHandling::RequireCarping)
    my $local_death = 0;
    local $SIG{__DIE__} = sub {
        $local_death ? die( $_[0] ) : die( sprintf( 'Error during run_detect_with_new (preparing new): "%s"', $_[0] ) );
    };

    local $SIG{__WARN__} = sub {
        $local_death = 1;
        die( sprintf( 'Warning during run_detect_with_new (preparing new): "%s"', $_[0] ) );
    };
    my $detector = $package->new(%dependencies_for_others);
    if ( !defined($detector) ) {
        return ( 'status' => 0, 'reasoning' => 'Invalid return from "new". Nothing returned' );
    }
    if ( !blessed($detector) || !$detector->isa($package) ) {
        my $ref = ref($detector);
        return (
            'status'    => 0,
            'reasoning' => sprintf(
                'Invalid return from "new". Expected a blessed object: got %s', ( $ref ? $ref : 'scalar: ' . $detector )
            )
        );
    }

    local $SIG{__DIE__} =
      sub { die( $local_death ? die( $_[0] ) : sprintf( 'Error during run_detect_with_new: "%s" ', $_[0] ) ); };

    local $SIG{__WARN__} =
      sub { $local_death = 1; die( sprintf( 'Warning during run_detect_with_new: "%s" ', $_[0] ) ); };
    my @result_array = $detect_can->($detector);
    my $scalar       = scalar(@result_array);
    if ( $scalar == 0 ) {
        die('Invalid return from "detect". No data returned.');
    }
    if ( $scalar % 2 ) {
        die(
            sprintf(
                'Invalid return from "detect". Expected a hash to be returned, got what appears to be %s',
                ref( $result_array[0] ) || 'scalar'
            )
        );
    }
    my %result = @result_array;
    return ( 'status' => 1, 'result' => \%result );
}

sub _use_detector_check_result ( $label, $result ) {
    my ( @new_languages, @new_invalid_languages, @new_reasoning );
    my $ref = ref($result);
    if ( $ref ne 'HASH' ) {
        return (
            'status'    => 0,
            'reasoning' => sprintf(
                'Invalid return from "detect". Expected a hash: got %s', ( $ref ? $ref : 'scalar: ' . $result )
            )
        );
    }
    if ( !exists( $result->{'languages'} ) ) {
        return (
            'status'    => 0,
            'reasoning' => 'Invalid return from "detect". No languages returned'
        );
    }
    if ( defined( $result->{'languages'} ) ) {
        $ref = ref( $result->{'languages'} );
        if ( $ref ne 'ARRAY' ) {
            return (
                'status'    => 0,
                'reasoning' => sprintf(
                    'Invalid return from "detect". Languages not returned as array: got %s',
                    ( $ref ? $ref : 'scalar: ' . $result->{'languages'} )
                )
            );
        }
        @new_languages = @{ $result->{'languages'} };
    }
    if ( !exists( $result->{'reasoning'} ) ) {
        return (
            'status'    => 0,
            'reasoning' => 'Invalid return from "detect". No reasoning returned'
        );
    }
    if ( defined( $result->{'reasoning'} ) ) {
        $ref = ref( $result->{'reasoning'} );
        if ( $ref ne 'ARRAY' ) {
            return (
                'status'    => 0,
                'reasoning' => sprintf(
                    'Invalid return from "detect". Reasoning not returned as array: got %s',
                    ( $ref ? $ref : 'scalar: ' . $result->{'reasoning'} )
                )
            );
        }
        for ( @{ $result->{'reasoning'} } ) {
            push @new_reasoning, sprintf( '    %s: Reasoning: %s', $label, $_ );
        }
    }
    if ( defined( $result->{'invalid_languages'} ) ) {
        $ref = ref( $result->{'invalid_languages'} );
        if ( $ref ne 'ARRAY' ) {
            return (
                'status'    => 0,
                'reasoning' => sprintf(
                    'Invalid return from "detect". If set, invalid_languages must be an array: got %s',
                    ( $ref ? $ref : 'scalar: ' . $result->{'invalid_languages'} )
                )
            );
        }
        if ( @{ $result->{'invalid_languages'} } ) {
            @new_invalid_languages = @{ $result->{'invalid_languages'} };
            push @new_reasoning,
              sprintf(
                '    %s: Found %d invalid languages during detection: %s', $label, scalar(@new_invalid_languages),
                join( q{, }, @new_invalid_languages )
              );
        }
        else {
            push @new_reasoning, sprintf( '    %s: No invalid languages returned internally by detector', $label );
        }
    }

    # we've passed validation.
    @reasoning = ( @reasoning, @new_reasoning );
    if ( !@new_languages ) {
        push @reasoning, sprintf( '<<< %s: No languages returned', $label );
        return ( 'status' => 1 );
    }
    push @reasoning, sprintf( '    %s: Returned languages: %s', $label, join( q{, }, @new_languages ) );
    my %langresults = _validate_dedupe_multiple(@new_languages);
    for ( @{ $langresults{'reasoning'} } ) {
        push @reasoning, sprintf( '    %s: %s', $label, $_ );
    }
    push @reasoning,
      sprintf( '+++ %s: Returning with languages: %s', $label, join( q{, }, @{ $langresults{'languages'} } ) );
    my $old_size = scalar(@languages);
    @languages = _dedup_preserve_order( @languages, @{ $langresults{'languages'} } );
    @invalid_languages =
      _dedup_preserve_order( @invalid_languages, @new_invalid_languages, @{ $langresults{'invalid_languages'} } );
    push @reasoning, sprintf( '<<< %s: Exiting with %d new languages', $label, ( scalar(@languages) - $old_size ) );
    return ( 'status' => 1 );
}

1;
