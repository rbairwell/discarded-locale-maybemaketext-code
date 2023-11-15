package Locale::MaybeMaketext::Tests::Overrider;

use strict;
use warnings;
use vars;
use Carp    qw/carp croak/;
use autodie qw/:all/;
use feature qw/signatures/;
use Data::Dumper;
no if $] >= 5.032, q|feature|, qw/indirect/;
no warnings qw/experimental::signatures/;

# add file system error messages lookups.
use Errno qw/EPERM EIO/;

# add file system modes.
use Fcntl qw/:mode :seek/;

# these need to be predefined to allow for filesystem mocking.
BEGIN {
    no warnings 'redefine';    ## no critic (TestingAndDebugging::ProhibitNoWarnings);
    *CORE::GLOBAL::stat  = \&_override_stat;
    *CORE::GLOBAL::open  = \&_override_open;
    *CORE::GLOBAL::read  = \&_override_read;
    *CORE::GLOBAL::seek  = \&_override_seek;
    *CORE::GLOBAL::close = \&_override_close;
}

my %fs_overrides  = ();
my @instance_user = ();

sub new ($class) {
    if ( scalar(@instance_user) ) {
        my @current_caller = caller;
        croak(
            sprintf(
                'Another override instance is currently active: Started in %s %s:%d - but just called at %s %s:%d',
                $instance_user[0],  $instance_user[1],  $instance_user[2],
                $current_caller[0], $current_caller[1], $current_caller[2]
            )
        );
    }
    @instance_user = caller;
    return bless {}, $class;
}

sub _validate_subroutine_name ( $self, $subname ) {
    if ( ref($subname) ne q{} ) {
        croak( sprintf( 'Subname must be a scalar string: instead got: %s', ref($subname) ) );
    }

    # names should:
    #  start with a letter (or underscore)
    #  followed by one or more: letter, digit or underscore
    #
    if (   ( $subname !~ qr/\A[[:alpha:]_][[:alpha:]\d_]+(?:\:\:[[:alpha:]\d_]{2,})+\z/nao )
        && ( $subname !~ qr/\A[[:alpha:]_][[:alpha:]\d_]+\z/nao ) ) {
        croak( sprintf( 'Invalid/incomplete subname "%s"', $subname ) );
    }
    return 1;
}

sub wrap ( $self, $subname, $new_sub ) {
    $self->_validate_subroutine_name($subname);
    {
        ## no critic (TestingAndDebugging::ProhibitNoStrict)
        no strict 'refs';
        if ( !defined( *{$subname}{CODE} ) ) {
            croak( sprintf( 'Cannot wrap subroutine "%s" as it does not exist', $subname ) );
        }
    }
    if ( ref($new_sub) ne 'CODE' ) {
        croak(
            sprintf(
                'Parameter 2 to wrap (new_sub) must be a code reference: instead got: %s', ref($new_sub) || 'scalar'
            )
        );
    }
    if (
        !eval {
            my $original;
            if ( exists( $self->{$subname} ) ) {
                $original = $self->{$subname};
            }
            else {
                no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
                $original = $self->{$subname} = *{$subname}{'CODE'};
            }
            no warnings 'redefine';    ## no critic (TestingAndDebugging::ProhibitNoWarnings)
            no strict 'refs';          ## no critic (TestingAndDebugging::ProhibitNoStrict)
            *{$subname} = sub (@params) {
                return $new_sub->( $original, @params );
            };
            1;
        }
    ) {
        croak(
            sprintf( 'Errored when trying to wrap_subroutine %s: %s', $subname, ( $@ || $! || '[Unknown reasoning]' ) )
        );
    }
    return $new_sub;
}

sub override ( $self, $subname, $new_sub ) {
    $self->_validate_subroutine_name($subname);

    if ( ref($new_sub) ne 'CODE' ) {
        croak(
            sprintf(
                'Parameter 2 to override (new_sub) must be a code reference: instead got: %s',
                ref($new_sub) || 'scalar'
            )
        );
    }

    if (
        !eval {
            no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
            if ( !exists( $self->{$subname} ) ) {
                if ( !defined( *{$subname}{CODE} ) ) {
                    $self->{$subname} = undef;
                }
                else {
                    $self->{$subname} = *{$subname}{'CODE'};
                }
            }
            no warnings 'redefine';    ## no critic (TestingAndDebugging::ProhibitNoWarnings)
            *{$subname} = $new_sub;
        }
    ) {
        croak( sprintf( 'Errored when trying to override %s: %s', $subname, ( $@ || $! || '[Unknown reasoning]' ) ) );
    }
    return $new_sub;

}

sub reset_single ( $self, $subname ) {
    $self->_validate_subroutine_name($subname);
    if ( !exists( $self->{$subname} ) ) {
        croak( sprintf( 'Subroutine %s is not overriden', $subname ) );
    }
    if ( defined( $self->{$subname} ) ) {
        ## no critic (TestingAndDebugging::ProhibitNoStrict,TestingAndDebugging::ProhibitNoWarnings)
        no strict 'refs';
        no warnings 'redefine';
        *{$subname} = $self->{$subname};
    }
    else {
        ## no critic (TestingAndDebugging::ProhibitNoStrict,TestingAndDebugging::ProhibitNoWarnings)
        no strict 'refs';
        no warnings 'redefine';
        undef *{$subname};

        # *{$subname} = sub { croak( sprintf( 'Overrider: This method, %s, should not exist', $subname ) ); };
    }
    delete $self->{$subname};
    return 1;
}

sub reset_all ($self) {
    for my $subname ( keys( %{$self} ) ) {
        $self->reset_single($subname);
    }
    return 1;
}

sub DESTROY ($self) {
    $self->reset_all();
    %fs_overrides  = ();
    @instance_user = ();
    return 1;
}

sub _override_open : prototype(*;$@) {    ## no critic (Subroutines::RequireArgUnpacking)
    my $arg_count = @_;
    my ( $filehandle, $mode_or_expr, $expr_or_ref );

    # we can only deal with 3 argument positioned open commands at the moment.
    if ( $arg_count < 2 || $arg_count > 3 ) {    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
        croak(
            sprintf(
                'Overrider cannot cope with %d argument "Open" commands: only 2 (with no override) or 3 (with or without override)',
                $arg_count
            )
        );
    }
    if ( $arg_count == 2 ) {
        return CORE::open( $_[0], $_[1] );
    }

    # should have 3 args from now on.
    ( $filehandle, $mode_or_expr, $expr_or_ref ) = @_;
    if ( ref($expr_or_ref) || !defined( $fs_overrides{ 'open_' . $expr_or_ref } ) ) {

        # we are only interested in a scalar entry we recognise
        return CORE::open( $_[0], $_[1], $_[2] );
    }
    if ( $mode_or_expr ne '<' ) {
        croak('Only read "<" is currently accepted as a mocked "open mode" option');
    }
    my %results = $fs_overrides{ 'open_' . $expr_or_ref }->($expr_or_ref);
    if ( defined( $results{'handle'} ) ) {
        $_[0] = $results{'handle'};
    }
    return $results{'result'};
}

sub _override_stat : prototype(;*) {
    my ($name) = @_;
    if ( defined( $fs_overrides{ 'stat_' . $name } ) ) {
        return $fs_overrides{ 'stat_' . $name }->($name);
    }
    return CORE::stat($name);
}

sub _override_read {    ## no critic (Subroutines::RequireArgUnpacking)
    my $arg_count = @_;
    if ( $arg_count < 3 || $arg_count > 4 ) {    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
        croak('Invalid number of arguments passed to read - must be 3 or 4');
    }
    my ( $filehandle, $scalar, $length, $offset ) = @_;

    if ( defined($filehandle) && !ref($filehandle) && defined( $fs_overrides{ 'read_' . $filehandle } ) ) {

        # if it is a defined filename which is a scalar and we know about, then it is for us!
        my %results = $fs_overrides{ 'read_' . $filehandle }->( $filehandle, $scalar, $length, $offset );
        if ( defined( $results{'error'} ) ) {
            return undef;    ## no critic (Subroutines::ProhibitExplicitReturnUndef)
        }
        $_[1] = $results{'contents'};
        return $results{'read_size'};
    }
    if ( $arg_count == 3 ) {    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
        return CORE::read( $_[0], $_[1], $_[2] );
    }
    return CORE::read( $_[0], $_[1], $_[2], $_[3] );    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
}

sub _override_seek {    ## no critic (Subroutines::RequireArgUnpacking)
    my ( $filehandle, $position, $whence ) = @_;
    if ( defined($filehandle) && !ref($filehandle) && defined( $fs_overrides{ 'read_' . $filehandle } ) ) {
        if ( !defined( $fs_overrides{ 'filepos_' . $filehandle } ) ) {
            croak('seek: Missing filepos for filehandle');
        }
        if ( !defined( $fs_overrides{ 'contents_' . $filehandle } ) ) {
            croak('seek: Missing contents for filehandle');
        }
        my $maxlength = length( $fs_overrides{ 'contents_' . $filehandle } );
        my $newpos;
        if ( $whence == SEEK_SET ) {
            $newpos = $position;
        }
        elsif ( $whence == SEEK_CUR ) {
            $newpos = $fs_overrides{ 'filepos_' . $filehandle } + $position;
        }
        elsif ( $whence == SEEK_END ) {
            $newpos = $maxlength + $position;
        }
        else {
            return 0;
        }
        if ( $newpos > $maxlength || $newpos < 0 ) {
            return 0;
        }
        $fs_overrides{ 'filepos_' . $filehandle } = $newpos;
        return 1;
    }
    return CORE::seek( $_[0], $_[1], $_[2] );
}

sub _override_close : prototype(;*) {
    my ($filehandle) = @_;
    if ( ref($filehandle) || !defined( $fs_overrides{ 'close_' . $filehandle } ) ) {

        # assume if they are passing in a non-string filename/reference that it isn't for us.
        return CORE::close($filehandle);
    }
    return $fs_overrides{ 'close_' . $filehandle }->($filehandle);
}

sub mock_stat ( $self, $fakename, @params ) {
    my %settings = ( 'exists' => 1, 'readable' => 1, 'file' => 1, 'size' => 0 );
    %settings = $self->_parse_params( \@params, \%settings, [qw/exists readable file/] );
    my $mode = ( $settings{'readable'} ? S_IRUSR : 0 ) + ( $settings{'file'} ? S_IFREG : 0 );
    if ( !$settings{'exists'} ) {
        $fs_overrides{ 'stat_' . $fakename } = sub ($filename) {
            return ();
        };
        return 1;
    }
    $fs_overrides{ 'stat_' . $fakename } =
      sub ($name) { return ( 0, 0, $mode, 0, 0, 0, 0, $settings{'size'}, 0, 0, 0, 0, 0 ); };
    return 1;
}

sub is_mock_stat ( $self, $filename ) {
    return defined( $fs_overrides{ 'stat_' . $filename } ) ? 1 : 0;
}

sub remove_mock_stat ( $self, $fakename ) {
    if ( defined( $fs_overrides{ 'stat_' . $fakename } ) ) {
        delete $fs_overrides{ 'stat_' . $fakename };
    }
    return 1;
}

sub remove_all_mock_stat ($self) {
    for ( keys(%fs_overrides) ) {
        if ( substr( $_, 0, 5 ) eq 'stat_' ) {    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
            delete $fs_overrides{$_};
        }
    }
    return 1;
}

