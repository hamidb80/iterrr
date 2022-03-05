import std/[macros, strutils, algorithm, options]
import macroplus
import ./iterrr/reducers

export reducers

# utils -----------------------------------------

template err(msg): untyped =
  raise newException(ValueError, msg)


proc flattenNestedDotExprCallImpl(n: NimNode, acc: var seq[NimNode]) =
  expectKind n, nnkCall

  case n[0].kind:
  of nnkDotExpr:
    flattenNestedDotExprCallImpl n[0][0], acc

    acc.add:
      case n.len:
      of 1: newCall n[0][1]
      of 2: newCall n[0][1], n[1]
      else: err "only 0 or 1 parameters can finalizer have"

  of nnkIdent:
    acc.add n

  else:
    error "invalid caller"

proc flattenNestedDotExprCall(n: NimNode): seq[NimNode] =
  ## imap(1).ifilter(2).imax()
  ##
  ## converts to >>>
  ##
  ## Call
  ##   Ident "imap"
  ##   IntLit 1
  ## Call
  ##   Ident "ifilter"
  ##   IntLit 2
  ## Call
  ##   Ident "imax"

  flattenNestedDotExprCallImpl n, result


# impl -----------------------------------------

type
  HigherOrderCallers = enum
    hoMap
    hoFilter

  HigherOrderCall = object
    kind: HigherOrderCallers
    expr: NimNode

  ReducerCall = object 
    caller: string
    defaultValue: Option[NimNode]

  FormalizedChain = object
    callChain: seq[HigherOrderCall]
    reducer: ReducerCall


proc formalize(nodes: seq[NimNode]): FormalizedChain =
  # TODO add `iseq` finalizer if it doesn't have any

  for i, n in nodes:
    let caller = n[CallIdent].strVal.normalize
    if not (
        caller in ["imap", "ifilter"] or
        i == nodes.high
      ):
      err "finalizer can only be last call: " & caller

proc iii(what, body: NimNode): NimNode =
  var
    accDef = newEmptyNode()
    loopBody = newStmtList()

  let 
    fff = formalize flattenNestedDotExprCall body
    accIdent = ident "acc"
    mainLoopIdent = ident "mainLoop"

  for call in fff.callChain:
    case:
    of hoMap:
      _
    of hoFilter:
      _

  newBlockStmt quote do:
    `accDef`

    block `mainLoopIdent`:
      for it {.inject.} in `what`:
        `loopBody`


macro `><`*(it, body) =
  iii it, body
