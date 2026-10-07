#!/usr/bin/perl
# Heartweaver: creates the subclass itself (ClassDescription, progression table, spell lists, skill list,
# the Arcana's SubClasses entries, two loca strings) on both sides -- game .lsx and Toolkit .tbl -- modelled
# on the Deceiver. Spec: Design/Rework/specs/2026-10-06-heartweaver-design.md (§6 progression; chassis
# decided by the user on 2026-10-06: WIS + CHA saves, light armour and caster weapons, Cleric sound set,
# empathy skill list). Idempotent: refuses to run twice. UUIDs and handles are deterministic.
#
#   perl heartweaver_subclass.pl            # shows what it would do
#   perl heartweaver_subclass.pl --apply    # writes (game and Toolkit closed)
use strict; use warnings;
use Digest::MD5 qw(md5_hex);
my $apply = grep { $_ eq '--apply' } @ARGV;
my $G = $ENV{BG3_DATA} // 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $M = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my %F = (
    cd_lsx => "$G/Public/$M/ClassDescriptions/ClassDescriptions.lsx", cd_tbl => "$G/Editor/Mods/$M/ClassDescriptions/ClassDescriptions.tbl",
    pr_lsx => "$G/Public/$M/Progressions/Progressions.lsx",           pr_tbl => "$G/Editor/Mods/$M/Progressions/Progressions.tbl",
    sl_lsx => "$G/Public/$M/Lists/SpellLists.lsx",                    sl_tbl => "$G/Editor/Mods/$M/Lists/SpellLists.tbl",
    kl_lsx => "$G/Public/$M/Lists/SkillLists.lsx",                    kl_tbl => "$G/Editor/Mods/$M/Lists/SkillLists.tbl",
    loca   => "$G/Mods/$M/Localization/English/english.xml",
);
sub uuid { my @h = unpack '(A4)8', md5_hex("arcana-heartweaver:" . shift); "$h[0]$h[1]-$h[2]-$h[3]-$h[4]-$h[5]$h[6]$h[7]" }
sub handle { my $h = md5_hex("arcana-heartweaver-loca:" . shift); 'h' . join 'g', substr($h,0,8), substr($h,8,4), substr($h,12,4), substr($h,16,4), substr($h,20,12) }

my $ARCANA   = '799a9fd7-f042-411a-80ae-a0eb46e7f829';
my $LAST_SUB = 'dc2e68d3-5577-4a9f-be4f-1a71707c1995';   # the last SubClass node today (Unbound)
my $CLASS    = uuid('class');
my $TABLE    = uuid('table');
my $SKILLS   = uuid('skills');
my %LIST     = map { $_ => uuid("list$_") } 1, 3, 5;
my $H_NAME   = handle('name');
my $H_DESC   = handle('desc');
my $CLERIC_TAG = '1671b4bf-4f47-4bb7-9cb9-80bb1f6009d5';   # vanilla Cleric class tag (Deceiver carries Bard's)
my $COLOR    = '#FF4B47C2';

my $NAME_TXT = 'Heartweaver';
my $DESC_TXT = "Mystra's empath reads every thread of feeling in the Weave and braids one emotion into another, until a single spark of fear or joy becomes something far stronger.";
my @SPELLS = (
    [1, 'Heartweaver Level 1', 'Target_Arcana_Card_Spell_EmotionJoy;Target_Arcana_Card_Spell_EmotionTrust;Target_Arcana_Card_Spell_EmotionFear'],
    [3, 'Heartweaver Level 3', 'Target_Arcana_Card_Spell_EmotionAnticipation;Target_Arcana_Card_Spell_EmotionSurprise;Target_Arcana_Card_Spell_EmotionSadness'],
    [5, 'Heartweaver Level 5', 'Target_Arcana_Card_Spell_EmotionDisgust;Target_Arcana_Card_Spell_EmotionAnger'],
);
my $SKILL_TXT = 'Insight, Persuasion, Medicine, Performance, Perception, Religion, AnimalHandling, Intimidation';
my $PROF = 'Proficiency(LightArmor);Proficiency(Daggers);Proficiency(Quarterstaffs);Proficiency(LightCrossbows);Proficiency(Darts)';
my $L1P  = 'Arcana_Passive_EmotionalAlchemy;Arcana_Passive_EmpathicSight';
my $ADD  = sub { "AddSpells($LIST{$_[0]},,,,AlwaysPrepared)" };

