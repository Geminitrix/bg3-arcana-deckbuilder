# Gera as variantes de nivel superior de cada carta.
#
# POR QUE ISSO EXISTE
# O BG3 nao paga um custo de nivel N com um espaco de nivel maior. O que ele faz -- e o que faz o
# Warlock parecer flexivel -- e trocar a magia por uma VARIANTE cujo custo bate com o espaco que voce
# tem. O jogo base traz 1208 dessas (Projectile_MagicMissile_2 ... _6). Como os espacos da Arcana sobem
# de nivel com o personagem, cada carta precisa das suas.
#
# As variantes daqui sao IDENTICAS a carta base, menos o custo: a potencia continua vindo do LevelMap,
# que escala pelo nivel do personagem. Conjurar com espaco maior nao deixa a carta mais forte, so
# permite conjura-la.
#
# RODE DE NOVO depois de acrescentar, renomear ou mudar o nivel de qualquer carta. E idempotente:
# apaga as variantes anteriores antes de gerar.
#
#   perl gen_upcast_variants.pl            # mostra o que faria
#   perl gen_upcast_variants.pl --apply    # grava (jogo e Toolkit fechados)

use strict; use warnings;
use File::Glob ':bsd_glob';

my $base    = 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $mod     = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my $MAXSLOT = 6;                       # maior nivel de espaco que a progressao concede
my $DRY     = (grep { $_ eq '--apply' } @ARGV) ? 0 : 1;

# TODA entrada que paga com espaco precisa de variante, sem excecao. Eu tinha deixado Created e
# Card_Passive de fora porque "so existem em combate, onde o ARCANA_WEAVING zera o custo do espaco" --
# mas o ARCANA_WEAVING so existe na edicao com SE. No console o custo vale como esta, e como o
# personagem so tem espaco de UM nivel por vez, do 11 em diante nada abaixo de 6 seria conjuravel.
my $KINDS          = qr/Card_Spell|Card_Ability|Card_Passive|Created/;
my $WANTS_VARIANTS = qr/_Arcana_(?:$KINDS)_/;
my $IS_VARIANT     = qr/_Arcana_(?:$KINDS)_.*_[1-9]$/;

sub uuid {
    my @h = map { sprintf "%04x", int(rand(65536)) } 1..8;
    $h[3] = sprintf("4%03x", hex($h[3]) & 0x0fff);
    $h[4] = sprintf("%04x", (hex($h[4]) & 0x3fff) | 0x8000);
    return "$h[0]$h[1]-$h[2]-$h[3]-$h[4]-$h[5]$h[6]$h[7]";
}

# ---------- 1. o que gerar, lido do .txt ----------
my (%plan, %fileOf, %allRoots);
for my $f (bsd_glob("$base/Public/$mod/Stats/Generated/Data/Spell_*.txt")) {
    open my $fh,'<:raw',$f or die "$f: $!"; local $/; my $s=<$fh>; close $fh;
    for my $b (split /(?=new entry )/, $s) {
        next unless $b =~ /^new entry "([^"]+)"/; my $n = $1;
        next unless $n =~ $WANTS_VARIANTS;
        next if $n =~ $IS_VARIANT;                       # nunca gerar variante de variante
        $allRoots{$n} = 1;                               # toda carta entra na tabela do Osiris
        my ($l) = $b =~ /data "Level" "([^"]*)"/;
        my ($u) = $b =~ /data "UseCosts" "([^"]*)"/;
        # Forma do vanilla: SpellSlotsGroup:min:max:nivel. O ArcanaSpellSlot e membro desse grupo --
        # o mod redefine o grupo do jogo base acrescentando um quarto membro aos tres originais.
        # Foi preciso porque com um grupo PROPRIO o motor registrava variantes de niveis que nao
        # existem: o Gale, com o mesmo estado de recurso (nv1 0/0, nv2 0/0, nv3 x/x), registrava so
        # a do nivel 3, enquanto a Arcana registrava _2 e _3 -- e duas opcoes viram caixa de escolha.
        next unless defined $u && $u =~ /SpellSlotsGroup:\d+:\d+:\d/;
        next unless defined $l && $l =~ /^[1-9]$/ && $l < $MAXSLOT;
        $plan{$n} = { level => $l, usecosts => $u };
        $fileOf{$n} = $f;
    }
}

