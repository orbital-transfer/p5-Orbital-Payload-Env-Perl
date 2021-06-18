use Modern::Perl;
package Orbital::Payload::Environment::Perl::Repo::Role::CPAN;
# ABSTRACT: A role for running CPAN clients

use Mu::Role;

use Module::Load;
use File::chdir;
use File::HomeDir;
use Path::Tiny;

use Orbital::Transfer::Common::Setup;

requires 'dist_name';

method _install_perl_deps_cpm_dir_arg() {
	my $global = $self->config->cpan_global_install;

	@{ $global ? [ qw(-g) ] : [ qw(-L), $self->config->lib_dir ] };
}

method _install_perl_deps_cpanm_dir_arg() {
	my $global = $self->config->cpan_global_install;

	@{ $global ? [] : [ qw(-L), $self->config->lib_dir ] };
}

method install_perl_build( :$dists = [], :$verbose = 0 ) {
	my $global = $self->config->cpan_global_install;
	try {
	$self->platform->author_perl->script('cpm',
			qw(install),
			@{ $verbose ? [ qw(-v) ] : [] },
			@{ $global ? [ qw(-g) ] : [ qw(-L), $self->config->build_tools_dir ] },
			@$dists
	);
	} catch { };
	$self->cpanm( perl => $self->platform->author_perl, arguments => [
		qw(-qn),
		@{ $verbose ? [ qw(-v) ] : [] },
		@{ $global ? [] : [ qw(-L), $self->config->build_tools_dir ] },
		@$dists
	]);
}

method install_perl_deps( @dists ) {
	my $global = $self->config->cpan_global_install;
	try {
	$self->platform->build_perl->script(
		qw(cpm install),
		@{ $global ? [ qw(-g) ] : [ qw(-L), $self->config->lib_dir ] },
		@dists
	);

	$self->cpanm( perl => $self->platform->build_perl, arguments => [
		qw(-qn),
		$self->_install_perl_deps_cpanm_dir_arg,
		@dists
	]);
	} catch { };

	# Ignore modules that are installed already without checking CPAN for
	# version: `--skip-satisfied` .
	# This may need to be improved by looking for versions of modules that
	# are installed via cpanfile-git instead of from CPAN.
	$self->cpanm( perl => $self->platform->build_perl, arguments => [
		qw(-qn),
		qw(--skip-satisfied),
		$self->_install_perl_deps_cpanm_dir_arg,
		@dists
	]);
}

lazy user_homedir => method() {
	my $homedir = $ENV{HOME}
		|| File::HomeDir->my_home
		|| join('', @ENV{qw(HOMEDRIVE HOMEPATH)}); # Win32

	if ( $^O eq 'MSWin32' ) {
		autoload "Win32";
		$homedir = Win32::GetShortPathName($homedir);
	}

	$homedir;
};

lazy orbital_home_dir => method() {
	if( $^O eq 'MSWin32' ) {
		# Make CPAN client working directory short so that certain
		# installs on Windows, such as `Alien::*` packages with deep
		# directory trees, do not truncate due to exceeding
		# `MAX_PATH = 260`.
		my $path = 'C:\\tmp';
		path($path)->mkpath;
		return $path;
	}

	return $self->user_homedir;
};

lazy _default_cpm_home_dir => method() { return "@{[ $self->user_homedir ]}/.perl-cpm"; };
lazy cpm_home_dir => method() {
	return "@{[ $self->orbital_home_dir ]}/.perl-cpm";
};
lazy _default_cpanm_home_dir => method() { return "@{[ $self->user_homedir ]}/.cpanm"; };
lazy cpanm_home_dir => method() {
	return "@{[ $self->orbital_home_dir ]}/.cpanm";
};

lazy cpm_latest_build_log => method() {
	return "@{[ $self->cpm_home_dir ]}/build.log";
};

lazy cpanm_latest_build_log => method() {
	return "@{[ $self->cpanm_home_dir ]}/build.log";
};

method cpm( :$perl, :$command_cb = sub {}, :$arguments = [] ) {
	try {
		if( $arguments->[0] eq 'install'
			&& $self->cpm_home_dir ne $self->_default_cpm_home_dir ) {
			shift @$arguments;
			unshift @$arguments, ( qw(install --home), $self->cpm_home_dir );
		}
		my $command = $perl->script_command( qw(cpm), @$arguments );
		$command_cb->( $command );
		$self->runner->system( $command );
	} catch {
		say STDERR "cpm failed. Dumping build.log.\n";
		say STDERR path( $self->cpm_latest_build_log )->slurp_utf8;
		say STDERR "End of build.log.\n";
		die $_;
	};
}

