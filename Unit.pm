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
	$self->{_expect_code} = 200;
	$self->{_cache} = {};
	$self->{_log} = [];
	$self->{_start} = time;
	$self->require_type('application/xml');

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

	if ($response->code != $self->{_expect_code}) {
		$self->{_error} = $response->reason;
		return undef;
	}

	# Store Raw Results
	$self->{_response} = $response;
	$self->{_content} = $response->body;
	
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
	elsif ($response->content_type =~ /^text\/html\;?/) {
		my $document = BostonMetrics::Document::HTML->new();
		if ($document->parse($response->body)) {
			return $document;
		}
		else {
			$self->{_error} = $document->error;
			return undef;
		}
	}
	elsif ($response->content_type =~ 'text/plain') {
		return $response->body;
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

	if ($response->code != $self->{_expect_code}) {
		$self->{_error} = $response->reason;
		return undef;
	}

	# Store Raw Results
	$self->{_response} = $response;
	$self->{_content} = $response->body;
	
	# Response based on content type
	if ($response->content_type eq 'application/xml') {
		my $document = BostonMetrics::Document::XML->new();
		if ($document->parse($response->body)) {
			if ($document->object->{success}) {
				if (defined($object) && length($object) > 0) {
					return $document->object->{$object};
				}
				else {
					return $document->object;
				}
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
	elsif ($self->require_type() eq 'application/xml') {
		$self->{_error} = $response->body();
	}
	elsif ($response->content_type =~ /^text\/html\;?/) {
		my $document = BostonMetrics::Document::HTML->new();
		if ($document->parse($response->body)) {
			return $document;
		}
		else {
			$self->{_error} = $document->error;
			return undef;
		}
	}
	elsif ($response->content_type eq 'text/plain') {
		return $response->body;
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
	$self->status('ERROR') if ($level eq 'ERROR');
}

sub logs {
	my $self = shift;
	return @{$self->{_log}};
}

sub expect_code {
	my $self = shift;
	my $code = shift;
	
	if (defined($code)) {
		$self->{_expect_code} = $code;
	}
	return $self->{_expect_code};
}
sub echo {
	my $self = shift;
	my $message = shift;
	$message =~ s/\r?\n$//;
	print "$message\n";
}

sub warn {
	my $self = shift;
	my $message = shift;
	$message =~ s/\r?\n//g;
	$self->log($message,'warn');
	print "Warning: $message\n";
}

sub warnings {
	my $self = shift;
	return @{$self->{warnings}};
}

sub fail {
	my $self = shift;
	my $error = shift;
	print "Test fail: ".$error."\n";
	$self->log($error,'error');
	$self->{_error} = $error;
	$self->{_status} = 'ERROR';
	$self->{_stop} = time;
}

sub skip {
	my $self = shift;
	my $message = shift;
	$self->log($message,'notice');
	$self->{_status} = 'SKIPPED';
	$self->{_stop} = time;
}

sub success {
	my $self = shift;
	$self->{_status} = 'SUCCESS';
	$self->{_stop} = time;
}

sub finish {
	my $self = shift;
	unless($self->{_status} =~ /error/i) {
		$self->{_status} = "SUCCESS";
	}
	$self->{_stop} = time;
}

sub elapsed {
	my $self = shift;
	return $self->{_stop} - $self->{_start};
}

sub content {
	my $self = shift;
	return $self->{_content};
}

sub response {
	my $self = shift;
	return $self->{_response};
}

sub require_type {
	my $self = shift;
	my $type = shift;
	if (defined($type)) {
		$self->{_require_type} = $type;
	}
	return $self->{_require_type};
}

sub version_check {
	my ($self,$current,$minimum) = @_;
	my ($cmajor,$cminor,$csub,$mmajor,$mminor,$msub);
	if ($current =~ /(\d+)\.(\d+)\.(\d+)/) {
		$cmajor = $1;
		$cminor = $2;
		$csub = $3;
	}
	else {
		$self->{_error} = "Cannot parse current version: '$current'";
		return undef;
	}
	if ($minimum =~ /(\d+)\.(\d+)\.(\d+)/) {
		$mmajor = $1;
		$mminor = $2;
		$msub = $3;
	}
	else {
		$self->{_error} = "Cannot parse minimum version: '$minimum'";
		return undef;
	}
	print STDOUT "$mmajor vs $cmajor, $mminor vs $cminor, $msub vs $csub\n";
	if ($cmajor >= $mmajor && $cminor >= $mminor && $csub >= $msub) {
		return 1;
	}
	else {
		return 0;
	}
}

sub error {
	my $self = shift;
	my $error = shift;

	if (defined($error)) {
		$self->{_error} = $error;
		print "Error: $error\n";
	}
	
	return $self->{_error};
}

1
