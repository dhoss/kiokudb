#!/usr/bin/perl

use utf8;

package KiokuDB::Test::Fixture::TypeMap::Default;
use Moose;

use Encode;
use Test::More;
use Test::Moose;

use KiokuDB::Test::Person;
use KiokuDB::Test::Employee;
use KiokuDB::Test::Company;

use namespace::clean -except => 'meta';

use constant required_backend_roles => qw(TypeMap::Default);

use Tie::RefHash;
use constant HAVE_DATETIME          => eval { require DateTime };
use constant HAVE_URI               => eval { require URI };
use constant HAVE_URI_WITH_BASE     => eval { require URI::WithBase };
use constant HAVE_AUTHEN_PASSPHRASE => eval { require Authen::Passphrase::SaltedDigest };
use constant HAVE_PATH_CLASS        => eval { require Path::Class };
use constant HAVE_IXHASH            => eval { require Tie::IxHash };
use constant HAVE_MX_TRAITS         => eval { require MooseX::Traits };
use constant HAVE_MX_OP             => eval { require MooseX::Object::Pluggable };

{
    package Some::Role;
    use Moose::Role;

    has role_attr => ( is => "rw" );

    package Some::Other::Role;
    use Moose::Role;

    has other_role_attr => ( is => "rw" );

    package Some::Third::Role;
    use Moose::Role;

    sub a_role_method { "hello" }

    package Some::Class;
    use Moose;

    if ( KiokuDB::Test::Fixture::TypeMap::Default::HAVE_MX_TRAITS ) {
        with qw(MooseX::Traits);
    }

    if ( KiokuDB::Test::Fixture::TypeMap::Default::HAVE_MX_OP ) {
        with qw(MooseX::Object::Pluggable);
    }

    has name => ( is => "rw" );
}

with qw(KiokuDB::Test::Fixture);

sub create {
    tie my %refhash, 'Tie::RefHash';

    $refhash{["foo"]} = "bar";

    $refhash{"blah"} = "oink";

    my %ixhash;
    tie %ixhash, 'Tie::IxHash' if HAVE_IXHASH;
    %ixhash = ( first => 1, second => "yes", third => "maybe", fourth => "a charm" );

    my $homer = KiokuDB::Test::Employee->new(
        name    => "Homer Simpson",
        company => KiokuDB::Test::Company->new(
            name => "Springfield Power Plant",
        ),
    );

    Some::Role->meta->apply($homer);

    $homer->role_attr("foo");

    return (
        refhash => \%refhash,
        HAVE_IXHASH            ? ( ixhash => \%ixhash                                           ) : (),
        HAVE_DATETIME          ? ( datetime   => { obj => DateTime->now }                       ) : (),
        HAVE_PATH_CLASS        ? ( path_class => { obj => Path::Class::file('bar', 'foo.txt') } ) : (),
        HAVE_URI               ? ( uri        => { obj => URI->new('http://www.google.com/') }  ) : (),
        HAVE_URI_WITH_BASE     ? (
            with_base  => {
                obj => URI::WithBase->new(
                    URI->new('foo'),
                    URI->new('http://www.google.com/')
                ),
            },
        ) : (),
        HAVE_AUTHEN_PASSPHRASE ? (
            passphrase => {
                obj => Authen::Passphrase::SaltedDigest->new(
                    algorithm => "SHA-1", salt_random => 20,
                    passphrase => "passphrase"
                ),
            },
        ) : (),
        HAVE_MX_TRAITS ? (
            traits => {
                obj => Some::Class->new_with_traits(
                    traits => [qw(Some::Other::Role Some::Third::Role)],
                    name => "blah",
                    other_role_attr => "foo",
                ),
            },
        ) : (),
        HAVE_MX_OP ? (
            op_one => do {
                my $obj = Some::Class->new( name => "first" );

                $obj->load_plugin("+Some::Other::Role");

                $obj->other_role_attr("after");

                $obj;
            },
            op_two => do {
                my $obj = Some::Class->new( name => "second" );
                
                $obj->load_plugin("+Some::Other::Role");

                $obj->other_role_attr("after");

                $obj->load_plugin("+Some::Third::Role");

                $obj;
            },
        ) : (),
        homer => $homer,
    );
}

