#!/usr/bin/perl
# tools/pack.pl - pack the mg_*.gsc sources into ONE loadable script (or a few, --parts N).
#
#   perl tools/pack.pl                          -> release/zm_prison_magmagat.gsc
#   perl tools/pack.pl --out FILE               -> somewhere else
#   perl tools/pack.pl --parts 2                -> ..._1.gsc / ..._2.gsc
#   perl tools/pack.pl --keep-comments          -> readable output, about twice the size
#   perl tools/pack.pl --no-qualify             -> leave unqualified vanilla calls, rely on #include
#
# THE LIMIT THAT MATTERS (measured 2026-09-08 with tools/gsc_header.pl on the compiled binary): every function
# and import name in a T6 script is a 16-bit offset into the string block that follows the 64-byte header. A
# script whose string block passes 65535 bytes makes the game read names from the wrong place and refuse the
# file with nonsense "Unresolved external" errors ("t_completed ", "bal_stat"). This tool refuses to write a
# file whose estimated string block is over $STRING_LIMIT bytes. When gsc-tool.exe is available it also
# compiles the result and reads the exact number from the binary.
#
# Comments are stripped (they are not in the binary, but the file is half the size) and the 25 unqualified
# vanilla helper calls are qualified from tools/vanilla_namespaces.txt (tools/gen_vanilla_map.pl), so the packed
# file needs no #include resolution at load.
use strict;
use warnings;
use File::Basename qw(dirname basename);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);

my $tools = dirname( File::Spec->rel2abs( $0 ) );
my $repo  = dirname( $tools );

my @ORDER = qw(
    mg_main.gsc mg_systems.gsc mg_coords.gsc mg_place.gsc mg_quest.gsc mg_hearth.gsc mg_run.gsc mg_forge.gsc
    mg_weapon.gsc mg_debug.gsc
);

# every mg_*.gsc of the repo must be in @ORDER: a source left out compiles fine alone and fails at load with
# "Unresolved external" (mg_audition.gsc, 2026-09-11)
{
    my %in = map { $_ => 1 } @ORDER;
    for my $f ( glob("$repo/mg_*.gsc") ) {
        my $b = basename($f);
        die "pack.pl: $b is not in the pack order (add it to \@ORDER, or the packed build will miss its functions)\n" unless $in{$b};
    }
}

my $STRING_LIMIT = 62000;   # engine limit 65535, minus a margin for what the estimate cannot see
my $GSC_TOOL = 'C:/Games/t6/gsc-tools/gsc-tool.exe';

my $out = "$repo/release/zm_prison_magmagat.gsc";
my $parts = 1;
my $strip = 1;
my $qualify = 1;

