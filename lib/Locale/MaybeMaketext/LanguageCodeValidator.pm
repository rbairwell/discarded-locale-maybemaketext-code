package Locale::MaybeMaketext::LanguageCodeValidator;

# pragmas
use v5.20.0;
use strict;
use warnings;
use vars;
use utf8;
use Carp         qw/croak/;
use Scalar::Util qw/blessed/;

use autodie qw/:all/;
use feature qw/signatures/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;
use constant MAXIMUM_TAG_LENGTH           => 8;
use constant MINIMUM_LANGUAGE_CODE_LENGTH => 2;
use constant MAXIMUM_LANGUAGE_CODE_LENGTH => 3;

sub new ( $class, %settings ) {
    if (   !blessed( $settings{'cache'} )
        || !$settings{'cache'}->isa('Locale::MaybeMaketext::Cache') ) {
        croak('Invalid cache');
    }
    return bless {
        'basic' => ( $settings{'basic'} || 0 ),
        'cache' => $settings{'cache'}->get_namespaced('LanguageCodeValidator')
    }, $class;
}

sub _get_cache ( $self, $cache_key ) {
    return wantarray ? $self->{'cache'}->get_cache($cache_key) : $self->{'cache'}->get_cache($cache_key);
}

sub _set_cache ( $self, $cache_key, @data ) {
    return $self->{'cache'}->set_cache( $cache_key, @data );
}

sub get_basic_setting ($self) {
    return $self->{'basic'};
}

sub _update_code_langtag_from_parts ( $self, %myparts ) {
    my $cache_key = 'langtag_from_parts_' . join( q{|}, %myparts );
    if ( $self->_get_cache($cache_key) ) {
        return $self->_get_cache($cache_key);
    }
    my ( @wanted_fields, @langtag_fields );
    for (qw/language extlang script region variant extension private irregular regular/) {
        if ( defined( $myparts{$_} ) ) {
            push @wanted_fields, $myparts{$_};
            if (   $_ eq 'language'
                || $_ eq 'extlang'
                || $_ eq 'script'
                || $_ eq 'region'
                || $_ eq 'variant'
                || $_ eq 'extension'
                || $_ eq 'private' ) {
                push @langtag_fields, $myparts{$_};
            }
        }
    }
    $myparts{'code'} = join( '_', @wanted_fields );
    if ( defined( $myparts{'language'} ) ) {

        # update langtag
        $myparts{'langtag'} = join( '_', @langtag_fields );
    }
    else {
        # no language = no langtag
        delete $myparts{'langtag'};
    }
    return $self->_set_cache( $cache_key, %myparts );
}

sub _alpha_lengths ( $self, $name, $min, $max, $value ) {
    my $length = length($value);
    if ( $length < $min || $length > $max ) {
        return [
            'status'    => 0,
            'reasoning' => sprintf(
                '%s "%s" is an invalid length (%d) - it should be between %d and %d inclusive',
                $name, $value, $length, $min, $max
            )
        ];
    }
    if ( $value !~ /\A[[:lower:]]*\z/ ) {
        return [
            'status'    => 0,
            'reasoning' => sprintf(
                '%s "%s" has invalid characters - only lower case a-z is permitted',
                $name, $value
            )
        ];
    }
    return 0;
}

# https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.4
sub _check_language ( $self, $language ) {
    my %results;
    if ( $self->_get_cache( 'check_language_' . $language ) ) {
        return $self->_get_cache( 'check_language_' . $language );
    }
    my $check =
      $self->_alpha_lengths( 'Language code', MINIMUM_LANGUAGE_CODE_LENGTH, MAXIMUM_LANGUAGE_CODE_LENGTH, $language );
    if ($check) {
        %results = @{$check};
    }
    else {
        my ($first_language_char) = ( substr( $language, 0, 1 ) );
        if ( $first_language_char eq 'q' && $language =~ /\Aq[a-t][[:lower:]]\z/ ) {
            $results{'status'}    = 0;
            $results{'reasoning'} = sprintf(
                'Language codes %s-%s are reserved for private use only - includes "%s"', 'qaa', 'qtz',
                $language
            );
        }
    }
    return $self->_set_cache( 'check_language_' . $language, %results );
}

