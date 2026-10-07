#!/usr/bin/perl
# Tests for the Emotional Alchemy generator.   perl t/gen_emotion_alchemy.t   (`prove` does not run on this Perl)
# One assertion per rule: each collects what breaks it, so a failure names the entries and a pass prints one line.
use strict; use warnings; no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
require(abs_path(dirname(__FILE__)) . '/../gen_emotion_alchemy.pl');

my @W = @Alchemy::WHEEL;
sub none { my ($name, @bad) = @_; is_deeply(\@bad, [], $name) }
sub block { my ($p, $id) = @_; my ($b) = $p =~ /(^new entry "\Q$id\E"\n.*?)\n\n/ms; $b // '' }

# ---- the wheel and Plutchik's dyads
none('distance is symmetric, wraps, and opposites are 4',
    (grep { my $x = $_; grep { Alchemy::distance($x, $_) != Alchemy::distance($_, $x) } @W } @W),
    (grep { Alchemy::distance($_->[0], $_->[1]) != 4 } [qw(Joy Sadness)], [qw(Trust Disgust)], [qw(Fear Anger)], [qw(Surprise Anticipation)]),
    (Alchemy::distance('Joy', 'Anticipation') == 1 ? () : 'wrap'));
my %plutchik = (1 => [qw(Love Submission Awe Disapproval Remorse Contempt Aggressiveness Optimism)],
                2 => [qw(Hope Guilt Curiosity Despair Unbelief Envy Cynicism Pride)],
                3 => [qw(Delight Sentimentality Shame Outrage Pessimism Morbidness Dominance Anxiety)]);
my %have;
for my $k (keys %Alchemy::FEELING) { my ($x, $y) = split /\+/, $k; push @{ $have{ Alchemy::distance($x, $y) } }, $Alchemy::FEELING{$k}{name} }
is_deeply({ map { $_ => [sort @{ $have{$_} }] } 1 .. 3 }, { map { $_ => [sort @{ $plutchik{$_} }] } 1 .. 3 }, "the 24 dyads, each at Plutchik's distance");
none('feeling keys in wheel order', grep { my ($x, $y) = split /\+/; $_ ne Alchemy::pair($x, $y) } keys %Alchemy::FEELING);

# ---- the 8x8 reaction matrix
none('every Surge/mood pair: right kind and gate', map { my $s = $_; map {
    my $r = Alchemy::reaction($s, $_); my $d = Alchemy::distance($s, $_);
    my $want = $d == 0 ? 'intensify' : $d == 4 ? 'catharsis' : 'feeling';
    ($r->{kind} ne $want || ($r->{gate} // '') ne ($Alchemy::GATE{$d} // '')) ? "$s/$_" : () } @W } @W);
is(Alchemy::reaction('Fear', 'Trust')->{status}, 'FEELING_SUBMISSION', 'Fear on Accepting = Submission');
is(Alchemy::reaction('Fear', 'Fear')->{status}, 'EMOTION_TERROR', 'Fear on Apprehensive = Terror');

# ---- SpellSuccess
my $ss = Alchemy::spell_success('Fear');
my @f = split /;(?=IF\()/, $ss;
like($f[0], qr/^IF\(not \(.*:ApplyStatus\(EMOTION_FEAR,100,1\)$/, 'first functor: the no-reaction case applies the peak (risk R1)');
is(scalar(() = $f[0] =~ /HasStatus\('MOOD_/g), 8, 'the no-reaction case checks all 8 moods');
like($ss, qr/IF\(HasStatus\('MOOD_SERENE'\) and HasPassive\('Arcana_Passive_ComplexFeelings', context\.Source\)\):ApplyStatus\(FEELING_GUILT,100,2\)/, 'a gated reaction');
like($ss, qr/DealDamage\(2d8,Psychic,Magical\).*RegainHitPoints\(2d8\).*ApplyStatus\(CATHARSIS,100,0\)$/, 'Catharsis harms, heals, then clears the moods last');
none('each Surge: 1 base case + 7 reactions + 3 Catharsis functors', grep { (() = Alchemy::spell_success($_) =~ /IF\(/g) != 11 } @W);

# ---- the whole patch
my $p = Alchemy::build_engine_patch();
my @entries = $p =~ /^new entry "([^"]+)"/mg;
my %defined = map { $_ => 1 } @entries;
is_deeply([map { my $re = $_; scalar grep { /$re/ } @entries } qr/^Target_Arcana_Card_Spell_Emotion/, qr/^MOOD_/, qr/^FEELING_(?!.*_TECH$|DISAPPROVED$)/, qr/^EMOTION_/],
    [8, 8, 24, 16], '8 Surges, 8 moods, 24 feelings, 16 emotions');
my %dup; $dup{$_}++ for @entries;
none('no duplicate entry', grep { $dup{$_} > 1 } sort keys %dup);
my %cited; $cited{$1}++ while $p =~ /(?:ApplyStatus\((?:SELF,)?|RemoveStatus\(|HasStatus\(')((?:EMOTION|MOOD|FEELING|CATHARSIS|HEARTWEAVER)\w*)/g;
$cited{$1}++ while $p =~ /(Arcana_Passive_(?:EmotionalAlchemy|EmpathicSight|ComplexFeelings|Overwhelm|MixedFeelings|Feeling\w+))/g;
none('every cited status/passive is defined', grep { !$defined{$_} } sort keys %cited);

# ---- status types: each in the file of its type, `using` right after StatusType
my %file_of; my $cur = '';
for my $l (split /\n/, $p) { $cur = $1 if $l =~ /^\@file (\S+)/; $file_of{$1} = $cur if $l =~ /^new entry "([^"]+)"/ }
my %type_of; $type_of{$1} = $2 while $p =~ /^new entry "([^"]+)"\ntype "StatusData"\ndata "StatusType" "(\w+)"/mg;
none('each status sits in Status_<its type>', grep { $file_of{$_} ne "Status_$type_of{$_}" } sort keys %type_of);
like($p, qr/^new entry "EMOTION_TERROR"\ntype "StatusData"\ndata "StatusType" "FEAR"\nusing "FEARED"\n/m, 'Terror: FEAR, using FEARED');
like($p, qr/^new entry "EMOTION_AMAZEMENT"\ntype "StatusData"\ndata "StatusType" "INCAPACITATED"\nusing "STUNNED"\n/m, 'Amazement: INCAPACITATED, using STUNNED');
like($p, qr/^new entry "FEELING_AWE"\ntype "StatusData"\ndata "StatusType" "INCAPACITATED"\nusing "HYPNOTIC_PATTERN"\n/m, 'Awe: INCAPACITATED, using HYPNOTIC_PATTERN');
like(block($p, 'EMOTION_TERROR'), qr/data "RemoveConditions" ""/, 'Terror clears the inherited per-turn save');
like(block($p, 'EMOTION_AMAZEMENT'), qr/data "OnApplyFunctors" "RemoveStatus\(MOOD_DISTRACTED\);BreakConcentration\(\)"/, 'Amazement keeps BreakConcentration');
none('statuses with `using` inherit TickType', grep { block($p, $_) =~ /^data "TickType"/m } qw(FEELING_AWE EMOTION_TERROR EMOTION_AMAZEMENT));

# ---- StackIds: peaks and intense share EMOTION, moods share MOOD, each feeling its own
my %stack_of; my $cs = '';
for my $l (split /\n/, $p) { $cs = $1 if $l =~ /^new entry "([^"]+)"/; $stack_of{$cs} = $1 if $l =~ /^data "StackId" "([^"]*)"$/ }
none('StackIds', (grep { $stack_of{$_} ne 'EMOTION' } map { ('EMOTION_' . uc $_, 'EMOTION_' . uc $Alchemy::EMO{$_}{intense}{name}) } @W),
    (grep { $stack_of{$_} ne 'MOOD' } map { 'MOOD_' . uc $Alchemy::EMO{$_}{mood}{name} } @W),
    (grep { $stack_of{$_} ne $_ } map { 'FEELING_' . uc $Alchemy::FEELING{$_}{name} } keys %Alchemy::FEELING));

# ---- the Surges
none('Surges: Wisdom save for non-allies, SpellFail, IsHarmful only on the dark arc, standard warning', map {
    my $sp = block($p, Alchemy::spell_id($_)); my $dark = $Alchemy::EMO{$_}{side} eq 'I';
    ($sp =~ /^data "SpellRoll" "Ally\(\) or Self\(\) or not SavingThrow\(Ability\.Wisdom, SourceSpellDC\(\)\)"$/m
     && $sp =~ /^data "SpellFail" "ApplyStatus\(SAVED_AGAINST_HOSTILE_SPELL,100,0\)"$/m
     && $sp =~ /^data "TooltipAttackSave" "Wisdom"$/m
     && $sp =~ /^data "TooltipPermanentWarnings" "$Alchemy::SURGE_WARNING"$/m
     && (($sp =~ /IsHarmful/ ? 1 : 0) == ($dark ? 1 : 0))) ? () : $_ } @W);
none('DescriptionParams use real damage types', grep { /,\s*Weapon\)/ } $p =~ /^data "DescriptionParams" "([^"]*)"$/mg);

# ---- text
is(Alchemy::tag_terms('Has Advantage on Attack Rolls. Advantage again.'),
   'Has <LSTag Tooltip="Advantage">Advantage</LSTag> on <LSTag Tooltip="AttackRoll">Attack Rolls</LSTag>. Advantage again.',
   'only the first mention becomes an LSTag');
my @loca = $p =~ /^\@loca (\S+) (.*)$/mg; my %lt = @loca;
is(scalar(keys %lt), @loca / 2, 'unique loca keys');
none('every {{key}} has a string', grep { !$lt{$_} } $p =~ /\{\{(\w+)\}\}/g);
none('strings: no dash, no double quotes outside LSTag, no nested LSTag, no raw key', grep { my $t = $lt{$_}; (my $bare = $t) =~ s/<LSTag[^>]*>//g;
    $t =~ /\x{2014}|\x{2013}|\xE2\x80[\x93\x94]/ || $bare =~ /"/ || $t =~ /<LSTag[^>]*>[^<]*<LSTag/ || $t =~ /\{\{|\}\}/ } sort keys %lt);
none('status text on one line', grep { $lt{$_} =~ /<br>/ } grep { /^HW_(?:EMOTION|MOOD|FEELING)_\w+_DESC$|^HW_CATHARSIS_DESC$/ } keys %lt);
none('Surge text: flavour, effect, then the mood; one line per kind of reaction, 8 reactions', map {
    my $id = uc Alchemy::spell_id($_); my $mood = $Alchemy::EMO{$_}{mood}{name}; my $x = $lt{"HW_${id}_EXTRA"};
    ($lt{"HW_${id}_DESC"} =~ /^[^.]+\. The target\b.*<br><br>When the surge fades, it leaves the target <LSTag[^>]*>$mood<\/LSTag> for 5 turns, /
     && join(',', map { /^(\w+)/ } split /<br>/, $x) eq 'Primary,Secondary,Tertiary,Catharsis,Intense'
     && (() = $x =~ / into /g) == 8) ? () : $_ } @W);

# ---- removals() keeps the upcast variants of the current Surges (synthetic data, no game files)
my $have = { Target_Arcana_Card_Spell_EmotionFear => 'Spell_Target', Target_Arcana_Card_Spell_EmotionFear_4 => 'Spell_Target',
    Target_Arcana_Card_Spell_EmotionFury_3 => 'Spell_Target', Target_Arcana_Card_Spell_FeelingLove => 'Spell_Target',
    MOOD_AFRAID => 'Status_BOOST', EMOTION_MOVED => 'Status_KNOCKED_DOWN', MOOD_SERENE => 'Status_BOOST' };
my $new = { Target_Arcana_Card_Spell_EmotionFear => 'Spell_Target', EMOTION_MOVED => 'Status_BOOST', MOOD_SERENE => 'Status_BOOST' };
is_deeply([sort map { "$_->[0]|$_->[1]" } Alchemy::removals($have, $new)],
    [sort qw(Spell_Target|Target_Arcana_Card_Spell_EmotionFury_3 Spell_Target|Target_Arcana_Card_Spell_FeelingLove Status_BOOST|MOOD_AFRAID Status_KNOCKED_DOWN|EMOTION_MOVED)],
    'removals: old entries and moved statuses go; current Surges, their variants and statuses stay');
my %all = map { my $e = $_; map { (Alchemy::spell_id($e) . "_$_" => 'Spell_Target') } 2 .. 6 } @W;
none('removals: no current variant is ever removed', map { $_->[1] } Alchemy::removals(\%all, {}));

done_testing();
