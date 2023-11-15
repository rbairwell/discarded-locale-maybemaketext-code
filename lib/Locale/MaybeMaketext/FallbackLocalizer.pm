package Locale::MaybeMaketext::FallbackLocalizer;
use strict;
use warnings;
use vars;
use utf8;
use Carp    qw/croak carp/;
use feature qw/signatures/;
no warnings qw/experimental::signatures/;

sub new ( $class, @languages ) {
    print "Locale::MaybeMaketext::FallbackLocalizer new CALLED with class $class!\n";
    return $class->get_handle( $class, @languages );
}

sub get_handle ( $class, @languages ) {
    print "Locale::MaybeMaketext::FallbackLocalizer get_handle CALLED!\n";
    if ( scalar(@languages) == 0 ) {
        @languages = 'i-default';
    }
    return bless { 'languages' => \@languages }, $class;
}

# From https://metacpan.org/release/TODDR/Locale-Maketext-1.32/view/lib/Locale/Maketext.pm#BRACKET-NOTATION :
# * Bracket groups that are empty, or which consist only of whitespace,
#   are ignored. (Examples: "[]", "[ ]", or a [ and a ] with returns
#    and/or tabs and/or spaces between them.
# * Otherwise, each group is taken to be a comma-separated group
#   of items, and each item is interpreted as follows:
#   - An item that is "_digits" or "_-digits" is interpreted as
#     $_[value]. I.e., "_1" becomes with $_[1], and "_-3" is
#     interpreted as $_[-3] (in which case @_ should have at least
#     three elements in it). Note that $_[0] is the language
#     handle, and is typically not named directly.
#   - An item "_*" is interpreted to mean "all of @_ except $_[0]".
#     I.e., @_[1..$#_]. Note that this is an empty list in the case of
#     calls like $lh->maketext(key) where there are no parameters
#     (except $_[0], the language handle).
# ( Otherwise, each item is interpreted as a string literal.)
# ...
# Note, incidentally, that items in each group are comma-separated, not /\s*,\s*/-separated.
# This is why we retain "spacer".
#
sub maketext ( $self, $string, @params ) {
    unshift( @params, $self->{'languages'}[0] );
    my $param_count = scalar(@params);

    my $callback = sub {
        my @captured = @{^CAPTURE};
        my @output;
        for my $item (@captured) {
            if ( !defined($item) ) {
                next;
            }

            # just whitespace
            if ( $item =~ /\A\s*\z/ ) {
                push @output, $item;
                next;
            }
            if ( $item eq '_*' ) {
                push @output, @params[ 1 .. $param_count ];
                next;
            }

            if ( $item =~ /\A_([\-]?\d+)\z/ ) {
                my $digits = $1;
                if ( abs($digits) > $param_count ) {
                    croak(
                        sprintf(
                            'maketext parameter mismsatched. Passed in %d : only %d parameters sent', $digits,
                            ( $param_count - 1 )
                        )
                    );
                }
                if ( $digits >= 0 ) {
                    push @output, $params[$digits];
                }
                else {
                    push @output, $params[$digits];
                }
                next;
            }
            push @output, $item;
        }
        return join( q{}, @output );

    };

    my $reg    = q/(_\d+|_\*|_\-\d+)/;
    my $spacer = q/(\s*)/;
    my $new    = $string =~ s/\[$spacer,?$reg(?:$spacer,?$reg|$spacer,|$spacer)*?\]/&$callback()/gre;
    return $new;
}

# not implemented - but part of the "maketext" spec
sub allowlist ( $self, @params ) {
    return _not_implemented( $self, @params );
}

# not implemented - but part of the "maketext" spec
sub whitelist ( $self, @params ) {
    return _not_implemented( $self, @params );
}

# not implemented - but part of the "maketext" spec
sub denylist ( $self, @params ) {
    return _not_implemented( $self, @params );
}

# not implemented - but part of the "maketext" spec
sub blacklist ( $self, @params ) {
    return _not_implemented( $self, @params );
}

# not implemented - but part of the "maketext" spec
sub fail_with ( $self, @params ) {
    return _not_implemented( $self, @params );
}

# not implemented - but part of the "maketext" spec
sub failure_handler_auto ( $self, @params ) {
    return _not_implemented( $self, @params );
}

sub _not_implemented ( $self, @params ) {
    my $caller_subroutine_field = 3;                         ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my $caller_data             = ( ( caller(1) )[$caller_subroutine_field] ) || '(no subroutine detected)';
    my $subroutine = ( split( /::/, $caller_data ) )[-1];    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    if ( ref($self) ne __PACKAGE__ || !defined( $self->{'languages'} ) ) {
        croak(
            sprintf(
                '%s must be called as a method. Use get_handle to get an instance. Otherwise not implemented.',
                $subroutine
            )
        );
    }
    carp( sprintf( '%s called - not implemented.', $subroutine ) );
    return 1;
}

1;
