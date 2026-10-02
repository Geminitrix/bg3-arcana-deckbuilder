#!/usr/bin/perl
# Organiza os arquivos de stats, dos dois lados (Public/*.txt e Editor/*.stats), na mesma ordem.
# Regras pedidas pelo usuario em 2026-10-01 (a versao anterior ordenava em ordem alfabetica):
#
#   1. Uma divisoria por grupo, nesta ordem: DEBUG, ARCANA (a classe), DECEIVER, STARCHILD, UNBOUND,
#      ETERNAL, AWAKEN (o Despertar do Aspecto). WEAPON / EQUIPMENT / BOON / CC SET ficam no fim, como
#      estao. Arquivo sem divisoria ganha as que precisar; "DECIEVER STATUS" vira "DECEIVER POLYMORPHED STATUS" (nome de entrada vale
#      para o mod inteiro: fora do Status_BOOST a divisoria de status leva o tipo).
#   2. Quem e de quem sai das referencias, nao do lugar onde a entrada estava: as raizes sao as magias
#      das listas e as passivas das progressoes de cada subclasse; o Despertar sao as entradas Aspect.
#      Dali segue o que cada entrada aplica, desbloqueia ou dispara (status, explosao, reacao...). O que
#      duas subclasses usam fica onde ja estava (e aparece no relatorio).
#   3. Dentro do grupo, ordem de nivel: as magias pelo nivel da carta; o que ela usa (explosao, copia,
#      status) logo depois dela; as variantes de upcast (_2.._6, X_3..X_6) logo depois da base, em ordem
#      crescente. Passivas e reacoes seguem o nivel da progressao. O que nenhuma raiz alcanca vai para o
#      fim do grupo, em ordem alfabetica.
#   4. Pai de `using` sempre antes do filho -- o motor le de cima para baixo.
#
#   perl sort_stats.pl            # relatorio: o que mudaria de grupo, conflitos, orfaos (nao grava)
#   perl sort_stats.pl --apply    # grava (jogo e Toolkit fechados)
use strict; use warnings;
use Digest::MD5 qw(md5_hex);

my $G   = $ENV{BG3_DATA} // 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $M   = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my $PUB = "$G/Public/$M/Stats/Generated/Data";
my $EDS = "$G/Editor/Mods/$M/Stats";
my $apply   = grep { $_ eq '--apply' } @ARGV;
my $verbose = grep { $_ eq '--verbose' } @ARGV;

my @GROUPS = qw(DEBUG ARCANA DECEIVER STARCHILD UNBOUND ETERNAL AWAKEN);
my %GRANK; $GRANK{$GROUPS[$_]} = $_ for 0 .. $#GROUPS;
my %COLOR = (DEBUG => '#FF000000', ARCANA => '#FF000000', DECEIVER => '#FFFF69B4', STARCHILD => '#FF800080',
             UNBOUND => '#FFDAA520', ETERNAL => '#FF2F4F4F', AWAKEN => '#FF1E90FF');
