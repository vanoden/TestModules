package Test::Set;

use strict;
use Test::Unit;

my $client;
my $endpoint;

sub new {
    my $package = shift;
    $client = shift;
    $endpoint = shift;

    my $self = { };
    bless $self, $package;

    $self->{_start} = time;
    return $self;
}

sub timeout {
    my $self = shift;
    my $timeout = shift;
    if (defined($timeout)) {
        $self->{_timeout} = $timeout;
        $client->timeout($timeout);
    }
    return $self->{_timeout};
}

sub client {
    my $self = shift;
    $client = shift;
}

sub endpoint {
    my $self = shift;
    $endpoint = shift;
}

sub cache {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    
    if (! defined($key)) {
        $self->{_error} = "Key required for cache";
        return undef;
    }
    elsif(defined($value)) {
        $self->{_cache}->{$key} = $value;
    }
    return $self->{_cache}->{$key};
}

sub add {
    my $self = shift;
    my $name = shift;

    push(@{$self->{_tests}},Test::Unit->new($client,$endpoint));
    $self->{_tests}->[-1]->name($name);
    return $self->{_tests}->[-1];
}

sub list {
    my $self = shift;

    return @{$self->{_tests}};
}

sub report {
    my $self = shift;

    my $elapsed = time - $self->{_start};
    print "\n\n---------Results for ".$self->{_cache}->{serial}."-----------\n";
    print "Completed ".@{$self->{_tests}}." connections in $elapsed seconds\n";

    foreach my $test(@{$self->{_tests}}) {
        print $test->name()." ".$test->elapsed()." seconds\n";
        foreach my $log($test->logs()) {
            print "\t".$log->{level}.": ".$log->{message}."\n";
        }
        print "\tSTATUS: ".$test->status()."\n";
    }
}

sub exit {
    my $self = shift;
    print "Premature Exit from test\n";
    $self->report();
    exit;
}
1
