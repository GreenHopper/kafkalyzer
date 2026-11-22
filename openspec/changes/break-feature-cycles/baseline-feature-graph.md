# Feature import graph — comparison record

Produced by task 1.1 of this change. Reproduce with the measurement recipe in
`design/code-quality-refactoring-backlog.md` section 5, counting one edge per
importing file (`git grep` over `lib/src/features`, generated sources excluded).
Import *statements* give 106 for the worktree; the matrix below and the guard in
task 5.1 use the module graph, so one edge per importing file.

## At the branch base — e786fd7 (merge base with origin/main, the CI base ref)

from\to    cluster consumer explorer navigati   schema scriptin   search settings    topic     total
cluster           0        0        0        0        0        0        0        0        2        2
consumer          2        0        0        1        0        0        0        0        0        3
explorer          2        0        0        1        1        0        0        0        2        6
navigation        1        0        0        0        0        0        0        0        1        2
schema            0        0        0        0        0        0        0        0        2        2
scripting         4        0        0        1        2        0        3        0        2       12
search            0        0        0        0        0        0        0        0        2        2
settings          1        0        0        0        0        0        1        0        0        2
topic             5        0        0        0        3        1        1        0        0       10
TOTAL EDGES 41
CYCLES:
  cluster -> topic -> cluster
  schema -> topic -> schema
  scripting -> topic -> scripting
  search -> topic -> search
  cluster -> topic -> scripting -> cluster
  navigation -> topic -> scripting -> navigation
  schema -> topic -> scripting -> schema
  scripting -> search -> topic -> scripting
  cluster -> topic -> scripting -> navigation -> cluster
MUTUALLY-REACHABLE PAIRS (direct): 4
   cluster <-> topic
   schema <-> topic
   scripting <-> topic
   search <-> topic

## Worktree at the start of this change (HEAD 9bd744c)

from\to    cluster consumer explorer navigati   schema scriptin   search settings    topic     total
cluster           0        0        0        0        0        0        0        0        2        2
consumer          2        0        0        1        0        0        0        0        0        3
explorer          5        0        0        1        4        0        0        0        5       15
navigation        1        0        0        0        0        0        0        0        1        2
schema            0        0        0        0        0        0        0        0        2        2
scripting         4        0        0        1        2        0        3        0        2       12
search            0        0        0        0        0        0        0        0        2        2
settings          5        0        0        0        0        0        1        0        0        6
topic             5        0        0        0        4        1        2        0        0       12
TOTAL EDGES 56
CYCLES:
  cluster -> topic -> cluster
  schema -> topic -> schema
  scripting -> topic -> scripting
  search -> topic -> search
  cluster -> topic -> scripting -> cluster
  navigation -> topic -> scripting -> navigation
  schema -> topic -> scripting -> schema
  scripting -> search -> topic -> scripting
  cluster -> topic -> scripting -> navigation -> cluster
MUTUALLY-REACHABLE PAIRS (direct): 4
   cluster <-> topic
   schema <-> topic
   scripting <-> topic
   search <-> topic

## Reading the two

- The four mutually-reachable pairs are the same at both revisions:
  `cluster↔topic`, `topic↔schema`, `topic↔search`, `topic↔scripting`.
  Enumerating elementary cycles gives 9, because each 2-node cycle extends
  through `scripting` (`topic→scripting→cluster`, `topic→scripting→navigation`,
  `topic→scripting→schema`, `scripting→search→topic`) and one 4-node cycle.
- The `quality-improvements` branch added 15 edges (41 → 56) without adding a
  cycle: the widget splits in `split-god-widgets` moved importing files around.
  That is why the guard grandfathers by reachability rather than by edge count.
- `topic` is on every cycle: 12 edges out of it, 21 into it.
- Target after this change: 0 cycles, and the directions listed in design.md D1.

## After group 2 — the small moves (tasks 2.1–2.4)

from\to    cluster consumer explorer navigati   schema scriptin   search settings    topic     total
cluster           0        0        0        0        0        0        0        0        2        2
consumer          2        0        0        1        0        0        0        0        0        3
explorer          5        0        0        1        4        0        0        0        5       15
navigation        1        0        0        0        0        0        0        0        1        2
schema            0        0        0        0        0        0        0        0        2        2
scripting         4        0        0        1        2        0        3        0        2       12
search            0        0        0        0        0        0        0        0        0        0
settings          5        0        0        0        0        0        1        0        0        6
topic             4        0        0        0        4        0        2        0        0       10
TOTAL EDGES 52
CYCLES:
  cluster -> topic -> cluster
  schema -> topic -> schema
MUTUALLY-REACHABLE PAIRS (direct): 2
   cluster <-> topic
   schema <-> topic

Two cycles left: `cluster↔topic` (group 4) and `topic↔schema` (group 3).

## After group 3 — the schema dialogs behind the topic-name port

from\to    cluster consumer explorer navigati   schema scriptin   search settings    topic     total
cluster           0        0        0        0        0        0        0        0        2        2
consumer          2        0        0        1        0        0        0        0        0        3
explorer          5        0        0        1        4        0        0        0        5       15
navigation        1        0        0        0        0        0        0        0        1        2
schema            0        0        0        0        0        0        0        0        0        0
scripting         4        0        0        1        2        0        3        0        2       12
search            0        0        0        0        0        0        0        0        0        0
settings          5        0        0        0        0        0        1        0        0        6
topic             4        0        0        0        4        0        2        0        0       10
TOTAL EDGES 50
CYCLES:
  cluster -> topic -> cluster
MUTUALLY-REACHABLE PAIRS (direct): 1
   cluster <-> topic

One cycle left: `cluster↔topic` (group 4).
