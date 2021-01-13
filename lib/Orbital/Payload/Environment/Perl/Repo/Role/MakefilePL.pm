use Modern::Perl;
package Orbital::Payload::Environment::Perl::Repo::Role::MakefilePL;
# ABSTRACT: A role for Makefile.PL-base distributions

use Mu::Role;

use Orbital::Transfer::Common::Setup;
use YAML;
use File::chdir;
use List::AllUtils qw(first);

lazy dist_name => method() {
	my $makefile_pl_path = $self->directory->child('Makefile.PL');
	my $meta_yml_path = $self->directory->child('MYMETA.yml');

	if ( ! $meta_yml_path->is_file ){
		try {
			$self->_run_makefile_pl;
		} catch {};
	}

	if( $meta_yml_path->is_file ) {
		my $meta = YAML::LoadFile($meta_yml_path);
		return $meta->{name};
	}

	# A hacky approach for dists that have configure deps
	my $name_line = first { /\bNAME\s*=>\s*/ }
		$makefile_pl_path->lines_utf8({ chomp => 1 });
	my (undef, $name) = $name_line =~ /\bNAME\s*=>\s*(['"])(\S*)\1/;

	return $name;
};

method _run_makefile_pl() {
	local $CWD = $self->directory;
	$self->runner->system(
		$self->platform->build_perl->command(
			qw(./Makefile.PL)
		)
	);
}

method setup_build() {
	# build-time dependency
	$self->install_perl_deps(qw(ExtUtils::MakeMaker));
	try {
		$self->_run_makefile_pl;
	} catch {
		try {
			# configure failed, try installing deps first from CPAN?
			$self->cpanm( perl => $self->platform->build_perl,
				command_cb => sub {
					shift->environment->add_environment( $self->environment );
				},
				arguments => [
					qw(--installdeps),
					qw(--notest),
					qw(--no-man-pages),
					$self->dist_name,
				],
			);
		} catch {};
	};
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
