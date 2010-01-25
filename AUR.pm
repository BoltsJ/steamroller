use strict;
use warnings;
use LWP::Simple qw(get getstore is_error);
use JSON qw(decode_json);

require Exporter;
our @EXPORT = qw(getaurpkg aursearch aurinfo aurcheck);

our $aurrpc = "http://aur.archlinux.org/rpc.php";

sub getaurpkg ($) {
    our $tmpdir;
    our $inf;

    my $pkg = shift;
    my $aururl = "http://aur.archlinux.org/packages/$pkg/$pkg.tar.gz";
    my $resp;

    mkdir $tmpdir;

    print "$inf $_...";
    $resp = getstore($aururl, "$tmpdir/$pkg.tar.gz");
    print " done.\n";

    return 0 if is_error($resp);
    return "$tmpdir/$pkg.tar.gz";
}

sub aursearch ($) {
    our $aurrpc;

    my $arg = shift;
    my $json;

    my $data;



    return () unless $arg;

    $json = get("$aurrpc?type=search&arg=$arg");
    $data = decode_json $json;

    if($data->{type} eq 'error') {
        return ();
    } else {
        return @{$data->{results}};
    }
}

sub aurinfo ($) {
    my $pkg = shift;
    my $aururl = "http://aur.archlinux.org/packages/$pkg/$pkg/PKGBUILD";
    my @fields = qw(pkgname pkgver pkgrel url license groups provides depends optdepends conflicts replaces pkgdesc);
    my $pkgbuild;
    my %info;

    my %pkginf;

    $pkgbuild = get $aururl;
    return () unless $pkgbuild;
    
    %info = $pkgbuild =~ m/^(\w+)=(\([^\(\)]+\)|[^\(\)\n]+)$/mg;

    foreach(@fields) {
        $pkginf{$_} = $info{$_} || "None";
        $pkginf{$_} =~ s/\s+/ /g;
        $pkginf{$_} =~ s/[\(\)'"]//g;
        $pkginf{$_} =~ s/\$pkgver/$info{pkgver}/g;
    }

    return %pkginf;
}


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
