#!perl
## no critic (ErrorHandling::RequireCarping)
# pragmas
use v5.20.0;    # minimum of v5.20.0 due to use of signatures, state and lexical_subs.
use strict;
use warnings;
use vars;
use utf8;

use autodie qw(:all);
use feature qw/signatures state lexical_subs/;    # state=5.10.0,others=5.20
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures experimental::lexical_subs/;

use File::Basename();
use File::Spec();
use List::Util qw/none/;

state sub _produce_output_for_item ( $tab, $dataset_name, $item, %dataset ) {
    my $equals = ' => ';
    my $output;
    my $longest_key = 0;
    for my $key ( keys(%dataset) ) {
        if ( length($key) > $longest_key ) {
            $longest_key = length($key);
        }
    }

    for my $key ( sort keys(%dataset) ) {
        my $value = $dataset{$key};
        if ( !defined($value) ) {
            die( sprintf( 'Unable to find value for key "%s" in %s dataset "%s"', $key, $dataset_name, $item ) );
        }
        $key   =~ tr{-}{_};
        $value =~ tr{-}{_};
        my $spacing = q{ } x ( ( $longest_key - length($key) ) );
        $output .= "\n$tab'$key'$spacing$equals'$value',";
    }
    return $output;
}

state sub _get_data_block() {

    my ( $line, @perl_source, %to_match );
    my @wanted_items = qw/languages regions fulls/;
    my $regexp       = '\Amy \%(?<item>' . join( q{|}, @wanted_items ) . ')\s+\= \(\);\z';
    $regexp = qr/$regexp/aa;
    while ( $line = <DATA> ) {
        chomp $line;
        if ( $line =~ $regexp ) {
            $to_match{ $+{'item'} } = 1;
        }
        push @perl_source, $line;
    }
    close DATA;
    if ( $perl_source[0] ne 'package Locale::MaybeMaketext::Alternatives;' ) {
        die( sprintf( 'Data block does not start with package declaration (received "%s")', $perl_source[0] ) );
    }
    my $line_count = scalar(@perl_source);
    if ( $perl_source[ $line_count - 1 ] ne '1;' ) {
        die( sprintf( 'Data block does end with line of "1;" (received "%s")', $perl_source[ $line_count - 1 ] ) );
    }
    for my $varname (@wanted_items) {
        if ( !$to_match{$varname} ) {
            die( sprintf( 'Data block appears to be missing "my %%%s = ();" line', $varname ) );
        }
    }
    return @perl_source;
}

state sub _backmap ( $type, %mappings ) {
    my %duplicate_mappings;
    my %reverse_mappings;
    for my $cur ( sort keys(%mappings) ) {
        my $value = $mappings{$cur};
        if ( $mappings{$value} ) {
            warn(
                sprintf(
                    'Cannot backmap %s code "%s" for "%s" as it already exists as a forward mapping for "%s"',
                    $type, $value, $cur, $mappings{$value}
                  )
                  . "\n"
            );
            $duplicate_mappings{$cur} = 1;
            next;
        }
        if ( $reverse_mappings{$value} ) {
            warn(
                sprintf(
                    'Cannot backmap %s code "%s" for "%s" as it already exists as a reverse mapping for "%s"',
                    $type, $value, $cur, $reverse_mappings{$value}
                  )
                  . "\n"
            );
            $duplicate_mappings{$cur} = 1;
            next;
        }
        $reverse_mappings{$value} = $cur;
    }
    for ( keys(%duplicate_mappings) ) {
        delete $reverse_mappings{$_};
    }
    return \%reverse_mappings;
}