my %PROGGROUP = (Arcana => 'ARCANA', Deceiver => 'DECEIVER', Starchild => 'STARCHILD', Unbound => 'UNBOUND', Eternal => 'ETERNAL');
# arquivos organizados: .txt => [.stats, tipo, sufixo da divisoria]. Armor/Character/Weapon nao sao de classe.
my %FILES = (
    Interrupt           => ['Stats/Interrupt.stats',              'InterruptData', 'INTERRUPTS'],
    Passive             => ['Stats/Passive.stats',                'PassiveData',   'PASSIVES'],
    Spell_Projectile    => ['SpellData/Projectile.stats',         'Projectile',    'SPELLS'],
    Spell_Rush          => ['SpellData/Rush.stats',               'Rush',          'SPELLS'],
    Spell_Shout         => ['SpellData/Shout.stats',              'Shout',         'SPELLS'],
    Spell_Target        => ['SpellData/Target.stats',             'Target',        'SPELLS'],
    Spell_Teleportation => ['SpellData/Teleportation.stats',      'Teleportation', 'SPELLS'],
    Spell_Zone          => ['SpellData/Zone.stats',               'Zone',          'SPELLS'],
    Status_BOOST        => ['StatusData/Status_BOOST.stats',      'BOOST',         'STATUS'],
    Status_DOWNED       => ['StatusData/Status_DOWNED.stats',     'DOWNED',        'STATUS'],
    Status_EFFECT       => ['StatusData/Status_EFFECT.stats',     'EFFECT',        'STATUS'],
    Status_INVISIBLE    => ['StatusData/Status_INVISIBLE.stats',  'INVISIBLE',     'STATUS'],
    Status_POLYMORPHED  => ['StatusData/Status_POLYMORPHED.stats','POLYMORPHED',   'STATUS'],
);
my $SPELLPFX = qr/^(?:Target|Shout|Projectile|Zone|Teleportation|Rush)_/;
# Despertar: entradas que existem por causa dele
my $AWAKEN_ROOT = qr/^(?:Arcana_Passive_Aspect_|ASPECT_|Interrupt_Arcana_Aspect_|(?:Target|Shout|Rush|Projectile)_Arcana_Created_Aspect_)/;

sub slurp { open my $h, '<:raw', $_[0] or die "$_[0]: $!"; local $/; my $s = <$h>; close $h; $s }
sub uuid_for { my @h = unpack '(A4)8', md5_hex("arcana-divider:" . shift); "$h[0]$h[1]-$h[2]-$h[3]-$h[4]-$h[5]$h[6]$h[7]" }
sub is_div  { (my $n = shift) =~ s/$SPELLPFX//; $n =~ /^[A-Z][A-Z ]*[A-Z]$/ && $n =~ / / }
sub div_word { (my $n = shift) =~ s/$SPELLPFX//; my ($w) = $n =~ /^([A-Z]+)/; $w = 'DECEIVER' if ($w // '') eq 'DECIEVER'; $w }

# ---------------------------------------------------------------- leitura dos .txt
my (%E, @ORDER);     # nome => { file, text, fields, using, div, cursec }
my (%TXT);           # arquivo => { head, crlf, items => [nomes] }
for my $f (sort keys %FILES) {
    my $p = "$PUB/$f.txt"; next unless -e $p;
    my $s = slurp($p); my $crlf = $s =~ /\r\n/ ? 1 : 0; $s =~ s/\r\n/\n/g;
    my @ch = split /(?=^new entry ")/m, $s; my $head = ($ch[0] // '') =~ /^new entry "/ ? '' : shift @ch;
    my ($sec, @names) = ('');
    for my $c (@ch) { my ($n) = $c =~ /^new entry "([^"]+)"/ or die "$f: bloco sem nome\n";
        $c =~ s/\s+\z//; my $div = is_div($n) ? 1 : 0; $sec = div_word($n) if $div;
        my %fl; $fl{$1} = $2 while $c =~ /^data "(\w+)" "(.*)"$/mg; my ($u) = $c =~ /^using "([^"]+)"/m;
        $E{$n} = { file => $f, text => $c, fields => \%fl, using => $u, div => $div, cursec => $sec };
        push @names, $n; push @ORDER, $n unless $div }
    $TXT{$f} = { head => $head, crlf => $crlf, items => \@names };
}
sub level { my $n = shift; my %seen;
    while (defined $n && $E{$n} && !$seen{$n}++) { return $E{$n}{fields}{Level} if defined $E{$n}{fields}{Level} && length $E{$n}{fields}{Level}; $n = $E{$n}{using} } undef }

# variantes: RootSpellID, ou "using X" com nome X_N
my (%VARS, %VAROF);
for my $n (@ORDER) { my $e = $E{$n}; my $root = $e->{fields}{RootSpellID};
    my $p = (defined $root && $E{$root}) ? $root : (defined $e->{using} && $n =~ /^\Q$e->{using}\E_(\d+)$/ ? $e->{using} : undef);
    next unless defined $p; $VAROF{$n} = $p; push @{ $VARS{$p} }, $n }
