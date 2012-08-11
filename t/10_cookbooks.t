use strict;
use warnings;

use Test::More;
use DBI qw(:sql_types);
use MySQL::PreparedStatement;

subtest "synopsis (server_prepare: 0)" => sub {
    my $s = MySQL::PreparedStatement->prepare('INSERT INTO test(id, name) VALUES(?, ?)', { name => 'sth1', server_prepare => 0, });

    $s->bind_param(1, 1, SQL_INTEGER);
    $s->bind_param(2, 'foo', SQL_VARCHAR);
    $s->execute;
    $s->finish;

    is_deeply(scalar $s->as_query, [
        q|INSERT INTO test(id, name) VALUES(1, 'foo')|,
    ]);
};

subtest "synopsis (server_prepare: 1)" => sub {
    my $s = MySQL::PreparedStatement->prepare('INSERT INTO test(id, name) VALUES(?, ?)', { name => 'sth1', server_prepare => 1, });

    $s->bind_param(1, 1, SQL_INTEGER);
    $s->bind_param(2, 'foo', SQL_VARCHAR);
    $s->execute;
    $s->finish;

    is_deeply(scalar $s->as_query, [
        q|PREPARE sth1 FROM 'INSERT INTO test(id, name) VALUES(?, ?)'|,
        q|SET @b1 = 1, @b2 = 'foo'|,
        q|EXECUTE sth1 USING @b1, @b2|,
        q|DEALLOCATE PREPARE sth1|,
    ]);
};

subtest "execute with bind parameters" => sub {
    my $s = MySQL::PreparedStatement->prepare('INSERT INTO test(id, name) VALUES(?, ?)', { name => 'sth1', server_prepare => 1, });
    $s->execute({ value => 1, type => SQL_INTEGER }, 'foo');
    $s->finish;

    is_deeply(scalar $s->as_query, [
        q|PREPARE sth1 FROM 'INSERT INTO test(id, name) VALUES(?, ?)'|,
        q|SET @b1 = 1, @b2 = 'foo'|,
        q|EXECUTE sth1 USING @b1, @b2|,
        q|DEALLOCATE PREPARE sth1|,
    ]);
};

subtest "reusing prepared statement" => sub {
    my $s = MySQL::PreparedStatement->prepare('INSERT INTO test(id, name) VALUES(?, ?)', { name => 'sth1', server_prepare => 1, });
    $s->execute({ value => 1, type => SQL_INTEGER }, 'foo');
    $s->execute({ value => 2, type => SQL_INTEGER }, 'bar');
    $s->finish;

    is_deeply(scalar $s->as_query, [
        q|PREPARE sth1 FROM 'INSERT INTO test(id, name) VALUES(?, ?)'|,
        q|SET @b1 = 1, @b2 = 'foo'|,
        q|EXECUTE sth1 USING @b1, @b2|,
        q|SET @b1 = 2, @b2 = 'bar'|,
        q|EXECUTE sth1 USING @b1, @b2|,
        q|DEALLOCATE PREPARE sth1|,
    ]);
};

done_testing;