state sub _process_iana_file ( $filehandle, $callback ) {
    my %current = ();
    my $line;
    while ( !eof($filehandle) ) {
        if ( !defined( $line = readline($filehandle) ) ) {
            die(
                sprintf(
                    'Failed to get result from readline: %s around line %d',
                    $1, $filehandle->input_line_number
                )
            );
        }
        chomp( $line = lc($line) );
        if ( $line eq q{%%} ) {
            $callback->(%current);
            %current = ();
            next;
        }
        if ( $line =~ /\A(type|tag|subtag|prefix|preferred\-value): (.*)\z/ ) {
            if ( !$current{'start_line'} ) {
                $current{'start_line'} = $filehandle->input_line_number;
            }
            if ( $current{$1} ) {
                if ( $1 eq 'prefix' ) {
                    $current{$1} = join( q{|}, $current{$1}, $2 );
                    next;
                }
                else {
                    die(
                        sprintf(
                            'Duplicate record type "%s" around line %d',
                            $1, $filehandle->input_line_number
                        )
                    );
                }
            }
            $current{$1} = $2;
        }
    }
    $callback->(%current);
    return 0;
}

state sub _validate_block (%current) {
    if ( !%current ) {
        return 0;
    }
    if ( !$current{'start_line'} ) {
        die('start_line is missing');
    }
    my $line_number = $current{'start_line'};
    if ( !$current{'type'} ) {
        die(
            sprintf(
                'Type: is missing in block starting at line %d',
                $line_number
            )
        );
    }
    my $type       = $current{'type'};
    my %type_specs = (
        'language' => [ 'requires' => 'subtag', 'regexp' => [ 'subtag' => '(?:[[:lower:]]{2,3}|qaa\.\.qtz)' ] ],
        'extlang'  => [ 'requires' => 'subtag', 'allow'  => 'prefix', 'regexp' => [ 'subtag' => '[[:lower:]]{3}' ] ],
        'script'   => [ 'requires' => 'subtag', 'regexp' => [ 'subtag' => '(?:[[:lower:]]{4}|qaaa\.\.qabx)' ] ],
        'region'   =>
          [ 'requires' => 'subtag', 'regexp' => [ 'subtag' => '(?:[[:lower:]]{2}|\d{3}|qm\.\.qz|xa\.\.xz)' ] ],
        'variant' => [
            'requires' => 'subtag', 'allow' => 'prefix',
            'regexp'   => [ 'subtag' => '(?:[[:lower:]\d]{5,8}|\d[[:lower:]\d]{3,7})' ]
        ],
        'grandfathered' => [ 'requires' => 'tag' ],
        'redundant'     => [ 'requires' => 'tag' ],
    );
    if ( !$type_specs{$type} ) {
        die(
            sprintf(
                'Unrecognised Type of %s in block starting at line %d',
                $type, $line_number
            )
        );
    }

    my %specs = @{ $type_specs{$type} };
    for ( split( / /, $specs{'requires'} ) ) {
        if ( !$current{$_} ) {
            die(
                sprintf(
                    'The record type "%s" MUST appear in records with Type: %s - in block starting at line %d',
                    $_, $type, $line_number
                )
            );
        }
    }
    my @allowed = split( / /, join( q{ }, $specs{'requires'} || q{}, $specs{'allow'} || q{} ) );
    for my $alltag (@allowed) {
        if ( none { $alltag eq $_ } @allowed ) {
            die(
                sprintf(
                    'Invalid "%s" record type: must NOT appear in Type: %s - in block starting at line %d',
                    $alltag, $type, $line_number
                )
            );
        }
    }
    if ( $specs{'regexp'} ) {
        my %regexpsettings = @{ $specs{'regexp'} };
        for my $regexpkey ( keys %regexpsettings ) {
            my $regexp = $regexpsettings{$regexpkey};
            if ( $current{$regexpkey} !~ /\A$regexp\z/ ) {
                die(
                    sprintf(
                        'Invalid "%s" record type for %s: Failed regular expression - in block starting at line %d',
                        $current{$regexpkey}, $type, $line_number
                    )
                );
            }
        }
    }
    if ( $current{'prefix'} && $current{'prefix'} =~ /\|/ ) {
        if ( $type ne 'variant' ) {
            die(
                sprintf(
                    'Invalid "%s" record type: Found multiple prefixes for %s - in block starting at line %d',
                    'Prefix', $type, $line_number
                )
            );
        }
    }
    return 1;
}

