package Test::Set;

use strict;
use Test::Unit;

my $client;

sub new {
    my $package = shift;
    $client = shift;
    my $endpoint = shift;
    my $title = shift;

    my $self = { };
    bless $self, $package;
    
    $self->{_title} = $title if (defined($title));
    $self->{_start} = time;
	$self->{endpoint} = $endpoint;
    return $self;
}

sub title {
    my $self = shift;
    my $title = shift;
    
    if (defined($title)) {
        $self->{_title} = $title;
    }
    return $self->{_title};
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
    my $endpoint = shift;
	if (defined($endpoint)) {
		$self->{endpoint} = $endpoint;
	}
	return $self->{endpoint};
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

    push(@{$self->{_tests}},Test::Unit->new($client,$self->{endpoint}));
    $self->{_tests}->[-1]->name($name);
    return $self->{_tests}->[-1];
}

sub list {
    my $self = shift;

    return @{$self->{_tests}};
}

sub report {
    my $self = shift;

    my %count;
    my $elapsed = time - $self->{_start};
    my $content = "\n\n---------".$self->title."-----------\n";

    foreach my $test(@{$self->{_tests}}) {
        $content .= $test->name()." ".$test->status()." in ".$test->elapsed()." seconds\n";
        $count{$test->status()} ++;
        foreach my $log($test->logs()) {
            $content .= "\t".$log->{level}.": ".$log->{message}."\n";
        }
    }

    $content .= "\n--------Results--------\n";
	if ($self->cache('version')) {
		$content .= "Package version ".$self->cache('version')."\n";
	}
    $content .= "Completed ".@{$self->{_tests}}." tests in $elapsed seconds\n";
    foreach my $status (sort keys %count) {
        $content .= "$status: ".$count{$status}."\n";
    }
    return $content;
}

sub successful {
	my $self = shift;

    foreach my $test(@{$self->{_tests}}) {
		if ($test->status() !~ /SUCCESS/ && $test->status() !~ /SKIPPED/) {
			return 0;
		}
    }
	return 1;
}

sub exit {
    my $self = shift;
    print "Premature Exit from test\n";
    $self->report();
    exit;
}
1
