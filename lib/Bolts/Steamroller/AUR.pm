use strict;
use warnings;
use LWP::Simple qw(get getstore is_error);
use LWP::UserAgent;
use JSON qw(decode_json);

require Exporter;
our @EXPORT = qw(getaurpkg aursearch aurinfo aurcheck);

our $aurrpc = "http://aur.archlinux.org/rpc.php";

sub getaurpkg ($) {
    our $tmpdir;
    our $inf;

    my $pkg = shift;
    my $aururl = "https://aur.archlinux.org/packages/$pkg/$pkg.tar.gz";
    my $ua = LWP::UserAgent->new;
    my $resp;

    mkdir $tmpdir;

    print "$inf $_...";
    #$resp = getstore($aururl, "$tmpdir/$pkg.tar.gz");
    $resp = $ua->get($aururl);
    if($resp->is_success) {
        print " done.\n";
        open(TARBALL,">>$tmpdir/$pkg.tar.gz");
        print TARBALL $resp->content;
        close TARBALL;
        return "$tmpdir/$pkg.tar.gz";
    } else {
        print "failed.\n";
        return 0;
    }
}

sub aursearch ($) {
    our $aurrpc;

    my $arg = shift;
    my $json;
    my $ua = LWP::UserAgent->new;

    my $data;



    return () unless $arg;

    $json = $ua->get("$aurrpc?type=search&arg=$arg");
    $data = decode_json $json->content;

    if($data->{type} eq 'error') {
        return ();
    } else {
        return @{$data->{results}};
    }
}

sub aurinfo ($) {
    our $aurrpc;

    my $pkg = shift;
    my $aururl = "https://aur.archlinux.org/packages/$pkg/PKGBUILD";
    my @fields = qw(pkgname pkgver pkgrel url license groups provides depends optdepends conflicts replaces pkgdesc);
    my $pkgbuild;
    my %info;
    my $ua = LWP::UserAgent->new;

    my $json;
    my $data;

    my %pkginf;

    $pkgbuild = $ua->get($aururl)->content;
    return () unless $pkgbuild;
    
    %info = $pkgbuild =~ m/^(\w+)=(\([^\(\)]+\)|[^\n]+)$/mg;

    foreach(@fields) {
        $pkginf{$_} = $info{$_} || "None";
        $pkginf{$_} =~ s/\s+/ /g;
        $pkginf{$_} =~ s/"//g if $pkginf{$_} =~ m/^"/;
        $pkginf{$_} =~ s/[\(\)'"]//g if $pkginf{$_} =~ m/^\(/;
        $pkginf{$_} =~ s/\$pkgver/$info{pkgver}/g;
    }

    $json = $ua->get("$aurrpc?type=info&arg=$pkg");
    $data = decode_json $json->content;
    if($data->{type} eq 'error') {
        return ();
    } else {
        if($data->{results}->{OutOfDate} == 1) {
            $pkginf{ood} = 1;
        }
    }


    return %pkginf;
}


sub aurcheck () {
    our $aurrpc;
    our %repo;
    our $msg;

    my $aurver;
    my %repopkgs;
    my $ua = LWP::UserAgent->new;

    my @upgrades;

    %repopkgs = `/usr/bin/bsdtar -tf $repo{dir}/$repo{name}.db.tar.gz` =~
        m#(.+)-(\d.*-\d+)/#g;

    print "$msg Checking for updates...\n";
    foreach(sort keys %repopkgs) {
        $aurver = $ua->get("$aurrpc?type=info&arg=$_")->content ||
        return 0;
        $aurver =~ s/.*"Version":"(.+?)".*/$1/ || next;
        push @upgrades, $_ if `/usr/bin/vercmp $aurver $repopkgs{$_}` == 1;
    }
    return @upgrades;
}

return 1;

# vim:ft=perl:
