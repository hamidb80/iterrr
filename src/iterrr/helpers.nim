import std/[macros, sequtils, strformat]
import macroplus

type NodePath* = seq[int]

# conventions -----------------------------

template err*(msg): untyped =
  raise newException(ValueError, msg)

# meta programming stuff ------------------

func `&.`*(id: NimNode, str: string): NimNode =
  ## concatinates Nim's ident with custom string
  case id.kind:
  of nnkIdent: ident id.strVal & str
  of nnkAccQuoted: id[0] &. str
  else: err "exptected nnkIdent or nnkAccQuoted but got " & $id.kind

template `~=`*(id1, id2): untyped = 
  eqIdent(id1, id2)

template expect*(expr, msg): untyped = 
  doAssert expr, msg

func `or`*[T](s1, s2: seq[T]): seq[T] =
  case s1.len:
  of 0: s2
  else: s1

func getName*(node: NimNode): string =
  ## extracts the name for ident and exported ident
  ## `id` => "id"
  ## `id`* => "id

  case node.kind:
  of nnkIdent:
    node.strVal

  of nnkPostfix:
    assert node[0].strval == "*"
    getName node[1]

  else:
    err "invalid ident. got: " & $node.kind


proc replacedIdents*(root: NimNode, targets, bys: openArray[NimNode]): NimNode =
  if root.kind == nnkIdent:
    for i, target in targets:
      if eqIdent(root, target):
        return bys[i] # FIXME

    root

  else:
    copyNimNode(root).add:
      root.mapIt replacedIdents(it, targets, bys)

proc replacedIdent*(root: NimNode, target, by: NimNode): NimNode {.inline.} =
  replacedIdents(root, [target], [by])


proc flattenNestedDotExprCallImpl(n: NimNode, acc: var seq[NimNode]) =
  expectKind n, nnkCall

  template dotExprJob(innerCall, caller, args): untyped =
    flattenNestedDotExprCallImpl innerCall, acc
    acc.add newCall(caller).add(args)

  case n[CallIdent].kind:
  of nnkIdent:
    acc.add n

  of nnkDotExpr:
    dotExprJob n[CallIdent][0], n[CallIdent][1], n[CallArgs]

  of nnkOpenSymChoice:
    acc.add n

  else:
    err fmt"invalid caller {n[CallIdent].kind}"

proc flattenNestedDotExprCall*(n: NimNode): seq[NimNode] {.inline.} =
  ## map(1).filter(2).map()
  ## 
  ## Call
  ##   DotExpr
  ##     Call
  ##       DotExpr
  ##         Call
  ##           Ident "map"
  ##           IntLit 1
  ##         Ident "filter"
  ##       IntLit 2
  ##     Ident "map"
  ##
  ## converts to >>>
  ##
  ## Call
  ##   Ident "map"
  ##   IntLit 1
  ## Call
  ##   Ident "filter"
  ##   IntLit 2
  ## Call
  ##   Ident "map"

  flattenNestedDotExprCallImpl n, result

func getNode*(node: NimNode, path: NodePath): NimNode =
  result = node
  for i in path:
    result = result[i]

proc replaceNode*(node: NimNode, path: NodePath, by: NimNode) =
  var cur = node

  for i in path[0 ..< ^1]:
    cur = cur[i]

  cur[path[^1]] = by


proc findPathsImpl(node: NimNode,
  fn: proc(node: NimNode): bool,
  path: NodePath,
  result: var seq[NodePath]) =

  if fn node:
    result.add path

  else:
    for i, n in node:
      findPathsImpl n, fn, path & @[i], result

proc findPaths*(node: NimNode,
  fn: proc(node: NimNode): bool): seq[NodePath] {.inline.} =

  findPathsImpl node, fn, @[], result

# ------------------------

var c {.compileTime.} = 0
proc genUniqId*(): string =
  inc c
  $c
