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


# METADATA
# Version: 0.0.1

# clyde - A makepkg wrapper with AUR and ABS support

use strict;
use warnings;
use Bolts::Clyde;

# Global declarations
our %repo;
our $tmpdir = '/tmp/clyde';
my @pkgs;
my %mode;
my $upkg;
my $taurball;

# Default Values
our $editor = $ENV{EDITOR} ||
    $ENV{VISUAL} || (
    "/usr/bin/vi" &&
    warn "\$EDITOR and \$VISUAL are not set. Using `vi`\n"
);
my $uconf = 1;
our $pacmanbin = "/usr/bin/pacman";

# Parse global config
open CONF, "/etc/clyde.conf" or
die "Failed to open global configuration file\n";
while(<CONF>) {
    next if /^\s*#/;
    if(/^RepoName=(.+?)(\s+#|$)/) {
        $repo{name} = $1;
        next;
    }
    if(/^RepoDir=(.+?)(\s+#|$)/) {
        $repo{dir} = $1;
        next;
    }
    if(/^BuildDir=(.+?)(\s+#|$)/) {
        $tmpdir = $1;
        next;
    }
    if(/^UserConfig=no/) {
        $uconf = 0;
    }
}
close CONF;
if(!$repo{name} && !$repo{dir}) {
    die "RepoName and RepoDir must be set in /etc/clyde.conf\n";
}

# Parse command line options
while($_ = shift) {
    if(/^-[^-]/) {
        if(/U/) {
            $mode{U} = 1;
            $mode{S} = 0;
            $taurball = shift;
            $upkg = shift;
            last;
        }
        $mode{S} = 1 if /S/;
        $mode{u} = 1 if /u/;
        $mode{y} = 1 if /y/;
    }
    $mode{S} = 1 if /^--sync$/;
    push @pkgs, $_ if /^[^-]/;
}

# MAIN()
if($mode{S}) {
    if($mode{u}) {
        exit 0;
#        @pkgs = getupdates $repo{dir};
    }
    if($mode{a}) {
        exit 0;
    }
    foreach(@pkgs) {
        getaurpkg $_;
        exttaurball $_;
        my $pkgf = makepkg $_ ||
        die "Build of $_ failed.\n";
        repoadd %repo, $pkgf;
    }
    syu if $mode{y};
    exit 0;
}

if($mode{U}) {
    mkdir $tmpdir;
    system("cp $taurball $tmpdir/$upkg.tar.gz");
    exttaurball $upkg;
    my $pkgf = makepkg $upkg;
    repoadd %repo, $pkgf;
}