# ---------- 2. UUID da base, lido do .stats ----------
my (%baseUuid, %statsFileOf);
for my $f (bsd_glob("$base/Editor/Mods/$mod/Stats/SpellData/*.stats")) {
    open my $fh,'<:raw',$f or die "$f: $!"; local $/; my $s=<$fh>; close $fh;
    # \s no fim: sem ele o split casa tambem o <stat_objects> que abre a lista
    for my $b (split /(?=<stat_object\s)/, $s) {
        next unless $b =~ /<field name="Name"[^>]*value="([^"]+)"/; my $k = $1;
        my ($u) = $b =~ /<field name="UUID"[^>]*value="([^"]+)"/;
        next unless $u;
        $baseUuid{$k} = $u; $statsFileOf{$k} = $f;
    }
}

# ---------- 3. limpar variantes antigas ----------
# Nada é gravado antes do fim: uma gravação parcial deixa metade dos arquivos com as variantes
# novas e metade sem, e foi exatamente assim que eu truncei três .stats numa tentativa anterior.
my %pending;
my $removed = 0;
for my $f (bsd_glob("$base/Public/$mod/Stats/Generated/Data/Spell_*.txt")) {
    open my $fh,'<:raw',$f or die $!; local $/; my $s=<$fh>; close $fh; my $o=$s;
    my @keep;
    for my $b (split /(?=new entry )/, $s) {
        if ($b =~ /^new entry "([^"]+)"/ && $1 =~ $IS_VARIANT && $b =~ /data "RootSpellID"/) { $removed++; next }
        push @keep, $b;
    }
    $s = join '', @keep;
    $pending{$f} = $s if $s ne $o;
}
for my $f (bsd_glob("$base/Editor/Mods/$mod/Stats/SpellData/*.stats")) {
    open my $fh,'<:raw',$f or die $!; local $/; my $s=<$fh>; close $fh; my $o=$s;
    my @chunks = split /(?=<stat_object\s)/, $s;
    # O fechamento do arquivo vem grudado na ultima entrada. Se ela for uma variante a remover,
    # o rodapé ia embora junto e o XML ficava truncado -- por isso ele sai daqui antes.
    my $tail = '';
    if (@chunks && $chunks[-1] =~ s{(</stat_object>)(.*)$}{$1}s) { $tail = $2 }
    my @keep;
    for my $b (@chunks) {
        if ($b =~ /<field name="Name"[^>]*value="([^"]+)"/ && "_$1" =~ $IS_VARIANT && $b =~ /name="RootSpellID"/) { next }
        push @keep, $b;
    }
    $s = join('', @keep) . $tail;
    $pending{$f} = $s if $s ne $o;
}

# ---------- 4. gerar ----------
my (%txtAdd, %statsAdd, @log, @warn, $khnNote);
for my $n (sort keys %plan) {
    my ($lvl, $uc) = @{$plan{$n}}{qw(level usecosts)};
    (my $key = $n) =~ s/^(?:Target|Shout|Projectile|Zone|Teleportation)_//;
    unless ($baseUuid{$key}) { push @warn, "  $n sem UUID no Editor -- variante so no .txt"; }
    my ($sptype) = $n =~ /^(Target|Shout|Projectile|Zone|Teleportation)_/;
    unless ($sptype) { push @warn, "  $n: nao consegui deduzir o SpellType"; next }
    for my $L ($lvl+1 .. $MAXSLOT) {
        (my $cost = $uc) =~ s/(SpellSlotsGroup:\d+:\d+):\d/$1:$L/;
        # O SpellType vai explicito e antes do `using`, como o vanilla escreve em 2276 de 2276
        # variantes. Herdar pelo `using` parece funcionar, mas nenhuma variante do jogo base faz isso.
        $txtAdd{$fileOf{$n}} .= join("\n",
            qq{new entry "${n}_$L"}, q{type "SpellData"}, qq{data "SpellType" "$sptype"},
            qq{using "$n"},
            qq{data "RootSpellID" "$n"}, qq{data "PowerLevel" "$L"},
            qq{data "UseCosts" "$cost"}) . "\n\n";
        if (my $bu = $baseUuid{$key}) {
            my $sf = $statsFileOf{$key};
            $statsAdd{$sf} .=
                qq{    <stat_object is_substat="false">\n      <fields>\n}
              . qq{        <field name="UUID" type="IdTableFieldDefinition" value="}.uuid().qq{" />\n}
              . qq{        <field name="Name" type="NameTableFieldDefinition" value="${key}_$L" />\n}
              . qq{        <field name="Using" type="BaseClassTableFieldDefinition" value="$bu" />\n}
              . qq{        <field name="RootSpellID" type="StringTableFieldDefinition" value="$n" />\n}
              . qq{        <field name="PowerLevel" type="IntegerTableFieldDefinition" value="$L" />\n}
              . qq{        <field name="UseCosts" type="StringTableFieldDefinition" value="$cost" />\n}
              . qq{      </fields>\n    </stat_object>\n};
        }
        push @log, sprintf("  %-50s nivel %s", "${n}_$L", $L);
    }
}

