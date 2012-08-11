use strict;
use warnings;

use Test::More;
use DBI qw(:sql_types);
use MySQL::PreparedStatement;

sub make_prepare_query {
    my ($stmt, $name) = @_;
    my $s = MySQL::PreparedStatement->prepare( $stmt, { name => $name, server_prepare => 1 } );
    return $s->_make_prepare_query;
}

is(
    make_prepare_query(q|SELECT 1|, 'aaa'),
    q|PREPARE aaa FROM 'SELECT 1'|,
    'non quoted query'
);

is(
    make_prepare_query(q|SELECT 'foo' AS name FROM dual|, 'aaa'),
    q|PREPARE aaa FROM 'SELECT ''foo'' AS name FROM dual'|,
    'quoted query'
);

done_testing;