sub verify {
    my $self = shift;

    {
        my $s = $self->new_scope;

        my $rh = $self->lookup_ok("refhash");

        is( ref($rh), "HASH", "plain hash" );
        isa_ok( tied(%$rh), "Tie::RefHash", "tied" );

        is_deeply( [ sort { ref($a) ? -1 : ( ref($b) ? 1 : ( $a cmp $b ) ) } keys %$rh ], [ ["foo"], "blah" ], "keys" );

    }

    $self->no_live_objects;

    {
        my $s = $self->new_scope;

        my $homer = $self->lookup_ok("homer");

        isa_ok( $homer, "KiokuDB::Test::Person" );
        is( $homer->name, "Homer Simpson", "class attr" );
        does_ok( $homer, "Some::Role", "does runtime role" );
        is( $homer->role_attr, "foo", "role attr" );
        ok( $homer->meta->is_anon_class, "anon class" );
        isa_ok( $homer->company, "KiokuDB::Test::Company" );

        undef $homer;
    }

    if ( HAVE_IXHASH ) {
        $self->no_live_objects;
        my $s = $self->new_scope;

        my $ix = $self->lookup_ok("ixhash");

        is( ref($ix), "HASH", "plain hash" );
        isa_ok( tied(%$ix), "Tie::IxHash", "tied" );

        is_deeply( [ keys %$ix ], [ qw(first second third fourth) ], "key order preserved" );
    }

    if ( HAVE_DATETIME ) {
        $self->no_live_objects;
        my $s = $self->new_scope;

        my $date = $self->lookup_ok("datetime")->{obj};

        isa_ok( $date, "DateTime" );
    }

    if ( HAVE_URI ) {
        $self->no_live_objects;
        my $s = $self->new_scope;

        my $uri = $self->lookup_ok("uri")->{obj};

        isa_ok( $uri, "URI" );
        is( "$uri", "http://www.google.com/", "uri" );
    }

    if ( HAVE_URI_WITH_BASE ) {
        $self->no_live_objects;
        my $s = $self->new_scope;

        my $uri = $self->lookup_ok("with_base")->{obj};

        isa_ok( $uri, "URI::WithBase" );

        isa_ok( $uri->base, "URI" );
    }

    if ( HAVE_PATH_CLASS ) {
        $self->no_live_objects;
        my $s = $self->new_scope;

        my $file = $self->lookup_ok("path_class")->{obj};

        isa_ok( $file, "Path::Class::Entity" );
        isa_ok( $file, "Path::Class::File" );

        is( $file->basename, "foo.txt", "basename" );
    }

    if ( HAVE_MX_TRAITS ) {
        $self->no_live_objects;
        my $s = $self->new_scope;

        my $obj = $self->lookup_ok("traits")->{obj};

        does_ok( $obj, "Some::Other::Role" );
        does_ok( $obj, "Some::Third::Role" );

        is( $obj->other_role_attr, "foo", "trait attr" );
        
        is( $obj->name, "blah", "normal attr" );
    }

    if ( HAVE_MX_OP ) {
        $self->no_live_objects;
        my $s = $self->new_scope;

        my $one = $self->lookup_ok("op_one");

        does_ok( $one, "Some::Other::Role" );

        is( $one->other_role_attr, "after", "role attr" );

        my $two = $self->lookup_ok("op_two");

        does_ok( $two, "Some::Other::Role" );
        does_ok( $two, "Some::Third::Role" );

        is( eval { $two->other_role_attr }, "after", "role attr" );
    }
}

__PACKAGE__

__END__
