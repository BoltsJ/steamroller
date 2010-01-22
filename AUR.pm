use strict;
use warnings;
use LWP::Simple qw(get getstore is_error);
use JSON qw(decode_json);

require Exporter;
our @EXPORT = qw(getaurpkg aursearch aurinfo aurcheck);

our $aurrpc = "http://aur.archlinux.org/rpc.php";

sub getaurpkg ($) {
    our $tmpdir;

    my $pkg = shift;
    my $aururl = "http://aur.archlinux.org/packages/$pkg/$pkg.tar.gz";
    my $resp;

    mkdir $tmpdir;

    print "Retreiving $_ sources from AUR...";
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
    our $aurrpc;

    my $arg = shift;
    my $json;

    my $data;

    return () unless $arg;

    $json = get "$aurrpc?type=info&arg=$arg";
    $data = decode_json $json;

    if($data->{type} eq 'error') {
        return ();
    } else {
        return %{$data->{results}};
    }
}


sub aurcheck () {
    our $aurrpc;
    our %repo;

    my $aurver;
    my %repopkgs;

    my @upgrades;

    %repopkgs = `/usr/bin/bsdtar -tf $repo{dir}/$repo{name}.db.tar.gz` =~
        m#(.+)-(\d.*-\d+)/#g;

    print "Checking for updates...\n";
    foreach(sort keys %repopkgs) {
        $aurver = get("$aurrpc?type=info&arg=$_");
        $aurver =~ s/.*"Version":"(.+?)".*/$1/ || next;
        push @upgrades, $_ if `/usr/bin/vercmp $aurver $repopkgs{$_}` == 1;
    }
    return @upgrades;
}

return 1;

# vim:ft=perl:
