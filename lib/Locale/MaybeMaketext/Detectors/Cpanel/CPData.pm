package Locale::MaybeMaketext::Detectors::Cpanel::CPData;

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
    my ( @languages, @reasoning );

    if ( !blessed($self) || !( $self->isa(__PACKAGE__) ) ) {
        croak( sprintf( 'run_detect should be passed an instance of its object %s', __PACKAGE__ ) );
    }

    my %cpdata = $self->_update_cpdata();

    # see if we have any data to handle regarding CPANEL-10445 "Required since we've banned use of Cpanel..."
    if ( !defined( $self->{'reseller_whm_reasoning'} ) ) {
        my %results = $self->_reseller_whm(%cpdata);

        $self->{'reseller_whm_reasoning'} = $results{'reasoning'};
        %cpdata = %{ $results{'cpdata'} };
    }
    for ( @{ $self->{'reseller_whm_reasoning'} } ) {
        push @reasoning, sprintf( 'Reseller WHM Cpdata: %s', $_ );
    }

    # have we got anything loaded?

    if (%cpdata) {
        push @reasoning, 'CpData{\'LOCALE\'} or CpData{\'LANG\'} already exists - no need to load';
    }
    else {
        @reasoning = $self->load_package_and_run_in_eval(
            'Cpanel::Locale::Utils::User',
            sub() {
                Cpanel::Locale::Utils::User::init_cpdata_keys();
                return ('Cpanel::Locale::Utils::User::init_cpdata_keys setup');
            },
            @reasoning
        );
        %cpdata = $self->_update_cpdata(%cpdata);
    }

    # check for locale
    if ( defined( $cpdata{'LOCALE'} ) ) {
        my %results = $self->_parse_locale(%cpdata);
        @languages = ( @languages, @{ $results{'languages'} } );
        @reasoning = ( @reasoning, @{ $results{'reasoning'} } );
    }
    else {
        push @reasoning, 'Locale: No languages found';
    }

    # check for lang
    if ( defined( $cpdata{'LANG'} ) ) {
        my %results = $self->_parse_lang(%cpdata);
        @languages = ( @languages, @{ $results{'languages'} } );
        @reasoning = ( @reasoning, @{ $results{'reasoning'} } );
    }
    else {
        push @reasoning, 'Lang: No languages found';
    }

    return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
}

sub _update_cpdata ( $self, %cpdata ) {
    if ( exists( $Cpanel::CPDATA{'LOCALE'} ) ) {
        $cpdata{'LOCALE'} = $Cpanel::CPDATA{'LOCALE'};
    }
    if ( exists( $Cpanel::CPDATA{'LANG'} ) ) {
        $cpdata{'LANG'} = $Cpanel::CPDATA{'LANG'};
    }
    return %cpdata;
}

sub _parse_locale ( $self, %cpdata ) {
    my ( @langtags, @reasoning );
    if ( ref( $cpdata{'LOCALE'} ) ) {
        push @reasoning, sprintf( 'Locale: Expected scalar, got: %s', ref( $cpdata{'LOCALE'} ) );
        return ( 'languages' => \@langtags, 'reasoning' => \@reasoning );
    }
    push @langtags,  $cpdata{'LOCALE'};
    push @reasoning, sprintf( 'Locale: Found 1 language: %s', join( q{, }, @langtags ) );
    return ( 'languages' => \@langtags, 'reasoning' => \@reasoning );
}

sub _parse_lang ( $self, %cpdata ) {
    my ( @langtags, @reasoning );
    if ( ref( $cpdata{'LANG'} ) ) {
        push @reasoning, sprintf( 'Lang: Expected scalar, got: %s', ref( $cpdata{'LANG'} ) );
        return ( 'languages' => \@langtags, 'reasoning' => \@reasoning );
    }
    my $new_style = $self->old_name_to_locale( $cpdata{'LANG'} );
    push @langtags, $new_style;
    if ( $new_style ne $cpdata{'LANG'} ) {
        push @reasoning,
          sprintf(
            'Lang: Transformed old style language "%s" to new style "%s"', $cpdata{'LANG'},
            $new_style
          );
    }
    push @reasoning, sprintf( 'Lang: Found 1 language: %s', join( q{, }, @langtags ) );
    return ( 'languages' => \@langtags, 'reasoning' => \@reasoning );
}

