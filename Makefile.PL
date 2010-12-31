sub requires_any_moose {};sub readme_from {}; sub auto_include_deps {}; sub author_tests {}; sub auto_set_repository {};
use inc::Module::Install;
readme_from 'lib/Finance/TW/TAIFEX.pm';
name 'Finance-TW-TAIFEX';
all_from 'lib/Finance/TW/TAIFEX.pm';
readme_from 'lib/Finance/TW/TAIFEX.pm';
build_requires 'Test::More';
build_requires 'Test::Exception';

requires 'DateTime';
requires 'File::ShareDir';
requires 'List::MoreUtils';
requires 'HTTP::Request::Common';

eval 'require Moose; 1';
if ($@ || -d 'inc/.author') {
    requires 'MouseX::NativeTraits'; # XXX: there's nativetraits are builtin for moose

    requires_any_moose 'X::Traits';
    requires_any_moose 'X::Types::DateTime';
}
else {
    requires 'Any::Moose';
    requires 'MooseX::Traits';
    requires 'MooseX::Types::DateTime';
}

install_share 'share';

auto_include_deps;
author_tests('xt');
auto_set_repository;
WriteAll;
