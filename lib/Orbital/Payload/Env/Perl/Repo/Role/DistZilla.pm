use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Env::Perl::Repo::Role::DistZilla;
# ABSTRACT: A role for Dist::Zilla repos

use Orbital::Transfer::Common::Setup;
use Mu::Role;

use File::Which;
use Module::Load;
use File::Temp qw(tempdir);
use File::chdir;
use Module::Reader;
use List::Util::MaybeXS qw(first);
use Sub::Retry;

method _dzil_command( @args ) {
	my $command = $self->platform->author_perl->script_command(
		qw(dzil), @args,
	);
	$command->environment
		->prepend_path_list('PERL5LIB', [ $self->directory->child('lib') ] );

	# TODO figure out a better way to do this. Maybe only if the underlying
	# Perl interpreters are the same?
	$command->environment
		->add_environment( $self->platform->build_perl->environment );

	return $command;
}

method _run_dzil(@args) {
	$self->runner->system(
		$self->_dzil_command( @args )
	);
}

method _install_dzil() {
	try_tt {
		$self->runner->system(
			$self->platform->author_perl->command(
				qw(-MDist::Zilla -e1),
			)
		);
	} catch_tt {
		$self->install_perl_build(dists => [ qw(Net::SSLeay Dist::Zilla) ]);
	};
}

method _get_dzil_authordeps() {
	local $CWD = $self->directory;

	my ($dzil_authordeps, $dzil_authordeps_stderr, $dzil_authordeps_exit) = try_tt {
		$self->runner->capture(
			$self->_dzil_command(
				qw(authordeps)
				# --missing
			)
		);
	} catch_tt {};

	my $reader = my $other_reader = Module::Reader->new( inc => [
		'.',
		@{ $self->platform->author_perl->library_paths }
	]);
	my @dzil_authordeps =
		grep { ! ( try_tt { $reader->module($_) } catch_tt { 0 } ) }
		split /\n/, $dzil_authordeps;
}

method _install_dzil_authordeps() {
	my @dzil_authordeps = $self->_get_dzil_authordeps;
	if( @dzil_authordeps ) {
		$self->install_perl_build( dists => \@dzil_authordeps );
	}
}

method _get_dzil_listdeps() {
	local $CWD = $self->directory;
	my ($dzil_deps, $dzil_deps_stderr, $exit_listdeps) = $self->runner->capture(
		$self->_dzil_command(
			qw(listdeps)
			# --missing
		)
	);
	my @dzil_deps = grep {
		$_ !~ /
			^\W
			| ^Possibly\ harmless
			| ^Attempt\ to\ reload.*aborted
			| ^BEGIN\ failed--compilation\ aborted
			| ^Can't\ locate.*in\ \@INC
			| ^Compilation\ failed\ in\ require
			| ^Could\ not\ find\ sub\ .*\ exported\ by
			| ^Can't\ load\ '.*'\ for\ module
		/x
	} split /\n/, $dzil_deps;
}

method _install_dzil_listdeps() {
	my @dzil_deps = $self->_get_dzil_listdeps;
	if( @dzil_deps ) {
		$self->install_perl_deps(@dzil_deps);
	}

}

lazy dzil_name => method() {
	# TODO fix this: an explicit name is not always there
	my $name_line = first { /^name\s*=/ }
		$self->directory->child('dist.ini')->lines_utf8({ chomp => 1 });

	my ($name) = $name_line =~ /^name\s*=\s*(\S*)$/;

	$name;
};

lazy dist_name => method() {
	return $self->dzil_name;
};

lazy dzil_build_dir => method() {
	#File::Spec->catfile( $self->directory, qq(../_orbital/build-dir) );
	File::Spec->catfile( $self->config->base_dir, qq(build-dir), $self->dzil_name );
};

method _dzil_build_in_dir() {
	local $CWD = $self->directory;

	print STDERR "Building dzil for @{[ $self->directory ]}\n";
	$self->_run_dzil(
		qw(build --in), $self->dzil_build_dir
	);
}

method _install_dzil_build() {
	$self->_dzil_build_in_dir;
	retry 3, 0, sub {
		$self->_install( $self->dzil_build_dir,
			quiet => 1,
			installdeps => 1,
		);
	};
}

method _dzil_has_plugin_test_podspelling() {
	return 1;

	load 'Test::DZil';

	my $temp_dir = tempdir( CLEANUP => 1 );

	my $dz = Test::DZil::Builder()->from_config(
		{ dist_root => $self->directory },
		{ tempdir_root => $temp_dir },
	);

	my @plugins = @{ $dz->plugins };

	scalar grep { ref $_ eq 'Dist::Zilla::Plugin::Test::PodSpelling' } @plugins;
}


method _install_dzil_spell_check_if_needed() {
	return unless $^O eq 'linux';

	require Orbital::Payload::Sys::Package::Spec::APT;
	if( $self->_dzil_has_plugin_test_podspelling ) {
		my @packages = map {
			Orbital::Payload::Sys::Package::Spec::APT->new( name => $_ )
		} qw(aspell aspell-en);
		$self->runner->system(
			$self->platform->apt->install_packages_command( @packages )
		) unless $self->platform->apt->are_all_installed(@packages);
	}
}

method setup_build() {
	$self->_install_dzil;
	$self->_install_dzil_authordeps;
	$self->_install_dzil_spell_check_if_needed;

	#$self->_install_dzil_listdeps;
	$self->_install_dzil_build;
}

method install() {
	$self->_dzil_build_in_dir;
	$self->_install( $self->dzil_build_dir );
}

method run_test() {
	$self->_dzil_build_in_dir;
	$self->_run_test( $self->dzil_build_dir );
}

with qw(
	Orbital::Payload::Env::Perl::Repo::Role::CPAN
	Orbital::Payload::Env::Perl::Repo::Role::PerlEnvironment
);

1;
