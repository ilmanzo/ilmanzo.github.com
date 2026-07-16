---
layout: post
description: "Divertirsi con le sfide di programmazione natalizie"
title: "Advent of Code 2025: i diari"
categories: programming
tags: [hackweek, programming, algorithms, quiz, challenges]
author: Andrea Manzini
date: 2025-12-01
---

## 🎄 Intro

È dicembre, il periodo dell'anno più bello per i programmatori. Ma effettuando l'accesso all'[Advent of Code (AoC) 2025](https://adventofcode.com/2025), potresti notare che l'atmosfera è leggermente diversa. Abbiamo superato un decennio dello straordinario lavoro di Eric Wastl, e con questo traguardo arriva un importante cambiamento nella tradizione.

Prima di tuffarmi nelle soluzioni, voglio prendermi un momento per riflettere sullo stato dell'AoC di quest'anno, sui cambiamenti che stiamo vedendo e sul perché — nonostante tutto — continuiamo a tornare davanti al terminale.

### I cambiamenti nel formato del 2025
Se stai cercando la classifica globale (Global Leaderboard) o ti stai preparando per una maratona di 25 giorni, avrai probabilmente notato due importanti novità:

- Nessuna classifica globale: la frenesia competitiva è stata rimossa quest'anno.
- Un calendario di 12 giorni: invece dei soliti 25 giorni, l'evento dura 12 giorni.

Sebbene questi cambiamenti possano sorprendere i veterani, portano con sé un messaggio di empatia. Mantenere un progetto di questa portata per dieci anni è un impegno colossale e massacrante. Eric ha costantemente lavorato a livelli incredibili per offrirci queste sfide così eleganti, divertenti e creative. Riconoscere il "costo umano" di questo evento significa supportare la necessità del creatore di tutelare il proprio tempo e la propria salute mentale.

### Perché continuiamo a risolvere i puzzle
Nel 2025, in mezzo al gran parlare di intelligenza artificiale e assistenti di scrittura codice, sorge una domanda spontanea: *"Perché scomodarsi a risolvere puzzle quando un'IA può farlo in pochi secondi?"*

La risposta è semplice: le persone continuano ad andare ai musical e ai concerti dal vivo, anche se esiste Spotify.

Non partecipiamo all'Advent of Code perché è la via più "efficiente" per ottenere una risposta. Lo facciamo perché *vogliamo risolvere il puzzle*. Lo facciamo per l'emozione, la frustrazione e l'apprendimento. L'AoC è un modo per riconnettersi con il puro amore per la programmazione. Si rivolge a qualsiasi livello di competenza, dal principiante alle prime armi fino allo sviluppatore esperto in cerca di uno stimolo.

### Una tradizione generazionale
Che si tratti di 25 o di 12 giorni, l'Advent of Code è dventato per molti di noi una tradizione forte tanto quanto Star Wars. È qualcosa da tramandare; ci sono bambini che oggi indossano il pigiama a tema AoC, crescendo con questi enigmi come punto fermo delle festività natalizie.

