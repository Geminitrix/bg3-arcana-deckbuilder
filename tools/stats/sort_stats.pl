# Põe os arquivos de stats em ordem legível, dos dois lados (Public/*.txt e Editor/*.stats).
#
# O QUE ELE FAZ
#   1. Cada variante de upcast volta para junto da carta base, em ordem crescente de nível.
#      O gerador de variantes as despeja no fim do arquivo, debaixo da última divisória -- foi assim
#      que 96 magias do Eternal viraram 96 magias que não são do Eternal.
#   2. As divisórias de nível 1 (as que o autor já usava: "ARCANA SPELLS", "DECEIVER PASSIVES"…)
#      passam para a ordem DEBUG, Classe, Deceiver, Starchild, Unbound, Eternal. O que não é de
#      classe nenhuma (WEAPON, EQUIPMENT, BOON, CC SET) vai para o fim, para os seis ficarem juntos.
#   3. Dentro de cada divisória, ordem alfabética. Subdivisórias (REJUVENATION, SIGIL, NEMESIS…)
#      continuam onde estão e são ordenadas por dentro -- o agrupamento delas é intencional.
#   4. Depois de ordenar, quem herda com `using` é empurrado para depois do pai. O motor lê o
#      arquivo de cima para baixo, então filho antes de pai quebraria a herança.
#
#   perl sort_stats.pl            # mostra o que faria
#   perl sort_stats.pl --apply    # grava (jogo e Toolkit fechados)

use strict; use warnings;
use File::Glob ':bsd_glob';

my $D   = 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $M   = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my $DRY = (grep { $_ eq '--apply' } @ARGV) ? 0 : 1;

# ordem pedida; o que não cair aqui fica depois, na ordem em que aparecia
my @ORDER = qw(DEBUG ARCANA DECEIVER STARCHILD UNBOUND ETERNAL);
my %RANK; $RANK{$ORDER[$_]} = $_ for 0..$#ORDER;

# "DECIEVER" é um erro de digitação que existe no arquivo; tratado como DECEIVER e corrigido ao gravar
sub bucket_of {
    my $name = shift;
    $name =~ s/^(?:Target|Shout|Projectile|Zone|Teleportation)_//;
    return undef unless $name =~ /^([A-Z]+)[A-Z ]*$/;
    my $w = $1;
    $w = 'DECEIVER' if $w eq 'DECIEVER';
    return exists $RANK{$w} ? $w : undef;
}
sub is_divider {
    my $name = shift;
    $name =~ s/^(?:Target|Shout|Projectile|Zone|Teleportation)_//;
    return $name =~ /^[A-Z][A-Z ]*[A-Z]$/ ? 1 : 0;
}
sub core     { my $n = shift; $n =~ s/^(?:Target|Shout|Projectile|Zone|Teleportation)_//; $n }
sub upcast   { my $n = shift; $n =~ /^(.*)_([1-9])$/ ? ($1, $2) : ($n, 0) }
sub sortkey  { my ($b,$l) = upcast(core(shift)); sprintf "%s\x00%d", lc $b, $l }
sub parent_of {
    my $t = shift;
    my ($p) = $t =~ /^using "([^"]+)"/m;
    ($p) = $t =~ /<field name="Using"[^>]*value="([^"]+)"/ unless defined $p;
    return $p;
}
sub slurp    { open my $h,'<:raw',$_[0] or die "$_[0]: $!"; local $/; my $s=<$h>; close $h; $s }
sub new_uuid {
    my @h = map { sprintf "%04x", int(rand(65536)) } 1..8;
    $h[3] = sprintf("4%03x", hex($h[3]) & 0x0fff);
    $h[4] = sprintf("%04x", (hex($h[4]) & 0x3fff) | 0x8000);
    return "$h[0]$h[1]-$h[2]-$h[3]-$h[4]-$h[5]$h[6]$h[7]";
}

# ---------- leitura ----------
# Devolve (cabeçalho, \@itens, rodapé). Cada item: { name, text, div }
sub parse {
    my ($text, $kind) = @_;
    my ($split, $nameRe) = $kind eq 'txt'
        ? (qr/(?=new entry )/,  qr/^new entry "([^"]+)"/)
        # \s no fim é o que separa um <stat_object ...> do <stat_objects> que abre a lista
        : (qr/(?=<stat_object\s)/, qr/<field name="Name"[^>]*value="([^"]+)"/);
    my @chunks = split $split, $text;
    my $head = (@chunks && $chunks[0] !~ $nameRe) ? shift @chunks : '';
    my $tail = '';
    if ($kind eq 'stats' && @chunks && $chunks[-1] =~ s{(</stat_object>)(.*)$}{$1}s) { $tail = $2 }
    my @items;
    for my $c (@chunks) {
        my ($n) = $c =~ $nameRe;
        return (undef) unless defined $n;
        push @items, { name => $n, text => $c, div => is_divider($n) };
    }
    return ($head, \@items, $tail);
}

