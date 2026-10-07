#!/usr/bin/perl
# Tests for the Emotional Alchemy generator.   perl t/gen_emotion_alchemy.t   (`prove` does not run on this Perl)
use strict; use warnings; no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
require(abs_path(dirname(__FILE__)) . '/../gen_emotion_alchemy.pl');

my @W = @Alchemy::WHEEL;

# ---- the wheel
is(Alchemy::distance('Joy', 'Joy'), 0, 'same emotion: 0');
is(Alchemy::distance('Joy', 'Trust'), 1, 'neighbours: 1');
is(Alchemy::distance('Joy', 'Anticipation'), 1, 'the wheel wraps: Anticipation neighbours Joy');
is(Alchemy::distance('Joy', 'Fear'), 2, 'two steps: 2');
is(Alchemy::distance('Joy', 'Surprise'), 3, 'three steps: 3');
is(Alchemy::distance('Joy', 'Sadness'), 4, 'opposites: 4');
for my $x (@W) { for my $y (@W) {
    is(Alchemy::distance($x, $y), Alchemy::distance($y, $x), "symmetric $x/$y") if $x lt $y } }
my %opp = (Joy => 'Sadness', Trust => 'Disgust', Fear => 'Anger', Surprise => 'Anticipation');
is(Alchemy::distance($_, $opp{$_}), 4, "Plutchik: $_ opposes $opp{$_}") for sort keys %opp;

# ---- Plutchik's 24 dyads, each at the right distance
my %plutchik = (
    1 => [qw(Love Submission Awe Disapproval Remorse Contempt Aggressiveness Optimism)],
    2 => [qw(Hope Guilt Curiosity Despair Unbelief Envy Cynicism Pride)],
    3 => [qw(Delight Sentimentality Shame Outrage Pessimism Morbidness Dominance Anxiety)],
);
my %have;
for my $k (sort keys %Alchemy::FEELING) {
    my ($x, $y) = split /\+/, $k;
    push @{ $have{ Alchemy::distance($x, $y) } }, $Alchemy::FEELING{$k}{name};
    is($k, Alchemy::pair($x, $y), "key $k in wheel order");
}
is_deeply([sort @{ $have{$_} }], [sort @{ $plutchik{$_} }], "dyads at distance $_") for 1 .. 3;
is(scalar keys %Alchemy::FEELING, 24, '24 dyads');
for my $x (@W) { for my $y (@W) { next unless $x lt $y; my $d = Alchemy::distance($x, $y);
    next if $d == 0 || $d == 4;
    ok(Alchemy::feeling_of($x, $y), "a Feeling exists for $x+$y") } }

# ---- the 8x8 reaction matrix
for my $s (@W) { for my $m (@W) {
    my $r = Alchemy::reaction($s, $m); my $d = Alchemy::distance($s, $m);
    my $want = $d == 0 ? 'intensify' : $d == 4 ? 'catharsis' : 'feeling';
    is($r->{kind}, $want, "$s on a $m mood: $want");
    is($r->{gate}, $Alchemy::GATE{$d}, "$s/$m: right gate");
} }
is(Alchemy::reaction('Fear', 'Trust')->{status}, 'FEELING_SUBMISSION', 'Fear + Accepting = Submission');
is(Alchemy::reaction('Trust', 'Fear')->{status}, 'FEELING_SUBMISSION', 'Trust + Apprehensive = Submission');
is(Alchemy::reaction('Fear', 'Fear')->{status}, 'EMOTION_TERROR', 'Fear + Apprehensive = Terror');
is(Alchemy::reaction('Fear', 'Anger')->{status}, 'CATHARSIS', 'Fear + Annoyed = Catharsis');

