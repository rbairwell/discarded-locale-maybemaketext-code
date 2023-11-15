package Locale::MaybeMaketext::PackageLoader;

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

sub new ( $class, %settings ) {
    if (   !blessed( $settings{'cache'} )
        || !$settings{'cache'}->isa('Locale::MaybeMaketext::Cache') ) {
        croak('Invalid cache');
    }
    return bless { 'cache' => $settings{'cache'}->get_namespaced('PackageLoader') }, $class;
}

sub _get_cache ( $self, $cache_key ) {
    return wantarray ? $self->{'cache'}->get_cache($cache_key) : $self->{'cache'}->get_cache($cache_key);
}

sub _set_cache ( $self, $cache_key, @data ) {
    return $self->{'cache'}->set_cache( $cache_key, @data );
}

sub attempt_package_load ( $self, $package_name ) {

    # basic check: if it is an invalid package name, do not cache.
    if ( !$self->is_valid_package_name($package_name) ) {
        return (
            'status'    => 0,
            'reasoning' => sprintf(
                'Invalid package name "%s"',
                (
                    defined($package_name)
                    ? ( ref($package_name) ? sprintf( '[Type:%s]', ref($package_name) ) : $package_name )
                    : '[Undefined]'
                )
            )
        );
    }
    my $cache_key = 'attempt_package_load_' . $package_name;

    if ( $self->_get_cache($cache_key) ) {
        my %load = $self->_get_cache($cache_key);
        $load{'_cached'} = 1;
        return %load;
    }
    my $path         = ( $package_name =~ tr{:}{\/}rs ) . '.pm';
    my %preloadcheck = $self->_load_check( $package_name, $path );
    if ( $preloadcheck{'status'} ) {
        return $self->_set_cache(
            $cache_key,
            (
                'status'    => 1,
                'reasoning' => sprintf(
                    'Already loaded "%s" - %s (%s)', $package_name, ( $preloadcheck{'loaded'} || 'unknown source' ),
                    $preloadcheck{'reasoning'}
                ),
            )
        );
    }

    # have we tried to load before?
    if ( $preloadcheck{'loaded'} ) {
        return $self->_set_cache(
            $cache_key,
            (
                'status'    => 0,
                'reasoning' => sprintf(
                    'Previous attempt to load "%s" failed due to "%s" after: %s',
                    $package_name, $preloadcheck{'reasoning'}, ( $preloadcheck{'loaded'} || 'Unknown source' ),
                )
            )
        );
    }

    # try to load.
    if (
        !eval {

            # Convert any warnings encountered during loading
            # into dies to catch "Subroutine redefined at..." and similar messages.
            local $SIG{__WARN__} = sub { die $_[0] };    ## no critic (ErrorHandling::RequireCarping)
            require $path;
            return 1;
        }
    ) {
        # load failed
        return $self->_set_cache(
            $cache_key,
            (
                'status'    => 0,
                'reasoning' => sprintf(
                    'Failed to load "%s" because: "%s" : before loading: %s', $package_name,
                    ( $@ || $! || '[Unknown reasoning]' ) =~ s/[\n\r\t]//gr,  $preloadcheck{'reasoning'}
                ),
            )
        );
    }

    # now check if we actually loaded - see if we have symbols
    my %loadcheck = $self->_load_check( $package_name, $path );
    if ( $loadcheck{'status'} ) {

        # success
        return $self->_set_cache(
            $cache_key,
            (
                'status'    => 1,
                'reasoning' => sprintf(
                    'Loaded "%s" - %s (as previously %s)',        $package_name,
                    ( $loadcheck{'loaded'} || 'Unknown source' ), $preloadcheck{'reasoning'}
                ),
            )
        );
    }
    return $self->_set_cache(
        $cache_key,
        (
            'status'    => 0,
            'reasoning' => sprintf(
                'Unable to load package "%s" - load attempt (%s) resulted in: %s (before load attempt: %s)',
                $package_name, ( $loadcheck{'loaded'} || 'no load attempt recorded' ), $loadcheck{'reasoning'},
                $preloadcheck{'reasoning'}
            )
        )
    );
}

