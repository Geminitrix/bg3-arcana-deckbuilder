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

# Derivado do nome da variante: a mesma variante ganha o mesmo UUID em toda execucao. Com UUID
# aleatorio, cada rodada do gerador reescrevia os 190 UUIDs e o diff do .stats virava ruido.
use Digest::MD5 qw(md5_hex);
sub uuid {
    my @h = unpack '(A4)8', md5_hex("arcana-upcast-variant:" . shift);
    $h[3] = sprintf("4%03x", hex($h[3]) & 0x0fff);
    $h[4] = sprintf("%04x", (hex($h[4]) & 0x3fff) | 0x8000);
    return "$h[0]$h[1]-$h[2]-$h[3]-$h[4]-$h[5]$h[6]$h[7]";
}

# ---------- 1. o que gerar, lido do .txt ----------
my (%plan, %fileOf, %allRoots, %blk, %fileAny);
for my $f (bsd_glob("$base/Public/$mod/Stats/Generated/Data/Spell_*.txt")) {
    open my $fh,'<:raw',$f or die "$f: $!"; local $/; my $s=<$fh>; close $fh;
    for my $b (split /(?=new entry )/, $s) {
        next unless $b =~ /^new entry "([^"]+)"/; my $n = $1;
        $blk{$n} = $b; $fileAny{$n} = $f;
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

# ---------- 1b. containers com upcast ----------
# O jogo base faz assim (Target_EnhanceAbility): a variante do container, "_3", lista as variantes
# dos filhos, "..._BearsEndurance_3", e cada filho ganha a propria "_3", com SpellContainerID apontando
# para o container "_3" e o custo do nivel 3. Antes a variante do container herdava a lista dos filhos
# BASE, que apontam para o container base -- e o Hemoplague abria vazio (2026-09-27).
sub resolved_field { my ($n, $k) = @_; my $i = 0;
    while ($n && $i++ < 10) { return undef unless $blk{$n};
        return $1 if $blk{$n} =~ /data "$k" "([^"]*)"/; ($n) = $blk{$n} =~ /using "([^"]+)"/ } undef }
my (%childLevels);
for my $n (sort keys %plan) {
    my $cs = resolved_field($n, 'ContainerSpells');
    next unless defined $cs && $cs =~ /\S/;
    my @kids = grep { length } split /;/, $cs;
    for my $c (@kids) {
        unless ($blk{$c}) { push @{ $plan{$n}{missing} }, $c; next }
        if ($plan{$c}) { push @{ $plan{$n}{ownPlan} }, $c; next }   # filho com variante propria: nao mexer
        push @{ $plan{$n}{children} }, $c;
        $childLevels{$c} = [ $plan{$n}{level}+1 .. $MAXSLOT ];
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
#
# CAMPOS EDITADOS A MAO SOBREVIVEM. O gerador e dono so do que ele escreve (SpellType, using,
# RootSpellID, PowerLevel e UseCosts no .txt; UUID, Name, Using, RootSpellID, PowerLevel e UseCosts no
# .stats). Qualquer outro campo que alguem ponha numa variante -- duracao de status, numero de alvos
# por nivel de upcast, como o jogo base faz nas dele -- e guardado aqui e escrito de volta na variante
# recriada, dos dois lados. Pedido do usuario em 2026-09-27.
my %pending;
my $removed = 0;
my (%keepTxt, %keepStats, %generated, %generatedKey);
my %OWN_TXT   = map { $_ => 1 } qw(SpellType RootSpellID PowerLevel UseCosts ContainerSpells SpellContainerID);
my %OWN_STATS = map { $_ => 1 } qw(UUID Name Using RootSpellID PowerLevel UseCosts ContainerSpells SpellContainerID);
for my $f (bsd_glob("$base/Public/$mod/Stats/Generated/Data/Spell_*.txt")) {
    open my $fh,'<:raw',$f or die $!; local $/; my $s=<$fh>; close $fh; my $o=$s;
    my @keep;
    for my $b (split /(?=new entry )/, $s) {
        # o nome sai de $1 ANTES do proximo regex, que zera o $1 -- armadilha que ja pegou o lint
        my ($v) = $b =~ /^new entry "([^"]+)"/;
        if (defined $v && $v =~ $IS_VARIANT && $b =~ /data "RootSpellID"/) {
            my @extra = grep { /^data "(\w+)"/ && !$OWN_TXT{$1} } map { s/\r$//r } split /\n/, $b;
            $keepTxt{$v} = \@extra if @extra;
            $removed++; next;
        }
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
        my ($v) = $b =~ /<field name="Name"[^>]*value="([^"]+)"/;
        if (defined $v && "_$v" =~ $IS_VARIANT && $b =~ /name="RootSpellID"/) {
            my @extra = grep { /<field name="(\w+)"/ && !$OWN_STATS{$1} } map { s/\r$//r } split /\n/, $b;
            $keepStats{$v} = \@extra if @extra;
            next;
        }
        push @keep, $b;
    }
    $s = join('', @keep) . $tail;
    $pending{$f} = $s if $s ne $o;
}