# [key, level, multiclass(undef = field absent), Boosts, PassivesAdded, Selectors]
my @ROWS = (
    ['l1',       1, 'false', "ProficiencyBonus(SavingThrow,Wisdom);ProficiencyBonus(SavingThrow,Charisma);$PROF", $L1P,
        "SelectAbilityBonus(b9149c8e-52c8-46e5-9cb6-fc39301c05fe,AbilityBonus,2,1);SelectSkills($SKILLS,4);SelectSkillsExpertise(f974ebd6-3725-4b90-bb5c-2b647d41615d,2);" . $ADD->(1)],
    ['l1multi',  1, 'true',  $PROF, $L1P, $ADD->(1)],
    (map { my $L = $_;
        [ "l$L", $L, undef, undef,
          { 5 => 'Arcana_Passive_ComplexFeelings', 7 => 'Arcana_Passive_Overwhelm', 9 => 'Arcana_Passive_MixedFeelings' }->{$L},
          ($L == 3 || $L == 5) ? $ADD->($L) : undef ] } 2 .. 20),
);

my (%txt, %orig);
for my $k (keys %F) { open my $h, '<:raw', $F{$k} or die "$F{$k}: $!"; local $/; $txt{$k} = <$h>; close $h; $orig{$k} = $txt{$k} }
die "Heartweaver already exists (ClassDescription $CLASS) -- nothing to do\n" if $txt{cd_lsx} =~ /\Q$CLASS\E/;

sub crlf { my ($k, $s) = @_; $orig{$k} =~ /\r\n/ ? ($s =~ s/\r?\n/\r\n/gr) : $s }
sub before_last { my ($k, $marker, $ins) = @_;   # insert $ins before the LAST occurrence of $marker
    my $i = rindex($txt{$k}, $marker); die "$k: marker not found\n" if $i < 0; substr($txt{$k}, $i, 0) = crlf($k, $ins) }

# ---- ClassDescription
before_last('cd_lsx', "            </children>\n        </node>\n    </region>", <<"X");
                <node id="ClassDescription">
                    <attribute id="CanLearnSpells" type="bool" value="true"/>
                    <attribute id="CharacterCreationPose" type="guid" value="0f07ec6e-4ef0-434e-9a51-1353260ccff8"/>
                    <attribute id="ClassEquipment" type="FixedString" value="EQP_CC_Deceiver"/>
                    <attribute id="Description" type="TranslatedString" handle="$H_DESC" version="1"/>
                    <attribute id="DisplayName" type="TranslatedString" handle="$H_NAME" version="1"/>
                    <attribute id="LearningStrategy" type="uint8" value="1"/>
                    <attribute id="MustPrepareSpells" type="bool" value="true"/>
                    <attribute id="Name" type="FixedString" value="Heartweaver"/>
                    <attribute id="ParentGuid" type="guid" value="$ARCANA"/>
                    <attribute id="ProgressionTableUUID" type="guid" value="$TABLE"/>
                    <attribute id="SoundClassType" type="FixedString" value="Cleric"/>
                    <attribute id="UUID" type="guid" value="$CLASS"/>
                    <children>
                        <node id="Tags">
                            <attribute id="Object" type="guid" value="$CLERIC_TAG"/>
                        </node>
                    </children>
                </node>
