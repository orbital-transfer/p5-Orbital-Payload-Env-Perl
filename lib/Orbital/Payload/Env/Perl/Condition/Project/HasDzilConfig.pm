use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Env::Perl::Condition::Project::HasDzilConfig;
# ABSTRACT: If a project has a Dist::Zilla dist.ini file

use Moo;

classmethod predicate( $project ) {
	return $project->directory->child('dist.ini')->is_file;
}

1;