sub mock_filesystem ( $self, $fakename, $contents = undef, @params ) {
    my %settings = ( 'open' => 1, 'read' => 1, 'close' => 1 );
    %settings = $self->_parse_params( \@params, \%settings );
    my $size = ( defined($contents) ? length($contents) : 0 );
    $self->mock_stat( $fakename, 'size=' . $size );
    if ( $settings{'open'} != 1 ) {
        $settings{'read'}  = 0;
        $settings{'close'} = 0;

        # EPERM = Operation not permitted
        my $error_code = ( $settings{'open'} == 0 ? EPERM : $settings{'open'} );
        $fs_overrides{ 'open_' . $fakename } = sub ($name) {
            $! = $error_code;    ## no critic (Variables::RequireLocalizedPunctuationVars)
            return ( 'result' => 0, 'error' => $error_code );
        };
        return 1;
    }
    if ( $settings{'read'} == 1 && !defined($contents) ) {
        croak('mock_filesystem: If read is enabled, contents must be set');
    }

    # now if we were to be able to open the file....
    my $tempname = sprintf( '_' . $fakename );
    $fs_overrides{ 'open_' . $fakename } = sub ($name) {
        my $fileid = sprintf( '#%s:%s:%s:%s#', 'Overrider', $fakename, time, _create_random() );
        $fs_overrides{ 'read_' . $fileid }     = $fs_overrides{ 'read_' . $tempname };
        $fs_overrides{ 'close_' . $fileid }    = $fs_overrides{ 'close_' . $tempname };
        $fs_overrides{ 'filepos_' . $fileid }  = $fs_overrides{ 'filepos_' . $tempname };
        $fs_overrides{ 'contents_' . $fileid } = $fs_overrides{ 'contents_' . $tempname };
        return ( 'handle' => $fileid, 'result' => 1 );
    };

    $fs_overrides{ 'contents_' . $tempname } = $contents;
    $fs_overrides{ 'read_' . $tempname }     = $self->_get_mock_read( $settings{'read'} );
    $fs_overrides{ 'close_' . $tempname }    = $self->_get_mock_close( $settings{'close'} );
    $fs_overrides{ 'filepos_' . $tempname }  = 0;
    return 1;
}

sub is_mock_filesystem ( $self, $filename ) {
    if ( defined( $fs_overrides{ 'open_' . $filename } ) ) {
        return 1;
    }
    my $tempname = sprintf( '_' . $filename );
    if ( defined( $fs_overrides{ 'read_' . $tempname } ) ) {
        croak( sprintf( 'Override read for "%s" is set, but no appropriate "open"', $filename ) );
    }
    if ( defined( $fs_overrides{ 'close_' . $tempname } ) ) {
        croak( sprintf( 'Override close for "%s" is set, but no appropriate "open"', $filename ) );
    }
    if ( defined( $fs_overrides{ 'filepos_' . $tempname } ) ) {
        croak( sprintf( 'Override position for "%s" is set, but no appropriate "open"', $filename ) );
    }
    return 0;
}

sub remove_mock_filesystem ( $self, $fakename ) {
    if ( defined( $fs_overrides{ 'open_' . $fakename } ) ) {
        delete $fs_overrides{ 'open_' . $fakename };
    }
    my $tempname = sprintf( '_' . $fakename );
    if ( defined( $fs_overrides{ 'close_' . $tempname } ) ) {
        delete $fs_overrides{ 'close_' . $tempname };
    }
    if ( defined( $fs_overrides{ 'read_' . $tempname } ) ) {
        delete $fs_overrides{ 'read_' . $tempname };
    }
    if ( defined( $fs_overrides{ 'filepos_' . $tempname } ) ) {
        delete $fs_overrides{ 'filepos_' . $tempname };
    }
    return 1;
}

sub remove_all_mock_filesystem ($self) {
    %fs_overrides = ();
    return 1;
}

sub _get_mock_close ( $self, $active ) {
    if ( $active != 1 ) {

        # EIO = I/O Error
        my $error_code = ( $active == 0 ? EIO : $active );
        return sub ($filehandle) {
            $! = $error_code;    ## no critic (Variables::RequireLocalizedPunctuationVars)
            return 0;
        };
    }
    return sub ($filehandle) {
        delete $fs_overrides{ 'read_' . $filehandle };
        delete $fs_overrides{ 'close_' . $filehandle };
        delete $fs_overrides{ 'filepos_' . $filehandle };
        return 1;
    }
}