# ---------- 4b. reescrever o helper do Mirrored Charm ----------
# SpellId() e comparacao EXATA: o motor nao resolve a raiz, e o proprio vanilla enumera cada nivel na
# mao (Target_Polymorph, _5, _6). Sem isso o Mirrored Charm para de valer assim que o jogador conjura
# num nivel acima -- e do personagem 11 em diante ele nunca mais vale, porque so a variante _6 e
# pagavel. A lista-fonte sao as cartas base abaixo; as variantes saem daqui, sempre em dia.
my @DECEIVER_ONE_TARGET = qw(
    Target_Arcana_Card_Spell_MaliciousWhispers
    Target_Arcana_Util_Friends
    Target_Arcana_Card_Spell_EtherealChains
    Target_Arcana_Created_MimicEtherealChains
    Target_Arcana_Card_Spell_MentalPrison
    Target_Arcana_Card_Spell_Terrify
    Target_Arcana_Card_Spell_Marionette
    Projectile_Arcana_Card_Spell_SigilofMalice
    Projectile_Arcana_Created_MimicSigilofMalice
);
{
    my @ids;
    for my $n (@DECEIVER_ONE_TARGET) {
        push @warn, "  $n: na lista do Mirrored Charm mas nao existe nos stats" unless $fileOf{$n} || !exists $plan{$n};
        push @ids, $n;
        push @ids, "${n}_$_" for ($plan{$n} ? ($plan{$n}{level}+1 .. $MAXSLOT) : ());
    }
    my $khn = "-- GERADO por gen_upcast_variants.pl a partir de \@DECEIVER_ONE_TARGET. Nao edite a mao:\n"
            . "-- acrescente a carta base na lista do gerador e rode de novo.\n"
            . "-- SpellId() compara o nome exato, entao cada variante de upcast precisa estar aqui.\n"
            . "function IsDeceiverOneTargetSpell()\n    return "
            . join(" |\n    ", map { "SpellId('$_')" } @ids) . "\n end\n";
    $khn =~ s/\n end\n$/\nend\n/;
    $pending{"$base/Mods/$mod/Scripts/thoth/helpers/IsDeceiverOneTargetSpell.khn"} = $khn;
    $khnNote = sprintf("IsDeceiverOneTargetSpell.khn reescrito com %d SpellId", scalar @ids);
}

