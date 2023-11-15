package Locale::MaybeMaketext::Detectors::Cpanel::ServerLocale;

use strict;
use warnings;
use vars;
use utf8;
use Carp         qw/croak carp/;
use Scalar::Util qw/blessed/;
use feature      qw/signatures/;
use Fcntl ':mode';
no warnings qw/experimental::signatures/;
use parent 'Locale::MaybeMaketext::Detectors::Cpanel::AbstractParent';

our $SERVER_LOCALE_FILE = '/var/cpanel/server_locale';

sub run_detect ($self) {
    my ( @languages, @reasoning );

    if ( !blessed($self) || !( $self->isa(__PACKAGE__) ) ) {
        croak( sprintf( 'run_detect should be passed an instance of its object %s', __PACKAGE__ ) );
    }
    if (%main::CPCONF) {
        if ( defined( $main::CPCONF{'server_locale'} ) ) {
            @languages = @{ $main::CPCONF{'server_locale'} };
        }
        else {
            push @reasoning, 'No server locale defined in cpconf';
        }
    }
    else {
        push @reasoning, 'No cpconf found';
    }
    my %results = $self->_load_server_locale($SERVER_LOCALE_FILE);
    @reasoning = ( @reasoning, @{ $results{'reasoning'} } );
    if ( $results{'contents'} ) {
        push @languages, $results{'contents'};
    }

    return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
}

sub _load_server_locale ( $self, $filename ) {
    my ( $contents, @reasoning );
    my %stats = $self->_check_file($filename);
    if ( $stats{'valid'} == 0 ) {
        push @reasoning, sprintf( 'Unable to load server locale file: %s', $stats{'reasoning'} );
        return ( 'contents' => $contents, 'reasoning' => \@reasoning );
    }
    if ( open( my $filehandle, '<', $SERVER_LOCALE_FILE ) ) {
        if ( read( $filehandle, $contents, 8192 ) ) {    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
            push @reasoning,
              sprintf( 'Read %d bytes from server locale file "%s"', length($contents), $filename );
        }
        else {
            push @reasoning, sprintf( 'Unable to read server locale file "%s": %s', $filename, ( $! || '[no error]' ) );
        }
        if ( !close $filehandle ) {
            push @reasoning,
              sprintf( 'Unable to close server locale file "%s": %s', $filename, ( $! || '[no error]' ) );
        }
    }
    else {
        push @reasoning, sprintf( 'Unable to open server locale file "%s": %s', $filename, ( $! || '[no error]' ) );
    }
    return ( 'contents' => $contents, 'reasoning' => \@reasoning );
}

# written to a) reduce the number of lookups (although using "_" as the parameter to filetests would negate that)
# and b) to ensure it can be easily unit tested by replacing stat".
sub _check_file ( $self, $filename ) {
    my @stats = stat($filename);
    if ( !@stats ) {
        return ( 'valid' => 0, 'reasoning' => sprintf( 'File "%s" not found', $filename ) );
    }
    my ( $mode, $uid, $gid, $size ) =
      ( $stats[2], $stats[4], $stats[5], $stats[7] );    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)

    if ( !S_ISREG($mode) ) {
        return ( 'valid' => 0, 'reasoning' => sprintf( '"%s" is not a file', $filename ) );
    }
    if ( !( $mode & S_IRUSR ) ) {
        return ( 'valid' => 0, 'reasoning' => sprintf( 'File "%s" is not readable by current user', $filename ) );
    }
    return ( 'valid' => 1, 'reasoning' => 'Accessible', 'size' => $size );
}

1;