for ( my $i = 0; $i < @ARGV; $i++ ) {
    my $a = $ARGV[$i];
    if    ( $a eq '--out' && defined $ARGV[$i+1] )   { $out = $ARGV[++$i]; $out =~ s/\x5c/\//g }
    elsif ( $a eq '--parts' && defined $ARGV[$i+1] ) { $parts = int( $ARGV[++$i] ) }
    elsif ( $a eq '--keep-comments' )                { $strip = 0 }
    elsif ( $a eq '--no-qualify' )                   { $qualify = 0 }
    else  { die "pack.pl: unknown option $a\n" }
}

die "pack.pl: --parts must be 1 or more\n" if $parts < 1;

# absolute, so the exact-check below (which cd's into a tempdir to run gsc-tool.exe) can still find it
$out = File::Spec->rel2abs( $out );
$out =~ s/\x5c/\//g;

# ---------------------------------------------------------------- vanilla namespace map ----
my %ns;

if ( $qualify ) {
    my $map = "$tools/vanilla_namespaces.txt";
    open my $h, '<', $map or die "pack.pl: $map missing (run tools/gen_vanilla_map.pl)\n";

    while ( my $l = <$h> ) {
        next if $l =~ /^#/;
        chomp $l;
        my ( $fn, $space ) = split /\t/, $l;
        next unless defined $space && length $space;
        $space =~ s{/}{\x5c}g;
        $ns{$fn} = $space;
    }

    close $h;
}

# ---------------------------------------------------------------------------- read ----
my ( @blocks, @missing, %vanilla_inc, %seen_fn, %dupe );
my $version = 'unknown';

for my $name ( @ORDER ) {
    my $path = "$repo/$name";

    if ( !-f $path ) { push @missing, $name; next }

    open my $h, '<:raw', $path or die "pack.pl: cannot read $path\n";
    local $/;
    my $src = <$h>;
    close $h;
    $src =~ s/\r\n/\n/g;
    $src =~ s/\r/\n/g;

    $version = $1 if $src =~ /level\.mg_version\s*=\s*"([^"]+)"/;

    my @keep;

    for my $line ( split /\n/, $src ) {
        if ( $line =~ /^\s*#include\s+(.+?);/ ) {
            my $inc = $1;
            next if $inc =~ /^scripts/i;
            $vanilla_inc{$inc} = 1;
            next;
        }

        push @keep, $line;
    }

    my $body = join "\n", @keep;
    $body = strip_comments( $body ) if $strip;
    $body = qualify_calls( $body, \%ns ) if $qualify;

    for my $line ( split /\n/, $body ) {
        next unless $line =~ /^([a-z_][a-z0-9_]*)\s*\(/;
        my $fn = $1;
        push @{ $dupe{$fn} }, $name if $seen_fn{$fn};
        $seen_fn{$fn} = $name;
    }

    push @blocks, { name => $name, body => $body };
}

if ( keys %dupe ) {
    print "pack.pl: DUPLICATE function name(s), nothing written:\n";
    print "  $_ in $seen_fn{$_} and @{ $dupe{$_} }\n" for sort keys %dupe;
    exit 2;
}

die "pack.pl: no sources found in $repo\n" unless @blocks;
print "pack.pl: WARNING missing source(s): @missing\n" if @missing;

# --------------------------------------------------------------------------- write ----
my @inc = sort keys %vanilla_inc;
my $date = sprintf '%04d-%02d-%02d', ( localtime )[5] + 1900, ( localtime )[4] + 1, ( localtime )[3];
my $dir = dirname( $out );
make_path( $dir ) unless -d $dir;

my $per = int( ( @blocks + $parts - 1 ) / $parts );
my ( @written, $over );

# names of the parts that will hold sources: with more than one file each part must #include the others,
# because the project includes were stripped and a function in part 2 is an external for part 1
my $stem = basename( $out, '.gsc' );
my @part_names;

for my $p ( 0 .. $parts - 1 ) {
    next if $p * $per > $#blocks;
    push @part_names, ( $parts > 1 ? $stem . '_' . ( $p + 1 ) : $stem );
}

