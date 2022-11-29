use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Env::Perl;
# ABSTRACT: Tools for Perl development

use Orbital::Transfer::Common::Setup;

classmethod apply_roles_to_repo( $repo ) {
	if( $repo->directory->child('dist.ini')->is_file ) {
		Moo::Role->apply_roles_to_object( $repo, 'Orbital::Payload::Env::Perl::Repo::Role::DistZilla');
	} elsif( $repo->directory->child('Makefile.PL')->is_file ) {
		Moo::Role->apply_roles_to_object( $repo, 'Orbital::Payload::Env::Perl::Repo::Role::MakefilePL');
	}
	# TODO Build.PL
	Moo::Role->apply_roles_to_object( $repo, 'Orbital::Payload::Env::Perl::Repo::Role::CpanfileGit');
}

1;
