#!/usr/bin/env perl

use Test::Most tests => 1;

use lib 't/lib';
use Orbital::Payload::Environment::Perl::Environment;
use Orbital::Transfer::Runner::Default;

subtest "Test Perl environment" => sub {
	my $env = Orbital::Payload::Environment::Perl::Environment->new(
		perl => $^X,
		runner => Orbital::Transfer::Runner::Default->new,
	);
	ok $env->sitebin_path;
};

done_testing;
