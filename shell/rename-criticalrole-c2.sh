#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: rename-criticalrole-c2.sh [OPTIONS]

Rename Critical Role Campaign 2 episode files from:
  <Episode Name> <sep> Critical Role <sep> Campaign 2, Episode XX [id].<ext>

to:
  Episode XX <Episode Name>.<ext>

Options:
  --dir PATH      Target directory (default: ~/Downloads/CriticalRole)
  --apply         Perform renames (default is dry run)
  --dry-run       Show planned renames only
  -h, --help      Show this help

Notes:
  - Handles .webm and matching subtitle .srt variants (.srt, .en.srt, .en-en.srt, ...)
  - Detects collisions before applying changes
EOF
}

mode="dry-run"
target_dir="$HOME/Downloads/CriticalRole"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            [[ $# -ge 2 ]] || { echo "Error: --dir requires a path" >&2; exit 2; }
            target_dir="$2"
            shift 2
            ;;
        --apply)
            mode="apply"
            shift
            ;;
        --dry-run)
            mode="dry-run"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -d "$target_dir" ]]; then
    echo "Error: Directory not found: $target_dir" >&2
    exit 1
fi

MODE="$mode" TARGET_DIR="$target_dir" perl -CS -Mstrict -Mwarnings -MFile::Find -e '
my $mode = $ENV{MODE};
my $dir = $ENV{TARGET_DIR};

my @entries;
find(
    {
        no_chdir => 1,
        wanted => sub {
            return unless -f $File::Find::name;
            my $full = $File::Find::name;
            my $rel = $full;
            $rel =~ s/^\Q$dir\E\/?//;
            push @entries, $rel if length $rel;
        },
    },
    $dir,
);

my @rename_ops;
my @unmatched;
my %target_to_sources;
my %source_set;
my $already_named = 0;

for my $name (sort @entries) {
    next unless $name =~ /\.(?:webm|srt)\z/;

    my ($parent, $base) = ("", $name);
    if ($name =~ /\A(.+)\/([^\/]+)\z/) {
        ($parent, $base) = ($1, $2);
    }

    if ($base =~ /\AEpisode [0-9]+ .+\.(?:webm|srt|[^.]+\.srt)\z/) {
        $already_named++;
        next;
    }

    if ($base =~ /\A(.+?)\s+[^\x00-\x7F]+\s+Critical Role\s+[^\x00-\x7F]+\s+Campaign 2, Episode ([0-9]+)(?: - [^\[]+)? \[[^\]]+\](\.[^.]+(?:\.srt)?|\.webm)\z/) {
        my ($title, $ep, $suffix) = ($1, $2, $3);
        my $new_base = "Episode $ep $title$suffix";
        my $new_name = $parent eq "" ? $new_base : "$parent/$new_base";

        push @rename_ops, [$name, $new_name];
        push @{ $target_to_sources{$new_name} }, $name;
        $source_set{$name} = 1;
        next;
    }

    push @unmatched, $name;
}

my @collisions = grep { @{ $target_to_sources{$_} } > 1 } sort keys %target_to_sources;
my @existing_conflicts;
for my $target (sort keys %target_to_sources) {
    next unless -e "$dir/$target";
    next if $source_set{$target};
    push @existing_conflicts, $target;
}

print "Directory: $dir\n";
print "Mode: $mode\n";
print "Candidates: " . scalar(@rename_ops) . "\n";
print "Already renamed: $already_named\n";
print "Unmatched: " . scalar(@unmatched) . "\n";
print "Collisions: " . scalar(@collisions) . "\n";
print "Existing target conflicts: " . scalar(@existing_conflicts) . "\n";

if (@unmatched) {
    print "\nUnmatched files (showing up to 20):\n";
    my $limit = @unmatched < 20 ? scalar @unmatched : 20;
    for my $i (0 .. $limit - 1) {
        print "  - $unmatched[$i]\n";
    }
}

if (@collisions) {
    print "\nCollisions:\n";
    for my $target (@collisions) {
        my $srcs = join(", ", @{ $target_to_sources{$target} });
        print "  - $target <= $srcs\n";
    }
}

if (@existing_conflicts) {
    print "\nExisting target conflicts:\n";
    for my $target (@existing_conflicts) {
        print "  - $target\n";
    }
}

if (@collisions || @existing_conflicts) {
    die "\nAborting due to conflicts.\n";
}

if (!@rename_ops) {
    print "\nNo files matched the old pattern.\n";
    exit 0;
}

print "\nPlanned renames (showing up to 25):\n";
my $preview_limit = @rename_ops < 25 ? scalar @rename_ops : 25;
for my $i (0 .. $preview_limit - 1) {
    my ($old, $new) = @{ $rename_ops[$i] };
    print "  - $old => $new\n";
}

if ($mode ne "apply") {
    print "\nDry run only. Re-run with --apply to rename files.\n";
    exit 0;
}

my $renamed = 0;
for my $op (@rename_ops) {
    my ($old, $new) = @$op;
    rename "$dir/$old", "$dir/$new" or die "Rename failed: $old => $new: $!\n";
    $renamed++;
}

print "\nRenamed files: $renamed\n";
'
