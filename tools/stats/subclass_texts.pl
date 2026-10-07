#!/usr/bin/perl
# One voice for the subclasses (2026-10-07): the class description, the SUBCLASSES panel line and the tag line of every
# Arcana subclass, written as if by the same hand -- Mystra, the Weave and each one's Major Arcanum. Also gives the
# Heartweaver its ProgressionDescription (what the character creation reads to list a subclass's proficiencies) and
# rewrites the shared warning every Weave Surge shows (TooltipExtraTexts 70aa3de3...).
#
#   perl subclass_texts.pl            # shows what would change
#   perl subclass_texts.pl --apply    # writes (game AND Toolkit closed)
#
# Existing handles keep their id: the text changes and the version goes up by one in english.xml and in every file
# that cites the handle (ClassDescriptions, ProgressionDescriptions, TooltipExtraTexts, Tags). Tags are .lsf: they go
# through Divine (lsf -> lsx -> lsf). Running it twice changes nothing.
use strict; use warnings;
use Digest::MD5 qw(md5_hex);
use File::Temp qw(tempdir);

my $G = $ENV{BG3_DATA} // 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $M = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my $DIVINE = 'C:/Softwares/ExportTool/Packed/Tools/Divine.exe';
my $apply = grep { $_ eq '--apply' } @ARGV;

my $LOCA = "$G/Mods/$M/Localization/English/english.xml";
my @CITING = map { "$G/$_" } (
    "Public/$M/ClassDescriptions/ClassDescriptions.lsx",         "Editor/Mods/$M/ClassDescriptions/ClassDescriptions.tbl",
    "Public/$M/Progressions/ProgressionDescriptions.lsx",        "Editor/Mods/$M/Progressions/ProgressionDescriptions.tbl",
    "Public/$M/TooltipExtras/TooltipExtraTexts.lsx",             "Editor/Mods/$M/TooltipExtras/TooltipExtraTexts.tbl");
my $TAGS = "$G/Public/$M/Tags";

# handle => [where, text]
my @TEXT = (
    # ClassDescription (character creation)
    [hf756bce1g79bag5985ga624gb4cc6e843978 => 'Unbound class', "Mystra wove the Unbound from the first step of every journey, a thread that answers only to curiosity and the open road. They wear no armour and strike with open hands and moving air, slipping past every blow until the ground itself stops holding them down."],
    [hcf1e5160g3e20g0953g6e16gd8b38b0e15f7 => 'Deceiver class', "Mystra wove the Deceiver from the veil between what is and what seems, a thread that no one watching can follow. They scatter Doubles that shatter when struck, sow Doubt until enemies can't trust their own eyes, and bind them with Sigils and chains."],
    [h759e0860g058eg3b3cg9db9g676e24da5bbc => 'Starchild class', "Mystra wove the Starchild from the light that remains after disaster, a thread of hope that never stops shining. They mend wounds that should have been fatal, shelter their allies beneath solar and lunar wards, and call the fallen back from the edge of death."],
    [h9f0b264cgfbe5g9544g296dg0d621ef7d5a0 => 'Eternal class', "Mystra wove the Eternal from an ending they refused to accept, a thread that crossed death and came back changed. They take the blows meant for others and grow harder to kill for it, draining the life from their foes and calling the grave to finish what their hammer began."],
    [h39d6214cg3283g6e70g879fg48b1471b7f07 => 'Heartweaver class', "Mystra wove the Heartweaver from the feelings that pass between every living thing, a thread that tempers one emotion with another. They surge joy, trust or fear into a creature's Weave, then braid what lingers into stronger feelings that lift allies and break enemies from within."],
    # ProgressionDescription (the SUBCLASSES panel)
    [h9a3184f7g73a8g6169g04a6g6dc398547d7f => 'Unbound panel', "The Unbound follows the Weave into the unknown, striking with open hands and moving air and never standing where an enemy expects."],
    [h8b19f5f0ge250g11dag5e72ge061bcb595b7 => 'Deceiver panel', "The Deceiver walks the veil of the Weave, scattering Doubles and sowing Doubt until no enemy can tell which of them is real."],
    [h954ca604g57b2g3440gdfb5g59a0b3091dd5 => 'Starchild panel', "The Starchild carries the light of the Weave after every fall, mending wounds and sheltering allies beneath solar and lunar wards."],
    [h0dae60d6g9f46g25a0gcb51g715871fe028c => 'Eternal panel', "The Eternal holds the Weave where life gives way to death, enduring every wound and turning its own pain into strength."],
    # Tags (DisplayDescription). The Heartweaver's tag line is the model and stays as it is.
    [h6aff0d51g6aa0g755egd26eg75d9f3248133 => 'Arcana tag', "We were chosen by the Lady of Mysteries, and the Weave answers when we pull on its threads."],
    [h65e864dfg6fabg0d32gef8bgf8558787ab9c => 'Unbound tag', "We leap before we look, and the Weave catches us wherever we land."],
    [hc27cd946g92a0g2987g3dd1g84ed4d9cc824 => 'Deceiver tag', "We keep the veil between what is and what seems, and the Weave lets us stand on either side of it."],
    [hde71b0a3gc617gb8d2ga14fgb29bea7aa3d7 => 'Starchild tag', "We keep a light burning after every fall, and the Weave lets us pour it into the wounded."],
    [h4d8e58d1g9816g64c0geebag689df505140a => 'Eternal tag', "We have crossed our own ending, and the Weave turns every wound we take into strength."],
    # The warning on every Weave Surge (gen_emotion_alchemy.pl, $SURGE_WARNING)
    [h40f84675gd665g2edcg95ffga40feba3891b => 'Surge warning', '<LSTag Type="Image" Info="SoftWarning"/> If the target already carries a mood, this surge reacts with it through <LSTag Type="Passive" Tooltip="Arcana_Passive_EmotionalAlchemy">Emotional Alchemy</LSTag> instead, and the mood is spent.'],
);