sub fill_data_block (%extracted) {
    my $output;
    my @wanted_items = qw/languages regions fulls/;
    my $regexp       = '\A(?<start>my \%(?<item>' . join( q{|}, @wanted_items ) . ')\s+\= \()\);\z';
    $regexp = qr/$regexp/aa;
    my $tab = q{ } x 4;    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    for my $line ( _get_data_block() ) {
        if ( $line =~ $regexp ) {
            my $item = $+{'item'};
            $output .= $+{'start'};
            if ( !defined( $extracted{$item} ) ) {
                die(
                    sprintf(
                        'Could not find dataset block for %s: keys found: %s', $item, join( q{, }, keys(%extracted) )
                    )
                );
            }
            my %dataset = %{ $extracted{$item} };
            $output .= _produce_output_for_item( $tab, $item, $item, %dataset );

            # now the back mapping

            $output .= "\n\n$tab# start of backmaps";
            if ( !defined( $extracted{ $item . '_backmap' } ) ) {
                die(
                    sprintf(
                        'Could not find dataset block for %s_backmap: keys found: %s', $item,
                        join( q{, }, keys(%extracted) )
                    )
                );
            }

            %dataset = %{ $extracted{ $item . '_backmap' } };
            $output .= _produce_output_for_item( $tab, $item . '_backmap', $item, %dataset );
            $output .= "\n);\n";
        }
        else {
            $output .= "$line\n";
        }
    }
    return $output;
}

sub find_and_check_paths() {
    my $current_directory = File::Basename::dirname( File::Spec->rel2abs(__FILE__) );
    my $mm_dir_path = File::Spec->catdir( $current_directory, File::Spec->updir(), qw{lib Bairwell MaybeMaketext} );
    if ( !-d $mm_dir_path ) { die( sprintf( 'Could not find code directory at %s', $mm_dir_path ) ); }
    my $output = File::Spec->catfile( $mm_dir_path,       q/Alternatives.pm/ );
    my $source = File::Spec->catfile( $current_directory, q/iana_preferred.txt/ );
    if ( !-f $source ) {
        die(
            sprintf(
                'Could not find the file %s in %s. Please download it from %s (as detailed on %s)',
                'iana_preferred.txt', $current_directory,
                'https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry',
                'https://www.iana.org/assignments/lang-subtags-templates/lang-subtags-templates.xhtml',
            )
        );
    }
    return ( $source, $output );
}