for my $p (keys %VARS) { @{ $VARS{$p} } = sort { (($a =~ /_(\d+)$/)[0] // 0) <=> (($b =~ /_(\d+)$/)[0] // 0) } @{ $VARS{$p} } }

# referencias: nomes de entradas citados nos campos (fora DisplayName/Description, que sao handles)
my %REF;
for my $n (@ORDER) { my %r;
    for my $k (keys %{ $E{$n}{fields} }) { next if $k =~ /^(?:DisplayName|Description|ExtraDescription|Icon|RootSpellID)$/;
        $r{$_} = 1 for grep { $_ ne $n && $E{$_} && !$E{$_}{div} } $E{$n}{fields}{$k} =~ /([A-Za-z][A-Za-z0-9_]*)/g }
    $REF{$n} = [ sort keys %r ] }

# ---------------------------------------------------------------- raizes (progressoes e listas)
my (%LIST, %PLIST);
{ my $s = slurp("$G/Public/$M/Lists/SpellLists.lsx");
  while ($s =~ /<node id="SpellList">(.*?)<\/node>/sg) { my $b = $1; my ($sp) = $b =~ /id="Spells" type="\w+" value="([^"]*)"/; my ($u) = $b =~ /id="UUID" type="\w+" value="([^"]*)"/;
      $LIST{$u} = [ grep { length } split /[;,]/, ($sp // '') ] if $u } }
{ my $s = slurp("$G/Public/$M/Lists/PassiveLists.lsx");
  while ($s =~ /<node id="PassiveList">(.*?)<\/node>/sg) { my $b = $1; my ($ps) = $b =~ /id="Passives" type="\w+" value="([^"]*)"/; my ($u) = $b =~ /id="UUID" type="\w+" value="([^"]*)"/;
      $PLIST{$u} = [ grep { length } split /[;,]/, ($ps // '') ] if $u } }
my %ROOT;    # grupo => [ [nome, chave_magia, chave_passiva] ]
{ my $s = slurp("$G/Public/$M/Progressions/Progressions.lsx");
  while ($s =~ /<node id="Progression">(.*?)<\/node>/sg) { my $b = $1; my %a; $a{$1} = $2 while $b =~ /id="(\w+)" type="\w+" value="([^"]*)"/g;
      my $g = $PROGGROUP{$a{Name} // ''} or next; my $L = $a{Level} // 99;
      for my $p (grep { length } split /;/, ($a{PassivesAdded} // '')) { push @{ $ROOT{$g} }, [$p, 'p', $L] }
      for my $sel (split /;/, ($a{Selectors} // '')) {
          if ($sel =~ /^(?:AddSpells|SelectSpells)\(([0-9a-f-]{36})/) { push @{ $ROOT{$g} }, [$_, 's', $L] for @{ $LIST{$1} // [] } }
          elsif ($sel =~ /^(?:SelectPassives|AddPassives)\(([0-9a-f-]{36})/) { push @{ $ROOT{$g} }, [$_, 'p', $L] for @{ $PLIST{$1} // [] } } }
      for my $sp (($a{Boosts} // '') =~ /UnlockSpell\((\w+)/g) { push @{ $ROOT{$g} }, [$sp, 's', $L] } } }

# ---------------------------------------------------------------- dono de cada entrada
my (%GRP, %WHY);
for my $n (@ORDER) {
    if ($n =~ /DEBUG/i)                                      { $GRP{$n} = 'DEBUG';  $WHY{$n} = 'nome' }
    elsif ($n =~ $AWAKEN_ROOT)                               { $GRP{$n} = 'AWAKEN'; $WHY{$n} = 'Despertar' } }
# WEAPON / EQUIPMENT / BOON / CC SET so valem para quem nenhuma raiz alcanca: uma publicacao do Toolkit ja
# despejou passivas do Despertar debaixo de EQUIPMENT PASSIVES.
sub keep_sec { my $c = $E{$_[0]}{cursec} // ''; length $c && !exists $GRANK{$c} && $c ne 'DECIEVER' ? $c : undef }
sub bfs { my ($starts, $ok) = @_; my (@q, %seen, @out) = (@$starts);
    while (@q) { my $n = shift @q; next if $seen{$n}++ || !$E{$n} || $E{$n}{div} || !$ok->($n); push @out, $n;
        push @q, @{ $VARS{$n} // [] }, @{ $REF{$n} // [] } } @out }
# a classe primeiro: o que ela da e de todos
for my $n (bfs([ map { $_->[0] } @{ $ROOT{ARCANA} // [] } ], sub { !exists $GRP{$_[0]} })) { $GRP{$n} = 'ARCANA'; $WHY{$n} = 'progressao Arcana' }
# subclasses: quem so uma alcanca e dela; quem varias alcancam fica onde estava
my %REACH;
for my $g (qw(DECEIVER STARCHILD UNBOUND ETERNAL)) {
    $REACH{$_}{$g} = 1 for bfs([ map { $_->[0] } @{ $ROOT{$g} // [] } ], sub { !exists $GRP{$_[0]} }) }
my @conflict;
for my $n (sort keys %REACH) { my @g = sort { $GRANK{$a} <=> $GRANK{$b} } keys %{ $REACH{$n} };
    if (@g == 1) { $GRP{$n} = $g[0]; $WHY{$n} = 'alcancado pela ' . lc $g[0] }
    else { my $cur = $E{$n}{cursec}; my ($keep) = grep { $_ eq ($cur eq 'DECIEVER' ? 'DECEIVER' : $cur) } @g;
           $GRP{$n} = 'ARCANA'; $WHY{$n} = 'compartilhado (vai para a classe): ' . join('/', @g); push @conflict, "$n (" . join('/', @g) . ") -> ARCANA" } }
# o Despertar alcanca o que sobrou
for my $n (bfs([ grep { ($GRP{$_} // '') eq 'AWAKEN' } @ORDER ], sub { my $x = $_[0]; !exists $GRP{$x} || $GRP{$x} eq 'AWAKEN' })) {
    next if exists $GRP{$n}; $GRP{$n} = 'AWAKEN'; $WHY{$n} = 'alcancado pelo Despertar' }
# O que so o Osiris aplica (copias do Mirror Image, Withdraw, os status de cada Aspecto...) nao aparece
# nos stats de ninguem. Se um goal cita a entrada e as outras entradas que ele cita sao todas de um grupo
# so, ela vai para esse grupo, logo depois da primeira delas (AFF).
my %AFF;
{ my $gd = "$G/Mods/$M/Story/RawFiles/Goals"; opendir my $dh, $gd or die "$gd: $!";
  my %goal; for my $gf (grep { /\.txt$/ } readdir $dh) { my $s = slurp("$gd/$gf"); $s =~ s{//[^\n]*}{}g;
      my (%seen, @names); for my $w ($s =~ /([A-Za-z][A-Za-z0-9_]*)/g) { push @names, $w if $E{$w} && !$E{$w}{div} && !$seen{$w}++ } $goal{$gf} = \@names }
  for my $n (@ORDER) { next if exists $GRP{$n} || $VAROF{$n};
      my (%g, $first);
      for my $gf (sort keys %goal) { next unless grep { $_ eq $n } @{ $goal{$gf} };
          for my $o (@{ $goal{$gf} }) { next if $o eq $n || !exists $GRP{$o} || $GRP{$o} =~ /^KEEP:/; $g{ $GRP{$o} } = 1; $first //= $o } }
      next unless keys %g == 1; my ($grp) = keys %g;
      $GRP{$n} = $grp; $WHY{$n} = "goal do Osiris (junto de $first)"; $AFF{$n} = $first } }
# Cartas que o baralho do SE cria (CardDB.lua, "conjures"): ficam junto da carta que as cria.
{ my $db = "$G/Mods/$M/ScriptExtender/Lua/Server/Cards/CardDB.lua";
  if (-e $db) { my $s = slurp($db);
      while ($s =~ /\["(\w+)"\]\s*=\s*\{((?:(?!\n    \["|\n\}).)*?conjures\s*=\s*\{.*?)\n    \}/sg) { my ($card, $b) = ($1, $2);
          for my $c ($b =~ /id\s*=\s*"(\w+)"/g) { next if exists $GRP{$c} || !$E{$c} || !exists $GRP{$card};
              $GRP{$c} = $GRP{$card}; $WHY{$c} = "criada por $card (CardDB)"; $AFF{$c} = $card } } } }
# Pelo nome: o status auxiliar fica com quem tem o mesmo nome-base (NEMESIS com NEMESIS_OWNER,
# ETERNAL_UNDYING_DOWNED com ETERNAL_UNDYING, Mirror Withdraw com Mimic Withdraw...).
sub core_name { my $n = lc shift; $n =~ s/^(?:target|shout|projectile|zone|teleportation|rush)_//; $n =~ s/^(?:arcana|deceiver)_//;
    $n =~ s/^(?:passive|card_spell|card_passive|card_ability|created|util|reaction|clone)_//; $n =~ s/^(?:mirror|mimic)//; $n }
for my $pass (1 .. 2) { for my $n (@ORDER) { next if exists $GRP{$n} || $VAROF{$n};
    my $cn = core_name($n); my @tok = split /_/, $cn; my ($best, $bl) = (undef, 0);
    for my $o (@ORDER) { next if $o eq $n || !exists $GRP{$o} || $GRP{$o} =~ /^KEEP:/;
        my @t2 = split /_/, core_name($o); my $k = 0; $k++ while $k < @tok && $k < @t2 && $tok[$k] eq $t2[$k];
        my $whole = $k == @tok || $k == @t2;            # um nome contem o outro inteiro
        next unless $k >= 2 || ($whole && $k >= 1 && length($tok[0]) >= 6);
        ($best, $bl) = ($o, $k) if $k > $bl }
    next unless $best; $GRP{$n} = $GRP{$best}; $WHY{$n} = "nome parecido com $best"; $AFF{$n} = $best } }
# variante segue a base; o resto fica na secao em que estava
my @orphan;
for my $n (@ORDER) { next if exists $GRP{$n};
    if ($VAROF{$n} && exists $GRP{ $VAROF{$n} }) { $GRP{$n} = $GRP{ $VAROF{$n} }; $WHY{$n} = 'variante'; next }
    if (defined(my $k = keep_sec($n))) { $GRP{$n} = "KEEP:$k"; $WHY{$n} = 'secao fora das classes'; next }
    my $c = $E{$n}{cursec}; $c = 'DECEIVER' if ($c // '') eq 'DECIEVER';
    $GRP{$n} = exists $GRANK{$c // ''} ? $c : 'ARCANA'; $WHY{$n} = 'orfao (mantido)'; push @orphan, "$n [$E{$n}{file}] -> $GRP{$n}" }
for my $n (@ORDER) { $GRP{$n} = $GRP{ $VAROF{$n} } if $VAROF{$n} && $GRP{$n} ne $GRP{ $VAROF{$n} } }

# ---------------------------------------------------------------- ordem dentro do grupo
# Ancora: a primeira raiz (na ordem de nivel) cuja busca alcanca a entrada, e a posicao nessa busca.
my (%ANC_S, %ANC_P);
for my $g (@GROUPS) {
    my @roots = @{ $ROOT{$g} // [] };
    push @roots, map { [$_, 'a', 0] } grep { $GRP{$_} eq $g && $_ =~ $AWAKEN_ROOT } @ORDER if $g eq 'AWAKEN';
    my %rk; for my $r (@roots) { my ($n, $k, $L) = @$r; my $lv = $k eq 's' ? (level($n) // 9) : 9;
        my $key = $k eq 's' ? [0, $lv, $L] : $k eq 'p' ? [1, $L, 0] : [2, 0, 0];
        $rk{$n} = $key if !$rk{$n} || "@$key" lt "@{ $rk{$n} }" }
    my @s = sort { $rk{$a}[0] <=> $rk{$b}[0] || $rk{$a}[1] <=> $rk{$b}[1] || $rk{$a}[2] <=> $rk{$b}[2] || $a cmp $b } keys %rk;
    my @p = sort { ($rk{$a}[0] == 1 ? 0 : 1) <=> ($rk{$b}[0] == 1 ? 0 : 1) || $rk{$a}[1] <=> $rk{$b}[1] || $rk{$a}[2] <=> $rk{$b}[2] || $a cmp $b } keys %rk;
    for my $pair ([\@s, \%ANC_S], [\@p, \%ANC_P]) { my ($list, $anc) = @$pair;
        for my $i (0 .. $#$list) { my $pos = 0;
            for my $n (bfs([ $list->[$i] ], sub { ($GRP{$_[0]} // '') eq $g })) { $anc->{$n} //= [$i, $pos++] } } } }
# quem veio pelo goal fica logo depois da entrada que o trouxe
for my $anc (\%ANC_S, \%ANC_P) { my $i = 0;
    for my $n (sort keys %AFF) { my $a = $anc->{ $AFF{$n} } or next; $anc->{$n} //= [ $a->[0], $a->[1] + 0.5 + 0.001 * $i++ ] } }
# Quem copia uma carta fica logo depois dela, nao onde a busca o achou: o Mimic (que herda a carta com
# `using`) e as copias do Mirror Image (mesmo nome-base). Raizes das listas mantem o proprio nivel.
my %ISROOT; $ISROOT{ $_->[0] } = 1 for map { @$_ } values %ROOT;
my %CARD_BY_CORE; for my $n (@ORDER) { next if $VAROF{$n} || !$ISROOT{$n} || $n !~ $SPELLPFX; $CARD_BY_CORE{ $GRP{$n} }{ core_name($n) } //= $n }
for my $anc (\%ANC_S, \%ANC_P) {
    for my $n (@ORDER) { next if $VAROF{$n} || $ISROOT{$n}; my $g = $GRP{$n};
        my $p = $E{$n}{using}; my ($to, $off);
        if (defined $p && ($GRP{$p} // '') eq $g && !$VAROF{$p} && $ISROOT{$p}) { ($to, $off) = ($p, 0.5) }
        elsif (my $c = $CARD_BY_CORE{$g}{ core_name($n) }) { ($to, $off) = ($c, $n =~ /Mirror/ ? 0.7 : 0.6) unless $c eq $n }
        next unless $to && $anc->{$to}; $anc->{$n} = [ $anc->{$to}[0], $anc->{$to}[1] + $off ] } }
sub anchor_cmp { my ($anc, $a, $b) = @_; my ($x, $y) = ($anc->{$a}, $anc->{$b});
    return ($x ? 0 : 1) <=> ($y ? 0 : 1) || ($x && $y ? ($x->[0] <=> $y->[0] || $x->[1] <=> $y->[1]) : 0) || lc $a cmp lc $b }

# ---------------------------------------------------------------- montagem por arquivo
my (@log, @warn, %out);
for my $f (sort keys %TXT) {
    my ($statsRel, $type, $suffix) = @{ $FILES{$f} };
    my $anc = $f =~ /^(?:Passive|Interrupt)$/ ? \%ANC_P : \%ANC_S;
    my @items = grep { !$E{$_}{div} } @{ $TXT{$f}{items} };
    my @divs  = grep { $E{$_}{div} } @{ $TXT{$f}{items} };
    my %divFor; for my $d (@divs) { my $w = div_word($d); $divFor{ $w eq 'DECEIVER' || $w eq 'DECIEVER' ? 'DECEIVER' : $w } //= $d }
    # grupos e secoes
    my (%by, @keepOrder);
    for my $n (@items) { my $g = $GRP{$n}; push @{ $by{$g} }, $n }
    my @secs = grep { $by{$_} } @GROUPS;
    my %seenKeep; for my $n (@items) { my $g = $GRP{$n}; push @keepOrder, $g if $g =~ /^KEEP:/ && !$seenKeep{$g}++ }
    # divisorias: as que existem ficam (mesmo vazias); faltando, cria
    my @newDivs; my $pfx = $f =~ /^Spell_/ ? "${type}_" : '';
    for my $g (@secs) { next if $divFor{$g};
        # o nome de uma entrada vale para o mod inteiro: fora do Status_BOOST a divisoria leva o tipo
        my $name = $f =~ /^Status_/ && $type ne 'BOOST' ? "$g $type $suffix" : "$pfx$g $suffix";
        die "$f: divisoria $name ja existe em $E{$name}{file}\n" if $E{$name};
        $divFor{$g} = $name; push @newDivs, $name;
        my $t = qq{new entry "$name"\ntype "} . ($f =~ /^Spell_/ ? 'SpellData' : $f =~ /^Status_/ ? 'StatusData' : $type) . qq{"};
        $t .= qq{\ndata "SpellType" "$type"} if $f =~ /^Spell_/; $t .= qq{\ndata "StatusType" "$type"} if $f =~ /^Status_/;
        $E{$name} = { file => $f, text => $t, fields => {}, div => 1, new => 1, group => $g } }
    my @order;
    my %emitted;
    my $emit; $emit = sub { my $n = shift; return if $emitted{$n}++; push @order, $n; $emit->($_) for @{ $VARS{$n} // [] } };
    for my $g (@secs, @keepOrder) {
        my $d = $g =~ /^KEEP:(.*)/ ? (grep { div_word($_) eq $1 } @divs)[0] : $divFor{$g};
        push @order, $d if defined $d;
        # variante cuja base esta na mesma secao sai junto com ela (pelo $emit)
        my %inGroup = map { $_ => 1 } @{ $by{$g} };
        my @base = grep { !($VAROF{$_} && $inGroup{ $VAROF{$_} }) } @{ $by{$g} };
        @base = sort { anchor_cmp($anc, $a, $b) } @base;
        $emit->($_) for @base;
    }
    # divisorias que ficaram sem grupo (vazias) vao para o fim da parte de classes, sem perder nada
    my %inOrder = map { $_ => 1 } @order; push @order, grep { !$inOrder{$_} } @divs;
    # pai de using antes do filho
    my $cap = 4 * @order + 20; my $fixes = 0;
    while ($cap-- > 0) { my %at; $at{ $order[$_] } = $_ for 0 .. $#order; my $again = 0;
        for my $k (0 .. $#order) { my $p = $E{ $order[$k] }{using}; next unless defined $p && exists $at{$p} && $at{$p} > $k;
            my ($c) = splice @order, $k, 1; my $j = 0; $j++ while $order[$j] ne $p; my $ins = $j + 1;
            $ins++ while $ins <= $#order && ($VAROF{ $order[$ins] } // '') eq $p; splice @order, $ins, 0, $c; $fixes++; $again = 1; last }
        last unless $again }
    push @warn, "$f: ciclo de using" if $cap <= 0;
    my %a = map { $_ => 1 } @{ $TXT{$f}{items} }, @newDivs; my %b = map { $_ => 1 } @order;
    die "$f: conjunto de entradas mudou\n" if join("\0", sort keys %a) ne join("\0", sort keys %b);
    my $moved = 0; for my $n (@items) { $moved++ if ($GRP{$n} =~ /^KEEP:(.*)/ ? $1 : $GRP{$n}) ne (($E{$n}{cursec} // '') eq 'DECIEVER' ? 'DECEIVER' : ($E{$n}{cursec} // '')) }
    push @log, sprintf "%-20s %4d entradas, %3d mudam de secao, %d divisoria(s) nova(s)%s%s", $f, scalar @items, $moved, scalar @newDivs,
        (@newDivs ? " [" . join(', ', @newDivs) . "]" : ''), ($fixes ? ", $fixes filho(s) depois do pai" : '');
    $out{$f} = { order => \@order, stats => $statsRel, newDivs => \@newDivs };
}

# ---------------------------------------------------------------- relatorio
print "== POR ARQUIVO ==\n", map { "  $_\n" } @log;
print "\n== COMPARTILHADOS (", scalar @conflict, ") -- usados por mais de uma subclasse: vao para ARCANA ==\n", map { "  $_\n" } @conflict;
print "\n== ORFAOS (", scalar @orphan, ") -- nenhuma raiz alcanca; ficam na secao em que estavam ==\n", map { "  $_\n" } @orphan;
if ($verbose) { print "\n== ORDEM ==\n";
    for my $f (sort keys %out) { print "-- $f\n"; for my $n (@{ $out{$f}{order} }) { print $E{$n}{div} ? "  [$n]\n" : sprintf("    %-60s %-9s L%-2s %s\n", $n, $GRP{$n}, level($n) // '-', $WHY{$n}) } } }
print "\n== AVISOS ==\n", map { "  $_\n" } @warn;

# ---------------------------------------------------------------- gravacao
exit 0 unless $apply;
for my $f (sort keys %out) {
    my $o = $out{$f}; my $nl = $TXT{$f}{crlf} ? "\r\n" : "\n";
    my $txt = $TXT{$f}{head} . join('', map { "$E{$_}{text}\n\n" } @{ $o->{order} }); $txt =~ s/\n/$nl/g if $TXT{$f}{crlf};
    # .stats: mesmos objetos, mesma ordem; o nome no .stats nao tem o prefixo do tipo de magia
    my $sp = "$EDS/$o->{stats}"; my $s = slurp($sp); my $bom = $s =~ s/^\xEF\xBB\xBF// ? "\xEF\xBB\xBF" : '';
    my $snl = $s =~ /\r\n/ ? "\r\n" : "\n";
    my ($head, $body, $tail) = $s =~ /\A(.*?<stat_objects>)(.*)(\s*<\/stat_objects>.*)\z/s or die "$sp: sem <stat_objects>\n";
    my ($ind) = $body =~ /\n([ \t]*)<stat_object\b/; $ind //= '    ';
    my %obj; while ($body =~ /(<stat_object\b.*?<\/stat_object>)/sg) { my $c = $1; my ($n) = $c =~ /<field name="Name"[^>]*value="([^"]*)"/; $obj{$n} = $c }
    my @parts;
    for my $n (@{ $o->{order} }) { my $sn = $n; $sn =~ s/$SPELLPFX// if $f =~ /^Spell_/;
        if ($E{$n}{new}) { my $g = $E{$n}{group}; my $i2 = "$ind  "; my $i3 = "$ind    ";
            push @parts, qq{<stat_object color="$COLOR{$g}" is_substat="false">$snl$i2<fields>$snl$i3<field name="UUID" type="IdTableFieldDefinition" value="} . uuid_for("$f/$n") . qq{" />$snl$i3<field name="Name" type="NameTableFieldDefinition" value="$sn" />$snl$i2</fields>$snl$ind</stat_object>}; next }
        my $c = delete $obj{$sn}; die "$sp: $sn nao existe no .stats\n" unless defined $c;
        $c =~ s/value="DECIEVER STATUS"/value="DECEIVER POLYMORPHED STATUS"/; push @parts, $c }
    die "$sp: objetos sem par no .txt: " . join(', ', sort keys %obj) . "\n" if %obj;
    my $new = $bom . $head . join('', map { "$snl$ind$_" } @parts) . $tail;
    $txt =~ s/new entry "DECIEVER STATUS"/new entry "DECEIVER POLYMORPHED STATUS"/;
    for ([ "$PUB/$f.txt", $txt ], [ $sp, $new ]) { open my $h, '>:raw', $_->[0] or die $!; print $h $_->[1]; close $h }
}
print "\n*** GRAVADO ***\n";
