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
our @EXPORT = qw(getaurpkg aursearch aurcheck);

our %repo;
our $tmpdir;

our $aurrpc = "http://aur.archlinux.org/rpc.php";

sub getaurpkg ($) {
    my $pkg = shift;
    my $aururl = "http://aur.archlinux.org/packages/$pkg/$pkg.tar.gz";
    our $tmpdir;
    mkdir $tmpdir;
    print "Retreiving $_ sources from AUR...";
    my $resp = getstore($aururl, "$tmpdir/$pkg.tar.gz");
    print " done.\n";
    return 0 if is_error($resp);
    return "$tmpdir/$pkg.tar.gz";
}

sub aursearch($) {
    my @results;
    our $aurrpc;
    my $arg = shift;
    return () unless $arg;
    my $json = get("$aurrpc?type=search&arg=$arg");
    my $data = decode_json $json;
    if($data->{results} eq "No results found") {
        return ();
    } else {
        return @{$data->{results}};
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
