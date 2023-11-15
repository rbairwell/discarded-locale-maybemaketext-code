package Locale::MaybeMaketext::Detectors::Cpanel::Cookies;

use strict;
use warnings;
use vars;
use utf8;
use Carp         qw/croak carp/;
use Scalar::Util qw/blessed/;
use feature      qw/signatures/;
use Data::Dumper qw/Dumper/;
no warnings qw/experimental::signatures/;
use parent 'Locale::MaybeMaketext::Detectors::Cpanel::AbstractParent';

sub run_detect ($self) {
    my ( @languages, @reasoning );
    my %cookies;

    if ( !blessed($self) || !( $self->isa(__PACKAGE__) ) ) {
        croak( sprintf( 'run_detect should be passed an instance of its object %s', __PACKAGE__ ) );
    }

    # If we don't have any cookies set, don't bother continuing.
    if ( !$ENV{'HTTP_COOKIE'} ) {
        push @reasoning, 'No ENV{\'HTTP_COOKIE\'} set';
        return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
    }

    # See if Cpanel itself has any cookies already loaded.
    if ( keys(%Cpanel::Cookies) ) {    ## no critic (Variables::ProhibitPackageVars)
        push @reasoning, 'Using cPanel extracted cookies';
        %cookies = %Cpanel::Cookies;    ## no critic (Variables::ProhibitPackageVars)
    }
    else {
        # if it hasn't use the cPanel Cpanel::Cookies library to extract them - but
        # only store them locally.
        push @reasoning, 'Extracting cookies';
        @reasoning = $self->load_package_and_run_in_eval(
            'Cpanel::Cookies',
            sub() {
                my $cpanel_returned = Cpanel::Cookies::get_cookie_hashref_from_string( $ENV{'HTTP_COOKIE'} );
                %cookies = %{$cpanel_returned};
                return ('Cookies extracted');
            },
            @reasoning
        );
    }
    my $cookie_count = scalar(%cookies);

    # unlikely to get 0 cookies back from the Cpanel parser, but just in case...
    if ( $cookie_count == 0 ) {
        push @reasoning, 'No cookie entries extracted';
        return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
    }
    push @reasoning, sprintf( 'Got %d cookie entries', $cookie_count );

    # have we got an appropriate session locale?
    if ( exists( $cookies{'session_locale'} ) && $cookies{'session_locale'} ) {
        push @reasoning, sprintf(
            'Found session_locale setting: %s',
            $cookies{'session_locale'}
        );

        # does it need updating from old cpanel standards?
        push @languages, $self->old_name_to_locale( $cookies{'session_locale'} );
    }
    else {
        push @reasoning, 'No session_locale setting found in extracted cookies';

    }
    return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
}

1;
