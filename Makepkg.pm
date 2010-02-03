use strict;
use warnings;
require Exporter;
our @EXPORT = qw(exttaurball finddeps makepkg repoadd pacsy);

sub exttaurball ($) {
    our $tmpdir;

    my $taurball = shift;

    chdir $tmpdir;
    system("/usr/bin/bsdtar -xf $taurball.tar.gz") &&
    return 0;
    return 1;
}

sub finddeps ($) {
    our $tmpdir;
    our $paclst;

    my $pkg = shift;
    my $pkgbuild = `bsdtar -xOf $tmpdir/$pkg.tar.gz $pkg/PKGBUILD`;
    my $deps;

    my @deplist;

    if($pkgbuild =~ /\ndepends=\(([^)]+)\)/) {
        $deps = $1;
        while($deps =~ s/'([^ ']+)'//) {
            my $i = $1;
            $i =~ s/^([^=<>]+).*?$/$1/;
            push @deplist, $i unless $paclst =~ m/^$i$/m;
        }
    }
    if($pkgbuild =~ /\nmakedepends=\(([^)]+)\)/) {
        $deps = $1;
        while($deps =~ s/'([^ ']+)'//) {
            my $i = $1;
            $i =~ s/^([^=<>]+).*?$/$1/;
            push @deplist, $i unless $paclst =~ m/^$i$/m;
        }
    }
    return @deplist;
}

sub makepkg ($) {
    our $editor;
    our $tmpdir;
    our $makepkgopt;

    my $pkg = shift;
    my @sources;

    my $pkgf;

    opendir BUILDDIR, "$tmpdir/$pkg";
    @sources = readdir BUILDDIR;
    closedir BUILDDIR;

    chdir("$tmpdir/$pkg");
    foreach my $source (@sources) {
        system("$editor $source") if $source =~ /^(PKGBUILD|.+\.install)$/i;
    }

    system("/usr/bin/makepkg -sf $makepkgopt") && 
    return 0;

    opendir BUILDDIR, ".";
    @sources = readdir BUILDDIR;
    closedir BUILDDIR;

    foreach(sort @sources) {
        $pkgf = $_ if /$pkg-.+-.+-.+\.pkg\.tar\.gz/;
    }
    system("cp $pkgf $tmpdir");
    chdir($tmpdir);

    return $pkgf;
}

sub repoadd ($) {
    our %repo;
    our $tmpdir;

    my $pkgf = pop;

    system("mv $tmpdir/$pkgf $repo{dir}") &&
    return 0;

    system("/usr/bin/repo-add $repo{dir}/$repo{name}.db.tar.gz $repo{dir}/$pkgf") &&
    return 0;

    return 1;
}

sub reporemove ($) {
    our %repo;

    my $pkg = pop;

    system("/usr/bin/repo-remove $repo{dir}/$repo{name}.db.tar.gz $pkg") &&
    return 0;

    return 1;
}

sub pacsy () {
    our $pacmanbin;

    if(stat "/usr/bin/sudo") {
        system("/usr/bin/sudo $pacmanbin -Sy") &&
        return 0;
    } else {
        system("/bin/su -c '$pacmanbin -Sy'") &&
        return 0;
    }
    return 1;
}

return 1;

# vim:ft=perl:
