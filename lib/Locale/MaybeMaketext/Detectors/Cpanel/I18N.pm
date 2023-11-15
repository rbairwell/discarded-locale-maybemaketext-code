package Locale::MaybeMaketext::Detectors::Cpanel::I18N;

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
    @reasoning = $self->load_package_and_run_in_eval(
        'Cpanel::CPAN::I18N::LangTags::Detect',
        sub() {
            @languages = Cpanel::CPAN::I18N::LangTags::Detect::detect();
            return (
                sprintf( 'Cpanel::CPAN::I18N::LangTags::Detect::detect returned %d languages', scalar(@languages) ) );
        },
        @reasoning
    );
    return ( 'languages' => \@languages, 'reasoning' => \@reasoning );
}

1;
