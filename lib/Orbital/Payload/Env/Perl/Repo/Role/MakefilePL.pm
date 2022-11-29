use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Env::Perl::Repo::Role::MakefilePL;
# ABSTRACT: A role for Makefile.PL-base distributions

use Orbital::Transfer::Common::Setup;
use Mu::Role;

use YAML;
use File::chdir;
use List::AllUtils qw(first);

lazy dist_name => method() {
	my $makefile_pl_path = $self->directory->child('Makefile.PL');
	my $meta_yml_path = $self->directory->child('MYMETA.yml');

	if ( ! $meta_yml_path->is_file ){
		try_tt {
			$self->_run_makefile_pl;
		} catch_tt {};
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
	try_tt {
		$self->_run_makefile_pl;
		die "Makefile.PL failed" unless $self->directory->child('MYMETA.yml')->is_file;
	} catch_tt {
		try_tt {
			# Configure failed, try installing deps first from CPAN?
			#
			# An even more complicated way of doing things is to
			# hook into @INC and check for packages being eval'd.
			$self->cpanm( perl => $self->platform->build_perl,
				command_cb => sub {
					shift->environment->add_environment( $self->environment );
				},
				arguments => [
					qw(--installdeps),
					qw(--notest),
					qw(--no-man-pages),
					$self->_install_perl_deps_cpanm_dir_arg,
					$self->dist_name,
				],
			);
		} catch_tt {};
	};
}

method install() {
	$self->_install( $self->directory );
}

method run_test() {
	$self->_run_test( $self->directory );
}

with qw(
	Orbital::Payload::Env::Perl::Repo::Role::CPAN
	Orbital::Payload::Env::Perl::Repo::Role::PerlEnvironment
);

1;
