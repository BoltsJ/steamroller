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
#package Clyde;
our @EXPORT = qw/getaurpkg exttaurball makepkg repoadd syu/;
our $VERSION = 0.01;

our %repo;
our $tmpdir;

sub getaurpkg ($) {
    my $pkg = shift;
    my $aururl = "http://aur.archlinux.org/packages/$pkg/$pkg.tar.gz";
    our $tmpdir;
    mkdir $tmpdir;
    system("/usr/bin/wget -O '$tmpdir/$pkg.tar.gz' -c '$aururl'") &&
    return 0;
    return "$tmpdir/$pkg.tar.gz";
}

sub exttaurball ($) {
    my $taurball = shift;
    our $tmpdir;
    chdir $tmpdir;
    system("/usr/bin/bsdtar -xf $taurball.tar.gz") &&
    return 0;
    return 1;
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

sub repoadd (%$) {
    my $pkgf = pop;
    my %repo = @_;
    system("mv $tmpdir/$pkgf $repo{dir}") &&
    return 0;
    system("/usr/bin/repo-add $repo{dir}/$repo{name}.db.tar.gz $repo{dir}/$pkgf") &&
    return 0;
    return 1;
}

sub syu () {
    our $pacmanbin;
    system("sudo $pacmanbin -Sy") &&
    return 0;
    return 1;
}

return 1;
