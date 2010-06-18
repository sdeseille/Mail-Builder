# ============================================================================
package Mail::Builder::Attachment;
# ============================================================================

use Moose;
with qw(Mail::Builder::Role::File Mail::Builder::Role::TypeConstraints);

use MIME::Types;
use Path::Class;
use IO::File;
use Carp;

our $VERSION = $Mail::Builder::VERSION;

has 'name' => (
    is          => 'rw',
    isa         => 'Str',
    lazy_build  => 1,
    trigger     => sub { shift->clear_cache },
);

has 'mimetype' => (
    is          => 'rw',
    isa         => 'Mail::Builder::Type::Mimetype',
    lazy_build  => 1,
    trigger     => sub { shift->clear_cache },
);

sub _build_mimetype {
    my ($self) = @_;
    
    my $filename = $self->filename;
    my $filetype;
    
    if (defined $filename
        && lc($filename->basename) =~ /\.([0-9a-z]{1,4})$/)  {
        my $mimetype = MIME::Types->new->mimeTypeOf($1);
        $filetype = $mimetype->type
            if defined $mimetype;
    }
    
    unless (defined $filetype) {
        my $filecontent = $self->filecontent;
        $filetype = $self->_check_magic_string($filecontent);
    }
    
    $filetype ||= 'application/octet-stream';
    
    return $filetype;
}

sub _build_name {
    my ($self) = @_;
    
    my $filename = $self->filename;
    my $name;
    
    if (defined $filename) {
        $name = $filename->basename;
    }
    
    unless (defined $name
        && $name !~ m/^\s*$/) {
        return __PACKAGE__->_throw_error('Could not determine the attachment name automatically');
    }
    
    return $name;
}

sub serialize {
    my ($self) = @_;
    
    return $self->cache 
        if (defined $self->has_cache);
    
    my $file = $self->file;
    my $accessor;
    my $value;
    
    if (blessed $file) {
        if ($file->isa('IO::File')) {
            $accessor = 'Data';
            $value = $self->filecontent;
        } elsif ($file->isa('Path::Class::File')) {
            $accessor = 'Path';
            $value = $file->stringify;
        }
    } else {
        $accessor = 'Data';
        $value = $file;
    }
    
    my $entity = build MIME::Entity(
        Disposition     => 'attachment',
        Type            => $self->mimetype,
        Top             => 0,
        Filename        => encode('MIME-Header', $self->name),
        Encoding        => 'base64',
        $accessor       => $value,
    );
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Mail::Builder::Attachment - Abstract class for handling attachments

=head1 SYNOPSIS

This is an abstract class. Please Use L<Mail::Builder::Attachment::Data> or
L<Mail::Builder::Attachment::Path>.
  
=head1 DESCRIPTION

This is a simple module for handling attachments with Mail::Builder.

=head1 METHODS

=head2 Constructor

=head3 new

Shortcut to the constructor from L<Mail::Builder::Attachment::File>.

=cut

=head2 Accessors

=head3 name

Accessor which takes/returns the name of the file as displayed in the e-mail
message.

=head3 mime

Accessor which takes/returns the mime type of the file. 

=cut


1;

__END__


=head1 AUTHOR

    Maroš Kollár
    CPAN ID: MAROS
    maros [at] k-1.com
    http://www.k-1.com

=cut

