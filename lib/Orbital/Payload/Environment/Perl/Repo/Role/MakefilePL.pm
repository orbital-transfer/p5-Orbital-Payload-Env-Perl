use Modern::Perl;
package Orbital::Payload::Environment::Perl::Repo::Role::MakefilePL;
# ABSTRACT: A role for Makefile.PL-base distributions

use Mu::Role;

use Orbital::Transfer::Common::Setup;
use YAML;
use File::chdir;

method dist_name() {
	my $meta_yml_path = $self->directory->child('MYMETA.yml');

	if ( ! $meta_yml_path->is_file ){
		local $CWD = $self->directory;
		$self->platform->build_perl->command(
			qw(Makefile.PL)
		);
	}

	my $meta = YAML::LoadFile($meta_yml_path);

	return $meta->{name};
}

method setup_build() {
	# build-time dependency
	$self->install_perl_deps(qw(ExtUtils::MakeMaker));
}

method install() {
	$self->_install( $self->directory );
}

method run_test() {
	$self->_run_test( $self->directory );
}

with qw(
	Orbital::Payload::Environment::Perl::Repo::Role::CPAN
	Orbital::Payload::Environment::Perl::Repo::Role::PerlEnvironment
);

1;
