#!/usr/bin/env perl

# SEE ALSO THE DOCUMENTATION IN port.sh
#
# This perl script is for porting files from the standard library to the HoTT library
#
# To use: first make it executable (chmod u+x port.pl). Then type
#
#  ./port.pl ../library/path/to/source.lean ../hott/path/to/destination.hlean ["from1" "to1" "from2" "to2" ...]
#
# This will port the file ../library/path/to/source.lean to ../hott/path/to/destination.hlean
# renaming core definitions form the standard library to core definitions in the HoTT library.
# These renamings are specified in port.txt. See the documentation in rename.pl for the syntax.
# The arguments "fromi" and "toi" are optional, but should be provided in pairs.
# These arguments will replace "fromi" by "toi" in the specified file,
# before doing any other renamings.
#
# We use slightly different regular expressions here. Given the replacement rule foo:bar, we replace
# foo by bar except is foo is preceded or followed by a letter. We still replace foo if it's
# followed by a digit, underscore, period or similar.
#
# TODO: Currently we use dictionaries to store the renamings. This has the unfortunate consequence
# that we cannot control the order in which the substitutions happens. This makes it very hard to
# replace all occurrences of "and" by "prod", but all occurrences of "and.intro" by "prod.mk"

use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename;
use File::Spec::Functions;
use File::Copy;
use feature 'unicode_strings';

# the global list of renamings
my %renamings = ();
my %literalrenamings = ();
my %literalrenamings2 = ();

# get the list of renamings from the file
sub get_renamings {
    if (scalar(@ARGV)%2==1) {die "ERROR: odd number of arguments provided"}
    %literalrenamings2 = @ARGV;
    my $fullname = catfile(dirname(abs_path($0)), "port.txt");
    open (my $renaming_file, "<", $fullname) or die $!;
    while (<$renaming_file>) {
	if (/([\w'.]+)[:]([\w'.]+)\n/) {
	    $renamings{$1} = $2;
	} elsif (/(.+)[;](.+)\n/) {
	    $literalrenamings{$1} = $2;
	}
    }
    close $renaming_file or die $!;
}

# print them out - for debugging
sub show_renamings {
    foreach my $key (keys %renamings) {
	print $key, " => ", $renamings{$key}, "\n";
    }
    print "\n";
    foreach my $lkey (keys %literalrenamings2) {
	print $lkey, " -> ", $literalrenamings2{$lkey}, "\n";
    }
    foreach my $lkey (keys %literalrenamings) {
	print $lkey, " -> ", $literalrenamings{$lkey}, "\n";
    }
}

# rename all identifiers a file; original goes in file.orig
sub rename_in_file {
    my $filename = shift;
    local($^I, @ARGV) = ('.temp', $filename);
    while (<>) {
	foreach my $lkey (keys %literalrenamings2) {
	    # replace all instances of lkey
	    # if (/$lkey/) {print STDOUT "renamed ", $lkey, "\n"; }
	    s/$lkey/$literalrenamings2{$lkey}/g;
	}
	foreach my $key (keys %renamings) {
	    # replace instances of key, not preceeded by a letter, and not
	    # followed by a letter, number, or '
	    s/(?<![a-zA-Z])$key(?![a-zA-Z])/$renamings{$key}/g;
	}
	foreach my $lkey (keys %literalrenamings) {
	    # replace all instances of lkey
	    s/$lkey/$literalrenamings{$lkey}/g;
	}
	print;
    }
}

my $oldfile = shift;
my $newfile = shift;
my $backup = "${newfile}.orig";
if (-e $newfile)  {
  print "backing up file ${newfile}.\n" unless -e $backup;
  copy($newfile,$backup) or die "Copy failed: $!" unless -e $backup ;
}
print "porting ", $oldfile, " to ",$newfile, ".\n";
copy($oldfile,$newfile) or die "Copy failed: $!";
get_renamings;
# show_renamings;
rename_in_file $newfile;
unlink "${newfile}.temp";
