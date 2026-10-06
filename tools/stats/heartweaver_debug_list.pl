#!/usr/bin/perl
# Heartweaver, before the subclass exists: puts the 8 Weave Surges and [DEBUG] Heartweaver Passives on the
# "Arcana Deck DEBUG" list (class level 1), on both sides -- SpellLists.lsx (game) and SpellLists.tbl (Toolkit).
# Idempotent. Plan 2 (the subclass) takes the Surges off again and keeps only the DEBUG utility.
#
#   perl heartweaver_debug_list.pl            # shows what it would do
#   perl heartweaver_debug_list.pl --apply    # writes (game and Toolkit closed)
#   perl heartweaver_debug_list.pl --remove-surges [--apply]   # (plan 2) takes the Surges off, keeps the utility
use strict; use warnings;
my $apply  = grep { $_ eq '--apply' } @ARGV;
my $remove = grep { $_ eq '--remove-surges' } @ARGV;
my $G = $ENV{BG3_DATA} // 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $M = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my $LIST = 'f2e5e2e9-42c8-4f0e-88de-830ef0224290';   # Arcana Deck DEBUG
my %F = (lsx => "$G/Public/$M/Lists/SpellLists.lsx", tbl => "$G/Editor/Mods/$M/Lists/SpellLists.tbl");
my @SURGES = map { "Target_Arcana_Card_Spell_Emotion$_" } qw(Joy Trust Fear Surprise Sadness Disgust Anger Anticipation);
my @ADD = $remove ? () : (@SURGES, 'Shout_Arcana_Util_DEBUG_Heartweaver');
my @DEL = $remove ? @SURGES : ();

sub merge { my $cur = shift; my @s = grep { length } split /;/, $cur; my %del = map { $_ => 1 } @DEL;
    @s = grep { !$del{$_} } @s; my %have = map { $_ => 1 } @s; push @s, grep { !$have{$_} } @ADD; join ';', @s }

my %txt; my %orig;
for my $k (keys %F) { open my $h, '<:raw', $F{$k} or die "$F{$k}: $!"; local $/; $txt{$k} = <$h>; close $h; $orig{$k} = $txt{$k} }
my $n = 0;
$n += $txt{lsx} =~ s{(<attribute id="Spells" type="LSString" value=")([^"]*)("/>\s*<attribute id="UUID" type="guid" value="\Q$LIST\E"/>)}{ "$1" . merge($2) . "$3" }e;
$n += $txt{tbl} =~ s{(value="\Q$LIST\E" />(?:(?!</stat_object>).)*?<field name="Spells" type="StringTableFieldDefinition" value=")([^"]*)}{ "$1" . merge($2) }se;
die "list $LIST not found in both files ($n of 2)\n" unless $n == 2;
for my $k (sort keys %F) {
    my ($v) = $k eq 'lsx' ? $txt{$k} =~ /value="([^"]*)"\/>\s*<attribute id="UUID" type="guid" value="\Q$LIST\E"/
                          : $txt{$k} =~ /value="\Q$LIST\E" \/>(?:(?!<\/stat_object>).)*?<field name="Spells" type="StringTableFieldDefinition" value="([^"]*)"/s;
    printf "%s %s: %s\n", ($txt{$k} eq $orig{$k} ? '=' : '~'), $k, $v;
}
if ($apply) { for my $k (keys %F) { next if $txt{$k} eq $orig{$k}; open my $h, '>:raw', $F{$k} or die "$F{$k}: $!"; print $h $txt{$k}; close $h } print "written\n" }
else { print "(dry run -- use --apply to write)\n" }