# ---- SpellSuccess
my $ss = Alchemy::spell_success('Fear');
my @f = split /;(?=IF\()/, $ss;
like($f[0], qr/^IF\(not \(/, 'first functor: the no-reaction case (risk R1)');
like($f[0], qr/:ApplyStatus\(EMOTION_FEAR,100,1\)$/, 'the no-reaction case applies the peak');
is(scalar(() = $f[0] =~ /HasStatus\('MOOD_/g), 8, 'the no-reaction case checks all 8 moods');
like($ss, qr/IF\(HasStatus\('MOOD_ACCEPTING'\)\):ApplyStatus\(FEELING_SUBMISSION,100,2\)/, 'primary: no gate, 2 turns');
like($ss, qr/IF\(HasStatus\('MOOD_SERENE'\) and HasPassive\('Arcana_Passive_ComplexFeelings', context\.Source\)\):ApplyStatus\(FEELING_GUILT,100,2\)/, 'secondary: gated');
like($ss, qr/IF\(HasStatus\('MOOD_INTERESTED'\) and HasPassive\('Arcana_Passive_MixedFeelings', context\.Source\)\):ApplyStatus\(FEELING_ANXIETY,100,2\)/, 'tertiary: gated');
like($ss, qr/IF\(HasStatus\('MOOD_APPREHENSIVE'\) and HasPassive\('Arcana_Passive_Overwhelm', context\.Source\)\):ApplyStatus\(EMOTION_TERROR,100,1\)/, 'intense: gated, 1 turn');
like($ss, qr/IF\(HasStatus\('MOOD_ANNOYED'\) and not Ally\(\) and not Self\(\)\):DealDamage\(2d8,Psychic,Magical\)/, 'Catharsis harms a non-ally');
like($ss, qr/IF\(HasStatus\('MOOD_ANNOYED'\) and \(Ally\(\) or Self\(\)\)\):RegainHitPoints\(2d8\)/, 'Catharsis heals an ally');
like($ss, qr/ApplyStatus\(CATHARSIS,100,0\)$/, 'the CATHARSIS status (which clears the moods) comes last');
for my $s (@W) {
    my $x = Alchemy::spell_success($s);
    is(scalar(() = $x =~ /IF\(/g), 1 + 7 + 3, "$s: 1 base case + 7 reactions + 3 Catharsis functors");
}

# ---- targeting
like(Alchemy::target_conditions('Fear'), qr/not HasPassive\('ARCANA_IS_CARD', context\.Source\)/, 'exact card mark (check_cards)');
like(Alchemy::target_conditions('Fear'), qr/\(not Ally\(\) and not Self\(\)\) or HasStatus/, 'dark: a non-ally, or anyone with a mood');
like(Alchemy::target_conditions('Joy'), qr/\(Ally\(\) or Self\(\)\) or HasStatus/, 'bright: an ally, or anyone with a mood');

# ---- text
is(Alchemy::tag_terms('Has Advantage on Attack Rolls. Advantage again.'),
   'Has <LSTag Tooltip="Advantage">Advantage</LSTag> on <LSTag Tooltip="AttackRoll">Attack Rolls</LSTag>. Advantage again.',
   'only the first mention becomes an LSTag');
is(Alchemy::tag_terms('Has Disadvantage.'), 'Has <LSTag Tooltip="Disadvantage">Disadvantage</LSTag>.', 'Disadvantage does not become Advantage');
unlike(Alchemy::tag_terms('Has Disadvantage and Advantage.'), qr/<LSTag[^>]*><LSTag/, 'no nested LSTag');

# ---- the whole patch
my $p = Alchemy::build_engine_patch();
my @entries = $p =~ /^new entry "([^"]+)"/mg;
my %defined = map { $_ => 1 } @entries;
is(scalar(grep { /^Target_Arcana_Card_Spell_Emotion/ } @entries), 8, '8 Weave Surges');
is(scalar(grep { /^MOOD_/ } @entries), 8, '8 moods');
is(scalar(grep { /^FEELING_/ && !/_TECH$|_DISAPPROVED$/ } @entries), 24, '24 feelings');
is(scalar(grep { /^EMOTION_/ } @entries), 16, '8 peaks + 8 intense');
ok($defined{$_}, "defined: $_") for qw(CATHARSIS FEELING_DISAPPROVED FEELING_REMORSE_TECH FEELING_MORBIDNESS_TECH HEARTWEAVER_DEBUG
    Shout_Arcana_Util_DEBUG_Heartweaver Arcana_Passive_EmotionalAlchemy Arcana_Passive_EmpathicSight Arcana_Passive_ComplexFeelings
    Arcana_Passive_Overwhelm Arcana_Passive_MixedFeelings Arcana_Passive_FeelingRemorse Arcana_Passive_FeelingMorbidness);
my %dup; $dup{$_}++ for @entries; is_deeply([grep { $dup{$_} > 1 } sort keys %dup], [], 'no duplicate entry');
# closure: every status/passive of ours that is cited exists
my %cited; $cited{$1}++ while $p =~ /(?:ApplyStatus\((?:SELF,)?|RemoveStatus\(|HasStatus\(')((?:EMOTION|MOOD|FEELING|CATHARSIS|HEARTWEAVER)\w*)/g;
$cited{$1}++ while $p =~ /(Arcana_Passive_(?:EmotionalAlchemy|EmpathicSight|ComplexFeelings|Overwhelm|MixedFeelings|Feeling\w+))/g;
ok($defined{$_}, "cited and defined: $_") for sort keys %cited;

# ---- status types: each status sits in the file of its type, `using` right after StatusType
my %file_of; my $cur = '';
for my $l (split /\n/, $p) { $cur = $1 if $l =~ /^\@file (\S+)/; $file_of{$1} = $cur if $l =~ /^new entry "([^"]+)"/ }
my %type_of; $type_of{$1} = $2 while $p =~ /^new entry "([^"]+)"\ntype "StatusData"\ndata "StatusType" "(\w+)"/mg;
is($file_of{$_}, "Status_$type_of{$_}", "$_ ($type_of{$_}) in Status_$type_of{$_}") for sort keys %type_of;
is($type_of{EMOTION_TERROR}, 'FEAR', 'Terror is FEAR: the creature flees');
is($type_of{$_}, 'INCAPACITATED', "$_ is INCAPACITATED") for qw(EMOTION_AMAZEMENT EMOTION_GRIEF FEELING_AWE);
like($p, qr/^new entry "EMOTION_TERROR"\ntype "StatusData"\ndata "StatusType" "FEAR"\nusing "FEARED"\n/m, 'Terror: using FEARED after StatusType');
like($p, qr/^new entry "EMOTION_AMAZEMENT"\ntype "StatusData"\ndata "StatusType" "INCAPACITATED"\nusing "STUNNED"\n/m, 'Amazement: using STUNNED');
like($p, qr/^new entry "FEELING_AWE"\ntype "StatusData"\ndata "StatusType" "INCAPACITATED"\nusing "HYPNOTIC_PATTERN"\n/m, 'Awe: using HYPNOTIC_PATTERN');
my ($terror) = $p =~ /(^new entry "EMOTION_TERROR".*?)\n\n/ms;
like($terror, qr/data "RemoveConditions" ""/, 'Terror clears the inherited per-turn save (1 turn only)');
unlike($terror, qr/data "StatusGroups"/, 'Terror inherits the Fleeing groups');
my ($amaze) = $p =~ /(^new entry "EMOTION_AMAZEMENT".*?)\n\n/ms;
like($amaze, qr/data "OnApplyFunctors" "RemoveStatus\(MOOD_DISTRACTED\);BreakConcentration\(\)"/, 'Amazement keeps STUNNED\'s BreakConcentration');
unlike($amaze, qr/data "Boosts"/, 'Amazement inherits STUNNED\'s boosts');

# ---- text rules
my @loca = $p =~ /^\@loca (\S+) (.*)$/mg;
my %lt = @loca;
my @refs = $p =~ /\{\{(\w+)\}\}/g;
ok($lt{$_}, "string exists: $_") for @refs;
is(scalar(keys %lt), scalar(@loca) / 2, 'unique loca keys');
for my $k (sort keys %lt) {
    my $t = $lt{$k};
    unlike($t, qr/\x{2014}|\x{2013}|\xE2\x80[\x93\x94]/, "$k: no dash");
    (my $bare = $t) =~ s/<LSTag[^>]*>//g;
    unlike($bare, qr/"/, "$k: no double quotes outside LSTag");
    unlike($t, qr/<LSTag[^>]*>[^<]*<LSTag/, "$k: no nested LSTag");
    unlike($t, qr/\{\{|\}\}/, "$k: no raw key");
}

# ---- review fixes (round 1)
# every Surge carries the same Wisdom save, bright or dark (spec 4.3: a save only when the target is a non-ally)
for my $e (@W) {
    my ($sp) = $p =~ /(^new entry "Target_Arcana_Card_Spell_Emotion$e"\n.*?)\n\n/ms;
    ok($sp, "$e: Surge entry found");
    like($sp, qr/^data "SpellRoll" "Ally\(\) or Self\(\) or not SavingThrow\(Ability\.Wisdom, SourceSpellDC\(\)\)"$/m, "$e: SpellRoll is the Wisdom save for non-allies");
    like($sp, qr/^data "SpellFail" "ApplyStatus\(SAVED_AGAINST_HOSTILE_SPELL,100,0\)"$/m, "$e: SpellFail");
    like($sp, qr/^data "TooltipAttackSave" "Wisdom"$/m, "$e: TooltipAttackSave");
    my ($flags) = $sp =~ /^data "SpellFlags" "([^"]*)"$/m;
    if ($Alchemy::EMO{$e}{side} eq 'I') { like($flags, qr/\bIsHarmful\b/, "$e (dark): IsHarmful") }
    else { unlike($flags, qr/IsHarmful/, "$e (bright): no IsHarmful") }
}
like($p, qr/^new entry "Target_Arcana_Card_Spell_EmotionJoy"\n(?:.*\n)*?data "SpellRoll" /m, 'Joy has a SpellRoll');
# damage types in DescriptionParams must be real ones
my @dparams = $p =~ /^data "DescriptionParams" "([^"]*)"$/mg;
ok(scalar(@dparams), 'there are DescriptionParams');
unlike($_, qr/,\s*Weapon\)/, "no bogus Weapon damage type: $_") for @dparams;
like($p, qr/DealDamage\(1d4, MainMeleeWeaponDamageType\)/, 'Aggressiveness uses MainMeleeWeaponDamageType');
# a status that inherits through `using` keeps the parent's TickType
for my $id (qw(FEELING_AWE EMOTION_TERROR EMOTION_AMAZEMENT)) {
    my ($se) = $p =~ /(^new entry "$id"\n.*?)\n\n/ms;
    unlike($se, qr/^data "TickType"/m, "$id: no TickType (inherits)");
}
my ($serene) = $p =~ /(^new entry "MOOD_SERENE"\n.*?)\n\n/ms;
like($serene, qr/^data "TickType" "EndTurn"$/m, 'a plain BOOST (MOOD_SERENE) keeps TickType EndTurn');

# ---- review fixes (round 3): StackIds. The 16 peaks and intense emotions share EMOTION (one emotion at a time), the moods
# share MOOD, each feeling stacks by its own id.
my %stack_of; my $cs = '';
for my $l (split /\n/, $p) {
    $cs = $1 if $l =~ /^new entry "([^"]+)"/;
    $stack_of{$cs} = $1 if $l =~ /^data "StackId" "([^"]*)"$/;
}
my @emo = ((map { 'EMOTION_' . uc $_ } @W), (map { 'EMOTION_' . uc $Alchemy::EMO{$_}{intense}{name} } @W));
is(scalar(@emo), 16, '8 peaks + 8 intense');
is($stack_of{$_}, 'EMOTION', "$_ stacks as EMOTION") for @emo;
is($stack_of{'MOOD_' . uc $_}, 'MOOD', 'MOOD_' . uc($_) . ' stacks as MOOD') for map { $Alchemy::EMO{$_}{mood}{name} } @W;
my @fe = map { 'FEELING_' . uc $Alchemy::FEELING{$_}{name} } sort keys %Alchemy::FEELING;
is(scalar(@fe), 24, '24 feelings');
is($stack_of{$_}, $_, "$_ has its own StackId") for @fe;
is_deeply([grep { $stack_of{$_} =~ /^(?:EMOTION|MOOD|FEELING)$/ } @fe], [], 'no feeling uses EMOTION, MOOD or FEELING');
is($stack_of{FEELING_AWE}, 'FEELING_AWE', 'Awe keeps its own StackId');
is($stack_of{EMOTION_TERROR}, 'EMOTION', 'Terror sets EMOTION, not the StackId of FEARED');

