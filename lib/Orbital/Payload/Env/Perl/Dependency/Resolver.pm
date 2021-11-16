package Orbital::Payload::Env::Perl::Dependency::Resolver;
# ABSTRACT: Resolves Perl dependencies

use Moo;
use Module::Load;
use CPAN::Meta;
use Module::CPANfile;

sub resolve {
	my ($self, $project_root) = @_;

}

sub root_resolve_cpanmeta {
	my ($self, $project_root) = @_;
	for my $meta_file ('META.json', 'META.yml') {
		my $meta_file_path = $project_root->child( $meta_file );
		next unless -f $meta_file_path;
		my $prereqs = CPAN::Meta->load_file( $meta_file_path )->prereqs;
	}
}

sub root_resolve_cpanfile {
	my ($self, $project_root) = @_;

	$self->resolve_cpanfile( )
}

sub resolve_cpanmeta {
	my ($self, $meta_file) = @_;
	CPAN::Meta->load_file( $meta_file );
	#)->prereqs;
}

sub resolve_cpanfile {
	my ($self, $cpanfile) = @_;

}

sub resolve_cpan {
	my ($self, $cpan_module)= @_;
	load 'CPAN::FindDependencies';
	my @dependencies = CPAN::FindDependencies::finddeps($cpan_module);
}

1;