sub _get_mock_read ( $self, $active ) {
    if ( $active != 1 ) {

        # EIO = I/O Error
        my $error_code = ( $active == 0 ? EIO : $active );
        return sub ( $filehandle, $scalar, $length, $offset = 0 ) {
            $! = $error_code;    ## no critic (Variables::RequireLocalizedPunctuationVars)
            return ( 'error' => $error_code );
        };
    }
    return sub ( $filehandle, $scalar, $length, $offset = 0 ) {
        if ( !defined( $fs_overrides{ 'filepos_' . $filehandle } ) ) {
            croak('read: Missing filepos for filehandle');
        }
        if ( !defined( $fs_overrides{ 'contents_' . $filehandle } ) ) {
            croak('read: Missing contents for filehandle');
        }
        my $current_contents =
          substr( $fs_overrides{ 'contents_' . $filehandle }, $fs_overrides{ 'filepos_' . $filehandle } );
        my $read_size;

        if ( defined($length) ) {
            $current_contents = substr( $current_contents, 0, $length );
        }
        $read_size = length($current_contents);
        $fs_overrides{ 'filepos_' . $filehandle } += $read_size;
        if ( !defined($offset) || $offset == 0 ) {
            return ( 'read_size' => $read_size, 'contents' => $current_contents );
        }

        # offset relates to the SCALAR (ie where our output is going) - not to the imput text.
        if ( !defined($scalar) ) {
            $scalar = q{};
        }
        my $scalar_size = length($scalar);
        if ( $offset >= $scalar_size ) {

            # if offset greater than length, left pad with \0 until size
            $current_contents = sprintf( '%s%s%s', $scalar, "\0" x ( $offset - $scalar_size ), $current_contents );
            return ( 'read_size' => $read_size, 'contents' => $current_contents );
        }
        if ( $offset > 0 ) {
            $current_contents = sprintf( '%s%s', substr( $scalar, 0, $offset ), $current_contents );
            return ( 'read_size' => $read_size, 'contents' => $current_contents );
        }

        # only negative offsets should remain at thispoint
        my $abs_offset = abs($offset);
        if ( $abs_offset > $scalar_size ) {
            $! = EIO;    ## no critic (Variables::RequireLocalizedPunctuationVars)
            croak('Offset outside string (when passed to Overrider)');
        }
        $current_contents = sprintf( '%s%s', substr( $scalar, 0, $offset ), $current_contents );

        return ( 'read_size' => $read_size, 'contents' => $current_contents );
    };
}

sub _parse_params ( $self, $params_ref, $settings_ref, $boolsonly_ref = undef ) {
    my @params     = @{$params_ref};
    my %settings   = %{$settings_ref};
    my %bools_only = ();
    if ($boolsonly_ref) {
        %bools_only = map { $_ => 1 } @{$boolsonly_ref};
    }
    for my $key (@params) {
        if ( index( $key, q{=} ) > 0 ) {
            my ( $temp_key, $value ) = split( /=/, $key, 2 );
            $temp_key =~ s/\s//g;    # remove whitespace
            if ( $bools_only{$temp_key} ) {
                croak( sprintf( '%s is a boolean only setting. It cannot use =', $temp_key ) );
            }
            $settings{$temp_key} = ( $value =~ s/\A\s//gr );    # remove leading whitespace
            next;
        }
        my ($first) = substr( $key, 0, 1 );
        my $bool = 1;
        if ( $first eq q{-} ) {
            $bool = 0;
            $key  = substr( $key, 1 );
        }
        elsif ( $first eq q{+} ) {
            $bool = 1;
            $key  = substr( $key, 1 );
        }
        if ( defined( $settings{$key} ) ) {
            $settings{$key} = $bool;
        }
    }
    return %settings;
}

sub _create_random ( $length = 8 ) {
    my $prefix;
    my @chars = ( 'a' .. 'z', '_', '0' .. '9' );
    for ( 1 ... $length ) {
        $prefix .= $chars[ rand @chars ];
    }
    return $prefix;
}

1;