Quindi, grazie a [Eric](https://was.tl/) per gli ultimi 10 anni. Noi siamo qui per gli enigmi, la community e la tradizione — in qualsiasi formato tu preferisca.

E ora, apriamo l'editor e risolviamo il Giorno 1. ATTENZIONE SPOILER!

## ⏰ [Giorno 1](https://adventofcode.com/2025/day/1) : La cassaforte

Oh no, a quanto pare gli Elfi hanno scoperto il Project Management! (Sospetto che questo sia un indizio sul numero ridotto di stelle di quest'anno, che [Eric](https://was.tl/) abbia cambiato ruolo?)

Abbiamo una cassaforte con una manopola a 100 posizioni (da 0 a 99) e le istruzioni per ruotarla a sinistra (Left) e a destra (Right) per un certo numero di volte: `L68 L30 R48 L5 R60 L55 L1 L99 R14 L82` e così via. La posizione iniziale della manopola è 50. Nella prima parte, devi calcolare quante volte la manopola si FERMA esattamente sul numero 0; nella seconda parte (svelata dopo la prima soluzione) devi calcolare quante volte è PASSATA per il numero 0.

![day01](/img/aoc2025/day01.gif)
(animazione per gentile concessione di https://www.reddit.com/user/Disastrous-Funny-781/)

Ecco un'elegante soluzione in AWK:
```awk
BEGIN { p = 50 }
{
    c = substr($0, 2)
    p = (p + (substr($0, 1, 1) == "R" ? c : 100 - c)) % 100
    n += !p
}
END { print n }
```
Questa soluzione sfrutta l'aritmetica modulare: ruotare a sinistra (Left) di N è equivalente a ruotare a destra (Right) di 100-N.

## 🎁 [Giorno 2](https://adventofcode.com/2025/day/2) : Il negozio di regali

Alcuni elfi più giovani hanno giocato con il computer del negozio di regali, incasinando gli ID dei prodotti!

Ti viene fornito un elenco di intervalli, come `11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124` e devi trovare quelli che non sono ID validi.

Per la prima parte, gli ID non validi sono quelli che si ripetono esattamente due volte, come `11` o `123123`. Per la seconda parte, possono ripetersi due o più volte, come `131313`.

![day02](/img/aoc2025/day02.gif)
(animazione per gentile concessione di https://www.reddit.com/user/Boojum/)

Dato che il problema riguarda interamente il filtraggio di un elenco, ho optato per uno *stile funzionale*. Il [linguaggio di programmazione D](https://dlang.org/) offre ottime funzionalità in questo senso:

{{< highlight D >}} 
bool isInvalidId1(string id) {
    auto mid = id.length / 2;
    return id.length > 0 && id.length % 2 == 0 && id[0 .. mid] == id[mid .. $];
}

bool isInvalidId2(string id) {
    auto m = id.length;
    foreach (k; 2 .. m + 1)
    {
        if (m % k == 0)
        {
            auto firstToken = id[0 .. m / k];
            if (firstToken.replicate(k).equal(id)) return true;
        }
    }
    return false;
}

void main() {
    auto ranges = stdin.readln().strip.split(',').map!(pair => pair.split('-').map!(to!long));
    auto numbers = ranges.map!(r => iota(r[0], r[1] + 1).map!(to!string)).joiner;
    writeln(numbers.filter!isInvalidId1.map!(to!long).sum);
    writeln(numbers.filter!isInvalidId2.map!(to!long).sum);
}
{{</ highlight >}}


A proposito, questo problema è interessante perché può essere affrontato in molti modi diversi: confronto di stringhe, espressioni regolari e approccio puramente aritmetico.
Possiamo anche notare che l'intervallo di input è limitato, ad esempio i numeri più grandi hanno dieci cifre. Ciò significa che anche i modi possibili in cui un pattern di cifre può "ripetersi" sono limitati.

## 🔋 [Giorno 3](https://adventofcode.com/2025/day/3) : Il voltaggio delle batterie

Dobbiamo raggiungere i piani inferiori, ma sfortunatamente gli ascensori sono senza corrente. Il problema di oggi consiste nel collegare tra loro alcune batterie per ottenere il massimo "Joltage" possibile.
Abbiamo quindi quattro pacchi batteria, qui rappresentati dalle seguenti righe:

```
987654321111111
811111111111119
234234234234278
818181911112111
```

Per ogni pacco, vuoi trovare il numero più grande che puoi ottenere collegando due batterie; ad esempio, nella prima riga, il `9` e l'`8` danno `98`.

![day01](/img/aoc2025/day03.gif)
(animazione per gentile concessione di https://www.reddit.com/user/danmaps/)

Nella seconda parte sarà necessario collegare 12 batterie.

Ecco la soluzione di oggi in Nim (pubblico qui solo la prima parte, puoi trovare la [seconda parte sul mio repository](https://github.com/ilmanzo/advent_of_code/tree/master/2025/day03))

{{< highlight nim >}} 
template benchmark(code: untyped) =
  block:
    let t0 = getMonoTime()
    code
    let elapsed = getMonoTime() - t0
    echo "Time ", elapsed.inMilliseconds(), " ms"

proc part1(data: seq[int]): int =
  for i in 0 ..< data.len - 1:
    let currentVal = 10 * data[i] + data[i + 1 .. ^1].max
    result = max(result, currentVal)

var input: seq[seq[int]]
for line in stdin.lines:
  input.add line.map(proc(c: char): int = parseInt($c))

benchmark:
  echo "Part 1: ", input.map(part1).sum
{{</ highlight >}}

L'algoritmo è lineare: per ogni cifra, la si accoppia con la cifra successiva più grande. La coppia così formata è una candidata a dventare il nuovo valore massimo.

Un paio di osservazioni sul linguaggio Nim, che a mio parere ha un enorme potenziale:
- Mi piace la facilità con cui si possono scrivere i template (vedi la funzione benchmark in alto) e come si integrano in modo trasparente con la sintassi del linguaggio.
- La speciale variabile `result` è molto comoda per qualsiasi calcolo e viene restituita automaticamente alla fine della funzione.
- Il programma viene compilato in un binario nativo estremamente veloce: utilizzando l'input reale 100x200, il programma restituisce il valore corretto in circa 2 millisecondi.


## 🧻 [Giorno 4](https://adventofcode.com/2025/day/4) : Rotoli di carta

Procedendo verso la base sotterranea, incontriamo il reparto stampa degli Elfi, dove viene stampata la famosa lista dei "buoni e cattivi".
I carrelli elevatori sono impegnatissimi con enormi rotoli di carta `@`, così decidiamo di dare una mano.

```
..@@.@@@@.
@@@.@.@.@@
@@@@@.@.@@
@.@@@@..@.
@@.@@@@.@@
.@@@@@@@.@
.@.@.@.@@@
@.@@@.@@@@
.@@@@@@@@.
@.@.@@@.@.
```

Si scopre che possiamo spostare solo i rotoli che hanno meno di 4 elementi adiacenti!

![day04](/img/aoc2025/day04.gif)
(animazione per gentile concessione di https://www.reddit.com/user/wimglenn/)

Per questo esercizio ho voluto testare [Zig](https://ziglang.org/), quindi temo che il codice sia troppo lungo per essere inserito qui. Se ti interessa, dai un'occhiata al [repository](https://github.com/ilmanzo/advent_of_code/tree/master/2025/day04)!


## 🥐 [Giorno 5](https://adventofcode.com/2025/day/5) : La mensa

Dopo aver sfondato la parete (!) con un carrello elevatore, scopriamo che dietro c'è una mensa. Il compito di oggi consiste nel trovare gli ID degli ingredienti *freschi* in mezzo a quelli avariati, dato un elenco di intervalli e l'ID da verificare:

```
3-5
10-14
16-20
12-18

1
5
8
11
17
32
```

La metà superiore dell'input rappresenta gli intervalli freschi, mentre quella inferiore contiene gli ingredienti. Ad esempio, `1` è avariato perché non è contenuto in alcun intervallo, mentre `11` appartiene all'intervallo `10-14`, quindi è fresco.

Questo problema è molto interessante perché può essere risolto in molti modi diversi, esplorando concetti di efficienza e algoritmi della teoria degli insiemi.
Ho adottato un approccio funzionale, utilizzando Elixir come linguaggio. Il codice completo si trova sul [repository](https://github.com/ilmanzo/advent_of_code/tree/master/2025/day05).

Nella prima parte, contiamo semplicemente quanti ingredienti rientrano nei nostri "intervalli freschi".

{{< highlight elixir >}} 
def part1(fresh, ingredients) do
  Enum.count(ingredients, fn ingredient ->
    Enum.any?(fresh, &(ingredient in &1))
  end)
end
{{</ highlight >}}



Per risolvere la seconda parte, dobbiamo fondamentalmente "unire" tutti gli intervalli e contare tutti gli ID che vi rientrano. Questo è un lavoro perfetto per l'operatore di pipe (`|>`)!

{{< highlight elixir >}} 
def part2(fresh) do
      fresh
      |> Enum.sort()
      |> merge_ranges()
      |> Enum.map(&Range.size/1)
      |> Enum.sum()
end
{{</ highlight >}}

![day05a](/img/aoc2025/day05a.gif)
(animazione per gentile concessione di https://www.reddit.com/user/Ok-Curve902/)

La logica principale è eseguita dalla funzione `merge_ranges()`. Vediamola:

{{< highlight elixir >}} 
defp merge_ranges([]), do: []

defp merge_ranges([r1, r2 | rest]) when r2.first <= r1.last + 1 do
  merged_range = r1.first..max(r1.last, r2.last)
  merge_ranges([merged_range | rest])
end

defp merge_ranges([head | tail]) do
  [head | merge_ranges(tail)]
end
{{</ highlight >}} 

Si tratta di una funzione ricorsiva che sfrutta il potente pattern matching di Elixir:
- Caso base: una lista vuota restituisce semplicemente una lista vuota.
- Caso di unione (merge): quando gli intervalli si sovrappongono, crea un `merged_range`. Questo nuovo intervallo inizia all'inizio del primo intervallo `(r1.first)` e termina nel punto finale più grande tra i due `(max(r1.last, r2.last))`. Richiama poi nuovamente `merge_ranges`. Cosa fondamentale, passa una nuova lista in cui `r1` e `r2` sono stati sostituiti dal singolo `merged_range`. Ciò consente di verificare se l'intervallo appena formato si sovrappone a quello successivo nell'elenco `(rest)`.
- Caso di mancata unione (no merge): poiché `head` non si sovrappone all'intervallo successivo, viene considerato per il momento come un intervallo finale e completo. Possiamo quindi inserirlo all'inizio della nostra lista dei risultati. La funzione chiama poi ricorsivamente `merge_ranges` sulla coda (`tail`) della lista per proseguire il processo con tutti gli intervalli successivi. Il risultato di tale chiamata ricorsiva viene accodato a `head`.

Combinando queste tre clausole, la funzione scorre in modo elegante l'elenco ordinato, unendo gli intervalli man mano che procede, fino a elaborare l'intera lista.


![day05b](/img/aoc2025/day05b.gif)
(animazione per gentile concessione di https://www.reddit.com/user/Just-Routine-5505/)

## 🎅 Note e riferimenti

Raccolgo qui tutti i collegamenti, i riferimenti o gli elementi correlati all'AoC25:

(attenzione: potrebbero essere presenti offerte commerciali)
- Advent of DevOps: https://sadservers.com/advent
- Advent of Cyber: https://tryhackme.com/adventofcyber25
- AoC in Kotlin: https://blog.jetbrains.com/kotlin/2025/11/advent-of-code-in-kotlin-2025/
- AoC Subreddit: https://www.reddit.com/r/adventofcode/
- Perl Advent Calendar: https://perladvent.org/2025/  (Day 20 is very special!)

Visualizzazione del [Giorno 6](https://adventofcode.com/2025/day/6) a cura di https://www.reddit.com/user/Ok-Curve902/:
![day06](/img/aoc2025/day06.gif)

[Giorno 7](https://adventofcode.com/2025/day/7) risolto su un vero albero di Natale!
![tree](https://i.ibb.co/dyCTz70/ezgif-39c8284705882154-1.gif)
Per gentile concessione di https://www.reddit.com/user/EverybodyCodes/