import std/[strutils, sequtils, algorithm]
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
    params: seq[NimNode]

  IterrrPack = object
    callChain: seq[HigherOrderCall]
    reducer: ReducerCall

# impl -----------------------------------------


proc formalize(nodes: seq[NimNode]): IterrrPack =
  var hasReducer = false

  for i, n in nodes:
    let caller = n[CallIdent].strVal.normalize

    template addToCallChain(higherOrderKind): untyped =
      result.callChain.add HigherOrderCall(
          kind: higherOrderKind,
          param: n[CallArgs][0])

    case caller:
    of "imap":
      addToCallChain hoMap

    of "ifilter":
      addToCallChain hoFilter

    elif i == nodes.high: # reducer
      hasReducer = true
      result.reducer = ReducerCall(
          caller: ident caller,
          params: n[CallArgs])

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
  var target = inlineQuote default(typeof(`iterIsh`))

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
    iredFinalizerProcIdent = ident ipack.reducer.caller.strVal & "Finalizer"
    iredDefaultProcIdent = ident ipack.reducer.caller.strval & "Default"

  var
    accDef =
      if ipack.reducer.params.len > 0:
        var c = newCall(iredDefaultProcIdent)
        c.add ipack.reducer.params

        let dfcall = c

        quote:
          var `accIdent` = `dfcall`

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

    `iredFinalizerProcIdent`(`accIdent`)

# broker ---------------------------------------

macro `><`*(iterIsh, body): untyped =
  iterrrImpl iterIsh, body