X
my $next_stat = sub { my $k = shift; my $n = -1; $n < $1 and $n = $1 while $txt{$k} =~ /value="New_Stat_(\d+)"/g; $n + 1 };
my $cdn = $next_stat->('cd_tbl');
before_last('cd_tbl', "  </stat_objects>", <<"X");
    <stat_object color="$COLOR" is_substat="false">
      <fields>
        <field name="Name" type="NameTableFieldDefinition" value="New_Stat_$cdn" />
        <field name="UUID" type="IdTableFieldDefinition" value="$CLASS" />
        <field name="ParentUUID" type="GuidObjectTableFieldDefinition" value="$ARCANA" />
        <field name="NameFS" type="FixedStringTableFieldDefinition" value="Heartweaver" />
        <field name="DisplayName" type="TranslatedStringTableFieldDefinition" handle="$H_NAME" version="1" />
        <field name="Description" type="TranslatedStringTableFieldDefinition" handle="$H_DESC" version="1" />
        <field name="ProgressionTableUUID" type="GuidTableFieldDefinition" value="$TABLE" />
        <field name="SoundClassType" type="FixedStringTableFieldDefinition" value="Cleric" />
        <field name="LearningStrategy" type="EnumerationTableFieldDefinition" value="AllChildren" enumeration_type_name="LearningStrategy" version="1" />
        <field name="ClassEquipment" type="FixedStringTableFieldDefinition" value="EQP_CC_Deceiver" />
        <field name="CharacterCreationPose" type="GuidTableFieldDefinition" value="0f07ec6e-4ef0-434e-9a51-1353260ccff8" />
        <field name="Tags" type="GuidObjectListTableFieldDefinition" value="$CLERIC_TAG" />
        <field name="MustPrepareSpells" type="BoolTableFieldDefinition" value="True" />
        <field name="CanLearnSpells" type="BoolTableFieldDefinition" value="True" />
      </fields>
    </stat_object>
X

# ---- Progression rows
my ($plsx, $ptbl) = ('', '');
my $pn = $next_stat->('pr_tbl');
for my $r (@ROWS) {
    my ($key, $L, $multi, $boosts, $pass, $sel) = @$r; my $u = uuid("row:$key");
    $plsx .= qq{                <node id="Progression">\n};
    $plsx .= qq{                    <attribute id="Boosts" type="LSString" value="$boosts"/>\n} if defined $boosts;
    $plsx .= qq{                    <attribute id="IsMulticlass" type="bool" value="$multi"/>\n} if defined $multi;
    $plsx .= qq{                    <attribute id="Level" type="uint8" value="$L"/>\n};
    $plsx .= qq{                    <attribute id="Name" type="LSString" value="Heartweaver"/>\n};
    $plsx .= qq{                    <attribute id="PassivesAdded" type="LSString" value="$pass"/>\n} if defined $pass;
    $plsx .= qq{                    <attribute id="ProgressionType" type="uint8" value="1"/>\n};
    $plsx .= qq{                    <attribute id="Selectors" type="LSString" value="$sel"/>\n} if defined $sel;
    $plsx .= qq{                    <attribute id="TableUUID" type="guid" value="$TABLE"/>\n};
    $plsx .= qq{                    <attribute id="UUID" type="guid" value="$u"/>\n                </node>\n};
    $ptbl .= qq{    <stat_object color="#FF000000" is_substat="false">\n      <fields>\n};
    $ptbl .= qq{        <field name="Name" type="NameTableFieldDefinition" value="New_Stat_} . $pn++ . qq{" />\n};
    $ptbl .= qq{        <field name="UUID" type="IdTableFieldDefinition" value="$u" />\n};
    $ptbl .= qq{        <field name="FSName" type="StringTableFieldDefinition" value="Heartweaver" />\n};
    $ptbl .= qq{        <field name="Level" type="ByteTableFieldDefinition" value="$L" />\n};
    $ptbl .= qq{        <field name="ProgressionType" type="ByteTableFieldDefinition" value="1" />\n};
    $ptbl .= qq{        <field name="TableUUID" type="GuidTableFieldDefinition" value="$TABLE" />\n};
    $ptbl .= qq{        <field name="Selectors" type="StringTableFieldDefinition" value="$sel" />\n} if defined $sel;
    $ptbl .= qq{        <field name="PassivesAdded" type="StringTableFieldDefinition" value="$pass" />\n} if defined $pass;
    $ptbl .= qq{        <field name="Boosts" type="StringTableFieldDefinition" value="$boosts" />\n} if defined $boosts;
    $ptbl .= qq{        <field name="IsMulticlass" type="BoolTableFieldDefinition" value="} . ($multi eq 'true' ? 'True' : 'False') . qq{" />\n} if defined $multi;
    $ptbl .= qq{      </fields>\n    </stat_object>\n};
}
before_last('pr_lsx', "            </children>\n        </node>\n    </region>", $plsx);
before_last('pr_tbl', "  </stat_objects>", $ptbl);

