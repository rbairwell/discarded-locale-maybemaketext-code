package Locale::MaybeMaketext::Cache;
use v5.20.0;
use strict;
use warnings;
use vars;
use utf8;
use autodie qw/:all/;
use feature qw/signatures/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;
use Carp qw/croak/;
use Time::HiRes();

sub new ($class) {
    return bless { 'namespaces' => {}, 'cache' => {}, 'cache_entry_times' => {} }, $class;
}

sub get_namespaced ( $self, $namespace ) {
    if ( defined( $self->{'namespace'} ) ) {
        croak('Already running within a namespace');
    }
    my %namespaces = %{ $self->{'namespaces'} };
    if ( defined( $namespaces{$namespace} ) ) {
        return $namespaces{$namespace};
    }
    my $new_ns = __PACKAGE__->new();
    $new_ns->{'namespace'}  = $namespace;
    $namespaces{$namespace} = $new_ns;
    $self->{'namespaces'}   = \%namespaces;
    return $namespaces{$namespace};
}

sub set_cache ( $self, $key, @data ) {
    if ( !defined( $self->{'namespace'} ) ) {
        croak('No namespace configured');
    }
    $self->{'cache'}->{$key}             = \@data;
    $self->{'cache_entry_times'}->{$key} = sprintf( '%.7f', Time::HiRes::time() );
    return @data;
}

sub remove_cache ( $self, $key ) {
    if ( !defined( $self->{'namespace'} ) ) {
        croak('No namespace configured');
    }
    if ( !exists( $self->{'cache'}->{$key} ) ) {
        croak(
            sprintf(
                'Attempt to delete non-existent cache key for "%s" in namespace "%s"',
                $key, $self->{'namespace'}
            )
        );
    }
    my $deleted = delete $self->{'cache'}->{$key};
    delete $self->{'cache_entry_times'}->{$key};
    return @{$deleted};
}

sub get_cache_entry_time ( $self, $key ) {
    if ( !defined( $self->{'namespace'} ) ) {
        croak('No namespace configured');
    }
    if ( defined( $self->{'cache_entry_times'}->{$key} ) ) {
        return $self->{'cache_entry_times'}->{$key};
    }
    return 0;
}

sub get_cache ( $self, $key ) {
    if ( !defined( $self->{'namespace'} ) ) {
        croak('No namespace configured');
    }
    if ( !wantarray ) {
        return exists( $self->{'cache'}->{$key} ) ? 1 : 0;
    }
    if ( exists( $self->{'cache'}->{$key} ) ) {
        return @{ $self->{'cache'}->{$key} };
    }
    croak(
        sprintf(
            'Attempt to access non-existent cache key for "%s" in namespace "%s"',
            $key, $self->{'namespace'}
        )
    );

}

1;
