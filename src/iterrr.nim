import std/[strutils, algorithm, options]
import std/macros, macroplus
import ./iterrr/[reducers, utils]

export reducers

# def ------------------------------------------

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

  IterrrPack = object
    callChain: seq[HigherOrderCall]
    reducer: ReducerCall

# impl -----------------------------------------

proc formalize(nodes: seq[NimNode]): IterrrPack =
  # TODO add `iseq` finalizer if it doesn't have any

  for i, n in nodes:
    let caller = n[CallIdent].strVal.normalize
    if not (
        caller in ["imap", "ifilter"] or
        i == nodes.high
      ):
      err "finalizer can only be last call: " & caller

proc iterrrImpl(iterableIsh, body: NimNode): NimNode =
  let
    ipack = formalize flattenNestedDotExprCall body

    accIdent = ident "acc"
    itIdent = ident "it"
    mainLoopIdent = ident "mainLoop"
    iredStateProcIdent = ipack.reducer
    iredDefaultStateProcIdent = ident ipack.reducer.caller.strval & "Default"

  var
    accDef = newEmptyNode()
    loopBody = quote:
      if not `iredStateProcIdent`(`accIdent`, `itIdent`):
        break `mainLoopIdent`


  for call in ipack.callChain.reversed:
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
      for `itIdent` in `iterableIsh`:
        `loopBody`

    `accIdent`

# broker ---------------------------------------

macro `><`*(iterableIsh, body) =
  iterrrImpl iterableIsh, body
