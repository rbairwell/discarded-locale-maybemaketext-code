package Locale::MaybeMaketext::Supers;

# pragmas
use v5.20.0;
use strict;
use warnings;
use vars;
use utf8;

use autodie qw/:all/;
use feature qw/signatures/;
use Carp    qw/croak carp/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;
use constant MAX_EXTENSION_PERMUTATIONS => 40;

my @factorials = (1);

sub new ( $class, %settings ) {
    my $bless = bless { 'factorial_0' => 1 }, $class;
    return $bless;
}

sub _bitwise_build ( $self, $size ) {

    # build our binary lookup table for speed.
    my @lookups;
    for my $bit ( 0 .. ($size) ) {
        push @lookups, oct( '0b' . ( '0' x ( ( $size + 1 ) - $bit ) ) . '1' . ( '0' x $bit ) );
    }

    # figure out the start point, what we need to bitwise add, and the end point.
    my ( $bitflag, $adder, $end ) = (
        oct( '0b' . ( '0' x $size ) ),
        oct( '0b' . ( '0' x ( $size - 1 ) ) . '1' ),
        oct( '0b' . ( '1' x ( $size + 1 ) ) ),
    );
    return ( $bitflag, $adder, $end, @lookups );
}

sub _bitwise_iterate ( $self, $callback, @datafields ) {
    my $size = ( scalar(@datafields) - 1 );
    if ( $size < 1 ) {
        return 1;
    }
    my ( $bitflag, $adder, $end, @lookups ) = $self->_bitwise_build($size);

    # loop until the end.
    while ( $bitflag <= $end ) {
        my @current;
        for ( 0 .. $size ) {
            if ( $bitflag & $lookups[$_] ) {
                push @current, $datafields[$_];
            }
        }
        if (@current) {
            $callback->(@current);
        }
        $bitflag += $adder;
    }
    return 1;
}

sub _calculate_factorial ( $self, $number ) {
    if ( $number == 0 )         { return 1; }
    if ( $factorials[$number] ) { return $factorials[$number]; }
    $factorials[$number] = $number * _calculate_factorial( $number - 1 );
    return $factorials[$number];
}

sub old_calculate_factorial ( $self, $number ) {
    if ( defined( $self->{"factorial_$number"} ) ) { return $self->{"factorial_$number"}; }
    if ( $number < 2 )                             { return 1; }
    $self->{"factorial_$number"} = $number * _calculate_factorial( $number - 1 );
    return $self->{"factorial_$number"};
}

sub make_supers ( $self, %parts ) {
    if ( !%parts ) {
        carp('make_supers called with nothing');
        return ();
    }
    if (   !defined( $parts{'code'} )
        || !defined( $parts{'language'} )
        || !exists( $parts{'status'} )
        || $parts{'status'} != 1 ) {
        carp(
            sprintf(
                'make_supers called with invalid language: %s',
                (
                    !defined( $parts{'code'} ) ? 'no code'
                    : (
                        !defined( $parts{'language'} ) ? 'no language'
                        : ( exists( $parts{'status'} ) ? 'invalid status' : 'no status' )
                    )
                )
            )
        );
        return ();
    }
    my @found_supers = ();
    my %known_languages;

    push @found_supers, $parts{'code'};
    push @found_supers, $parts{'language'};
    $known_languages{ $parts{'code'} }     = 1;
    $known_languages{ $parts{'language'} } = 1;

    # prepare the fields we will process - we don't actually care
    # what they are called, just that the actual data appears in the correct order.

    my @datafields     = $self->_build_datafields( \%parts );
    my $has_extensions = defined( $parts{'extension'} ) && defined( $parts{'extensions'} );
    my $subroutine     = sub (@fields) {
        my $current = $parts{'language'} . join( q{}, @fields );

        if ($has_extensions) {
            my @with_extensions = $self->_insert_extensions( $current, $parts{'extension'}, @{ $parts{'extensions'} } );
            for my $expanded (@with_extensions) {
                if ( !$known_languages{$expanded} ) {
                    push @found_supers, $expanded;
                    $known_languages{$expanded} = 1;
                }
            }
        }
        if ( $known_languages{$current} ) {
            return 1;
        }
        push @found_supers, $current;
        $known_languages{$current} = 1;

        return 1;
    };
    $self->_bitwise_iterate( $subroutine, @datafields );

    # sort by the most number of underscores so we get the most specific ones first.
    return reverse sort { $a =~ tr/_// <=> $b =~ tr/_//; } @found_supers;
}

sub _permute ( $self, @options ) {
    my @output;
    my $permutations = $self->_calculate_factorial( scalar(@options) );
    if ( $permutations > MAX_EXTENSION_PERMUTATIONS ) {
        carp(
            sprintf(
                'When going to create permutations for the extensions, there were too many (%d) possibilities to continue',
                $permutations
            )
        );
        return @output;
    }
    for my $iteration ( 0 .. ( $permutations - 1 ) ) {
        my @patterns;
        for ( 1 .. $#options + 1 ) {
            push @patterns, $iteration % $_;
        }
        push @output, @options[ $self->_patterns_to_permutations(@patterns) ];
    }
    return @output;
}

sub _patterns_to_permutations ( $self, @patterns ) {
    my @source = ( 0 .. $#patterns );
    my @perm;
    while (@patterns) {
        push @perm, splice( @source, ( pop @patterns ), 1 );
    }
    return @perm;
}

sub _insert_extensions ( $self, $current, $single_extension, @extensions ) {
    my @output;
    my $index = index( $current, $single_extension );
    if ( $index < 0 ) {

        # might not have an entry in this permutation.
        return ();
    }
    my $prefix = substr( $current, 0, $index - 1 );
    my $suffix = substr( $current, $index + length($single_extension) );
    my (@iterated);

    # get all bit selected combinations
    $self->_bitwise_iterate( sub (@items) { @iterated = ( @iterated, @items ); }, @extensions );

    # first add one without any extensions
    push @output, ( $prefix . $suffix =~ tr{__}{_}r );    # try and remove multiple underscores

    # now arrange them in multiple orders.
    for my $processing (@iterated) {
        if ( ref($processing) eq q{} ) {
            push @output, $prefix . q{_} . $processing . $suffix;
        }
        else {
            my @possibilities = _permute( @{$processing} );
            for (@possibilities) {
                push @output, $prefix . join( q{_}, @{$_} ) . $suffix;
            }
        }
        if ( scalar(@output) > MAX_EXTENSION_PERMUTATIONS ) {
            carp( sprintf( 'Too many extension permutations reached (%d) - stopping', MAX_EXTENSION_PERMUTATIONS ) );
            last;
        }
    }
    return @output;
}

sub _build_datafields ( $self, $parts_in, @fields ) {
    my @datafields;
    my %parts = %{$parts_in};
    if ( !@fields ) {
        @fields = qw/extlang script region variants extension private/;
    }
    for my $part (@fields) {
        if ( defined( $parts{$part} ) ) {
            if ( $part eq 'variants' ) {
                if ( scalar( $parts{$part} ) > 1 ) {

                    # there are multiple variants - these need to be togglable but in alphabetical order
                    # luckily the bitwise iterator will retain the order.
                    $self->_bitwise_iterate(
                        sub (@fields) { push @datafields, join( q{_}, @fields ); },
                        @{ $parts{$part} }
                    );
                }
                else {
                    push @datafields, q{_} . @{ $parts{$part} }[0];
                }
            }
            else {
                # there may be multiple extensions, we'll deal with these later.
                push @datafields, q{_} . $parts{$part};
            }
        }
    }
    return @datafields;
}

1;
