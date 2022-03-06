import std/[strutils, sequtils, algorithm, options]
import std/macros, macroplus
import ./iterrr/[reducers, utils]

export reducers

# def ------------------------------------------

type
  HigherOrderCallers = enum
    hoMap, hoFilter

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

proc getFirstArg(n: NimNode): NimNode =
  n[CallArgs][0]

proc getFirstArgIfExists(n: NimNode): Option[NimNode] =
  if n[CallArgs].len == 0:
    none NimNode
  else:
    some getFirstArg n

proc formalize(nodes: seq[NimNode]): IterrrPack =
  var hasReducer = false

  for i, n in nodes:
    let caller = n[CallIdent].strVal.normalize

    template addToCallChain(higherOrderKind): untyped =
      result.callChain.add HigherOrderCall(
          kind: higherOrderKind,
          param: getFirstArg n)

    case caller:
    of "imap":
      addToCallChain hoMap

    of "ifilter":
      addToCallChain hoFilter

    elif i == nodes.high: # reducer
      hasReducer = true
      result.reducer = ReducerCall(
          caller: ident caller,
          defaultValue: getFirstArgIfExists n)

    else:
      err "finalizer can only be last call: " & caller

  if not hasReducer:
    result.reducer = ReducerCall(caller: ident "iseq")

proc replaceIdent(root: NimNode, target, by: NimNode): NimNode =
  if eqIdent(root, target):
    by
  
  else:
    var croot = copyNimNode root

    for n in root:
      croot.add replaceIdent(n, target, by)
    
    croot

proc derefType(iterIsh: NimNode, mapsParam: seq[NimNode]): NimNode =
  var target = inlineQuote default typeof `iterIsh`

  for operation in mapsParam:
    target = replaceIdent(operation, ident "it", target)
  
  inlineQuote typeof `target` 

proc iterrrImpl(iterIsh, body: NimNode): NimNode =
  let
    ipack = formalize flattenNestedDotExprCall body

    accIdent = ident "acc"
    itIdent = ident "it"
    mainLoopIdent = ident "mainLoop"
    iredStateProcIdent = ipack.reducer.caller
    iredDefaultProcIdent = ident ipack.reducer.caller.strval & "Default"

  var
    accDef =
      if isSome ipack.reducer.defaultValue:
        let val = ipack.reducer.defaultValue
        quote:
          var `accIdent` = `val`

      else:
        let dtype = derefType iterIsh:
          ipack.callChain.filterIt(it.kind == hoMap).mapIt(it.param)

        quote:
          var `accIdent` = `iredDefaultProcIdent`[`dtype`]()


    loopBody = quote:
      if not `iredStateProcIdent`(`accIdent`, `itIdent`):
        break `mainLoopIdent`


  for i, call in ipack.callChain.reversed:
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


  dumpReprAndReturn newBlockStmt quote do:
    `accDef`

    block `mainLoopIdent`:
      for `itIdent` in `iterIsh`:
        `loopBody`

    `accIdent`

# broker ---------------------------------------

macro `><`*(iterIsh, body): untyped =
  iterrrImpl iterIsh, body