# ---- Arcana's SubClasses (both level-1 rows)
my $n = ($txt{pr_lsx} =~ s{(([ \t]*)<node id="SubClass">\s*<attribute id="Object" type="guid" value="\Q$LAST_SUB\E"/>\s*</node>)}
    { "$1\n$2<node id=\"SubClass\">\n$2    <attribute id=\"Object\" type=\"guid\" value=\"$CLASS\"/>\n$2</node>" }ge);
die "pr_lsx: expected 2 SubClasses nodes, found $n\n" unless $n == 2;
$n = ($txt{pr_tbl} =~ s{(<field name="SubClasses" type="GuidObjectListTableFieldDefinition" value="[^"]*)"}{$1;$CLASS"}g);
die "pr_tbl: expected 2 SubClasses fields, found $n\n" unless $n == 2;

# ---- Spell lists and skill list
for my $l (@SPELLS) { my ($L, $name, $spells) = @$l;
    before_last('sl_lsx', "            </children>\n        </node>\n    </region>", <<"X");
                <node id="SpellList">
                    <attribute id="Name" type="FixedString" value="$name"/>
                    <attribute id="Spells" type="LSString" value="$spells"/>
                    <attribute id="UUID" type="guid" value="$LIST{$L}"/>
                </node>
X
    before_last('sl_tbl', "  </stat_objects>", <<"X");
    <stat_object color="$COLOR" is_substat="false">
      <fields>
        <field name="UUID" type="IdTableFieldDefinition" value="$LIST{$L}" />
        <field name="Name" type="NameTableFieldDefinition" value="$name" />
        <field name="Spells" type="StringTableFieldDefinition" value="$spells" />
      </fields>
    </stat_object>
X
}
before_last('kl_lsx', "            </children>\n        </node>\n    </region>", <<"X");
                <node id="SkillList">
                    <attribute id="Name" type="FixedString" value="The Empath Skill List"/>
                    <attribute id="Skills" type="LSString" value="$SKILL_TXT"/>
                    <attribute id="UUID" type="guid" value="$SKILLS"/>
                </node>
X
before_last('kl_tbl', "  </stat_objects>", <<"X");
    <stat_object color="$COLOR" is_substat="false">
      <fields>
        <field name="UUID" type="IdTableFieldDefinition" value="$SKILLS" />
        <field name="Name" type="NameTableFieldDefinition" value="The Empath Skill List" />
        <field name="Skills" type="StringTableFieldDefinition" value="$SKILL_TXT" />
      </fields>
    </stat_object>
X

# ---- loca
(my $desc_xml = $DESC_TXT) =~ s/&/&amp;/g;
before_last('loca', "</contentList>", qq{  <content contentuid="$H_NAME" version="1">$NAME_TXT</content>\n  <content contentuid="$H_DESC" version="1">$desc_xml</content>\n});

# ---- report / write
printf "ClassDescription %s (table %s), skills %s, lists L1 %s L3 %s L5 %s\nhandles: name %s, desc %s\n",
    $CLASS, $TABLE, $SKILLS, @LIST{1,3,5}, $H_NAME, $H_DESC;
for my $k (sort keys %F) { printf "%-7s %+6d bytes  %s\n", $k, length($txt{$k}) - length($orig{$k}), $F{$k} }
if ($apply) { for my $k (keys %F) { open my $h, '>:raw', $F{$k} or die "$F{$k}: $!"; print $h $txt{$k}; close $h } print "written\n" }
else { print "(dry run -- use --apply to write)\n" }
