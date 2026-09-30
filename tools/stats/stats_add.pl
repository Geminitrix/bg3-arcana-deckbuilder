#!/usr/bin/perl
# Aplica patches de stats nos dois lados do mod -- Public/*.txt (o jogo) e Editor/*.stats (o Toolkit) --
# e as strings em ingles no english.xml. Um publish do Toolkit regera o Public a partir do .stats, entao
# o que so existe no .txt some; escrever os dois lados a mao foi a fonte classica de erro.
#
#   perl stats_add.pl a.patch [b.patch ...]            # mostra o que faria
#   perl stats_add.pl a.patch [b.patch ...] --apply    # grava (jogo e Toolkit fechados)
#   perl stats_add.pl --selftest                       # regera o .stats de cada entrada existente e compara
#
# Formato do patch (LF):
#   # comentario
#   @file Status_BOOST          arquivo Public (sem .txt) das entradas seguintes
#   @section UNBOUND STATUS     divisoria sob a qual entradas NOVAS entram ("-" = fim do arquivo)
#   @remove NOME                apaga a entrada dos dois lados (aviso se nao existir)
#   @set NOME CAMPO VALOR...    troca ou acrescenta um campo de uma entrada existente
#   @loca CHAVE Texto...        string em ingles. CHAVE livre = handle novo e deterministico;
#                               CHAVE = handle existente = texto trocado e versao +1 em todo lugar
#   new entry "X" ... (ate a linha em branco)   entrada completa; substitui se ja existir no mesmo arquivo
# Em qualquer valor, {{CHAVE}} ou {{hXXXX...}} vira "handle;versao".
use strict; use warnings;
use Digest::MD5 qw(md5_hex);

my $GAME = $ENV{BG3_DATA} // 'C:/Program Files (x86)/Steam/steamapps/common/Baldurs Gate 3/Data';
my $MOD  = 'AspectClass_9d734fbd-cb67-95c0-e2c9-46f05fe2f8a7';
my $PUB  = "$GAME/Public/$MOD/Stats/Generated/Data";
my $EDS  = "$GAME/Editor/Mods/$MOD/Stats";
my $LOCA = "$GAME/Mods/$MOD/Localization/English/english.xml";
my @VANILLA = map { "$GAME/Editor/Mods/$_/Stats" } qw(Shared SharedDev Gustav GustavDev GustavX);
my %NEW_DEF = ('SpellData/Rush' => 'bbe0e72e-fa2a-41d2-be9a-c604af561421');   # de Editor/Mods/Shared/Stats/SpellData/Rush.stats
# campos com nome diferente no .txt (jogo) e no .stats (Toolkit)
my %ALIAS = (WeaponTypes => "WeaponType", SpellAnimationIntentType => "AnimationIntentType", ValueOverride => "Value", MemoryCost => "SpellPrepareCost");
my $LENIENT = 0;   # selftest: campo que so existe no .txt (MemoryCost, ValueOverride...) e pulado

my $apply    = grep { $_ eq '--apply' } @ARGV;
my $selftest = grep { $_ eq '--selftest' } @ARGV;
my @patches  = grep { !/^--/ } @ARGV;

# ---------- io: preserva BOM e CRLF de cada arquivo ----------
my %orig;
sub slurp { my $p = shift; open my $fh, '<:raw', $p or return undef; local $/; my $s = <$fh>; close $fh;
    my $bom = ($s =~ s/^\xEF\xBB\xBF//) ? 1 : 0; my $crlf = ($s =~ /\r\n/) ? 1 : 0; $s =~ s/\r\n/\n/g;
    $orig{$p} = { bom => $bom, crlf => $crlf }; return $s }
sub spew { my ($p, $s) = @_; my $o = $orig{$p} // { bom => 0, crlf => 1 };
    $s =~ s/\n/\r\n/g if $o->{crlf}; $s = "\xEF\xBB\xBF$s" if $o->{bom};
    open my $fh, '>:raw', $p or die "$p: $!"; print $fh $s; close $fh }
sub files_under { my ($dir, $re) = @_; my @out; opendir my $d, $dir or return ();
    for my $f (sort readdir $d) { next if $f =~ /^\./; my $p = "$dir/$f";
        if (-d $p) { push @out, files_under($p, $re) } elsif ($f =~ $re) { push @out, $p } } @out }

sub det_uuid { my @h = unpack '(A4)8', md5_hex("arcana-aspect:" . shift); "$h[0]$h[1]-$h[2]-$h[3]-$h[4]-$h[5]$h[6]$h[7]" }
sub det_handle { my $h = md5_hex("arcana-aspect-loca:" . shift);
    'h' . substr($h,0,8) . 'g' . substr($h,8,4) . 'g' . substr($h,12,4) . 'g' . substr($h,16,4) . 'g' . substr($h,20,12) }

# ---------- Public basename <-> Editor .stats ----------
sub stats_rel { my $pub = shift;
    return "SpellData/$1" if $pub =~ /^Spell_(\w+)$/;
    return "StatusData/$pub" if $pub =~ /^Status_/;
    return "Stats/$pub" }
sub stats_name { my ($pub, $n) = @_; return $n unless $pub =~ /^Spell_(\w+)$/; my $t = $1;
    $n =~ s/^\Q$t\E_// or die "$n: magia sem o prefixo ${t}_\n"; $n }

# ---------- aprende tipos de campo e UUIDs (mod primeiro, depois vanilla) ----------
my (%ftype, %uuid_of);
my $FIELD = qr{<field name="(\w+)" type="(\w+)"((?:\s+\w+="[^"]*")*)\s*/>};
sub learn { my $root = shift;
    for my $f (files_under($root, qr/\.stats$/)) {
        (my $rel = $f) =~ s{^\Q$root\E/}{}; $rel =~ s/\.stats$//;
        my $s = slurp($f) // next;
        for my $obj ($s =~ /<stat_object\b.*?<\/stat_object>/gs) {
            my ($name) = $obj =~ /<field name="Name" type="\w+" value="([^"]*)"/;
            my ($uuid) = $obj =~ /<field name="UUID" type="\w+" value="([^"]*)"/;
            if (defined $name && defined $uuid) {
                my $full = $rel =~ m{^SpellData/(\w+)$} ? "$1_$name" : $name; $uuid_of{$full} //= $uuid }
            while ($obj =~ /$FIELD/g) { my ($fn, $ty, $rest) = ($1, $2, $3);
                next if $rest =~ /clear_inherited_value/;
                (my $tail = $rest) =~ s/\s+(?:value|handle)="[^"]*"//g;
                $tail =~ s/\s+version="\d+"// if $ty eq 'TranslatedStringTableFieldDefinition';
                $ftype{$rel}{$fn} //= [$ty, $tail] } } } }

# ---------- .txt ----------
my %blocks;   # path -> [blocks]
sub blocks_of { my $pub = shift; my $p = "$PUB/$pub.txt";
    $blocks{$p} //= do { my $s = slurp($p); if (!defined $s) { $orig{$p} = { bom => 0, crlf => 1 }; $s = '' }
        $s =~ s/^\s+|\s+$//g; [ grep { length } split /\n{2,}/, $s ] };
    ($p, $blocks{$p}) }
sub bname { $_[0] =~ /^new entry "([^"]+)"/ ? $1 : '' }
sub is_divider { bname($_[0]) =~ / / }
sub parse_entry { my %e = (data => []);
    for my $l (split /\n/, shift) {
        if    ($l =~ /^new entry "([^"]+)"/)      { $e{name} = $1 }
        elsif ($l =~ /^type "([^"]+)"/)           { $e{type} = $1 }
        elsif ($l =~ /^using "([^"]+)"/)          { $e{using} = $1 }
        elsif ($l =~ /^data "([^"]+)" "(.*)"\s*$/) { push @{$e{data}}, [$1, $2] } }
    \%e }
sub all_pubs { map { m{/([^/]+)\.txt$} ? $1 : () } files_under($PUB, qr/\.txt$/) }
sub find_entry { my $name = shift;
    for my $pub (all_pubs()) { my (undef, $tb) = blocks_of($pub);
        for my $i (0..$#$tb) { return ($pub, $i) if bname($tb->[$i]) eq $name } }
    () }

# ---------- .stats ----------
my %stats;   # path -> {head, objs, foot}
sub stats_of { my $pub = shift; my $rel = stats_rel($pub); my $p = "$EDS/$rel.stats";
    $stats{$p} //= do { my $s = slurp($p);
        if (!defined $s) { my $def = $NEW_DEF{$rel} // die "$rel.stats nao existe e nao sei o stat_object_definition_id\n";
            $orig{$p} = { bom => 1, crlf => 1 };
            $s = qq{<?xml version="1.0" encoding="utf-8"?>\n<stats stat_object_definition_id="$def">\n  <stat_objects />\n</stats>\n} }
        $s =~ s{<stat_objects />}{<stat_objects>\n  </stat_objects>};
        my ($head, $body, $foot) = $s =~ m{^(.*?<stat_objects>\n)(.*?)(\n?\s*</stat_objects>.*)$}s or die "$p: formato inesperado\n";
        { head => $head, objs => [ $body =~ /( *<stat_object\b.*?<\/stat_object>)/gs ], foot => $foot } };
    ($p, $stats{$p}) }
sub oname  { $_[0] =~ /<field name="Name" type="\w+" value="([^"]*)"/ ? $1 : '' }
sub ouuid  { $_[0] =~ /<field name="UUID" type="\w+" value="([^"]*)"/ ? $1 : '' }
sub ocolor { $_[0] =~ /<stat_object color="([^"]*)"/ ? $1 : undef }
sub xml_attr { my $v = shift; $v =~ s/&/&amp;/g; $v =~ s/	/&#x9;/g; $v =~ s/</&lt;/g; $v =~ s/>/&gt;/g; $v =~ s/"/&quot;/g; $v }
sub field_line { my ($n, $t, $a) = @_; qq{<field name="$n" type="$t" $a />} }
sub build_field { my ($rel, $ename, $k, $v) = @_;
    $k = $ALIAS{$k} // $k;
    my $t = $ftype{$rel}{$k};
    # um campo comum tem o mesmo tipo em todo tipo de magia (ou de status); o Rush.stats do vanilla, por
    # exemplo, so tem weapon actions e nao traz Level nem SpellSchool
    if (!$t && $rel =~ m{^(SpellData|StatusData)/}) { my $kind = $1;
        for my $o (sort grep { m{^\Q$kind\E/} } keys %ftype) { $t = $ftype{$o}{$k} and last } }
    return undef if !$t && $LENIENT; $t // die "$ename: campo $k sem tipo conhecido em $rel\n"; my ($ty, $tail) = @$t;
    if ($ty eq 'TranslatedStringTableFieldDefinition') {
        return field_line($k, $ty, 'clear_inherited_value="true"') if $v eq '';
        my ($h, $ver) = $v =~ /^(h[0-9a-g]+);(\d+)$/ or die "$ename: $k nao e handle;versao: $v\n";
        return field_line($k, $ty, qq{handle="$h" version="$ver"}) }
    return field_line($k, $ty, 'clear_inherited_value="true" value=""' . $tail) if $v eq '';
    $v = $v eq "1" ? "True" : $v eq "0" ? "False" : $v if $ty eq "BoolTableFieldDefinition";
    field_line($k, $ty, 'value="' . xml_attr($v) . '"' . $tail) }
sub build_obj { my ($pub, $e, $uuid, $color) = @_; my $rel = stats_rel($pub);
    my @f = (field_line('UUID', 'IdTableFieldDefinition', qq{value="$uuid"}),
             field_line('Name', 'NameTableFieldDefinition', 'value="' . xml_attr(stats_name($pub, $e->{name})) . '"'));
    if (defined $e->{using}) { my $u = $uuid_of{$e->{using}} // die "$e->{name}: using $e->{using} sem UUID conhecido\n";
        push @f, field_line('Using', 'BaseClassTableFieldDefinition', qq{value="$u"}) }
    for my $d (@{$e->{data}}) { my ($k, $v) = @$d; next if $k eq 'SpellType' || $k eq 'StatusType';
        my $line = build_field($rel, $e->{name}, $k, $v); push @f, $line if defined $line }
    my $open = defined $color ? qq{<stat_object color="$color" is_substat="false">} : qq{<stat_object is_substat="false">};
    "    $open\n      <fields>\n" . join('', map { "        $_\n" } @f) . "      </fields>\n    </stat_object>" }

# ---------- selftest ----------
sub norm_fields { my $obj = shift; my %f;
    while ($obj =~ /$FIELD/g) { my ($n, $t, $r) = ($1, $2, $3); next if $n eq 'UUID';
        my %a = $r =~ /(\w+)="([^"]*)"/g;
        # uma filha que sobrescreve o campo do pai ganha clear_inherited_value no Toolkit; o .txt nao diz isso
        delete $a{clear_inherited_value} if length($a{value} // '') || exists $a{handle};
        $f{$n} = join '|', $t, map { "$_=$a{$_}" } sort keys %a } \%f }