sub process ($path) {
    my ( %language_mappings, %region_mappings, %full_mappings, %mapping_history );
    if ( !( -f $path ) ) {
        die( sprintf( 'Cannot find %s for reading', $path ) );
    }
    my $fault_message =
      'Duplicate mapping found for "%s" type tag "%s": current "%s" (start of block %d), wants to be "%s" (start of block %d)';
    my %type_actions = (
        'language' => sub ( $type, %current ) {
            my $tag = $current{'subtag'};
            if ( $language_mappings{$tag} ) {
                if ( $language_mappings{$tag} eq $current{'preferred-value'} ) {
                    return 0;
                }
                die(
                    sprintf(
                        $fault_message,
                        $type, $tag, $language_mappings{$tag},
                        $mapping_history{ 'language_' . $tag },
                        $current{'preferred-value'}, $current{'start_line'}
                    )
                );
            }
            $language_mappings{$tag} = $current{'preferred-value'};
            $mapping_history{ 'language_' . $tag } = $current{'start_line'};
            return 1;
        },

        'extlang' => sub ( $type, %current ) {
            my $tag       = join( q{-}, $current{'prefix'}, $current{'subtag'} );
            my $preferred = $current{'preferred-value'};

            if ( $full_mappings{$tag} ) {
                if ( $full_mappings{$tag} eq $preferred ) {
                    return 0;
                }
                die(
                    sprintf(
                        $fault_message,
                        $type, $tag, $full_mappings{$tag},
                        $mapping_history{ 'full_' . $tag },
                        $preferred, $current{'start_line'}
                    )
                );
            }
            $full_mappings{$tag} = $preferred;
            $mapping_history{ 'full_' . $tag } = $current{'start_line'};
            return 1;
        },
        'variant' => sub ( $type, %current ) {
            if ( !$current{'prefix'} ) {
                die(
                    sprintf(
                        'Missing "%s" record type for %s - in block starting at line %d',
                        'Prefix', $type, $current{'start_line'}
                    )
                );
            }
            for my $prefix ( split( /\|/, $current{'prefix'} ) ) {
                my $tag       = join( q{-}, $prefix, $current{'subtag'} );
                my $preferred = $current{'preferred-value'};

                # misclassified https://unicode-org.atlassian.net/browse/ICU-13726
                if ( $tag eq 'ja-latn-hepburn-heploc' ) {
                    $preferred = 'ja-latn-alalc97';
                }
                if ( $full_mappings{$tag} ) {
                    if ( $full_mappings{$tag} eq $preferred ) {
                        return 0;
                    }
                    die(
                        sprintf(
                            $fault_message,
                            $type, $tag, $full_mappings{$tag},
                            $mapping_history{ 'full_' . $tag },
                            $preferred, $current{'start_line'}
                        )
                    );
                }
                $full_mappings{$tag} = $preferred;
                $mapping_history{ 'full_' . $tag } = $current{'start_line'};
            }
            return 1;
        },
        'region' => sub ( $type, %current ) {
            my $tag = $current{'subtag'};
            if ( $region_mappings{$tag} ) {
                if ( $region_mappings{$tag} eq $current{'preferred-value'} ) {
                    return 0;
                }
                die(
                    sprintf(
                        $fault_message,
                        $type, $tag, $region_mappings{$tag},
                        $mapping_history{ 'region_' . $tag },
                        $current{'preferred-value'}, $current{'start_line'}
                    )
                );
            }
            $region_mappings{$tag} = $current{'preferred-value'};
            $mapping_history{ 'region_' . $tag } = $current{'start_line'};
            return 1;
        },
        'grandfathered' => sub ( $type, %current ) {
            my $tag = $current{'tag'};
            if ( $full_mappings{$tag} ) {
                if ( $full_mappings{$tag} eq $current{'preferred-value'} ) {
                    return 0;
                }
                die(
                    sprintf(
                        $fault_message,
                        $type, $tag, $full_mappings{$tag},
                        $mapping_history{ 'full_' . $tag },
                        $current{'preferred-value'}, $current{'start_line'}
                    )
                );
            }
            $full_mappings{$tag} = $current{'preferred-value'};
            $mapping_history{ 'full_' . $tag } = $current{'start_line'};
            return 1;
        },
    );
    $type_actions{'redundant'} = $type_actions{'grandfathered'};

    my $callback = sub (%current) {
        if ( !_validate_block(%current) ) {
            return 0;
        }
        if ( !$current{'preferred-value'} ) {
            return 1;
        }
        my $type = $current{'type'};
        if ( !$type_actions{$type} ) {
            die( sprintf( 'Unrecognised type %s in block starting %d', $type, $current{'start_line'} ) );
        }
        return $type_actions{$type}->( $type, %current );
    };
    open( my $filehandle, '<', $path ) || die( sprintf( 'Cannot open %s for reading', $path ) );
    _process_iana_file( $filehandle, $callback );
    close $filehandle;
    return [
        'languages'         => \%language_mappings,
        'languages_backmap' => _backmap( 'language', %language_mappings ),
        'regions'           => \%region_mappings,
        'regions_backmap'   => _backmap( 'region', %region_mappings ),
        'fulls'             => \%full_mappings,
        'fulls_backmap'     => _backmap( 'full', %full_mappings ),
    ];
}

################### Main

my ( $source_file, $output_file ) = find_and_check_paths();
my $previous_file = q{};
if ( -f $output_file ) {
    print "Reading original file at $output_file...\n";
    open( my $fh, '<', $output_file ) || die( sprintf( 'Cannot open %s for reading', $output_file ) );
    while (<$fh>) {
        $previous_file .= $_;
    }
    close $fh;
}
my %extracted = @{ process($source_file) };

my $data = fill_data_block(%extracted);
if ( $data eq $previous_file ) {
    print "No changes to data\n";
    exit(0);
}
open( my $fh, '>', $output_file ) || die( sprintf( 'Cannot open %s for writing', $output_file ) );
print {$fh} $data;
close $fh;
print "Completed\n";

