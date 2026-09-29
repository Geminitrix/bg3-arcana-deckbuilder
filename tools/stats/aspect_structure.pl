#!/usr/bin/perl
# Despertar do Aspecto: passivas de tier nas progressoes (e saida dos capstones do nivel 20), magias nas
# listas de nivel 7 e 13, e os dois recursos por turno (Fool's Luck, Beloved). Lado jogo (.lsx) e lado
# Toolkit (.tbl) sempre juntos. Idempotente.
#
#   perl aspect_structure.pl            # mostra o que faria
#   perl aspect_structure.pl --apply    # grava (jogo e Toolkit fechados)
use strict; use warnings;
use Digest::MD5 qw(md5_hex);
my $apply = grep { $_ eq '--apply' } @ARGV;
my $G = $ENV{BG3_DATA} // 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $M = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my %F = (
    plsx => "$G/Public/$M/Progressions/Progressions.lsx",
    ptbl => "$G/Editor/Mods/$M/Progressions/Progressions.tbl",
    llsx => "$G/Public/$M/Lists/SpellLists.lsx",
    ltbl => "$G/Editor/Mods/$M/Lists/SpellLists.tbl",
    rlsx => "$G/Public/$M/ActionResourceDefinitions/ActionResourceDefinitions.lsx",
    rtbl => "$G/Editor/Mods/$M/ActionResourceDefinitions/ActionResourceDefinitions.tbl",
);
# linha da progressao (UUID) => [passivas a acrescentar], [passivas a tirar]
# Tiers nos niveis 3 / 7 / 12 (decisao do usuario em 2026-09-29, para quem joga ate o 12); ate entao eram
# 3 / 9 / 17, e as linhas de 9 e 17 ficam aqui so para tirar as passivas de la.
my %prog = (
    'fb53cf40-4c7a-4130-9b21-6f42fb58cb1c' => [['Arcana_Passive_Aspect_Fool_I'], []],        # Unbound 3
    'd67189a0-6e3b-4800-8155-6295ea2a8158' => [['Arcana_Passive_Aspect_Fool_II'], []],       # Unbound 7
    '1e8fdfd5-879c-455b-a5bd-0a52c7ea5dd9' => [[], ['Arcana_Passive_Aspect_Fool_II']],       # Unbound 9
    '207f9358-88f8-4c28-a7e5-4cbc5b528cc3' => [['Arcana_Passive_Aspect_Fool_III'], []],      # Unbound 12
    'f654f991-a4b7-452b-96b1-57029a496eb6' => [[], ['Arcana_Passive_Aspect_Fool_III']],      # Unbound 17
    'd33bb4ba-8201-4993-a418-8c697850a2a1' => [[], [qw(Arcana_Passive_TheFool_EX Arcana_Passive_TheFool_EX_Tech)]],
    '8e9c09c9-9390-4c6f-9d49-0585c4ec842a' => [['Arcana_Passive_Aspect_Empress_I'], []],     # Deceiver 3
    'd355f68d-767d-42ed-81c6-b7c63e01d7f8' => [['Arcana_Passive_Aspect_Empress_II'], []],    # Deceiver 7
    '3ce373b9-deb5-4c79-8592-0fe462f524fb' => [[], ['Arcana_Passive_Aspect_Empress_II']],    # Deceiver 9
    'dd366005-9385-440c-9515-5363933908c8' => [['Arcana_Passive_Aspect_Empress_III'], []],   # Deceiver 12
    '678e0915-e01b-46c2-8636-20d3e62ad121' => [[], ['Arcana_Passive_Aspect_Empress_III']],   # Deceiver 17
    '2c4887f9-d4f8-4a95-974c-519643440029' => [[], [qw(Arcana_Passive_TheEmpress_EX Arcana_Passive_TheEmpress_EX_Tech_I Arcana_Passive_TheEmpress_EX_Tech_II Arcana_Passive_TheEmpress_EX_Unlock)]],
    'b5d65203-1e22-4ae6-874b-01a1721ccda1' => [['Arcana_Passive_Aspect_Star_I'], []],        # Starchild 3
    '124e876a-062b-4c9a-a7e5-161ae3aeda96' => [['Arcana_Passive_Aspect_Star_II'], []],       # Starchild 7
    '293b4c11-0e14-44ce-a47a-ce3eee94ae88' => [[], ['Arcana_Passive_Aspect_Star_II']],       # Starchild 9
    'a78eaf69-9b36-4014-b00c-04665b240129' => [['Arcana_Passive_Aspect_Star_III'], []],      # Starchild 12
    '4e960d48-8a90-4605-8f27-dd5152989df7' => [[], ['Arcana_Passive_Aspect_Star_III']],      # Starchild 17
    '60e3e094-10e1-4d36-9f12-f368dad72f47' => [[], [qw(Arcana_Passive_TheStar_EX Arcana_Passive_TheStar_EX_Tech Arcana_Passive_TheStar_EX_Unlock)]],
    '0fe06ade-94c1-4618-9abe-4fe8e204ed7d' => [['Arcana_Passive_Aspect_Death_I'], []],       # Eternal 3
    'fca3a169-ac9f-4845-82bc-8c0a6683aa24' => [['Arcana_Passive_Aspect_Death_II'], []],      # Eternal 7
    'b66c5349-7135-4c4a-a568-5aa4e233f656' => [[], ['Arcana_Passive_Aspect_Death_II']],      # Eternal 9
    'a7c619e4-879d-417d-a811-f2c78243cd6e' => [['Arcana_Passive_Aspect_Death_III'], []],     # Eternal 12
    'b965d74f-79bb-40dd-be0f-fb4d8d9e3f30' => [[], ['Arcana_Passive_Aspect_Death_III']],     # Eternal 17
    '8ba69d3c-9e0e-4a78-9637-8466e41314d2' => [[], [qw(Arcana_Passive_Death_EX Arcana_Passive_Death_EX_Unlock)]],
);
my %lists = (
    '6cc7bce7-943c-4b5c-b4b4-e5144917adf1' => [['Shout_Arcana_Card_Spell_BloodOffering'], ['Shout_Arcana_Card_Passive_DarknessRise']], # Eternal 7
    '8abac308-3262-4ce8-99c2-3d3e9c6ba42e' => [['Shout_Arcana_Card_Spell_HowlOfTheDead'], []],   # Eternal 13
    '4657a3f6-e7f5-4ac4-b5c4-c0665adcb36d' => [['Target_Arcana_Util_Friends_EX'], []],            # Deceiver 13
);
my @resources = qw(ArcanaFoolsLuck ArcanaBeloved);   # ReplenishType Turn, ocultos

