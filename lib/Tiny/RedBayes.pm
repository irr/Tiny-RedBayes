package Tiny::RedBayes;

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ('all' => [ qw() ]);
our @EXPORT_OK = ();
our @EXPORT = ();

our $VERSION = '0.01';

use Redis;
use Try::Tiny;

sub fr {
    my ($k, $w) = @_;
    return "$k:$w";
}

sub k {
    my ($self, $cls, $s) = @_;
    return "$self->{namespace}:$cls:_$s";
}

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    foreach (qw/namespace classes host port reconnect/) {
        die "missing required $_" unless $args{$_};
    }
    $self->{classes} = $args{classes};
    $self->{namespace} = $args{namespace};

    try {
        $self->{redis} = Redis->new(server => "$args{host}:$args{port}",
                                    reconnect => $args{reconnect});
        foreach (@{$self->{classes}}) {
            $self->{redis}->sadd($self->{namespace} => $_);
            $self->{redis}->setnx($self->k($_, "total") => "0");
        }
    } catch {
        die "error initializing redis classes [@{$self->{classes}}] ($_)";
    };
    return $self;
}

sub learn {
    my ($self, $class, $words) = @_;
    my $key = $self->k($class, "freqs");
    my $tot = $self->k($class, "total");
    try {
        $self->{redis}->multi;
        foreach (@{$words}) {
            my $w = fr($key, $_);
            $self->{redis}->setnx($w, "0");
            $self->{redis}->incr($w);
            $self->{redis}->incr($tot);
        } 
        $self->{redis}->exec;
    } catch {
        die "error learning redis class [$class] ($_)";
    };
    return $self;
}

sub query {
    my ($self, $words) = @_;
    my ($scores, $priors) = ({}, {});
    my $sum = 0;
    
    try {
        foreach (@{$self->{classes}}) {
            my $total = $self->{redis}->get($self->k($_, "total"));
            $priors->{$_} = $total;
            $sum += $total;
        }
        
        foreach (@{$self->{classes}}) {
            $priors->{$_} = $priors->{$_} / $sum;
        }
        
        $sum = 0;
        foreach (@{$self->{classes}}) {
            my $class = $_;
            my $total = $self->{redis}->get($self->k($class, "total"));
            my $score = $priors->{$class};
            foreach (@{$words}) {
                my $freq = $self->{redis}->get(fr($self->k($class, "freqs"), $_));
                $score = $score * ((defined($freq)) ? ($freq / $total) : 0.00000000001);
            }
            $scores->{$class} = $score;
            $sum += $score;
        }

        foreach (@{$self->{classes}}) {
            $scores->{$_} = $scores->{$_} / $sum;
        }

        return $scores;
    } catch {
        warn "error querying ($_)";
        return undef;
    };
}

sub quit {
    my $self = shift;
    try {
        $self->{redis}->quit;
    } catch {
        warn "error disconnecting redis ($_)";
    };
    return $self;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Tiny::RedBayes - Perl extension for naive bayesian classification using Redis as a storage backend

=head1 SYNOPSIS

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


=head1 DESCRIPTION

Perform naive Bayesian classification using an array of words per category and Redis as a storage backend.

=head1 SEE ALSO

Based upon:

=over

=item C<https://github.com/irr/bayesian>

=item C<https://github.com/irr/newlisp-labs/tree/master/bayes>

=back

=head1 AUTHOR

Ivan Ribeiro Rocha, E<lt>ivan.ribeiro@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Ivan Ribeiro Rocha

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