__DATA__
package Locale::MaybeMaketext::Alternatives;

# pragmas
use v5.20.0;
use strict;
use warnings;
use vars;
use utf8;

use autodie      qw/:all/;
use feature      qw/signatures/;
use Scalar::Util qw/blessed/;
use Carp         qw/croak/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

my @field_parts = qw/language extlang script region variant extension irregular regular/;

# Generated languages
my %languages = ();

# Generated regions
my %regions = ();

# Generated full strings
my %fulls = ();

sub new ( $class, %settings ) {
    if (   !blessed( $settings{'cache'} )
        || !$settings{'cache'}->isa('Locale::MaybeMaketext::Cache') ) {
        croak('Invalid cache');
    }
    return bless { 'cache' => $settings{'cache'}->get_namespaced('Alternatives') }, $class;
}

sub _get_cache ( $self, $cache_key ) {
    return wantarray ? $self->{'cache'}->get_cache($cache_key) : $self->{'cache'}->get_cache($cache_key);
}

sub _set_cache ( $self, $cache_key, @data ) {
    return $self->{'cache'}->set_cache( $cache_key, @data );
}

sub _join_parts ( $self, %myparts ) {
    my @wanted_fields;
    for (@field_parts) {
        if ( defined( $myparts{$_} ) ) { push @wanted_fields, $myparts{$_}; }
    }
    return join( '_', @wanted_fields );
}

sub _copy_but_change ( $self, $item, $new, %parts ) {
    my %output;
    for (@field_parts) {
        if ( defined( $parts{$_} ) ) {
            if ( $_ eq $item ) {
                $output{$_} = $new;
            }
            else {
                $output{$_} = $parts{$_};
            }
        }
    }
    return \%output;
}

sub find_alternatives ( $self, %parts ) {
    my ( @output_array, %output_strings );
    my $original_as_string = $self->_join_parts(%parts);
    if ( $self->_get_cache( 'find_alternatives' . $original_as_string ) ) {
        my @cache = $self->_get_cache( 'find_alternatives' . $original_as_string );
        return @cache;
    }

    # see what needs changing
    if ( defined( $parts{'language'} ) ) {
        if ( $languages{ $parts{'language'} } ) {
            push @output_array, $self->_copy_but_change( 'language', $languages{ $parts{'language'} }, %parts );
        }
        if ( defined( $parts{'region'} ) && $regions{ $parts{'region'} } ) {

            # add original
            push @output_array, $self->_copy_but_change( 'region', $regions{ $parts{'region'} }, %parts );

            # change any already stored.
            # use a temporary array as we are going to be looping over the original.
            my @new_regions;
            for my $cur (@output_array) {
                push @new_regions, $self->_copy_but_change( 'region', $regions{ $parts{'region'} }, %{$cur} );

            }
            @output_array = ( @output_array, @new_regions );
        }
    }

    # make all into strings
    my $joined;
    $output_strings{$original_as_string} = 1;
    for (@output_array) {
        $joined = $self->_join_parts( %{$_} );
        if ( !$output_strings{$joined} ) { $output_strings{$joined} = 1; }
    }
    my @keys = keys(%output_strings);

    # check for full length replacements for all strings
  LANGLOOP: for my $current_language (@keys) {
        for my $entry ( keys(%fulls) ) {
            my $entry_length = length($entry);

            # are we a full match?
            if ( $current_language eq $entry ) {
                if ( !$output_strings{ $fulls{$entry} } ) {
                    $output_strings{ $fulls{$entry} } = 1;
                }
                next LANGLOOP;
            }

            elsif ( substr( $current_language, 0, $entry_length + 1 ) eq $entry . '_' ) {

                # or just up to a marker?
                my $out     = $fulls{$entry};
                my $changed = $out . substr( $current_language, $entry_length );
                if ( !$output_strings{$changed} ) { $output_strings{$changed} = 1; }
                next LANGLOOP;
            }
        }
    }    # end LANGLOOP
    @keys = keys(%output_strings);
    $self->_set_cache( 'find_alternatives' . $original_as_string, @keys );
    return @keys;
}

1;