sub run_selftest {
    $LENIENT = 1;
    learn($EDS); learn($_) for @VANILLA;
    my ($ok, $bad, $missing) = (0, 0, 0);
    for my $pub (all_pubs()) { my $sp = "$EDS/" . stats_rel($pub) . ".stats"; next unless -e $sp;
        my (undef, $tb) = blocks_of($pub); my (undef, $st) = stats_of($pub);
        my %by = map { oname($_) => $_ } @{$st->{objs}};
        for my $blk (@$tb) { my $e = parse_entry($blk); my $sn = eval { stats_name($pub, $e->{name}) } // $e->{name};
            my $have = $by{$sn}; if (!$have) { $missing++; print "  sem .stats: $pub $e->{name}\n" if $missing <= 10; next }
            my $gen = eval { build_obj($pub, $e, ouuid($have), ocolor($have)) };
            if (!$gen) { $bad++; print "  ERRO $pub $e->{name}: $@" if $bad <= 30; next }
            my ($a, $b) = (norm_fields($have), norm_fields($gen));
            my @diff = grep { ($a->{$_} // '') ne ($b->{$_} // '') } sort keys %{{ %$a, %$b }};
            if (@diff) { $bad++; if ($bad <= 30) { print "  DIFERE $pub $e->{name}:\n";
                    print "    $_\n      tem: ", ($a->{$_} // '(nada)'), "\n      gen: ", ($b->{$_} // '(nada)'), "\n" for @diff } }
            else { $ok++ } } }
    print "selftest: $ok iguais, $bad diferentes, $missing sem objeto no .stats\n";
    exit($bad ? 1 : 0) }

run_selftest() if $selftest;
die "uso: perl stats_add.pl a.patch [...] [--apply] | --selftest\n" unless @patches;

# ---------- patches ----------
learn($EDS); learn($_) for @VANILLA;
my $loca = slurp($LOCA) // die "$LOCA: $!";
my (%loca_ver, %loca_key, %bumped, @log, %dirty);   # %dirty: so o que mudou e gravado
$loca_ver{$1} = $2 while $loca =~ /<content contentuid="(h[0-9a-g]+)" version="(\d+)">/g;
sub note { push @log, shift }
sub loca_esc { my $t = shift; $t =~ s/&(?!(?:amp|lt|gt|quot|apos);)/&amp;/g; $t =~ s/</&lt;/g; $t =~ s/>/&gt;/g; $t }
sub loca_set { my ($key, $text) = @_;
    my $is_h = $key =~ /^h[0-9a-f]{8}g[0-9a-f]{4}g/; my $h = $is_h ? $key : det_handle($key); my $esc = loca_esc($text);
    if ($loca =~ /<content contentuid="\Q$h\E" version="(\d+)">(.*?)<\/content>/) { my ($ver, $old) = ($1, $2);
        if ($old ne $esc) { my $nv = $ver + 1;
            $loca =~ s/<content contentuid="\Q$h\E" version="\d+">.*?<\/content>/<content contentuid="$h" version="$nv">$esc<\/content>/;
            $loca_ver{$h} = $nv; $bumped{$h} = $nv; note("loca ~ $key ($h;$nv)") } }
    else { die "$key: handle nao existe no english.xml\n" if $is_h;
        $loca =~ s{(\n?</contentList>)}{\n  <content contentuid="$h" version="1">$esc</content>$1};
        $loca_ver{$h} = 1; note("loca + $key ($h)") }
    $loca_key{$key} = $h }
sub resolve { my $v = shift;
    $v =~ s{\{\{([\w]+)\}\}}{ my $k = $1; my $h = $k =~ /^h[0-9a-f]{8}g/ ? $k : ($loca_key{$k} // die "{{$k}}: chave sem \@loca\n");
        "$h;" . ($loca_ver{$h} // die "{{$k}}: handle $h sem versao\n") }ge; $v }

my @ops;   # pass 1: le todos os patches, aplica @loca
for my $pf (@patches) { my $s = slurp($pf) // die "$pf: $!"; my ($file, $sec) = (undef, '-');
    my @chunks = split /\n{2,}/, $s;
    for my $c (@chunks) { my @rest;
        for my $l (split /\n/, $c) {
            next if $l =~ /^\s*(#|$)/;
            if    ($l =~ /^\@file (\S+)/)            { $file = $1 }
            elsif ($l =~ /^\@section (.+?)\s*$/)     { $sec = $1 }
            elsif ($l =~ /^\@remove (\S+)/)          { push @ops, ['remove', $1] }
            elsif ($l =~ /^\@set (\S+) (\S+) ?(.*)$/) { push @ops, ['set', $1, $2, $3] }
            elsif ($l =~ /^\@loca (\S+) (.+)$/)      { loca_set($1, $2) }
            else { push @rest, $l } }
        next unless @rest;
        die "$pf: bloco sem 'new entry': $rest[0]\n" unless $rest[0] =~ /^new entry /;
        die "$pf: entrada antes de \@file\n" unless defined $file;
        push @ops, ['put', $file, $sec, join("\n", @rest)] } }

sub put_entry { my ($pub, $sec, $blk) = @_; my $e = parse_entry($blk);
    my ($opub, $oi) = find_entry($e->{name}); die "$e->{name} ja existe em $opub, nao em $pub\n" if defined $opub && $opub ne $pub;
    my ($tp, $tb) = blocks_of($pub); $dirty{$tp} = 1;
    # uma filha nova vai logo depois do pai quando ele esta no mesmo arquivo: o jogo le de cima para baixo e
    # uma filha antes do pai nao herda nada (2026-09-29: STAR_MOONLIT_II sem icone e sem StackId)
    my ($pi) = defined $e->{using} ? grep { bname($tb->[$_]) eq $e->{using} } 0..$#$tb : ();
    if (defined $oi) { $tb->[$oi] = $blk; note("txt ~ $pub $e->{name}") }
    elsif (defined $pi) { splice @$tb, $pi + 1, 0, $blk; note("txt + $pub $e->{name} (depois de $e->{using})") }
    elsif ($sec eq '-') { push @$tb, $blk; note("txt + $pub $e->{name} (fim)") }
    else { my ($d) = grep { bname($tb->[$_]) eq $sec } 0..$#$tb; die "divisoria '$sec' nao achada em $pub\n" unless defined $d;
        my $k = $d + 1; $k++ while $k <= $#$tb && !is_divider($tb->[$k]); splice @$tb, $k, 0, $blk; note("txt + $pub $e->{name} (em $sec)") }
    my ($sp, $st) = stats_of($pub); $dirty{$sp} = 1; my $sn = stats_name($pub, $e->{name});
    my ($j) = grep { oname($st->{objs}[$_]) eq $sn } 0..$#{$st->{objs}};
    my $uuid = defined $j ? ouuid($st->{objs}[$j]) : det_uuid($e->{name});
    my $obj = build_obj($pub, $e, $uuid, defined $j ? ocolor($st->{objs}[$j]) : undef);
    if (defined $j) { $st->{objs}[$j] = $obj } else { push @{$st->{objs}}, $obj }
    $uuid_of{$e->{name}} = $uuid }
sub set_field { my ($name, $k, $v) = @_; my ($pub, $i) = find_entry($name); die "\@set: $name nao existe\n" unless defined $pub;
    my ($tp, $tb) = blocks_of($pub); $dirty{$tp} = 1; my $blk = $tb->[$i];
    if ($blk =~ /^data "\Q$k\E" ".*"$/m) { $blk =~ s/^data "\Q$k\E" ".*"$/data "$k" "$v"/m } else { $blk .= qq{\ndata "$k" "$v"} }
    $tb->[$i] = $blk;
    my ($sp, $st) = stats_of($pub); $dirty{$sp} = 1; my $sn = stats_name($pub, $name);
    my ($j) = grep { oname($st->{objs}[$_]) eq $sn } 0..$#{$st->{objs}}; die "\@set: $name sem objeto no .stats\n" unless defined $j;
    my $line = build_field(stats_rel($pub), $name, $k, $v);
    if ($st->{objs}[$j] =~ /<field name="\Q$k\E" /) { $st->{objs}[$j] =~ s/<field name="\Q$k\E" [^\n]*\/>/$line/ }
    else { $st->{objs}[$j] =~ s{(\n\s*</fields>)}{\n        $line$1} }
    note("set $name.$k") }
sub remove_entry { my $name = shift; my ($pub, $i) = find_entry($name);
    if (!defined $pub) { note("AVISO: \@remove $name - nao existe"); return }
    my ($tp, $tb) = blocks_of($pub); $dirty{$tp} = 1; splice @$tb, $i, 1;
    my ($sp, $st) = stats_of($pub); $dirty{$sp} = 1; my $sn = stats_name($pub, $name);
    @{$st->{objs}} = grep { oname($_) ne $sn } @{$st->{objs}}; note("remove $pub $name") }

for my $op (@ops) { my ($k, @a) = @$op;
    if    ($k eq 'put')    { put_entry($a[0], $a[1], resolve($a[2])) }
    elsif ($k eq 'set')    { set_field($a[0], $a[1], resolve($a[2])) }
    elsif ($k eq 'remove') { remove_entry($a[0]) } }

# versao nova de um handle existente vale em todo lugar que o cita
if (%bumped) {
    for my $pub (all_pubs()) { my ($tp, $tb) = blocks_of($pub);
        for (@$tb) { for my $h (keys %bumped) { my $v = $bumped{$h};
            $dirty{$tp} = 1 if s/\b\Q$h\E;(?!$v\b)\d+/$h;$v/g } } }
    for my $pub (all_pubs()) { next unless -e "$EDS/" . stats_rel($pub) . ".stats" or $stats{"$EDS/" . stats_rel($pub) . ".stats"};
        my ($sp, $st) = stats_of($pub);
        for (@{$st->{objs}}) { for my $h (keys %bumped) { my $v = $bumped{$h};
            $dirty{$sp} = 1 if s/handle="\Q$h\E" version="(?!$v")\d+"/handle="$h" version="$v"/g } } } }

print "$_\n" for @log;
if ($apply) {
    # linha em branco tambem depois da ultima entrada: o sort_stats.pl conta com ela e, sem ela, cola a
    # ultima entrada na que ele mover para depois
    for my $p (grep { $dirty{$_} } keys %blocks) { spew($p, join("\n\n", @{$blocks{$p}}) . "\n\n") }
    for my $p (grep { $dirty{$_} } keys %stats) { my $s = $stats{$p}; my $foot = $s->{foot};
        $foot = "\n$foot" if @{$s->{objs}} && $foot !~ /^\n/;   # arquivo que nasceu vazio (<stat_objects />)
        spew($p, $s->{head} . join("\n", @{$s->{objs}}) . $foot) }
    spew($LOCA, $loca); print "gravado.\n" }
else { print "(simulacao -- rode com --apply para gravar)\n" }
