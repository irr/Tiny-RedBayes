use 5.010001;

use warnings;
use strict;
use diagnostics;

use Tiny::RedBayes;
use YAML;

sub load {
    my $file = shift;
    my $contents =`cat $file` or die $!;
    return ($contents =~ /(\w+)/g);
}

sub test {
    my ($obj, $words) = @_;
    print "\nTesting $obj ( @{$words} )...\n";
    print Dump($b->query($words));
}

$b = Tiny::RedBayes->new(namespace => "bayes",
                         classes => ["good", "bad", "neutral"],
                         host => "127.0.0.1", 
                         port => 6379,
                         reconnect => 60);

$b->learn("good", ["tall", "handsome", "rich"]);
$b->learn("bad", ["bald", "poor", "ugly", "bitch"]);
$b->learn("neutral", ["none", "nothing", "maybe"]);

test($b, ["tall", "poor", "rich", "dummy", "nothing"]);

$b->quit;
