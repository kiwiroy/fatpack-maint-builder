
# include this in project cpanfile

on develop => sub {
   requires 'Applify' => "0.14";
   requires 'App::FatPacker' => "0";
   requires 'Mojolicious' => "7.55";
};
