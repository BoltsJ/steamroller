use strict;
use warnings;
use LWP::Simple qw(get getstore is_error);
use JSON qw(decode_json);
package Bolts::Steamroller::AUR;

our $aurrpc = "http://aur.archlinux.org/rpc.php";

sub new {
    my ($class, @args) = @_;

    my $self = { };

    bless $self, "Bolts::Steamroller::AUR";

    return $self;
}

sub get {
    my $self = shift;
    my $name = shift;

    our $tmpdir;
    our %messages;

    $self->{url} = "http://aur.archlinux.org/packages/$name/$name.tar.gz";
    $self->{tarball} = "$tmpdir/$name.tar.gz"
    print "$messages{info} $name...";
    $self->{response} = !is_erorr(getstore($self->{url}, $self->{tarball}));
    if($self->{response}) {
        print " done.\n";
    } else {
        print " failed.\n";
    }

    return $self->{response};
}




sub search {
    my $self = shift;
    my $terms = join @_, '+';

    my $json = get("$aurrpc?type=search&arg=$terms");

    $self->{data} = decode_json $json;

    return $self->{data}->{type};
}

sub info {
    my $self = shift;
    my $name = shift;

    my @fields = qw(pkgname pkgver pkgrel url license groups provides depends optdepends conflicts replaces pkgdesc);
    my %info;

    my $pkgbuild = get("http://aur.archlinux.org/packages/$name/$name/PKGBUILD");
    my $json = get("$aurrpc?type=info&arg=$name");

    return 'error' unless $pkgbuild;
    return 'error' unless $json->{type} eq 'info';

    %info = $pkgbuild =~ m/^(\w+)=(\([^\(\)]+\)|[^\n]+)$/mg;

    foreach(@fields) {
        $self->{info}->{$_} = $info{$_} || "None";
        $self->{info}->{$_} =~ s/\s+/ /g;
        $self->{info}->{$_} =~ s/"//g if $pkginf{$_} =~ m/^"/;
        $self->{info}->{$_} =~ s/[\(\)'"]//g if $pkginf{$_} =~ m/^\(/;
        $self->{info}->{$_} =~ s/\$pkgver/$info{pkgver}/g;
    }

    $info{ood} = decode_json $json;
    $self->{info}->{ood} = $json->{results}->{OutOfDate} == 1;

    return $self->{info};
}

return 1;


__END__
sub aurcheck () {
    our $aurrpc;
    our %repo;
    our $msg;

    my $aurver;
    my %repopkgs;

    my @upgrades;

    %repopkgs = `/usr/bin/bsdtar -tf $repo{dir}/$repo{name}.db.tar.gz` =~
        m#(.+)-(\d.*-\d+)/#g;

    print "$msg Checking for updates...\n";
    foreach(sort keys %repopkgs) {
        $aurver = get("$aurrpc?type=info&arg=$_") ||
        return 0;
        $aurver =~ s/.*"Version":"(.+?)".*/$1/ || next;
        push @upgrades, $_ if `/usr/bin/vercmp $aurver $repopkgs{$_}` == 1;
    }
    return @upgrades;
}

return 1;

# vim:ft=perl:
