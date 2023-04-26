use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Env::Perl;
# ABSTRACT: Tools for Perl development

use Orbital::Transfer::Common::Setup;

use aliased 'Orbital::Payload::Env::Perl::Condition::Project::HasDzilConfig';
use aliased 'Orbital::Payload::Env::Perl::Condition::Project::HasMakefilePL';

classmethod apply_roles_to_repo( $repo ) {
	if( HasDzilConfig->predicate($repo) ) {
		Moo::Role->apply_roles_to_object( $repo, 'Orbital::Payload::Env::Perl::Repo::Role::DistZilla');
	} elsif( HasMakefilePL->predicate($repo) ) {
		Moo::Role->apply_roles_to_object( $repo, 'Orbital::Payload::Env::Perl::Repo::Role::MakefilePL');
	}
	# TODO Build.PL
	Moo::Role->apply_roles_to_object( $repo, 'Orbital::Payload::Env::Perl::Repo::Role::CpanfileGit');
}

1;
