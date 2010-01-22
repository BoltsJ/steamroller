#!/usr/bin/perl

# Copyright (C) 2010 Joseph 'Bolts' Nosie
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use warnings;
require Exporter;
our @EXPORT = qw(exttaurball finddeps makepkg repoadd pacsy);

our %repo;
our $tmpdir;

sub exttaurball ($) {
    my $taurball = shift;
    our $tmpdir;
    chdir $tmpdir;
    system("/usr/bin/bsdtar -xf $taurball.tar.gz") &&
    return 0;
    return 1;
}

sub finddeps ($) {
    my $pkg = shift;
    our $tmpdir;
    our $paclst;
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
    my $pkg = shift;
    my $pkgf;
    our $editor;
    opendir BUILDDIR, "$tmpdir/$pkg";
    my @sources = readdir BUILDDIR;
    closedir BUILDDIR;
    chdir("$tmpdir/$pkg");
    foreach my $source (@sources) {
        system("$editor $source") if $source =~ /^(PKGBUILD|.+\.install)$/i;
    }
    system("/usr/bin/makepkg -s") && 
    return 0;
    opendir BUILDDIR, ".";
    @sources = readdir BUILDDIR;
    closedir BUILDDIR;
    foreach(@sources) {
        $pkgf = $_ if /$pkg-.+-.+-.+\.pkg\.tar\.gz/;
    }
    system("cp $pkgf ../");
    chdir('..');
    return $pkgf;
}

sub repoadd ($) {
    my $pkgf = pop;
    our %repo;
    system("mv $tmpdir/$pkgf $repo{dir}") &&
    return 0;
    system("/usr/bin/repo-add $repo{dir}/$repo{name}.db.tar.gz $repo{dir}/$pkgf") &&
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