# https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.4
sub _check_region ( $self, $region ) {
    my %results;
    if ( $self->_get_cache( 'check_region_' . $region ) ) {
        return $self->_get_cache( 'check_region_' . $region );
    }

    # https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.4 part 2
    # "the exception of 'UK', which is an exact synonym for the assigned code 'GB'"
    if ( $region eq 'uk' ) {
        $results{'region'}   = 'gb';
        $results{'_changed'} = 1;
    }
    my ($first_region_char) = ( substr( $region, 0, 1 ) );
    if (   $region eq 'aa'
        || $region eq 'zz'
        || $first_region_char eq 'x'
        || ( $first_region_char eq 'q' && $region =~ /\Aq[m-z]\z/ ) ) {
        $results{'status'}    = 0;
        $results{'reasoning'} = sprintf( 'Region code "%s" is reserved for private use only', $region );
    }
    return $self->_set_cache( 'check_region_' . $region, %results );
}

# https://www.rfc-editor.org/rfc/rfc5646.html#section-2.2.3
sub _check_script ( $self, $script ) {
    if ( $self->_get_cache( 'check_script_' . $script ) ) {
        return $self->_get_cache( 'check_script_' . $script );
    }
    my %results;

    my ($first_script_char) = ( substr( $script, 0, 1 ) );
    if ( $first_script_char eq 'q' && $script =~ /\Aqa(?:a[[:lower:]]|b[a-x])\z/ ) {
        $results{'status'} = 0;
        $results{'reasoning'} =
          sprintf( 'Script codes %s-%s are reserved for private use only - includes "%s"', 'Qaaa', 'Qabx', $script );
    }
    return $self->_set_cache( 'check_script_' . $script, %results );
}

# Checking that variants only have each underscore variant listed once
sub _check_variant ( $self, $variant ) {
    if ( $self->_get_cache( 'check_variant_' . $variant ) ) {
        return $self->_get_cache( 'check_variant_' . $variant );
    }
    my %variant_lookup;
    my %bad_variants;

    # special case for rozaj-biske which is a single word despite being split with - (changed to _)
    my $temporary_variant = ( $variant =~ s/(\A|_)rozaj_biske(\z|_)/$1rozaj-biske$2/r );
    for ( split( /_/, $temporary_variant ) ) {
        my $current_variant = ( $_ =~ tr{-}{_}r );    # any temporary dashed ones change back
        if ( defined( $variant_lookup{$current_variant} ) ) {
            $bad_variants{$current_variant} = 1;
        }
        $variant_lookup{$current_variant}++;
    }
    my %results;
    if (%bad_variants) {
        %results = (
            'reasoning' => sprintf( 'Duplicated variants: %s', join( ', ', keys(%bad_variants) ) ),
            'status'    => 0
        );
    }
    else {
        my @sorted = sort( keys(%variant_lookup) );
        %results = (
            'variants' => \@sorted,
            'variant'  => join( '_', @sorted )
        );
        if ( $results{'variant'} ne $variant ) {

            $results{'_changed'} = 1;
        }
    }

    return $self->_set_cache( 'check_variant_' . $variant, %results );
}

# Really just splits up the privates.
sub _check_private ( $self, $private ) {
    if ( $self->_get_cache( 'check_private_' . $private ) ) {
        return $self->_get_cache( 'check_private_' . $private );
    }

    # privates will start with x_ and then be 1 to 8 (MAXIMUM_TAG_LENGTH) characters in
    # length before an optional another underscore and then repeat.
    my @privates     = split( /_/, $private );
    my @bad_privates = ();
    my %found_privates;
    shift(@privates);    # remove the 'x' at the start.
    my $private_counter = 0;
    for my $current_private (@privates) {
        $private_counter++;
        my $length = length($current_private);
        if ( $length < 1 ) {
            push @bad_privates, sprintf( 'Private entry %d has no text', $private_counter );
            next;
        }
        if ( $length > MAXIMUM_TAG_LENGTH ) {
            push @bad_privates, sprintf(
                'Private entry %d ("%s") exceeds maximum length (it is %d characters in length)',
                $private_counter, $current_private, $length
            );
            next;
        }
        if ( $current_private !~ /\A[[:lower:]\d]*\z/ ) {
            push @bad_privates,
              sprintf( 'Private entry %d ("%s") has invalid characters', $private_counter, $current_private );
            next;
        }
        if ( defined( $found_privates{$current_private} ) ) {
            push @bad_privates,
              sprintf(
                'Private entry %d ("%s") is a duplicate of that found in position %d',
                $private_counter, $current_private, $found_privates{$current_private}
              );
            next;
        }
        $found_privates{$current_private} = $private_counter;
    }
    my %results;
    if (@bad_privates) {
        %results = (
            'reasoning' => sprintf( 'Bad private entries: %s', join( ', ', values(@bad_privates) ) ),
            'status'    => 0
        );
        return $self->_set_cache( 'check_private_' . $private, %results );
    }
    %results = ( 'privates' => \@privates );
    return $self->_set_cache( 'check_private_' . $private, %results );
}

=head2 _check_extension

Check extensions which are separated from other subtags by a non-x singleton.

Singletons should be unique.

As of August 2023, only two extensions have been allocated:
 * "U": December 2010. RFC 6067 "BCP 47 Extension U"
 * "T": February 2012. RFC 6497 "BCP 47 Extension T - Transformed Content"
Accoding to https://www.rfc-editor.org/search/rfc_search_detail.php?title=%22bcp+47%22 .
=over

=item B<Parameters>

=over

=item string: C<$extension>: What is the full extension string we are checking.

=back

=item B<Returns>

hash: Containing a status of "0" and a "reasoning" string giving the reason for the failure
OR
hash: Containing "extensions" (array) of the extensions, "extension" (string) a sorted list of
      the extensions and (optionally) "changed" (1) if "extension" has been changed from what was
      provided.

=cut

sub _check_extension ( $self, $extension ) {
    if ( $self->_get_cache( 'check_extension_' . $extension ) ) {
        return $self->_get_cache( 'check_extension_' . $extension );
    }
    my %results;
    my ( %singletons, %bad_singletons );
    my $extension_matcher = '(?<all>\G(?<singleton>[a-wy-z\d])_'      # capture singleton
      . '(?<extsubtag>[[:lower:]\d]{2,' . MAXIMUM_TAG_LENGTH . '}'    # first match
      . '(?:_[[:lower:]\d]{2,' . MAXIMUM_TAG_LENGTH . '})*'           # allow data to repeat
      . ')'                                                           # end extsubtag
      . ')*';                                                         # end all
    my $extsubtag_matcher = '(?:\A|_)(?<subtag>[[:lower:]\d]{2,' . MAXIMUM_TAG_LENGTH . '})';
  EXTLOOP: while ( $extension =~ /$extension_matcher/g ) {
        if ( !defined( $+{'singleton'} ) || !defined( $+{'extsubtag'} ) ) {
            next;
        }
        my $singleton = $+{'singleton'};
        if ( defined( $singletons{$singleton} ) ) {
            $bad_singletons{$singleton} = sprintf( 'Duplicated singleton "%s"', $singleton );
            next EXTLOOP;
        }

        # check the singleton has been allocated.
        if ( $singleton ne 't' && $singleton ne 'u' ) {
            $bad_singletons{$singleton} =
              sprintf( 'Invalid singleton "%s" - only "t" and "u" are accepted for extensions', $singleton );
            next EXTLOOP;
        }
        $singletons{$singleton} = ();
        my %exts;
        my $extsubtag = $+{'extsubtag'};
        while ( $extsubtag =~ /$extsubtag_matcher/g ) {
            if ( defined( $exts{ $+{'subtag'} } ) ) {
                $bad_singletons{$singleton} =
                  sprintf( 'Singleton "%s" has duplicated extension: %s', $singleton, $+{'subtag'} );
                next EXTLOOP;
            }
            $exts{ $+{'subtag'} }++;
        }
        $singletons{$singleton} = join( '_', sort( keys(%exts) ) );
    }
    if (%bad_singletons) {
        %results = (
            'reasoning' => sprintf( 'Bad singletons: %s', join( ', ', values(%bad_singletons) ) ),
            'status'    => 0
        );
        return $self->_set_cache( 'check_extension_' . $extension, %results );
    }
    my (@temp_extensions);
    for ( sort( keys(%singletons) ) ) {
        push @temp_extensions, ( $_ . '_' . $singletons{$_} );
    }
    %results = (
        'extensions' => \@temp_extensions,
        'extension'  => join( '_', @temp_extensions )
    );
    if ( $results{'extension'} ne $extension ) {

        $results{'_changed'} = 1;
    }
    return $self->_set_cache( 'check_extension_' . $extension, %results );
}

=for comment

Language tags regular expression based off RFC5646 (part of BCP 47) as detailed in
https://www.rfc-editor.org/info/bcp47 
https://www.rfc-editor.org/rfc/rfc5646.html
https://www.w3.org/International/articles/language-tags/ .
 RFC5646 "Tags for Identifying Languages" obsoleted:
   - RFC4646 "Tags for identifying languages" which (with RFC4647 "Matching of Language Tags") obsoleted
     - RFC3066 "Tags for the Identification of Languages" which obsoleted
       - RFC1766 "Tags for the Identification of Languages"
 Format: language-extlang-script-region-variant-extension-privateuse
   language is 2 or 3 letters MUST be set (unless private or extension)
   extlang always 3 letters. optional. must follow language.
   script always 4 letters optional. must follow language or extlang tag.
   region is 2 letters or 3 digit code. optional. must follow language, extlang or script tag.
   variant is 5 to 8 alphanum or a digit followed by 3 alphanum. optional. must follow language, extlang or script tag. may be repeated.
   extensions start with any character/digit (apart from x), dash and then 2-8 alphas. this can repeat.
   privates start with 'x' dash and then 2 - 8 alphas which can repeat.
      anything after 'x' is considered private. may or may not be preceded by language, extlang etc .


=cut

sub _get_regular_expression ($self) {
    if ( defined( $self->{'regular_expression'} ) ) {
        return $self->{'regular_expression'};
    }

    # these are repeated:
    my $variant_base = '(?:[[:lower:]\d]{5,' . MAXIMUM_TAG_LENGTH . '}|\d[[:lower:]\d]{3,7})';
    my $extension_base =
        '[a-wy-z\d]_(?:[[:lower:]\d]{2,'
      . MAXIMUM_TAG_LENGTH
      . '})(?:_[[:lower:]\d]{2,'
      . MAXIMUM_TAG_LENGTH
      . '})*';    # no "x" as that is for private.
    my $regular_expression = '\A(?<code>'

      # private tags may sit alone (i.e. without an inital underscore)
      . '(?<private>x_.*)?'

      # start grandfathered in settings
      . '|(?:'
      . '(?<irregular>en_gb_oed|sgn_be_ft|sgn_be_nl|sgn_ch_de|'
      . 'i_ami|i_bnn|i_default|i_enochian|i_hak|i_klingon|i_lux|i_mingo|i_navajo|i_pwn|i_tao|i_tay|i_tsu)?'
      . '(?<regular>art_lojban|cel_gaulish|no_bok|no_nyn|zh_guoyu|zh_hakka|zh_min|zh_min_nan|zh_xiang)?'

      # end grandfathered
      . ')'

      # start the main "language code tag/langtag"
      . '|(?<langtag>'

      # now the individual sections
      . '(?<language>[^_]+)'                       # 2-3 alphas: length validation is done in checker
      . '(?:_(?<extlang>[[:lower:]]{3}))?'         # optional 3 alphas
      . '(?:_(?<script>[[:lower:]]{4}))?'          # optional 4 alphas
      . '(?:_(?<region>[[:lower:]]{2}|\d{3}))?'    # optional 2 alphas or 3 digits

      # variants may repeat multiple times
      . "(?:_(?<variant>$variant_base(?:_$variant_base)*))?"

      # extensions may repeat multiple times
      . "(?:_(?<extension>$extension_base(?:_$extension_base)*))?"

      # private tags may follow the above
      . '(?:_(?<private>x_.*))?'

      # end langtag
      . ')'

      # end all/code
      . ')\z';

    # qr=build+cache into regexp object, aa = enforce ascii
    $regular_expression = qr/$regular_expression/aa;
    $self->{'regular_expression'} = $regular_expression;
    return $regular_expression;
}

sub validate ( $self, $langcode ) {
    if ( !defined($langcode) ) {
        return ( 'status' => 0, 'reasoning' => 'No language code provided' );
    }
    if ( ref($langcode) ne q{} ) {
        return ( 'status' => 0, 'reasoning' => 'Language code must be a scalar string' );
    }
    if ( $self->_get_cache( 'validate_' . $self->{'basic'} . $langcode ) ) {
        return $self->_get_cache( 'validate_' . $self->{'basic'} . $langcode );
    }

    # normalise: lower case, change dashes to underscores and remove spaces before compare to regular expression.

    my $to_match = ( lc( $langcode =~ tr{-}{_}r ) =~ s/\s//gr );
    if ( length($to_match) < 2 ) {
        return $self->_set_cache(
            'validate_' . $self->{'basic'} . $langcode,
            ( 'status' => 0, 'reasoning' => 'Language code is empty/too short' )
        );
    }
    if ( $self->_get_cache( 'validate_' . $self->{'basic'} . $to_match ) ) {

        # copy across from normalised
        $self->_set_cache(
            'validate_' . $self->{'basic'} . $langcode,
            $self->_get_cache( 'validate_' . $self->{'basic'} . $to_match )
        );
        return $self->_get_cache( 'validate_' . $self->{'basic'} . $to_match );
    }

    my $regular_expression = $self->_get_regular_expression();

    # tentively mark as valid.
    my %to_return = ( 'status' => 1, 'reasoning' => 'OK' );

    if ( $to_match !~ $regular_expression ) {
        %to_return = ( 'status' => 0, 'reasoning' => 'Failed regular expression match' );
        $self->_set_cache( 'validate_' . $self->{'basic'} . $langcode, %to_return );
        return $self->_set_cache( 'validate_' . $self->{'basic'} . $to_match, %to_return );
    }

    # map across what we want
    if ( $self->{'basic'} ) {
        for (qw/langtag language script region irregular regular/) {
            if ( defined( $+{$_} ) ) {
                $to_return{$_} = $+{$_};
            }
        }
        %to_return = $self->_update_code_langtag_from_parts(%to_return);
    }
    else {
        for (qw/code langtag language extlang script region variant extension private irregular regular/) {
            if ( defined( $+{$_} ) ) {
                $to_return{$_} = $+{$_};
            }
        }
    }

    %to_return = $self->_validate_checkers(%to_return);

    $self->_set_cache( 'validate_' . $self->{'basic'} . $langcode, %to_return );
    return $self->_set_cache( 'validate_' . $self->{'basic'} . $to_match, %to_return );

}

sub _validate_checkers ( $self, %to_return ) {
    my %checkers = (
        'language'  => sub { $self->_check_language(@_) },
        'region'    => sub { $self->_check_region(@_) },
        'script'    => sub { $self->_check_script(@_) },
        'variant'   => sub { $self->_check_variant(@_) },
        'extension' => sub { $self->_check_extension(@_) },
        'private'   => sub { $self->_check_private(@_) },
    );

    # check each one
    for my $section (qw/language region script variant extension private/) {

        if ( !defined( $to_return{$section} ) || !defined( $checkers{$section} ) ) {
            next;
        }
        my %results = $checkers{$section}->( $to_return{$section} );
        for ( keys(%results) ) {
            $to_return{$_} = $results{$_};
        }
        if ( $to_return{'_changed'} ) {

            # rebuild code.
            delete $to_return{'_changed'};
            %to_return = $self->_update_code_langtag_from_parts(%to_return);
        }
        if ( $to_return{'status'} == 0 && !defined( $to_return{'reasoning'} ) ) {
            croak('Code came back invalid, but no reasoning set');
        }
        if ( $to_return{'status'} == 0 ) {

            # return if faulty.
            last;
        }
    }
    return %to_return;
}

sub dedup_multiple ( $self, @langcodes ) {
    my %known_languages;
    my @okay_languages;
    my @duplicated_languages;
    my %validated = $self->validate_multiple(@langcodes);
    for my $curlang ( @{ $validated{'languages'} } ) {
        if ( $known_languages{$curlang} ) {
            if ( $known_languages{$curlang} == 1 ) {
                push @duplicated_languages, $curlang;
            }
            $known_languages{$curlang} += 1;
            next;
        }
        push @okay_languages, $curlang;
        $known_languages{$curlang} = 1;
    }
    $validated{'languages'} = \@okay_languages;
    if (@duplicated_languages) {
        my @reasoning = @{ $validated{'reasoning'} };
        for my $curlang (@duplicated_languages) {
            push @reasoning, sprintf( 'Removed %d duplicates of "%s"', ( $known_languages{$curlang} - 1 ), $curlang );
        }
        $validated{'reasoning'} = \@reasoning;
    }
    return %validated;
}

sub validate_multiple ( $self, @langcodes ) {
    my ( @languages, @invalid_languages, @reasoning ) = ( (), (), () );
    for my $index ( 0 .. $#langcodes ) {
        my $cur         = $langcodes[$index];
        my %langresults = $self->validate($cur);
        my $ref         = ref($cur);
        if ( $langresults{'status'} == 1 ) {
            push @languages, $langresults{'code'};
        }
        else {
            if ($ref) {
                push @invalid_languages, "[Type: $ref] at position $index";
            }
            else {
                push @invalid_languages, $cur;
            }
        }
        if ( $langresults{'reasoning'} ) {
            push @reasoning,
              sprintf(
                'Language "%s" in position %d: %s', ( $ref ? "[Type: $ref]" : $cur ), $index,
                $langresults{'reasoning'}
              );
        }
    }
    return (
        'languages'         => \@languages,
        'invalid_languages' => \@invalid_languages,
        'reasoning'         => \@reasoning,
    );
}

1;
