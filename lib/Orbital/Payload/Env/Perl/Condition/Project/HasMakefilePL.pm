use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Env::Perl::Condition::Project::HasMakefilePL;
# ABSTRACT: If a project has a Makefile.PL file

use Moo;

classmethod predicate( $project ) {
	return $project->directory->child('Makefile.PL')->is_file;
}

1;