# ---- review fixes (round 4): removals() keeps the upcast variants of the current Surges (synthetic data, no game files)
{
    my $have = {
        Target_Arcana_Card_Spell_EmotionFear   => 'Spell_Target',
        Target_Arcana_Card_Spell_EmotionFear_4 => 'Spell_Target',
        Target_Arcana_Card_Spell_EmotionFury_3 => 'Spell_Target',
        Target_Arcana_Card_Spell_FeelingLove   => 'Spell_Target',
        MOOD_AFRAID                            => 'Status_BOOST',
        EMOTION_MOVED                          => 'Status_KNOCKED_DOWN',
        MOOD_SERENE                            => 'Status_BOOST',
    };
    my $new = {
        Target_Arcana_Card_Spell_EmotionFear => 'Spell_Target',
        EMOTION_MOVED                        => 'Status_BOOST',
        MOOD_SERENE                          => 'Status_BOOST',
    };
    my %rm = map { ("$_->[0]|$_->[1]" => 1) } Alchemy::removals($have, $new);
    ok(!$rm{'Spell_Target|Target_Arcana_Card_Spell_EmotionFear_4'}, 'removals: a variant of a current Surge (EmotionFear_4) stays');
    ok($rm{'Spell_Target|Target_Arcana_Card_Spell_EmotionFury_3'}, 'removals: a variant of an old spell (EmotionFury_3) goes');
    ok($rm{'Spell_Target|Target_Arcana_Card_Spell_FeelingLove'}, 'removals: an old Feeling spell goes');
    ok($rm{'Status_BOOST|MOOD_AFRAID'}, 'removals: an old status (MOOD_AFRAID) goes');
    ok($rm{'Status_KNOCKED_DOWN|EMOTION_MOVED'}, 'removals: a status that moved files goes from its old file');
    ok(!$rm{'Spell_Target|Target_Arcana_Card_Spell_EmotionFear'}, 'removals: a current Surge in the same file stays');
    ok(!$rm{'Status_BOOST|MOOD_SERENE'}, 'removals: a current status in the same file stays');
    is(scalar(keys %rm), 4, 'removals: exactly the 4 old entries');
    my %all = map { my $e = $_; map { (Alchemy::spell_id($e) . "_$_" => 'Spell_Target') } 2 .. 6 } @W;
    is_deeply([Alchemy::removals(\%all, {})], [], 'removals: none of the 40 current variants is ever removed');
}

