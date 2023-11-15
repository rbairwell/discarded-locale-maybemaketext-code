package Locale::MaybeMaketext::Detectors::Cpanel::Env;

use strict;
use warnings;
use vars;
use utf8;
use Carp         qw/croak carp/;
use Scalar::Util qw/blessed/;
use feature      qw/signatures/;
no warnings qw/experimental::signatures/;
use parent 'Locale::MaybeMaketext::Detectors::Cpanel::AbstractParent';

sub run_detect ($self) {
    my ( @reasoning, @languages );

    if ( !blessed($self) || !( $self->isa(__PACKAGE__) ) ) {
        croak( sprintf( 'run_detect should be passed an instance of its object %s', __PACKAGE__ ) );
    }
    if ( defined( $ENV{'CPANEL_SERVER_LOCALE'} ) ) {
        if ( $ENV{'CPANEL_SERVER_LOCALE'} =~ /\A[[:alnum:]\_\-]*\Z/ ) {
            push @languages, $ENV{'CPANEL_SERVER_LOCALE'};
            push @reasoning, sprintf( 'Found CPANEL_SERVER_LOCALE: %s', $ENV{'CPANEL_SERVER_LOCALE'} );
        }
        else {
            push @reasoning,
              sprintf( 'CPANEL_SERVER_LOCALE Failed regular expression check: %s', $ENV{'CPANEL_SERVER_LOCALE'} );
        }
    }
    else {
        push @reasoning, 'No CPANEL_SERVER_LOCALE environment variable set';
    }

    return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
}

1;
