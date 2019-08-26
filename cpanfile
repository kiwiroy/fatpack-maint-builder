# process with cpanm --installdeps --with-develop .

test_requires 'Test::More' => '0.90';

on develop => sub {
   requires 'Applify' => "==0.15";
   requires 'App::FatPacker' => "0";
   requires 'Mojolicious' => "7.55";
   requires 'Devel::Cover';
   requires 'Test::Pod';
   requires 'Test::Pod::Coverage';
   requires 'Devel::Cover::Report::Coveralls' => '0.11';
   requires 'Devel::Cover::Report::Kritika';
   requires 'Test::Applify' => "0.06";
};