# ---------- 4c. tabela de familias para o Osiris ----------
# O evento de conjurar (UsingSpell, CastSpell, UsingSpellOnTarget) entrega o nome da VARIANTE que o
# personagem pagou -- "..._5" --, nao o da carta. Confirmado no jogo em 2026-09-24: Distortion com
# upcast nao liberava o Withdraw, e Sigil/Ethereal nao aplicavam o status do Mimic. Por isso nenhuma
# regra do Story deve comparar nome de carta direto; ela pergunta
#     DB_ARCANA_CardFamily(_ArcanaSpell, "<carta>")
# e a tabela abaixo liga cada carta e cada variante a raiz. Ela e montada numa PROC chamada pelo
# INITSECTION (jogo novo) e pelo SavegameLoaded (save existente -- INITSECTION nao roda de novo em
# save antigo). Mora no goal do Withdraw porque ele ja esta registrado e ativo; a DB e global.
{
    my $goal = "$base/Mods/$mod/Story/RawFiles/Goals/ARCANA_Spell_Withdraw.txt";
    my $g = exists $pending{$goal} ? $pending{$goal} : do { open my $h,'<:raw',$goal or die "$goal: $!"; local $/; my $x=<$h>; close $h; $x };
    # O goal e CRLF. O cat -A do Git Bash esconde o CR e ja enganou uma checagem minha, entao o fim
    # de linha e lido do proprio arquivo em vez de assumido.
    my $nl = ($g =~ /\r\n/) ? "\r\n" : "\n";
    my @facts;
    for my $r (sort keys %allRoots) {
        push @facts, qq{DB_ARCANA_CardFamily("$r", "$r");};
        push @facts, qq{DB_ARCANA_CardFamily("${r}_$_", "$r");} for ($plan{$r} ? ($plan{$r}{level}+1 .. $MAXSLOT) : ());
    }
    my @region = (
        "//REGION Gerado por gen_upcast_variants.pl -- familias de cartas (nao edite a mao)",
        "// Regra que reage a uma carta pergunta DB_ARCANA_CardFamily(_ArcanaSpell, \"<carta>\"), porque o evento",
        "// de conjurar entrega o nome da variante paga (..._5), nao o da carta.",
        "PROC", "PROC_ARCANA_CardFamilies()", "THEN", @facts, "",
        "IF", "SavegameLoaded()", "THEN", "PROC_ARCANA_CardFamilies();", "//END_REGION",
    );
    my $region = join($nl, @region) . $nl;
    my $START = '//REGION Gerado por gen_upcast_variants.pl';
    if ($g =~ /\Q$START\E/) {
        $g =~ s{\Q$START\E.*?//END_REGION\r?\n}{$region}s;
    } else {
        $g =~ s{(KBSECTION\r?\n)}{$1$region$nl} or push @warn, "  goal do Withdraw sem KBSECTION";
    }
    $g =~ s{(INITSECTION\r?\n)}{$1PROC_ARCANA_CardFamilies();$nl}
        unless $g =~ /INITSECTION\r?\nPROC_ARCANA_CardFamilies\(\);/;
    $pending{$goal} = $g;
    $khnNote .= sprintf("; familias do Osiris: %d cartas, %d linhas", scalar keys %allRoots, scalar @facts);
}

# ---------- 5. juntar tudo em memória, conferir, e só então gravar ----------
sub current { my $f = shift;
    return $pending{$f} if exists $pending{$f};
    open my $h,'<:raw',$f or die "$f: $!"; local $/; my $s=<$h>; close $h; $s;
}
for my $f (keys %txtAdd)   { $pending{$f} = current($f) . "\n" . $txtAdd{$f} }
for my $f (keys %statsAdd) {
    my $s = current($f);
    $s =~ s{(\s*</stat_objects>)}{$statsAdd{$f}$1}
        or push @warn, "  $f: fechamento </stat_objects> nao encontrado";
    $pending{$f} = $s;
}
# uma âncora perdida significaria variante só de um lado -- melhor não gravar nada
if (grep { /stat_objects/ } @warn) {
    print "== ABORTADO, nada foi gravado ==\n", map {"$_\n"} @warn;
    exit 1;
}
unless ($DRY) {
    for my $f (sort keys %pending) { open my $x,'>:raw',$f or die $!; print $x $pending{$f}; close $x }
}

printf "== %s variantes para %s cartas (antigas removidas: %s) ==\n", scalar @log, scalar keys %plan, $removed;
print "$_\n" for @log[0..($#log > 7 ? 7 : $#log)];
print "  ...\n" if @log > 8;
print "  $khnNote\n" if $khnNote;
print "== AVISOS (", scalar @warn, ") ==\n", map {"$_\n"} @warn;
print $DRY ? "*** DRY RUN ***\n" : "*** GRAVADO ***\n";
