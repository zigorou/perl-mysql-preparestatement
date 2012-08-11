use strict;
use warnings;

use Test::More;
use DBI qw(:sql_types);
use MySQL::PreparedStatement;

sub make_binded_query {
    my (@binds) = @_;
    my $s = MySQL::PreparedStatement->prepare( 'INSERT INTO test(id, name, published_at) VALUES(?, ?, ?)', { name => 'sth1', server_prepare => 0 } );
    $s->_binds(\@binds);
    $s->_make_binded_query;
}

is(
    make_binded_query(
        +{ value => 10, type => SQL_INTEGER },
        +{ value => 'test', type => SQL_VARCHAR },
        +{ value => 123456, type => SQL_INTEGER },
    ),
    q|INSERT INTO test(id, name, published_at) VALUES(10, 'test', 123456)|,
    'three bind parameters',
);

is(
    make_binded_query(
        +{ value => 10, type => SQL_INTEGER },
        +{ value => 'test', type => SQL_VARCHAR },
        +{ value => \'UNIX_TIMESTAMP()', type => SQL_VARCHAR },
    ),
    q|INSERT INTO test(id, name, published_at) VALUES(10, 'test', UNIX_TIMESTAMP())|,
    'three bind parameters including scalar reference bind value',
);

done_testing;