# The Heartweaver's line in the SUBCLASSES panel (new)
sub det_uuid   { my @h = unpack '(A4)8', md5_hex("arcana-heartweaver:" . shift); "$h[0]$h[1]-$h[2]-$h[3]-$h[4]-$h[5]$h[6]$h[7]" }
sub det_handle { my @h = unpack '(A4)8', md5_hex("arcana-heartweaver-loca:" . shift); "h$h[0]$h[1]g$h[2]g$h[3]g$h[4]g$h[5]$h[6]$h[7]" }
my $HW_TABLE = '62727cb1-9114-ffbf-7fdb-51e28f73bd0f';
my $HW_PD    = det_uuid('progression_description');
my $HW_PD_NAME = det_handle('progression_description_name');
my $HW_PD_DESC = det_handle('progression_description_desc');
my %NEW_TEXT = ($HW_PD_NAME => 'The Heartweaver',
    $HW_PD_DESC => "The Heartweaver tempers one feeling of the Weave with another, surging emotions into creatures and braiding what lingers into stronger feelings.");

# ---------- io (keeps BOM and line endings)
sub slurp { my $p = shift; open my $h, '<:raw', $p or die "$p: $!"; local $/; my $s = <$h>; close $h; $s }
sub spew  { my ($p, $s) = @_; open my $h, '>:raw', $p or die "$p: $!"; print $h $s; close $h }
sub eol   { $_[0] =~ /\r\n/ ? "\r\n" : "\n" }
sub esc   { my $t = shift; $t =~ s/&(?!(?:amp|lt|gt|quot|apos);)/&amp;/g; $t =~ s/</&lt;/g; $t =~ s/>/&gt;/g; $t }

my (@log, %out, %bumped);
my $loca = slurp($LOCA); my $nl = eol($loca);

# ---------- english.xml
for my $t (@TEXT) {
    my ($h, $where, $text) = @$t;
    my $e = esc($text);
    $loca =~ /<content contentuid="\Q$h\E" version="(\d+)">(.*?)<\/content>/ or die "$where: $h not in english.xml\n";
    my ($v, $old) = ($1, $2);
    next if $old eq $e;
    my $nv = $v + 1;
    $loca =~ s/<content contentuid="\Q$h\E" version="\d+">.*?<\/content>/<content contentuid="$h" version="$nv">$e<\/content>/;
    $bumped{$h} = $nv; push @log, "loca ~ $where ($h;$nv)";
}
for my $h (sort keys %NEW_TEXT) {
    next if $loca =~ /contentuid="\Q$h\E"/;
    my $e = esc($NEW_TEXT{$h});
    $loca =~ s{(\r?\n?</contentList>)}{$nl  <content contentuid="$h" version="1">$e</content>$1} or die "no </contentList>\n";
    push @log, "loca + $h $NEW_TEXT{$h}";
}
$out{$LOCA} = $loca if $loca ne slurp($LOCA);

# ---------- files that cite a bumped handle (lsx: version="N"/>, tbl: version="N" />)
for my $f (@CITING) {
    my $s = $out{$f} // slurp($f); my $o = $s;
    for my $h (keys %bumped) { $s =~ s/handle="\Q$h\E" version="\d+"/handle="$h" version="$bumped{$h}"/g }
    if ($s ne $o) { $out{$f} = $s; push @log, "version ~ $f" }
}

