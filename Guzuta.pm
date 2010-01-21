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
use LWP::Simple qw(get getstore is_error);
use JSON::XS qw(decode_json);
require Exporter;
our @EXPORT = qw(getaurpkg exttaurball finddeps makepkg repoadd pacsy aursearch aurcheck);
our $VERSION = 0.01;

our %repo;
our $tmpdir;

our $aurrpc = "http://aur.archlinux.org/rpc.php";

sub getaurpkg ($) {
    my $pkg = shift;
    my $aururl = "http://aur.archlinux.org/packages/$pkg/$pkg.tar.gz";
    our $tmpdir;
    mkdir $tmpdir;
    my $resp = getstore($aururl, "$tmpdir/$pkg.tar.gz");
#    system("/usr/bin/wget -O '$tmpdir/$pkg.tar.gz' -c '$aururl'") &&
#    return 0;
    return 0 if is_error($resp);
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

sub aursearch($) {
    my @results;
    our $aurrpc;
    my $arg = shift;
    my $json = get("$aurrpc?type=search&arg=$arg");
    if($json->{results} eq "No results found") {
        return 0;
    } else {
        return @{$json->{results}};
    }
}

sub aurcheck () {
    my @upgrades;
    my $pkg;
    my $pkgver;
    my $pkginfo;
    my $aurver;
    my %repopkgs;
    our $aurrpc;
    our %repo;
    opendir REPO, $repo{dir};
    my @repofiles = readdir REPO;
    closedir REPO;
    chdir $repo{dir};
    foreach(@repofiles) {
        next unless /\.pkg\.tar\.gz$/;
        $pkginfo = `/usr/bin/bsdtar -xOf $_ .PKGINFO`;
        $pkginfo =~ /pkgver\s+=\s+(\S+)\n/;
        $pkgver = $1;
        $pkginfo =~ /pkgname\s+=\s+(\S+)\n/;
        $pkg = $1;
        $repopkgs{$pkg} = $pkgver;
    }
    foreach(sort keys %repopkgs) {
        $aurver = get("$aurrpc?type=info&arg=$_");
        $aurver =~ s/.*"Version":"(.+?)".*/$1/ || next;
        push @upgrades, $_ if `/usr/bin/vercmp $aurver $repopkgs{$_}` == 1;
    }
    return @upgrades;
}

return 1;
