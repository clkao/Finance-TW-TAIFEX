use inc::Module::Install;
sub readme_from {}
readme_from 'lib/Finance/TW/TAIFEX.pm';
name 'Finance-TW-TAIFEX';
all_from 'lib/Finance/TW/TAIFEX.pm';
readme_from 'lib/Finance/TW/TAIFEX.pm';
build_requires 'Test::More';
build_requires 'Test::Exception';

requires 'DateTime';
requires 'File::ShareDir';
requires 'List::MoreUtils';
requires 'Moose';
requires 'MooseX::Traits';
requires 'MooseX::Types::DateTime';

install_share 'share';

auto_include_deps;
author_tests('xt');
auto_set_repository;
WriteAll;
