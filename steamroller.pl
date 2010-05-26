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

# steamroller - A makepkg wrapper with AUR support

use strict;
use warnings;
use Bolts::Steamroller::Makepkg;
use Bolts::Steamroller::AUR;

# Global declarations
our %repo;
our $tmpdir = '/tmp/steamroller';
our $col = 0;
our $msg = "==>";
our $inf = "  ->";
our $err = "==> ERROR:";
our $makepkgopt = ' ';

my @pkgs;
my %mode;

# Default Values
our $editor = $ENV{EDITOR} ||
    $ENV{VISUAL} || (
    "/usr/bin/vi" &&
    warn "\$EDITOR and \$VISUAL are not set. Using `vi`\n"
);
my $uconf = 1;
our $pacmanbin = "/usr/bin/pacman";


# Parse global config
open CONF, "/etc/steamroller.conf" or
die "Failed to open global configuration file\n";
while(<CONF>) {
    next if /^\s*#/;
    if(/^RepoName=(.+?)\s*(?:#|$)/) {
        $repo{name} = $1;
    }
    if(/^RepoDir=(.+?)\s*(?:#|$)/) {
        $repo{dir} = $1;
    }
    if(/^Colour=yes/ && -t STDOUT) {
        $col = 1;
    }
    if(/^BuildDir=(.+?)\s*(?:#|$)/) {
        $tmpdir = $1;
    }
    if(/^UserConfig=no/) {
        $uconf = 0;
    }
    if(/^PacmanBin=(.+?)\s*(?:#|$)/) {
        $pacmanbin = $1;
    }
    if(/^MakepkgOpts='(.+?)'\s*(?:#|$)/) {
        $makepkgopt = $1;
    }
}
if($uconf && stat("$ENV{HOME}/.steamroller.conf")) {
    open CONF, "$ENV{HOME}/.steamroller.conf" or
    die "Unable to read \$HOME/.steamroller.conf\n";
    while(<CONF>) {
        next if /^\s*#/;
        if(/^RepoName=(.+?)(\s+#|$)/) {
            $repo{name} = $1;
        }
        if(/^RepoDir=(.+?)(\s+#|$)/) {
            $repo{dir} = $1;
        }
        if(/^Colour=yes/ && -t STDOUT) {
            $col = 1;
        }
        if(/^BuildDir=(.+?)(\s+#|$)/) {
            $tmpdir = $1;
        }
        if(/^PacmanBin=(.+?)(\s+#|$)/) {
            $pacmanbin = $1;
        }
        if(/^MakepkgOpts='(.+?)'\s*(?:#|$)/) {
            $makepkgopt = $1;
        }
    }
}
close CONF;
if(!$repo{name} && !$repo{dir}) {
    die "RepoName and RepoDir must be set in /etc/steamroller.conf\n";
}


# Parse command line options
while($_ = shift) {
    if(/^-[^-]/) {
        $mode{S} = 1 if /S/;
        $mode{U} = 1 if /U/;
        $mode{R} = 1 if /R/;
        $mode{s} = 1 if /s/;
        $mode{i} = 1 if /i/;
        $mode{c} = 1 if /c/;
        $mode{u} = 1 if /u/;
        $mode{n} = 1 if /n/;
        $mode{q} = 1 if /q/;
    }
    $mode{S} = 1 if /^--sync$/;
    $mode{U} = 1 if /^--upgrade$/;
    $mode{R} = 1 if /^--remove$/;
    $mode{s} = 1 if /^--search$/;
    $mode{i} = 1 if /^--info$/;
    $mode{c} = 1 if /^--clean$/;
    $mode{u} = 1 if /^--update$/;
    $mode{n} = 1 if /^--no-save$/;
    $mode{q} = 1 if /^--quiet$/;
    push @pkgs, $_ if /^[^-]/;
}


# main()
if($col) {
    $err = "\e[31;1m==> ERROR:\e[0m";
    $inf = "\e[34;1m  ->\e[0m";
    $msg = "\e[32;1m==>\e[0m";
}

if($mode{S}) {

    if($mode{i}) {
        die "$err No packages specified\n" unless @pkgs;
        my %pkginf;
        my @fmt;
        if($col) {
            @fmt = (
                "\e[0;1m", "\e[35;1m",
                "\e[0;1m", "\e[0;1m",
                "\e[0;1m", "\e[32;1m",
                "\e[0;1m", "\e[36;1m",
                "\e[0;1m", "\e[0m",
            );
            push @fmt, (@fmt[8,9]) x 7;
        } else {
            @fmt = ('') x 24;
        }
        foreach(@pkgs) {
            %pkginf = aurinfo $_;

            die "$err $_ not found in AUR\n" unless scalar %pkginf;
            printf <<EOI, @fmt;
%sRepository      : %sAUR
%sName            : %s$pkginf{pkgname}
%sVersion         : %s$pkginf{pkgver}-$pkginf{pkgrel}
%sURL             : %s$pkginf{url}
%sLicenses        : %s$pkginf{license}
%sGroups          : %s$pkginf{groups}
%sProvides        : %s$pkginf{provides}
%sDepends On      : %s$pkginf{depends}
%sOptional Deps   : %s$pkginf{optdepends}
%sConflicts With  : %s$pkginf{conflicts}
%sReplaces        : %s$pkginf{replaces}
%sDescription     : %s$pkginf{pkgdesc}

EOI
        }
        exit 0;
    }
    if($mode{s}) {
        die "$err No search string specified\n" unless @pkgs;
        my @results = aursearch join '+', @pkgs;
        if(!@results) {
            print "$msg No results found\n";
            exit 1;
        }
        if($mode{q}) {
            foreach(@results) {
                print "$_->{Name}\n"
            }
        } else {
            foreach(@results) {
                printf "%sAUR/%s$_->{Name} %s$_->{Version}%s\n    $_->{Description}\n",
                $col ? "\e[35;1m" : "",
                $col ? "\e[0;1m"  : "",
                $col ? "\e[32;1m" : "",
                $col ? "\e[0m"    : "";
            }
        }
        exit 0;
    }

    if($mode{c}) {
        my %repopkgs = `/usr/bin/bsdtar -tf $repo{dir}/$repo{name}.db.tar.gz` =~
            m#(.+)-(\d.*-\d+)/#g;
        opendir REPODIR, $repo{dir};
        my @dir = readdir REPODIR;
        closedir REPODIR;

        my @del;

        DEL: foreach my $i (@dir) {
            next unless $i =~ /\.pkg\.tar\.(?:g|x)z$/;
            foreach my $j (keys %repopkgs) {
                my $ver = $repopkgs{$j};
                next DEL if $i =~ /^$j-$ver-(?:i686|x86_64|any)\.pkg/;
            }
            push @del, "$repo{dir}/$i";
        }
        unlink @del;
        exit 0;
    }

    if($mode{u}) {
        @pkgs = aurcheck or
        print "$msg Local repo is up to date with AUR\n";
    }
    exit 0 unless @pkgs;
    our $paclst = `$pacmanbin -Sqs`;
    # Match with $paclst =~ m/^<pattern>$/m
    my @deplist;
    my @apkgs = ();
    print "$msg Retreiving sources from AUR...\n";
    foreach(@pkgs) { # Generate list of AUR dependencies
        getaurpkg $_ ||
        warn "$err $_ not found on the AUR\n" &&
        next;
        push @deplist, finddeps $_;
        push @apkgs, $_;
    }
    if(!@apkgs) {
        die "$err No targets\n";
    }
#       Prepend each AUR dependency to the list of pkgs to add to the repo
#       then check its dependencies
    print "$msg Resolving dependencies...\n";
    while($_ = pop @deplist) {
        unshift @apkgs, $_;
        getaurpkg $_ ||
        warn "$err $_ not found in sync database or on AUR\n";
        unshift @deplist, finddeps $_;
    }

    # Remove duplicate entries from package list
    my @bpkgs = ();
    PKG: foreach my $i (@apkgs) {
        foreach my $j (@bpkgs) {
            next PKG if $i eq $j;
        }
        push @bpkgs, $i;
    }

    printf "Targets(%s): @bpkgs\nProceed with build? [Y/n] ", scalar @bpkgs;
    if(<STDIN> =~ /no?/i) {
        exit 0;
    }
    # build packages in order
    foreach(@bpkgs) {
        exttaurball $_ ||
        die "$err Could not extract $tmpdir/$_.tar.gz\n";
        my $pkgf = makepkg $_ ||
        die "$err Build of $_ failed.\n";
        repoadd $pkgf ||
        die "$err Failed to add $_ to local repo `$repo{name}'\n";
        pacsy; # Update pacman repos for build dep resolution.
    }
    exit 0;
}

if($mode{U}) {
    my @upkgs;
    foreach(@pkgs) {
        mkdir $tmpdir;
        my $upkg = `/usr/bin/bsdtar -xOf $_ */PKGBUILD`;
        $upkg =~ /^pkgname=(.+)$/m;
        $upkg = $1;
        push @upkgs, $upkg;
        system("cp $_ $tmpdir/$upkg.tar.gz");
    }
    foreach(@upkgs) {
        exttaurball $_ ||
        die "$err Could not extract $tmpdir/$_.tar.gz";
        my $pkgf = makepkg $_ ||
        die "$err Build of $_ failed.\n";
        repoadd $pkgf ||
        die "$err Failed to add $_ to local repo `$repo{name}'\n";
    }
    exit 0;
}

if($mode{R}) {
    foreach(@pkgs) {
        reporemove $_ or
            die "$err $_ could not be removed\n";
        if($mode{n}) {
            opendir REPODIR, $repo{dir} or
            die "$err Could not open repo dir\n";
            my @dir = readdir REPODIR;
            closedir REPODIR;

            foreach my $i (@dir) {
                if($i =~ m/^($_-\d.*-\d+-(?:i686|x86_64|any)\.pkg\.tar\.(?:gz|xz))$/) {
                    print "$msg Deleting $1 from repo dir\n";
                    unlink "$repo{dir}/$1";
                }
            }
        }
    }
    exit 0;
}

print "$err No operation specified\n";
exit 2;

