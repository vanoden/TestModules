package Test::Unit;

use strict;
use BostonMetrics::HTTP::Client;
use BostonMetrics::HTTP::Request;
use BostonMetrics::HTTP::Response;
use BostonMetrics::Document::HTML;
use BostonMetrics::Document::XML;
use Data::Dumper;
use Time::HiRes qw( usleep time );

sub new {
	my $package = shift;
	my $client = shift;
	my $endpoint = shift;

	my $self = { };
	bless $self, $package;

	$self->{client} = $client;
	$self->{endpoint} = $endpoint;
	$self->{_status} = 'INCOMPLETE';
	$self->{_cache} = {};
	$self->{_log} = [];
	$self->{_start} = utime;

	return $self;
}

sub debug {
	my $self = shift;
	my $debug = shift;
	if ($debug == 1) {
		$self->{_debug} = 1;
	}
	else {
		$self->{_debug} = 0;
	}
}

sub name {
	my $self = shift;
	my $name = shift;
	
	if (defined($name)) {
		$self->{_name} = $name;
	}
	return $self->{_name};
}

sub status {
	my $self = shift;
	my $status = shift;
	
	if (defined($status)) {
		$self->{_status} = $status;
	}
	return $self->{_status};
}

sub get {
	my $self = shift;
	my $uri = shift;
	my $object = shift;
	my $params = shift;
	$self->{_error} = undef;

	my $request = BostonMetrics::HTTP::Request->new();
	$request->url($self->{endpoint}.$uri);

	foreach my $param(sort keys %{$params}) {
		$request->add_param($param,$params->{$param});
	}

	if ($params->{_debug} || $self->{_debug}) {
		print Dumper $request;
	}
	
	my $response = $self->{client}->get($request);
	if ($self->{client}->error) {
		$self->{_error} = $self->{client}->error;
		return undef;
	}

	if ($params->{_debug} || $self->{_debug}) {
		print Dumper $response;
		exit;
	}

	if ($response->content_type eq 'application/xml') {
		my $document = BostonMetrics::Document::XML->new();

		if ($document->parse($response->body)) {
			if ($document->object->{success}) {
				my $object = $document->object->{$object};
				return $object;
			}
			else {
				$self->{_error} = $document->object->{error};
				return undef;
			}
		}
		else {
			$self->{_error} = $document->error;
			return undef;
		}
	}
	else {
		$self->{_error} = "Unparsable document type: ".$response->content_type;
		return undef;
	}
}

sub post {
	my $self = shift;
	my $uri = shift;
	my $object = shift;
	my $params = shift;
	$self->{_error} = undef;
	
	my $request = BostonMetrics::HTTP::Request->new();
	$request->url($self->{endpoint}.$uri);
	$request->method('POST');
	
	foreach my $param(sort keys %{$params}) {
		$request->add_param($param,$params->{$param});
	}

	if ($params->{_debug} || $self->{_debug}) {
		print $request->serialize()."\n";
	}

	my $response = $self->{client}->post($request);
	if ($self->{client}->error) {
		$self->{_error} = $self->{client}->error;
		return undef;
	}

	if ($params->{_debug} || $self->{_debug}) {
		print Dumper $response;
		exit;
	}

	if ($response->content_type eq 'application/xml') {
		my $document = BostonMetrics::Document::XML->new();
		if ($document->parse($response->body)) {
			if ($document->object->{success}) {
				my $object = $document->object->{$object};
				return $object;
			}
			else {
				$self->{_error} = $document->object->{error};
				return undef;
			}
		}
		else {
			$self->{_error} = $document->error;
			return undef;
		}
	}
	else {
		$self->{_error} = "Unparseable document type: ".$response->content_type;
		return undef;
	}
}

sub _send {
	my $self = shift;
}

sub log {
	my $self = shift;
	my $message = shift;
	my $level = shift;
	$level = 'debug' unless($level =~ /^(debug|info|warn|notice|error|emerg|crit)/i);
	$level = uc($level);

	push(@{$self->{_log}},{'message' => $message,'level' => $level});
}

sub logs {
	my $self = shift;
	return @{$self->{_log}};
}

sub echo {
	my $self = shift;
	my $message = shift;
	print $message;
}

sub fail {
	my $self = shift;
	my $error = shift;
	print "Test fail: ".$error."\n";
	$self->log($error,'error');
	$self->{_error} = $error;
	$self->{_status} = 'ERROR';
	$self->{_stop} = utime;
}

sub skip {
	my $self = shift;
	my $message = shift;
	$self->{_status} = 'SKIPPED';
	$self->{_stop} = utime;
}

sub success {
	my $self = shift;
	$self->{_status} = 'SUCCESS';
	$self->{_stop} = utime;
}

sub finish {
	my $self = shift;
	unless($self->{_status} =~ /error/i) {
		$self->{_status} = "SUCCESS";
	}
	$self->{_stop} = utime;
}

sub elapsed {
	my $self = shift;
	return $self->{_stop} - $self->{_start};
}

sub error {
	my $self = shift;
	return $self->{_error};
}

1
