use inc::Module::Install;
name 'MySQL-PreparedStatement';
all_from 'lib/MySQL/PreparedStatement.pm';

requires 'Carp';
requires 'Class::Accessor::Lite';
requires 'DBI';
requires 'List::MoreUtils';
requires 'SQL::Tokenizer';
requires 'String::Random';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
