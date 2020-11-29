use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Environment::Perl;
# ABSTRACT: Tools for Perl development

use strict;
use warnings;

classmethod apply_roles_to_repo( $repo ) {
	Moo::Role->apply_roles_to_object( $repo, 'Orbital::Payload::Environment::Perl::Repo::Role::DistZilla');
	Moo::Role->apply_roles_to_object( $repo, 'Orbital::Payload::Environment::Perl::Repo::Role::CpanfileGit');
}

1;