# ---------- 4. gerar ----------
my (%txtAdd, %statsAdd, @log, @warn, $khnNote);
my $TYPES = qr/^(Target|Shout|Projectile|Zone|Teleportation)_/;
# uma variante, dos dois lados. $extra: campos de container, como [nome, valor]
sub emit_variant { my ($n, $L, $cost, @extra) = @_;
    (my $key = $n) =~ s/$TYPES//;
    my ($sptype) = $n =~ $TYPES;
    unless ($sptype) { push @warn, "  $n: nao consegui deduzir o SpellType"; return }
    unless ($fileAny{$n}) { push @warn, "  $n: nao achei no .txt"; return }
    unless ($baseUuid{$key}) { push @warn, "  $n sem UUID no Editor -- variante so no .txt"; }
    # O SpellType vai explicito e antes do `using`, como o vanilla escreve em 2276 de 2276
    # variantes. Herdar pelo `using` parece funcionar, mas nenhuma variante do jogo base faz isso.
    $txtAdd{$fileAny{$n}} .= join("\n",
        qq{new entry "${n}_$L"}, q{type "SpellData"}, qq{data "SpellType" "$sptype"},
        qq{using "$n"},
        (map { qq{data "$_->[0]" "$_->[1]"} } @extra),
        qq{data "RootSpellID" "$n"}, qq{data "PowerLevel" "$L"},
        qq{data "UseCosts" "$cost"}, @{ $keepTxt{"${n}_$L"} || [] }) . "\n\n";
    $generated{"${n}_$L"} = 1;
    if (my $bu = $baseUuid{$key}) {
        my $sf = $statsFileOf{$key};
        $statsAdd{$sf} .=
            qq{    <stat_object is_substat="false">\n      <fields>\n}
          . qq{        <field name="UUID" type="IdTableFieldDefinition" value="}.uuid("${key}_$L").qq{" />\n}
          . qq{        <field name="Name" type="NameTableFieldDefinition" value="${key}_$L" />\n}
          . qq{        <field name="Using" type="BaseClassTableFieldDefinition" value="$bu" />\n}
          . join('', map { qq{        <field name="$_->[0]" type="StringTableFieldDefinition" value="$_->[1]" />\n} } @extra)
          . qq{        <field name="RootSpellID" type="StringTableFieldDefinition" value="$n" />\n}
          . qq{        <field name="PowerLevel" type="IntegerTableFieldDefinition" value="$L" />\n}
          . qq{        <field name="UseCosts" type="StringTableFieldDefinition" value="$cost" />\n}
          . join('', map { "$_\n" } @{ $keepStats{"${key}_$L"} || [] })
          . qq{      </fields>\n    </stat_object>\n};
        $generatedKey{"${key}_$L"} = 1;
    }
    push @log, sprintf("  %-50s nivel %s", "${n}_$L", $L);
}
for my $n (sort keys %plan) {
    my ($lvl, $uc) = @{$plan{$n}}{qw(level usecosts)};
    push @warn, "  $n: filho '$_' do container nao existe" for @{ $plan{$n}{missing} || [] };
    push @warn, "  $n: filho '$_' tem variantes proprias -- o container nao as liga" for @{ $plan{$n}{ownPlan} || [] };
    my @kids = @{ $plan{$n}{children} || [] };
    for my $L ($lvl+1 .. $MAXSLOT) {
        (my $cost = $uc) =~ s/(SpellSlotsGroup:\d+:\d+):\d/$1:$L/;
        emit_variant($n, $L, $cost, @kids ? (['ContainerSpells', join(';', map { "${_}_$L" } @kids)]) : ());
        # cada filho: a sua "_L", dentro do container "_L", com o custo do nivel L
        emit_variant($_, $L, $cost, ['SpellContainerID', "${n}_$L"]) for @kids;
    }
}

# (4b, o helper IsDeceiverOneTargetSpell.khn com a lista de SpellId do Mirrored Charm, saiu em
# 2026-09-27: o Mirrored Self passou a escolher as magias por propriedade, em IsMirroredSelfSpell.khn,
# como o Twinned do jogo base, e nao precisa mais de lista nem de variante enumerada.)

# variante que era preservada e nao foi gerada de novo: a carta mudou de nivel ou de nome
for my $v (sort keys %keepTxt)   { push @warn, "  campos editados em $v se perderam: a variante nao existe mais" unless $generated{$v} }
for my $v (sort keys %keepStats) { push @warn, "  campos editados em $v (Editor) se perderam: a variante nao existe mais" unless $generatedKey{$v} }
$khnNote = sprintf("%d variante(s) com campos editados preservados", scalar keys %keepTxt);