# It is possible for a package to exist without a INC entry, likewise it is possible for an INC
# entry to exist without the package being loaded.
#  require tried on             $INC{path} results      Symbol table results on package name
#  Not existent package/path    No entry                No items
#  Invalid return on package    No entry                Count of items
#  Raises error/warn on load    Null                    Count of items
#  Normal package               Full path               Count of items (loaded from right file,no errors+1;)
#  Wrong package in file        Full path               No items
#  Incorrect package from file  No entry                Count of items
#  Own package                  No entry                Count of items
#  Normal package by INC hook   reference               Count of items
sub _load_check ( $self, $package_name, $path ) {
    my ( $inc_results, %symbols, $symbol_count, $has_functions, $has_isa );
    $inc_results = (
        exists( $INC{$path} )
        ? (
            defined( $INC{$path} )
            ? ( ref( $INC{$path} ) ? 'loaded by hook' : sprintf( 'loaded by filesystem from "%s"', $INC{$path} ) )
            : 'raised error/warning on load'
          )
        : undef    # no load attempt recorded
    );
    {
        {
            no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
            %symbols = %{ *{"${package_name}::"} };
        }
        $symbol_count = scalar(%symbols);
        if ( defined( $symbols{'ISA'} ) && defined( *{ $symbols{'ISA'} }{ARRAY} ) ) {
            $has_isa = 1;
        }
        for my $symbol ( keys(%symbols) ) {

            # we only want defined scalars
            if ( !defined( $symbols{$symbol} ) || ref( $symbols{$symbol} ) ) {
                next;
            }

            # we need to check if this is a function/CODE - as Perl "helpfully" puts references to functions
            # in the symbol table as soon as they are encountered - not when they are declared!
            if ( defined( *{ $symbols{$symbol} }{CODE} ) ) {
                $has_functions = 1;
                last;
            }
        }
    };
    if ( $symbol_count == 0 && !$inc_results ) {
        return (
            'status'    => 0,
            'reasoning' => 'Not loaded and no matching symbols found',
            'loaded'    => $inc_results
        );
    }

    # we only count a valid load if we have symbols and: at least one is a function OR has ISA set
    if ( $symbol_count == 0 ) {
        return (
            'status'    => 0,
            'reasoning' => 'No symbols found',
            'loaded'    => $inc_results
        );
    }

    my ( $reasoning, $status );
    $status = 0;
    if ($has_functions) {
        if ($has_isa) {
            $reasoning = 'with at least one function and ISA/parent';
            $status    = 1;
        }
        else {
            $reasoning = 'with at least one function';
            $status    = 1;
        }
    }
    else {
        if ($has_isa) {
            $reasoning = 'with ISA/parent but no functions';
            $status    = 1;
        }
        else {
            $reasoning = 'but no functions or ISA/parent';
        }
    }
    return (
        'status'    => $status,
        'reasoning' => sprintf( 'Found %d symbols - %s', $symbol_count, $reasoning ),
        'loaded'    => $inc_results
    );

}

=for comment

We try and do some basic validation of Potential Perl Package Pseudonyms (okay, package names, but
the alliteration!). Yes, this regualr expression will miss out on single character packages
such as "B", but hopefully that won't be too much of an issue.

We also may pick up on subroutine names such as ABC::DEF::subroutine.

Perl itself seems to allow "any non-empty string be used as a package name"
https://github.com/Perl/perl5/commit/7156e69abfd37267e85105c6ec0c449ce4e41523

=cut

sub is_valid_package_name ( $self, $package_name ) {

    my $regular_expression = qr/\A[[:alpha:]_][[:alpha:]\d_]+(?:\:\:[[:alpha:]\d_]{2,})+\z/nao;

    # n=no capture, a=ascii, o=compile once
    # outer package: first character is always an alpha or underscore, second onwards can be alpha, digits or underscore
    # subsequent packages: can be alpha, digits or underscore
    # We specifically limit package name checks to those packages which have two parts (AB::CD instead of just AB)
    # to prevent internal package names being used and help promote the Perl package hierarchy system.
    # A minimum length of two characters per part is also enforced for similar reasons.

    # if anything but a scalar string is passed (or a string which isn't a valid looking package name),
    # then the result is false/0.
    my $ref = defined($package_name) ? ref($package_name) // 0 : 'undefined';
    if ($ref) {
        return 0;
    }

    my %cached;
    if ( $self->_get_cache( 'is_valid_package_name' . $package_name ) ) {
        %cached = $self->_get_cache( 'is_valid_package_name' . $package_name );
    }
    else {
        my $result = ( $package_name =~ $regular_expression );
        %cached = $self->_set_cache(
            'is_valid_package_name' . $package_name,
            ( 'status' => $result )
        );
    }
    return $cached{'status'};
}

1;
