import std/[macros, sequtils]
import macroplus

type NodePath* = seq[int]

# conventions -----------------------------

template err*(msg): untyped =
  raise newException(ValueError, msg)

template impossible*: untyped =
  err "imposible"

# common utilities ------------------------

func last*[T](s: seq[T]): T {.inline.} =
  s[s.high]

# meta programming stuff ------------------

proc replacedIdents*(root: NimNode, targets, bys: openArray[NimNode]): NimNode =
  if root.kind == nnkIdent:
    for i, target in targets:
      if eqIdent(root, target):
        return bys[i]

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

  of nnkBracketExpr:
    case n[CallIdent][BracketExprIdent].kind:
    of nnkIdent:
      acc.add n

    of nnkDotExpr:
      dotExprJob(
        n[CallIdent][BracketExprIdent][0],
        newTree(nnkBracketExpr, n[CallIdent][BracketExprIdent][1]).add(n[
            CallIdent][BracketExprParams]),
        n[CallArgs])

    else:
      err "no"

  of nnkDotExpr:
    dotExprJob n[CallIdent][0], n[CallIdent][1], n[CallArgs]

  else:
    err "invalid caller"

proc flattenNestedDotExprCall*(n: NimNode): seq[NimNode] {.inline.} =
  ## imap[T](1).ifilter(2).imax()
  ##
  ## converts to >>>
  ##
  ## Call
  ##   BracketExpr
  ##     Ident "imap"
  ##     Ident "T"
  ##   IntLit 1
  ## Call
  ##   Ident "ifilter"
  ##   IntLit 2
  ## Call
  ##   Ident "imax"

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


func findPathsImpl(node: NimNode,
  fn: proc(node: NimNode): bool,
  path: NodePath,
  result: var seq[NodePath]) =

  if fn node:
    result.add path

  else:
    for i, n in node:
      findPathsImpl n, fn, path & @[i], result

func findPaths*(node: NimNode,
  fn: proc(node: NimNode): bool): seq[NodePath] {.inline.} =

  findPathsImpl node, fn, @[], result
