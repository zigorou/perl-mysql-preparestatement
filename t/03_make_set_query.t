use strict;
use warnings;

use Test::More;
use DBI qw(:sql_types);
use MySQL::PreparedStatement;

sub make_set_query {
    my (@binds) = @_;
    my $s = MySQL::PreparedStatement->prepare( 'SELECT 1 FROM dual', { name => 'aaa' } );
    $s->_binds(\@binds);
    $s->_make_set_query;
}

is(make_set_query(), undef, 'none bind params');
is(
    make_set_query({ value => 10, type => SQL_INTEGER }),
    q|SET @b1 = 10|,
    'one bind parameter',
);
is(
    make_set_query(
        +{ value => 10, type => SQL_INTEGER },
        +{ value => 'test', type => SQL_VARCHAR },
    ),
    q|SET @b1 = 10, @b2 = 'test'|,
    'two bind parameters',
);

done_testing;
