# Confere a marca de carta e o que costuma quebrar depois de um publish pelo Toolkit.
#
# Rode depois de CADA publish e depois de mexer em carta. Sai com codigo 1 se achar problema.
#
#   perl check_cards.pl
#
# A marca e not HasPassive('ARCANA_IS_CARD', context.Source) no TargetConditions: e por ela que o
# IsCardSpell() (Khonsu) reconhece carta, e o Registry do Lua vai reconhecer pelo mesmo lugar. Tudo
# aqui existe para que "tem a marca" continue querendo dizer exatamente "e carta".
use strict; use warnings;
use File::Glob ':bsd_glob';

my $D = $ENV{BG3_DATA} || 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $M = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my $GROUP_UUID = '03b17647-161a-42e1-9660-5ba517e80ad2';     # o SpellSlotsGroup do jogo base
my $MARKRE = qr/not HasPassive\('ARCANA_IS_CARD', context\.Source\)/;
my (@err, @note);

sub strip_prefix { my $x = shift; $x =~ s/^(?:Target|Shout|Projectile|Zone|Teleportation)_//; $x }
sub slurp { open my $h,'<:raw',$_[0] or die "$_[0]: $!"; local $/; my $s=<$h>; close $h; $s }

# ---------- Public ----------
my %e;
for my $f (bsd_glob("$D/Public/$M/Stats/Generated/Data/Spell_*.txt")) {
    for my $b (split /(?=new entry )/, slurp($f)) { $e{$1} = $b if $b =~ /^new entry "([^"]+)"/ }
}
sub tc  { my $x = shift; return undef unless $e{$x}; $e{$x} =~ /data "TargetConditions" "([^"]*)"/ ? $1 : undef }
sub par { my $x = shift; return undef unless $e{$x}; $e{$x} =~ /^using "([^"]+)"/m ? $1 : undef }
sub resolved { my $x = shift; my $k = 0;
    while ($x && $k++ < 10) { my $t = tc($x); return $t if defined $t; $x = par($x) } return undef }

for my $x (sort keys %e) {
    my $b = $e{$x};
    # qualquer campo de condicao com "; and" / "; or" -- o jogo base nunca escreve isso
    while ($b =~ /data "([A-Za-z]*Conditions)" "([^"]*)"/g) {
        # copiar antes: o regex do teste abaixo apaga $1 -- armadilha que ja pegou este projeto antes
        my ($field, $val) = ($1, $2);
        push @err, "';' no meio da condicao  $x  ($field)" if $val =~ /;\s*(?:and|or)\b/;
    }
    next if $x =~ /_[1-9]$/;                                   # variantes herdam da base
    my $r = resolved($x); my $marked = defined $r && $r =~ $MARKRE;

    if ($x =~ /_Arcana_Card_(?:Spell|Passive)_/ && !$marked) { push @err, "carta sem a marca          $x" }
    if ($x =~ /_Deceiver_Clone_/ && $marked)                   { push @err, "clone com a marca          $x (quem conjura e o clone, nao e carta)" }
    if ($marked && $b =~ /data "Level" ""/)                    { push @err, "Level em branco            $x (o Toolkit ja zerou o Withdraw assim)" }

    # campo proprio so com a marca, enquanto o pai tem condicao de verdade: a marca APAGOU a mira
    my $own = tc($x);
    if (defined $own && $own =~ /^$MARKRE$/ && (my $p = par($x))) {
        my $pr = resolved($p);
        if (defined $pr && $pr ne '' && $pr !~ /^$MARKRE$/) {
            push @err, "mira herdada apagada       $x (o pai tem \"$pr\")";
        }
    }
}

# ---------- Editor: mesmo conjunto de marcas proprias ----------
my (%pub, %edt);
for my $x (keys %e) { my $t = tc($x); $pub{strip_prefix($x)} = 1 if defined $t && $t =~ $MARKRE }
for my $f (bsd_glob("$D/Editor/Mods/$M/Stats/SpellData/*.stats")) {
    for my $b (split /(?=<stat_object\s)/, slurp($f)) {
        next unless $b =~ /<field name="Name"[^>]*value="([^"]+)"/; my $k = $1;
        $edt{$k} = 1 if $b =~ /<field name="TargetConditions"[^>]*value="[^"]*$MARKRE/;
    }
}
push @err, "marca so no Public         $_" for sort grep { !$edt{$_} } keys %pub;
push @err, "marca so no Editor         $_" for sort grep { !$pub{$_} } keys %edt;

# ---------- recurso que nao existe mais ----------
for my $f (bsd_glob("$D/Public/$M/Stats/Generated/Data/*.txt")) {
    (my $bn = $f) =~ s{.*/}{};
    my $n = () = slurp($f) =~ /ArcaneEssence/g;
    push @err, "ArcaneEssence em $bn ($n) -- o recurso foi apagado" if $n;
}

# ---------- Story: gatilho comparando nome de carta ----------
# O evento de conjurar entrega o nome da VARIANTE paga (..._5), entao comparar o nome da carta perde
# toda conjuracao com upcast. A regra tem de perguntar DB_ARCANA_CardFamily(_ArcanaSpell, "<carta>").
for my $f (bsd_glob("$D/Mods/$M/Story/RawFiles/Goals/*.txt")) {
    (my $bn = $f) =~ s{.*/}{};
    my $s = slurp($f);
    while ($s =~ /^((?:UsingSpell|UsingSpellOnTarget|CastSpell|CastedSpell)\([^\r\n]*"([A-Za-z]+_Arcana_(?:Card_[A-Za-z]+|Created)_[A-Za-z0-9_]+)")/mg) {
        my $card = $2;
        push @err, "Story compara nome de carta  $bn  ($card) -- use DB_ARCANA_CardFamily";
    }
}

# ---------- o grupo que as cartas cobram ----------
my $g = slurp("$D/Public/$M/ActionResourceGroupDefinitions/ActionResourceGroupDefinitions.lsx");
push @err, "SpellSlotsGroup com UUID trocado (o Toolkit recria a linha com UUID novo; tem de ser $GROUP_UUID)"
    unless $g =~ /\Q$GROUP_UUID\E/;

my $cards = grep { !/_[1-9]$/ && do { my $r = resolved($_); defined $r && $r =~ $MARKRE } } keys %e;
print "raizes marcadas: $cards\n";
if (@err) { print "== ", scalar @err, " PROBLEMA(S) ==\n", map {"  $_\n"} @err; exit 1 }
print "OK -- nenhum problema\n";
exit 0;
