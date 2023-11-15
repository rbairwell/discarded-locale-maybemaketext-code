package Locale::MaybeMaketext::Tests::Base;

use strict;
use warnings;
use vars;
use Data::Dumper qw/Dumper/;
use Test2::V0;
use Test2::Tools::Exception qw/dies lives/;
use Test2::Tools::Warnings  qw/warns warning warnings no_warnings/;
use Test2::Plugin::BailOnFail;
use Test2::Plugin::ExitSummary;
use Test2::Tools::Compare qw/is like/;
use Test2::Tools::Exports qw/imported_ok/;
use Test2::Tools::Ref     qw/ref_ok/;
use Test2::Tools::Subtest qw/subtest_buffered/;
use Carp                  qw/carp croak/;
use Scalar::Util          qw/blessed/;
use List::Util            qw/any/;
use Exporter              qw/import/;
use Readonly              qw/Readonly/;
use autodie               qw/:all/;
use feature               qw/signatures/;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

our @EXPORT_OK = qw/
  ok fail pass diag note skip plan done_testing todo
  is like
  dies lives warns warning warnings no_warnings
  imported_ok
  can_ok isa_ok
  ref_ok
  subtest_buffered
  carp croak Dumper any none dualvar Readonly
  starts_with check_isas check_ref nice_ref add_diag standardise_die_line/;

our %EXPORT_TAGS = (
    basics              => [qw/ok pass fail diag note skip plan done_testing todo/],
    compare             => [qw/is like/],
    exceptions_warnings => [qw/dies liveswarns warning warnings no_warnings/],
    exports             => [qw/imported_ok/],
    classes             => [qw/can_ok isa_ok/],
    ref                 => [qw/ref_ok/],
    subtest             => [qw/subtest_buffered/],
    third_party_utils   => [qw/carp croak Dumper any none dualvar Readonly/],
    our_utils           => [qw/starts_with check_isas check_ref nice_ref add_diag standardise_die_line/],
    all                 => [@EXPORT_OK],
);

sub get_export_ok {
    return @EXPORT_OK;
}

sub get_export_tags {
    return %EXPORT_TAGS;
}

sub check_ref ( $provided, $expected, $message ) {
    if ( ref($expected) ) { die( 'Expected (second) must be a string: got ' . nice_ref($expected) . "\n" ); }
    if ( ref($provided) ne $expected ) {
        fail( $message, "Expected reference of type $expected, but got " . nice_ref($provided) );
    }
    else {
        pass($message);
    }
    return 1;
}

sub nice_ref ( $item, $verbose = 0 ) {
    if ($verbose) {
        return defined($item)
          ? ( ref($item) ? ref($item) . q{:} . Data::Dumper::Dumper($item) : 'Scalar:' . $item )
          : 'UNDEFINED';
    }
    return defined($item) ? ref($item) || 'Scalar:' . $item : 'UNDEFINED';
}

sub add_diag (@error) {
    my ( $caller_package, $caller_file, $caller_line, $called_sub ) = caller(1);
    if ( !$caller_package && !$caller_line && !$caller_file ) {
        ( $caller_package, $caller_file, $caller_line, $called_sub ) = caller(0);
    }
    my $location = sprintf(
        'Test location: %s %s %s', $caller_package || '[Unknown package]',
        $caller_file || '[Unknown file]', $caller_line || '[Unknown line]'
    );
    return ( @error, $location );
}

sub starts_with ( $received, $expected, $message, @diag ) {
    if ( !defined($received) ) {
        if ( defined($expected) ) {
            fail(
                $message,
                add_diag('starts_with expected a defined string, but the received data was UNDEFINED')
            );
        }
        pass($message);
    }
    elsif ( !defined($expected) ) {
        fail(
            $message, 'starts_with expected text to be undefined, but received: ' . $received,
            ( @diag, add_diag("Received: $received") )
        );
    }
    my $length = length($expected);
    is( substr( $received, 0, $length ), $expected, $message, ( @diag, add_diag("Received: $received") ) );
    return 1;
}

sub check_isas ( $class, $isas, $message ) {
    my ( @supported, @not_supported ) = ( (), () );
    foreach my $isa ( @{$isas} ) {
        if ( $class->isa($isa) ) {
            push @supported, $isa;
        }
        else {
            push @not_supported, $isa;
        }
    }
    my $ref = ref($class) || $class;

    if (@not_supported) {
        fail(   "$message : $ref does not inherit: "
              . join( q{, }, @not_supported )
              . ' did support '
              . join( q{, }, @supported ) );
    }
    pass( "$message: $ref inherits: " . join( q{, }, @supported ) );
    return 1;
}

sub standardise_die_line ($line) {
    $line =~ s/[\n\r\t]/ /g;                                                      #remove newlines etc
    $line =~ s/\ at\ \S+\ line\ \d+\.\s*(Compilation failed in require)?//gsm;    # remove the at .. line ... extra part
    $line =~ s/\ filesystem\ from\ "\S+\.pm"/ filesystem from "PATH"/gsm;
    $line =~ s/\ in \@INC\ \(you\ may.*\z/ in INC/gsm;
    $line =~ s/[\s|\.]*\z//g;    # remove trailing newlines, spaces, tabs and full stops.
    chomp($line);
    return $line;
}

1;