# ---- text layout (2026-10-07): status text on one line; the Surge says its mood up front and lists its reactions
for my $k (grep { /^HW_(?:EMOTION|MOOD|FEELING)_\w+_DESC$|^HW_CATHARSIS_DESC$/ } sort keys %lt) {
    unlike($lt{$k}, qr/<br>/, "$k: one line");
}
for my $e (@W) {
    my $id = uc Alchemy::spell_id($e);
    my $mood = $Alchemy::EMO{$e}{mood}{name};
    like($lt{"HW_${id}_DESC"}, qr/^[^.]+\. The target\b.*<br><br>When the surge fades, it leaves the target <LSTag[^>]*>$mood<\/LSTag> for 5 turns, /,
        "$e: one flavour sentence, the effect, then the mood");
    my @lines = split /<br>/, $lt{"HW_${id}_EXTRA"};
    is_deeply([map { /^(\w+)/ } @lines], [qw(Primary Secondary Tertiary Catharsis Intense)], "$e: one line per kind of reaction");
    is(scalar(() = $lt{"HW_${id}_EXTRA"} =~ / into /g), 8, "$e: 8 reactions listed (one per mood)");
    my ($sp) = $p =~ /(^new entry "Target_Arcana_Card_Spell_Emotion$e"\n.*?)\n\n/ms;
    like($sp, qr/^data "TooltipPermanentWarnings" "$Alchemy::SURGE_WARNING"$/m, "$e: the standard warning");
}
done_testing();
