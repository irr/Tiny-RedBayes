use Test::More tests => 5;
BEGIN { use_ok('Tiny::RedBayes') };

my $classes = ["A", "B", "C"];
my $words = { A => ["ale", "alessandra", "alexandra", "alexa"], 
              B => ["babi", "baby", "babylon"], 
              C => ["lara", "luma"] };

my $b = Tiny::RedBayes->new(namespace => "bayes",
                            classes => $classes,
                            host => "127.0.0.1", 
                            port => 6379,
                            reconnect => 60);              

foreach (@{$classes}) {    
    $b->learn($_, $words->{$_});    
}

my $testA = $b->query(["ale", "babi", "alessandra", "ivan"]);
ok($testA->{A} > 0.999999, 'testA OK');

my $testB = $b->query(["ale", "babi", "alessandra", "ivan", "baby", "babylon"]);
ok($testB->{B} > 0.999999, 'testB OK');

my $testC = $b->query(["lara", "luma", "alessandra", "ivan", "ale", "luma"]);
ok($testC->{C} > 0.999999, 'testC OK');

my $testX = $b->query(["babi", "alessandra", "ivan", "luma"]);
ok((($testX->{A} == $testX->{B}) and ($testX->{A} == $testX->{C})), 'testX OK');