# ---------- the Heartweaver's ProgressionDescription (after the Eternal's, both sides)
{
    my $f = "$G/Public/$M/Progressions/ProgressionDescriptions.lsx"; my $s = $out{$f} // slurp($f); my $n = eol($s);
    unless ($s =~ /\Q$HW_PD\E/) {
        my $node = join $n, '                <node id="ProgressionDescription">',
            qq{                    <attribute id="Description" type="TranslatedString" handle="$HW_PD_DESC" version="1"/>},
            qq{                    <attribute id="DisplayName" type="TranslatedString" handle="$HW_PD_NAME" version="1"/>},
            qq{                    <attribute id="ProgressionTableId" type="guid" value="$HW_TABLE"/>},
            qq{                    <attribute id="Type" type="FixedString" value="Heartweaver"/>},
            qq{                    <attribute id="UUID" type="guid" value="$HW_PD"/>},
            '                </node>', '';
        $s =~ s{(<attribute id="UUID" type="guid" value="f21ac0a6-141d-4620-a411-555952da764e"/>\r?\n\s*</node>\r?\n)}{$1$node} or die "lsx: Eternal node not found\n";
        $out{$f} = $s; push @log, "lsx + ProgressionDescription Heartweaver $HW_PD";
    }
    $f = "$G/Editor/Mods/$M/Progressions/ProgressionDescriptions.tbl"; $s = $out{$f} // slurp($f); $n = eol($s);
    unless ($s =~ /\Q$HW_PD\E/) {
        my $obj = join $n, '    <stat_object color="#00FFFFFF" is_substat="false">', '      <fields>',
            '        <field name="Name" type="NameTableFieldDefinition" value="New_Stat_Heartweaver" />',
            qq{        <field name="UUID" type="IdTableFieldDefinition" value="$HW_PD" />},
            qq{        <field name="DisplayName" type="TranslatedStringTableFieldDefinition" handle="$HW_PD_NAME" version="1" />},
            qq{        <field name="Description" type="TranslatedStringTableFieldDefinition" handle="$HW_PD_DESC" version="1" />},
            '        <field name="Type" type="FixedStringTableFieldDefinition" value="Heartweaver" />',
            qq{        <field name="ProgressionTableId" type="GuidTableFieldDefinition" value="$HW_TABLE" />},
            '      </fields>', '    </stat_object>', '';
        $s =~ s{(value="f21ac0a6-141d-4620-a411-555952da764e" />.*?</stat_object>\r?\n)}{$1$obj}s or die "tbl: Eternal object not found\n";
        $out{$f} = $s; push @log, "tbl + ProgressionDescription Heartweaver $HW_PD";
    }
}

# ---------- tags (.lsf through Divine)
my %tag_lsf;   # lsf path => new lsx text
my $tmp = tempdir(CLEANUP => 1);
opendir my $td, $TAGS or die "$TAGS: $!";
my @tag_files = map { "$TAGS/$_" } sort grep { /\.lsf$/ } readdir $td;   # not glob: the path has spaces
closedir $td;
for my $lsf (@tag_files) {
    my @hs = grep { $bumped{$_} } keys %bumped; next unless @hs;
    (my $base = $lsf) =~ s{.*/}{}; my $lsx = "$tmp/$base.lsx";
    system($DIVINE, '-g', 'bg3', '-a', 'convert-resource', '-s', $lsf, '-d', $lsx) == 0 or die "Divine failed on $lsf\n";
    my $s = slurp($lsx); my $o = $s;
    for my $h (@hs) { $s =~ s/handle="\Q$h\E" version="\d+"/handle="$h" version="$bumped{$h}"/g }
    next if $s eq $o;
    $tag_lsf{$lsf} = $s; push @log, "tag ~ $base";
}

print "$_\n" for @log;
print "(nothing to do)\n" unless @log;
if ($apply) {
    spew($_, $out{$_}) for keys %out;
    for my $lsf (keys %tag_lsf) {
        (my $base = $lsf) =~ s{.*/}{};
        my ($lsx, $new, $back) = ("$tmp/$base.new.lsx", "$tmp/$base.new.lsf", "$tmp/$base.check.lsx");
        spew($lsx, $tag_lsf{$lsf});
        system($DIVINE, '-g', 'bg3', '-a', 'convert-resource', '-s', $lsx, '-d', $new) == 0 or die "Divine failed on $lsx\n";
        system($DIVINE, '-g', 'bg3', '-a', 'convert-resource', '-s', $new, '-d', $back) == 0 or die "Divine failed on $new\n";
        (my $a = $tag_lsf{$lsf}) =~ s/<version[^>]*>//; (my $b = slurp($back)) =~ s/<version[^>]*>//;
        $a eq $b or die "$base: round trip differs, tag left untouched\n";
        spew($lsf, slurp($new));
    }
    print "written.\n";
} else { print "(dry run -- add --apply to write)\n" }
