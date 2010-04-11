# ============================================================================
package Mail::Builder::Role::File;
# ============================================================================

use Moose::Role;
use Moose::Util::TypeConstraints;

use Path::Class::File;
use IO::File;

subtype 'MailBuilderFile'
    => as 'Defined'
    => where {
        my $file = $_;
        return 1
            if blessed($file)
            && grep { $file->isa($_) } qw(IO::File Path::Class::File);
        return 1
            unless ref($file);
        return 0;
    };
    
coerce 'MailBuilderFile'
    => from 'GlobRef'
    => via { bless($_,'IO::File'); }
    => from 'Str'
    => via { 
        if (-e $_ && -f $_) {
            return Path::Class::File->new($_);
        }
        return $_;
    };

has 'file' => (
    is          => 'rw',
    isa         => 'MailBuilderFile',
    required    => 1,
    trigger     => sub { shift->clear_cache },
);

has 'cache' => (
    is          => 'rw',
    predicate   => 'has_cache',
    clearer     => 'clear_cache',
);

our %MAGIC_STRINGS = (
    'image/gif' => _build_magic_string(0x47,0x49,0x46,0x38,0x39,0x61),
    'image/jpeg'=> _build_magic_string(0xFF,0xD8),
    'image/png' => _build_magic_string(0x89,0x50,0x4E,0x47,0x0D,0x0A),
);

sub _build_magic_string {
    my (@chars) = @_;
    return join ('',map { chr($_) } @chars);
}

sub _check_magic_string {
    my ($self,$string);
    
    foreach my $type (keys %MAGIC_STRINGS) {
        return $type
            if substr($string,0,(length $MAGIC_STRINGS{$type})) eq $MAGIC_STRINGS{$type};
    }
    return;
}

sub filename {
    my ($self) = @_;
    
    my $file = $self->file;
    
    # Return filename if we know it 
    if (blessed $file
        && $file->isa('Path::Class::File')) {
        return $file;
    }
    
    # We don't know the filename
    return;
}

sub filehandle {
    my ($self) = @_;
    
    my $file = $self->file;
    
    my $file_handle;
    
    # Open Path::Class::File
    if (blessed $file
        && $file->isa('Path::Class::File')) {
        $file_handle = $file->openr();
    # Return filehandle
    } elsif (blessed $file
        && $file->isa('IO::File')) {
        $file_handle = $file;
    # We don't have a filehandle
    } else {
        return;
    }
    
    $file_handle->binmode();
    return $file_handle;
}

sub filecontent {
    my ($self) = @_;
    
    my $file = $self->file;
    
    return $file
        unless ref $file;
    
    my $filehandle = $self->filehandle;
    
    my $filecontent = do { local $/; <$filehandle> };
    
    if (blessed $file 
        && $file->isa('Path::Class::File')) {
        $filehandle->close;
    } else {
        $filehandle->seek(0,0);
    }
    
    # Store file in memory
    $self->file($filecontent);
    
    return $filecontent;
}


sub compare {
    my ($self,$compare) = @_;
    
    return 0 
        unless ($compare);
    
    my $filename_self = $self->filename;
    my $filename_compare = $compare->filename;
    
    if (defined $filename_self
        && defined $filename_compare) {
        return ($filename_self eq $filename_compare ? 1:0);
    }
    
    my $filecontent_self = $self->filecontent;
    my $filecontent_compare = $compare->filecontent;
    
    return ($filecontent_self eq $filecontent_compare ? 1:0);
}


1;