import std/[strutils, algorithm, options]
import std/macros, macroplus
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
    param: NimNode

  ReducerCall = object 
    caller: NimNode
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
  let 
    fff = formalize flattenNestedDotExprCall body
    
    accIdent = ident "acc"
    itIdent = ident "it"
    mainLoopIdent = ident "mainLoop"
    iredStateProcIdent = fff.reducer
    iredDefaultStateProcIdent = ident fff.reducer.caller.strval & "Default"

  var 
    accDef = newEmptyNode()
    loopBody = quote:
      if not `iredStateProcIdent`(`accIdent`, `itIdent`):
        break `mainLoopIdent`


  for call in fff.callChain.reversed:
    let p = call.param

    loopBody = 
      case call.kind:
      of hoMap:
        quote:
          block:
            let `itIdent` = `p`
            `loopBody`

      of hoFilter:
        quote:
          if `p`:
            `loopBody`


  newBlockStmt quote do:
    `accDef`

    block `mainLoopIdent`:
      for `itIdent` in `what`:
        `loopBody`

    `accIdent`

macro `><`*(it, body) =
  iii it, body