method cpanm( :$perl, :$command_cb = sub {}, :$arguments = [] ) {
	try {
		my $command = $perl->script_command( qw(cpanm), @$arguments );
		$command_cb->( $command );
		if( $self->cpanm_home_dir ne $self->_default_cpanm_home_dir ) {
			$command->environment->set_string(
				'PERL_CPANM_HOME', $self->cpanm_home_dir
			);
		}
		$self->runner->system( $command );
	} catch {
		say STDERR "cpanm failed. Dumping build.log.\n";
		say STDERR path( $self->cpanm_latest_build_log )->slurp_utf8;
		say STDERR "End of build.log.\n";
		die $_;
	};
}

method _install( $directory, :$quiet = 0, :$installdeps = 0 ) {
	try {
		$self->_install_cpm( $directory, quiet => $quiet, installdeps => $installdeps );
	} catch {};
	$self->_install_cpanm( $directory, quiet => $quiet, installdeps => $installdeps );
}

method _install_cpm( $directory, :$quiet = 0, :$installdeps = 0 ) {
	local $CWD = $directory;
	# NOTE does not handle installdeps
	$self->cpm( perl => $self->platform->build_perl,
		command_cb => sub {
			shift->environment->add_environment( $self->environment );
		},
		arguments => [
			qw(install),
			( $quiet ? qw() : qw(-v) ),
			# default is no test
			# default is no man pages
			$self->_install_perl_deps_cpm_dir_arg,
			'.',
		],
	);
}

method _install_cpanm( $directory, :$quiet = 0, :$installdeps = 0 ) {
	local $CWD = $directory;
	$self->cpanm( perl => $self->platform->build_perl,
		command_cb => sub {
			shift->environment->add_environment( $self->environment );
		},
		arguments => [
			( $installdeps ? qw(--installdeps) : () ),
			( $quiet ? qw(-q) : () ),
			qw(--notest),
			qw(--no-man-pages),
			$self->_install_perl_deps_cpanm_dir_arg,
			'.',
		],
	);
}

method _run_test( $directory ) {
	my $test_env = $self->test_environment;

	if( $self->config->has_orbital_coverage ) {
		# Need to have at least Devel::Cover~1.31 for fix to
		# "Devel::Cover hangs when used with Function::Parameters"
		# GH#164 <https://github.com/pjcj/Devel--Cover/issues/164>.
		$self->cpanm( perl => $self->platform->build_perl, arguments => [
			qw(--no-man-pages),
			$self->_install_perl_deps_cpanm_dir_arg,
			qw(--notest),
			qw(Devel::Cover~1.31)
		]);

		$test_env->append_string(
			'HARNESS_PERL_SWITCHES', " -MDevel::Cover"
		);


		if( $self->config->orbital_coverage eq 'coveralls' ) {
			$self->cpanm( perl => $self->platform->build_perl, arguments => [
				qw(--no-man-pages),
				$self->_install_perl_deps_cpanm_dir_arg,
				qw(--notest),
				qw(Devel::Cover::Report::Coveralls)
			]);
		}
	}

	{
	local $CWD = $directory;
	$self->cpanm( perl => $self->platform->build_perl,
		command_cb => sub {
			shift->environment->add_environment( $test_env );
		},
		arguments => [
			qw(--no-man-pages),
			$self->_install_perl_deps_cpanm_dir_arg,
			qw(--verbose),
			qw(--test-only),
			qw(--test-args), 'TEST_VERBOSE=1',
			'.',
	]);
	}

	if( $self->config->has_orbital_coverage ) {
		local $CWD = $directory;
		if( $self->config->orbital_coverage eq 'coveralls' ) {
			$self->platform->build_perl->script(
				qw(cover), qw(-report coveralls)
			);
		} else {
			$self->platform->build_perl->script(
				qw(cover),
			);
		}
	}
}

method uninstall() {
	try {
		$self->platform->build_perl->which_script( 'pm-uninstall' )
	} catch {
		$self->cpanm( perl => $self->platform->build_perl, arguments => [
			qw(--no-man-pages),
			$self->_install_perl_deps_cpanm_dir_arg,
			qw(--notest),
			qw(App::pmuninstall)
		]);
	};

	try {
		# TODO Check if dist is there?  If it is not, this will fail.
		$self->platform->build_perl->script(
			qw(pm-uninstall -vfn),

			# TODO this happens to be the same syntax as cpanm
			$self->_install_perl_deps_cpanm_dir_arg,

			$self->dist_name,
		);
	} catch {};
}

1;
