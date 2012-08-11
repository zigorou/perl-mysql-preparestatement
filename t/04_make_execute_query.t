use strict;
use warnings;

use Test::More;
use DBI qw(:sql_types);
use MySQL::PreparedStatement;

sub make_execute_query {
    my (@binds) = @_;
    my $s = MySQL::PreparedStatement->prepare( 'SELECT 1 FROM dual', { name => 'sth', server_prepare => 1 } );
    $s->_binds(\@binds);
    $s->_make_execute_query;
}

is(make_execute_query(), q|EXECUTE sth|, 'none bind parameter');
is(make_execute_query( { value => 10, type => SQL_INTEGER } ), q|EXECUTE sth USING @b1|, 'one bind parameter');
is(
    make_execute_query(
        +{ value => 10, type => SQL_INTEGER },
        +{ value => 'test', type => SQL_VARCHAR },
    ),
    q|EXECUTE sth USING @b1, @b2|,
    'two bind parameters',
);

done_testing;