# ---------- 4c. tabela de familias para o Osiris ----------
# O evento de conjurar (UsingSpell, CastSpell, UsingSpellOnTarget) entrega o nome da VARIANTE que o
# personagem pagou -- "..._5" --, nao o da carta. Confirmado no jogo em 2026-09-24: Distortion com
# upcast nao liberava o Withdraw, e Sigil/Ethereal nao aplicavam o status do Mimic. Por isso nenhuma
# regra do Story deve comparar nome de carta direto; ela pergunta
#     DB_ARCANA_CardFamily(_ArcanaSpell, "<carta>")
# e a tabela abaixo liga cada carta e cada variante a raiz. Ela e montada numa PROC chamada pelo
# INITSECTION (jogo novo) e pelo SavegameLoaded (save existente -- INITSECTION nao roda de novo em
# save antigo). O goal ARCANA_CardFamilies e so dela e e reescrito inteiro a cada execucao; a DB e
# global, entao qualquer goal a consulta.
{
    my $dir  = "$base/Mods/$mod/Story/RawFiles/Goals";
    my $goal = "$dir/ARCANA_CardFamilies.txt";
    # Os goals sao CRLF. O cat -A do Git Bash esconde o CR e ja enganou uma checagem minha, entao o
    # fim de linha e lido de um goal existente em vez de assumido.
    my $w = "$dir/ARCANA_Spell_Withdraw.txt";
    my $g = exists $pending{$w} ? $pending{$w} : do { open my $h,'<:raw',$w or die "$w: $!"; local $/; my $x=<$h>; close $h; $x };
    my $nl = ($g =~ /\r\n/) ? "\r\n" : "\n";
    my @facts;
    for my $r (sort keys %allRoots) {
        push @facts, qq{DB_ARCANA_CardFamily("$r", "$r");};
        push @facts, qq{DB_ARCANA_CardFamily("${r}_$_", "$r");}
            for ($plan{$r} ? ($plan{$r}{level}+1 .. $MAXSLOT) : @{ $childLevels{$r} || [] });
    }
    $pending{$goal} = join($nl,
        "Version 1", "SubGoalCombiner SGC_AND", "INITSECTION", "PROC_ARCANA_CardFamilies();", "",
        "KBSECTION",
        "// GERADO por gen_upcast_variants.pl -- nao edite a mao: rode o gerador de novo.",
        "// Regra que reage a uma carta pergunta DB_ARCANA_CardFamily(_ArcanaSpell, \"<carta>\"), porque o evento",
        "// de conjurar entrega o nome da variante paga (..._5), nao o da carta.",
        "PROC", "PROC_ARCANA_CardFamilies()", "THEN", @facts, "",
        "IF", "SavegameLoaded()", "THEN", "PROC_ARCANA_CardFamilies();",
        "EXITSECTION", "", "ENDEXITSECTION", "");
    # Ate 2026-09-26 a tabela morava no goal do Withdraw. Tira de la se ainda estiver.
    my $START = '//REGION Gerado por gen_upcast_variants.pl';
    my $o = $g;
    $g =~ s{\Q$START\E.*?//END_REGION\r?\n(?:\r?\n)?}{}s;
    $g =~ s{(INITSECTION\r?\n)PROC_ARCANA_CardFamilies\(\);\r?\n}{$1};
    $pending{$w} = $g if $g ne $o;
    $khnNote .= sprintf("; familias do Osiris (ARCANA_CardFamilies): %d cartas, %d linhas", scalar keys %allRoots, scalar @facts);
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
# Arrumacao de espaco em branco. Os arquivos sao CRLF e as variantes eram montadas com LF, e cada
# execucao deixava para tras uma linha em branco no .txt e uma linha so de espacos no .stats -- ja
# havia trechos com 15 quebras seguidas. Aqui o fim de linha vira o do proprio arquivo, o .txt fica
# com exatamente uma linha em branco entre entradas, e o .stats perde as linhas vazias.
for my $f (grep { /\.(?:txt|stats)$/ && !m{/Goals/} } keys %pending) {
    my $s = $pending{$f};
    my $nl = ($s =~ /\r\n/) ? "\r\n" : "\n";
    $s =~ s/\r?\n/$nl/g;
    if ($f =~ /\.txt$/) {
        $s =~ s/(?:[ \t]*\Q$nl\E){3,}/$nl$nl/g;
    } else {
        $s =~ s{</stat_object>[ \t]*<stat_object}{</stat_object>$nl    <stat_object}g;
        $s =~ s/(?<=\n)[ \t]*\Q$nl\E//g;
    }
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