for my $p ( 0 .. $parts - 1 ) {
    my $last = ( $p + 1 ) * $per - 1;
    $last = $#blocks if $last > $#blocks;
    next if $p * $per > $#blocks;
    my @mine = @blocks[ $p * $per .. $last ];

    my $file = $out;
    $file =~ s/\.gsc$/'_' . ( $p + 1 ) . '.gsc'/e if $parts > 1;

    my $text = '';
    $text .= "#include $_;\n" for @inc;

    if ( $parts > 1 ) {
        my $me = $stem . '_' . ( $p + 1 );

        for my $other ( @part_names ) {
            next if $other eq $me;
            $text .= "#include scripts\x5czm\x5czm_prison\x5c$other;\n";
        }
    }
    $text .= "\n// Magmagat for Mob of the Dead $version - generated by tools/pack.pl on $date. Do not edit.\n";
    $text .= "// Sources: " . join( ', ', map { $_->{name} } @mine ) . "\n";
    $text .= "// Edit the mg_*.gsc sources in the repo, then run tools/deploy.pl.\n\n";
    $text .= $_->{body} . "\n" for @mine;

    my $est = string_block_estimate( $text );
    my $fn = () = $text =~ /^[a-z_][a-z0-9_]*\s*\(/mg;

    if ( $est > $STRING_LIMIT ) {
        printf "pack.pl: REFUSED %s: estimated string block %d bytes > %d (engine limit 65535). Use --parts %d or drop strings.\n",
            basename( $file ), $est, $STRING_LIMIT, $parts + 1;
        $over = 1;
        next;
    }

    open my $o, '>:raw', $file or die "pack.pl: cannot write $file\n";
    print $o $text;
    close $o;
    push @written, $file;
    printf "pack.pl: %-34s %2d source(s), %3d functions, %3d KB, string block ~%d bytes\n",
        basename( $file ), scalar @mine, $fn, int( ( -s $file ) / 1024 ), $est;
}

exit 3 if $over;

printf "pack.pl: version %s, %d vanilla include(s)%s%s\n", $version, scalar @inc,
    ( $strip ? ', comments stripped' : '' ), ( $qualify ? ', calls qualified' : '' );

# exact check when the compiler is here (Windows dev machine); CI relies on the estimate
if ( -x $GSC_TOOL || -f $GSC_TOOL ) {
    my $tmp = tempdir( CLEANUP => 1 );
    my $bad = 0;

    for my $file ( @written ) {
        my $rc = system( "cd \"$tmp\" && \"$GSC_TOOL\" -m comp -g t6 -s pc \"$file\" > \"$tmp/log.txt\" 2>&1" );
        my $bin = "$tmp/compiled/t6/" . basename( $file );

        if ( $rc != 0 || !-f $bin ) {
            print "pack.pl: gsc-tool FAILED on " . basename( $file ) . ":\n";
            system( "cat \"$tmp/log.txt\"" );
            $bad = 1;
            next;
        }

        my $hdr = `perl "$tools/gsc_header.pl" "$bin"`;
        my ( $real ) = $hdr =~ /string block\s+(\d+)/;
        printf "pack.pl: %-34s compiled ok, real string block %d bytes (%s)\n", basename( $file ), $real, ( $real > 65535 ? 'OVER THE LIMIT' : 'under 65535' );
        $bad = 1 if $real > 65535;
    }

    if ( $bad ) {
        unlink $_ for @written;
        print "pack.pl: output removed, fix the sources or use --parts\n";
        exit 3;
    }
}

print "pack.pl: $_\n" for @written;
exit 0;

# ------------------------------------------------------------------------- helpers ----

# Unique string literals plus unique identifiers (function, field and namespace names), one NUL each: a close
# upper estimate of the binary's string block (the compiler stores each distinct string once).
sub string_block_estimate {
    my ( $text ) = @_;
    my %s;
    $s{$1} = 1 while $text =~ /"((?:[^"\x5c]|\x5c.)*)"/g;
    $s{$1} = 1 while $text =~ /(?<![\w])([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
    $s{$1} = 1 while $text =~ /\.([A-Za-z_][A-Za-z0-9_]*)/g;
    $s{$1} = 1 while $text =~ /([A-Za-z_][A-Za-z0-9_\x5c]*)::/g;
    my $n = 0;
    $n += length( $_ ) + 1 for keys %s;
    return $n;
}

sub strip_comments {
    my ( $text ) = @_;
    my @out;

    for my $line ( split /\n/, $text ) {
        my ( $code, $in_str, $i ) = ( '', 0, 0 );

        while ( $i < length $line ) {
            my $c = substr $line, $i, 1;
            last if !$in_str && substr( $line, $i, 2 ) eq '//';
            $in_str = !$in_str if $c eq '"';
            $code .= $c;
            $i++;
        }

        $code =~ s/\s+$//;
        push @out, $code if length $code;
    }

    return join "\n", @out;
}

sub qualify_calls {
    my ( $text, $map ) = @_;

    for my $fn ( keys %$map ) {
        my $space = $map->{$fn};
        $text =~ s/(?<![\w:\x5c])\Q$fn\E(\s*\()/$space\::$fn$1/g;
    }

    return $text;
}