# ---------- reorganização ----------
sub reorganize {
    my ($items, $log, $label, $created) = @_;

    # blocos de nível 1: começam numa divisória de bloco (ou no começo do arquivo)
    my @blocks; my $cur;
    for my $it (@$items) {
        if ($it->{div} && defined bucket_of($it->{name})) {
            push @blocks, ($cur = { head => $it, groups => [ { head => undef, items => [] } ] });
        } elsif (!$cur) {
            push @blocks, ($cur = { head => undef, groups => [ { head => undef, items => [] } ] });
            push @{ $cur->{groups}[0]{items} }, $it unless $it->{div};
            push @{ $cur->{groups} }, { head => $it, items => [] } if $it->{div};
        } elsif ($it->{div}) {
            push @{ $cur->{groups} }, { head => $it, items => [] };     # subdivisória
        } else {
            push @{ $cur->{groups}[-1]{items} }, $it;
        }
    }

    # 0. tudo que se chama DEBUG vai para o bloco DEBUG. Se o arquivo não tiver um, ele é clonado
    #    de uma divisória que já exista ali -- assim o SpellType e a animação saem certos sozinhos.
    my ($dbg) = grep { $_->{head} && (bucket_of($_->{head}{name}) // '') eq 'DEBUG' } @blocks;
    my @stray = grep { !$_->{div} && $_->{name} =~ /DEBUG/ } map { @{ $_->{items} } } map { @{ $_->{groups} } } @blocks;
    if (@stray && !$dbg) {
        my ($model) = grep { $_->{head} } @blocks;
        if ($model) {
            my $h = $model->{head};
            (my $newName = $h->{name}) =~ s/(^(?:Target_|Shout_|Projectile_|Zone_|Teleportation_)?)[A-Z]+(\s)/$1DEBUG$2/;
            (my $txt = $h->{text}) =~ s/\Q$h->{name}\E/$newName/g;
            $txt =~ s/(name="UUID"[^>]*value=")[0-9a-f-]{36}(")/$1 . new_uuid() . $2/e;
            $dbg = { head => { name => $newName, text => $txt, div => 1 },
                     groups => [ { head => undef, items => [] } ] };
            push @blocks, $dbg;
            push @$created, $newName;
            push @$log, sprintf("  %-26s bloco DEBUG criado (%s)", $label, $newName);
        }
    }
    if ($dbg) {
        my $n = 0;
        for my $blk (@blocks) {
            next if $blk == $dbg;
            for my $g (@{ $blk->{groups} }) {
                my @keep;
                for my $it (@{ $g->{items} }) {
                    if ($it->{name} =~ /DEBUG/) { push @{ $dbg->{groups}[0]{items} }, $it; $n++ }
                    else { push @keep, $it }
                }
                $g->{items} = \@keep;
            }
        }
        push @$log, sprintf("  %-26s %d entradas DEBUG recolhidas", $label, $n) if $n;
    }

    # 1. cada variante volta para o grupo da sua base
    my %groupOf;
    for my $blk (@blocks) { for my $g (@{ $blk->{groups} }) { $groupOf{$_->{name}} = $g for @{ $g->{items} } } }
    my $moved = 0;
    for my $blk (@blocks) {
        for my $g (@{ $blk->{groups} }) {
            my @keep;
            for my $it (@{ $g->{items} }) {
                my ($base, $lvl) = upcast($it->{name});
                if ($lvl && $groupOf{$base} && $groupOf{$base} != $g) {
                    push @{ $groupOf{$base}{items} }, $it; $moved++;
                } else { push @keep, $it }
            }
            $g->{items} = \@keep;
        }
    }
    push @$log, sprintf("  %-26s %d variantes reagrupadas", $label, $moved) if $moved;

    # 2. ordem dos blocos. O que não é de classe nenhuma fica com rank 99 e cai para o fim,
    #    mantendo entre si a ordem em que já estava.
    my $i = 0;
    for my $blk (@blocks) {
        $blk->{seq} = $i++;
        my $w = $blk->{head} ? bucket_of($blk->{head}{name}) : undef;
        $blk->{rank} = defined $w ? $RANK{$w} : 99;
    }
    my @sorted = sort { $a->{rank} <=> $b->{rank} || $a->{seq} <=> $b->{seq} } @blocks;

    # 3. ordem alfabética dentro de cada grupo, variante logo depois da sua base
    for my $blk (@sorted) {
        for my $g (@{ $blk->{groups} }) {
            @{ $g->{items} } = sort {
                my ($na,$la) = upcast(core($a->{name}));
                my ($nb,$lb) = upcast(core($b->{name}));
                lc($na) cmp lc($nb) || $la <=> $lb;
            } @{ $g->{items} };
        }
    }

    # 4. pai de `using` sempre antes do filho
    my @out;
    for my $blk (@sorted) {
        push @out, $blk->{head} if $blk->{head};
        for my $g (@{ $blk->{groups} }) { push @out, $g->{head} if $g->{head}; push @out, @{ $g->{items} } }
    }
    # Um passe move um filho, e mover um pode desarrumar outro, então repete até estabilizar. O teto
    # é só contra ciclo de herança (A usa B, B usa A), que travaria aqui para sempre.
    my $fixes = 0;
    my $cap = 4 * @out + 20;
    while ($cap-- > 0) {
        my %at; $at{ $out[$_]{name} } = $_ for 0..$#out;
        my $again = 0;
        for my $k (0..$#out) {
            my $p = parent_of($out[$k]{text});
            next unless defined $p && exists $at{$p} && $at{$p} > $k;
            my ($child) = splice @out, $k, 1;                      # tira o filho
            my $j = 0; $j++ while $j <= $#out && $out[$j]{name} ne $p;
            # Põe depois do pai, mas atrás de duas coisas: das variantes do próprio pai, que têm de
            # ficar coladas nele, e dos irmãos que já estão ali e vêm antes dele -- senão dois filhos
            # empurrados para o mesmo pai saem invertidos.
            my $pcore = core($p);
            my $ins = $j + 1;
            while ($ins <= $#out) {
                my ($nb, $nl) = upcast(core($out[$ins]{name}));
                my $variante_do_pai = $nl && $nb eq $pcore;
                my $irmao_anterior  = (parent_of($out[$ins]{text}) // '') eq $p
                                   && sortkey($out[$ins]{name}) lt sortkey($child->{name});
                last unless $variante_do_pai || $irmao_anterior;
                $ins++;
            }
            splice @out, $ins, 0, $child;
            $fixes++; $again = 1; last;
        }
        last unless $again;
    }
    push @$log, "  $label: ciclo de 'using' -- ordem nao estabilizou" if $cap <= 0;
    push @$log, sprintf("  %-26s %d filhos movidos para depois do pai", $label, $fixes) if $fixes;
    return \@out;
}

# ---------- execução ----------
my @log; my @warn;
my @files = (
    (map { [ $_, 'txt' ] }   bsd_glob("$D/Public/$M/Stats/Generated/Data/*.txt")),
    (map { [ $_, 'stats' ] } bsd_glob("$D/Editor/Mods/$M/Stats/**/*.stats")),
    (map { [ $_, 'stats' ] } bsd_glob("$D/Editor/Mods/$M/Stats/*.stats")),
);
for my $spec (@files) {
    my ($f, $kind) = @$spec;
    (my $label = $f) =~ s{.*/}{};
    my $text = slurp($f);
    my ($head, $items, $tail) = parse($text, $kind);
    unless (defined $head) { push @warn, "  $label: entrada sem nome, arquivo intocado"; next }
    next unless @$items > 1;
    my @created;
    my $before = join "\x00", map { $_->{name} } @$items;
    my $out    = reorganize($items, \@log, $label, \@created);
    my $after  = join "\x00", map { $_->{name} } @$out;

    # rede de segurança: fora as divisórias que eu declarei criar, nenhuma entrada pode sumir nem aparecer
    $before = join "\x00", $before, @created if @created;
    if (join("\x00", sort split /\x00/, $before) ne join("\x00", sort split /\x00/, $after)) {
        push @warn, "  $label: o conjunto de entradas mudou -- NAO gravado"; next;
    }
    next if $before eq $after;
    my $new = $head . join('', map { $_->{text} } @$out) . $tail;
    unless ($DRY) { open my $h,'>:raw',$f or die $!; print $h $new; close $h }
}

print "== REORGANIZADO ==\n", (@log ? map {"$_\n"} @log : "  (nada a fazer)\n");
print "== AVISOS (", scalar @warn, ") ==\n", map {"$_\n"} @warn;
print $DRY ? "\n*** DRY RUN ***\n" : "\n*** GRAVADO ***\n";