# Replicate the workaround of CPANEL-10445 "Required since we've banned use of Cpanel module in whostmgr binaries."
# as per Cpanel::Locale::_setup_for_real_get_handle
sub _reseller_whm ( $self, %cpdata ) {
    my @reasoning = ();
    my %results;
    if ( !defined( $ENV{'REMOTE_USER'} ) ) {
        return ( 'reasoning' => ['No remote user environment variable'], 'cpdata' => \%cpdata );
    }
    my $remote_user = lc( $ENV{'REMOTE_USER'} );
    if ( $remote_user eq 'root' ) {
        return ( 'reasoning' => ['User is "root"'], 'cpdata' => \%cpdata );
    }
    push @reasoning, sprintf( 'Remote user is "%s"', $remote_user );

    # are we in whm?
    # by looks of Cpanel::App, we are meant to use Cpanel::App::is_whm but when we include
    # Cpanel::App, it then overwrites any existing Cpanel::App::appname value causing is_whm to
    # always return 0/false.
    if ( !defined($Cpanel::App::appname) ) {    ## no critic (Variables::ProhibitPackageVars)
        push @reasoning, 'Cpanel::App::appname not set';
        return ( 'reasoning' => \@reasoning, 'cpdata' => \%cpdata );
    }
    push @reasoning,
      sprintf(
        'Cpanel::App::appname set to "%s"',
        $Cpanel::App::appname    ## no critic (Variables::ProhibitPackageVars)
      );
    if ( $Cpanel::App::appname ne 'whostmgr' ) {    ## no critic (Variables::ProhibitPackageVars)
        return ( 'reasoning' => \@reasoning, 'cpdata' => \%cpdata );
    }

    # is the cpuser file readable?
    %results   = $self->_check_readable_cpuser($remote_user);
    @reasoning = ( @reasoning, @{ $results{'reasoning'} } );
    if ( !$results{'readable'} ) {
        return ( 'reasoning' => \@reasoning, 'cpdata' => \%cpdata );
    }

    # read the file.
    my $cpdata_ref;
    @reasoning = $self->load_package_and_run_in_eval(
        'Cpanel::Config::LoadCpUserFile::CurrentUser',
        sub() {
            %results    = $self->_load_current_user($remote_user);
            $cpdata_ref = $results{'cpdata'};
            return @{ $results{'reasoning'} };
        },
        @reasoning
    );
    if ( defined($cpdata_ref) ) {
        %cpdata = %{$cpdata_ref};
    }
    return ( 'reasoning' => \@reasoning, 'cpdata' => \%cpdata );
}

sub _check_readable_cpuser ( $self, $remote_user ) {
    my @reasoning;
    my $cpuserfile = 0;
    @reasoning = $self->load_package_and_run_in_eval(
        'Cpanel::Config::HasCpUserFile',
        sub() {
            if ( Cpanel::Config::HasCpUserFile::has_readable_cpuser_file($remote_user) ) {
                $cpuserfile = 1;
                return ('Has readable CpUser data file');
            }
            return ('CpUser data file unreadable');
        },
        @reasoning
    );
    return ( 'readable' => $cpuserfile, 'reasoning' => \@reasoning );
}

sub _load_current_user ( $self, $remote_user ) {
    my $cpdata_ref = Cpanel::Config::LoadCpUserFile::CurrentUser::load($remote_user);
    my @reasoning;
    if ( blessed($cpdata_ref) ) {
        if ( $cpdata_ref->isa('Cpanel::Config::CpUser::Object') ) {
            my $scalar = scalar( keys( %{$cpdata_ref} ) );
            if ($scalar) {
                push @reasoning, sprintf( 'Read %d entries from CpData', $scalar );
            }
            else {
                $cpdata_ref = undef;
                push @reasoning, 'Unable to read CpData';
            }
        }
        else {
            push @reasoning, sprintf(
                'Cpanel::Config::LoadCpUserFile::CurrentUser::load returned incorrect object type of: %s',
                ( ref($cpdata_ref) || 'scalar: ' . $cpdata_ref )
            );
            $cpdata_ref = undef;
        }
    }
    else {
        push @reasoning, sprintf(
            'Cpanel::Config::LoadCpUserFile::CurrentUser::load returned non-blessed item of type: %s',
            ( ref($cpdata_ref) || 'scalar: ' . $cpdata_ref )
        );

        $cpdata_ref = undef;
    }
    return ( 'cpdata' => $cpdata_ref, 'reasoning' => \@reasoning );
}

1;