my (%txt, %crlf, %bom, @log);
for my $k (keys %F) { open my $fh, '<:raw', $F{$k} or die "$F{$k}: $!"; local $/; my $s = <$fh>;
    $bom{$k} = ($s =~ s/^\xEF\xBB\xBF//) ? 1 : 0; $crlf{$k} = ($s =~ /\r\n/) ? 1 : 0; $s =~ s/\r\n/\n/g; $txt{$k} = $s }
sub uuid { my @h = unpack '(A4)8', md5_hex("arcana-aspect-resource:" . shift); "$h[0]$h[1]-$h[2]-$h[3]-$h[4]-$h[5]$h[6]$h[7]" }
sub merge { my ($cur, $add, $del) = @_; my %d = map { $_ => 1 } @$del;
    my @out = grep { length && !$d{$_} } split /;/, ($cur // ''); my %have = map { $_ => 1 } @out;
    push @out, grep { !$have{$_}++ } @$add; join ';', @out }

# --- progressoes, lado jogo: o atributo UUID e o ultimo do no (ordem alfabetica) ---
for my $u (sort keys %prog) { my ($add, $del) = @{$prog{$u}};
    $txt{plsx} =~ s{(<node id="Progression">\n(?:(?!</node>).)*?<attribute id="UUID" type="guid" value="\Q$u\E"/>\n\s*</node>)}{
        my $n = $1; my ($cur) = $n =~ /<attribute id="PassivesAdded" type="LSString" value="([^"]*)"\/>/;
        my $new = merge($cur, $add, $del);
        if (defined $cur) { if (length $new) { $n =~ s/(<attribute id="PassivesAdded" type="LSString" value=")[^"]*/$1$new/ }
                            else { $n =~ s/\n[ \t]*<attribute id="PassivesAdded" type="LSString" value="[^"]*"\/>// } }
        elsif (length $new) { $n =~ s/(\n([ \t]*)<attribute id="Name" type="LSString" value="[^"]*"\/>)/$1\n$2<attribute id="PassivesAdded" type="LSString" value="$new"\/>/ }
        push @log, "plsx $u: " . ($cur // '(nada)') . " -> $new"; $n }se or die "progressao $u nao achada no .lsx\n" }
# --- progressoes, lado Toolkit ---
for my $u (sort keys %prog) { my ($add, $del) = @{$prog{$u}};
    $txt{ptbl} =~ s{(<stat_object\b(?:(?!</stat_object>).)*?<field name="UUID" type="IdTableFieldDefinition" value="\Q$u\E" />.*?</stat_object>)}{
        my $o = $1; my ($cur) = $o =~ /<field name="PassivesAdded" type="StringTableFieldDefinition" value="([^"]*)" \/>/;
        my $new = merge($cur, $add, $del);
        if (defined $cur) { if (length $new) { $o =~ s/(<field name="PassivesAdded" type="StringTableFieldDefinition" value=")[^"]*/$1$new/ }
                            else { $o =~ s/\n[ \t]*<field name="PassivesAdded" type="StringTableFieldDefinition" value="[^"]*" \/>// } }
        elsif (length $new) { $o =~ s/(\n([ \t]*)<field name="ProgressionType" [^\n]*\/>)/$1\n$2<field name="PassivesAdded" type="StringTableFieldDefinition" value="$new" \/>/ }
        push @log, "ptbl $u: " . ($cur // '(nada)') . " -> $new"; $o }se or die "progressao $u nao achada no .tbl\n" }
# --- listas ---
for my $u (sort keys %lists) { my ($add, $del) = @{$lists{$u}};
    $txt{llsx} =~ s{(<attribute id="Spells" type="LSString" value=")([^"]*)("/>\n\s*<attribute id="UUID" type="guid" value="\Q$u\E"/>)}{ my $n = merge($2, $add, $del); push @log, "llsx $u: $2 -> $n"; "$1$n$3" }e
        or die "lista $u nao achada no .lsx\n";
    $txt{ltbl} =~ s{(value="\Q$u\E" />(?:(?!</stat_object>).)*?<field name="Spells" type="StringTableFieldDefinition" value=")([^"]*)}{ my $n = merge($2, $add, $del); push @log, "ltbl $u: $2 -> $n"; "$1$n" }se
        or die "lista $u nao achada no .tbl\n" }
# --- recursos ---
for my $r (@resources) { my $id = uuid($r);
    if ($txt{rlsx} !~ /value="\Q$r\E"/) {
        $txt{rlsx} =~ s{(\n([ \t]*)<node id="ActionResourceDefinition">)}{\n$2<node id="ActionResourceDefinition">\n$2    <attribute id="IsHidden" type="bool" value="true"/>\n$2    <attribute id="Name" type="FixedString" value="$r"/>\n$2    <attribute id="ReplenishType" type="FixedString" value="Turn"/>\n$2    <attribute id="UUID" type="guid" value="$id"/>\n$2</node>$1} or die "sem ActionResourceDefinition no .lsx\n";
        push @log, "rlsx + $r ($id)" }
    if ($txt{rtbl} !~ /value="\Q$r\E"/) {
        my $obj = qq{    <stat_object is_substat="false">\n      <fields>\n        <field name="Name" type="NameTableFieldDefinition" value="$r" />\n        <field name="UUID" type="IdTableFieldDefinition" value="$id" />\n        <field name="NameFS" type="FixedStringTableFieldDefinition" value="$r" />\n        <field name="ReplenishType" type="FixedStringTableFieldDefinition" value="Turn" />\n        <field name="IsHidden" type="BoolTableFieldDefinition" value="True" />\n      </fields>\n    </stat_object>\n};
        $txt{rtbl} =~ s{(\s*</stat_objects>)}{\n$obj$1} or die "sem </stat_objects> no .tbl\n";
        push @log, "rtbl + $r ($id)" } }

print "$_\n" for @log;
if ($apply) { for my $k (keys %F) { my $s = $txt{$k}; $s =~ s/\n/\r\n/g if $crlf{$k}; $s = "\xEF\xBB\xBF$s" if $bom{$k};
        open my $fh, '>:raw', $F{$k} or die $!; print $fh $s; close $fh } print "gravado.\n" }
else { print "(simulacao -- rode com --apply para gravar)\n" }
