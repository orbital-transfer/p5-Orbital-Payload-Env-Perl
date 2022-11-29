use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Env::Perl::Environment;
# ABSTRACT: Perl interpreter

use Mu;
use Orbital::Transfer::Common::Types qw(AbsFile ArrayRef Path);
use aliased 'Orbital::Transfer::Runnable';
use Config;
use Orbital::Transfer::EnvironmentVariables;
use Object::Util magic => 0;
use File::Which;

has parent_environment => (
	is => 'ro',
	predicate => 1, # has_parent_environment
);

has perl => (
	is => 'ro',
	isa => AbsFile,
	required => 1,
	coerce => 1,

);

has library_paths => (
	is => 'ro',
	isa => ArrayRef[Path],
	coerce => 1,
	default => sub { [] },
);

lazy sitebin_path => method() {
	my $sitebin_output = $self->runner->capture(Runnable->new(
		command => [ "" . $self->perl, '-V:sitebin:' ]
	));
	my ($sitebin) = $sitebin_output =~ m/^sitebin='(.+)'\s*$/;

	$sitebin;
};

lazy vendorbin_path => method() {
	my $vendorbin_output = $self->runner->capture(Runnable->new(
		command => [ "". $self->perl, '-V:vendorbin:' ]
	));
	my ($vendorbin) = $vendorbin_output =~ m/^vendorbin='(.+)'\s*$/;

	$vendorbin;
};

lazy environment => method() {
	Orbital::Transfer::EnvironmentVariables->new(
		$self->has_parent_environment
		? ( parent => $self->parent_environment )
		: ()
	)
	->$_tap( 'prepend_path_list', 'PERL5LIB', $self->library_paths )
	->$_tap( 'prepend_path_list', 'PATH', [
		grep { defined } (
			$self->sitebin_path,
			$self->vendorbin_path
		)
	]);
};

method command( @arguments ) {
	Runnable->new(
		command => [ "" . $self->perl, @arguments, ],
		environment => Orbital::Transfer::EnvironmentVariables->new(
			parent => $self->environment,
		),
	)
}

method script_command( $script, @arguments ) {
	$self->command(
		$self->which_script( $script ),
		@arguments,
	);
}

method script( $script, @arguments ) {
	$self->runner->system(
		$self->script_command( $script, @arguments )
	)
}

method which_script( $script ) {
	local $ENV{PATH} = $self->environment->environment_hash->{PATH};
	my $script_path = which( $script );

	if( $^O eq 'MSWin32' ) {
		my $new_path = $script_path =~ s/\.bat$//ir;
		$script_path = $new_path if -f $new_path;
	}

	$script_path or die "Could not find $script in $ENV{PATH}";
}

with qw(Orbital::Transfer::Role::HasRunner);

1;
