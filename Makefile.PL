use inc::Module::Install;
name 'MySQL-PreparedStatement';
all_from 'lib/MySQL/PreparedStatement.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
