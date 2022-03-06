import std/[strutils, sequtils, algorithm]
import std/macros, macroplus
import ./iterrr/[reducers, helper]

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

proc toIterrrPack(nodes: seq[NimNode]): IterrrPack =
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

proc detectType(iterIsh: NimNode, mapsParam: seq[NimNode]): NimNode =
  var target = inlineQuote default(typeof(`iterIsh`))

  for operation in mapsParam:
    target = replaceIdent(operation, ident "it", target)

  inlineQuote typeof(`target`)

proc iterrrImpl(iterIsh, body: NimNode): NimNode =
  let
    ipack = toIterrrPack flattenNestedDotExprCall body

    accIdent = ident "acc"
    itIdent = ident "it"
    mainLoopIdent = ident "mainLoop"
    reducerStateUpdaterProcIdent = ipack.reducer.caller
    reducerFinalizerProcIdent = ident ipack.reducer.caller.strVal & "Finalizer"
    reducerInitProcIdent = ident ipack.reducer.caller.strval & "Init"

    accDef =
      if ipack.reducer.params.len > 0:
        var reducerInitCall = newCall(reducerInitProcIdent)
        reducerInitCall.add ipack.reducer.params

        quote:
          var `accIdent` = `reducerInitCall`

      else:
        let dtype = detectType iterIsh:
          ipack.callChain.filterIt(it.kind == hoMap).mapIt(it.param)

        quote:
          var `accIdent` = `reducerInitProcIdent`[`dtype`]()


  var loopBody = quote:
      if not `reducerStateUpdaterProcIdent`(`accIdent`, `itIdent`):
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
      for `itIdent` in `iterIsh`:
        `loopBody`

    `reducerFinalizerProcIdent`(`accIdent`)

# macro ---------------------------------------

macro `><`*(iterIsh, body): untyped =
  iterrrImpl iterIsh, body

macro `>!<`*(iterIsh, body): untyped =
  result = iterrrImpl(iterIsh, body)
  echo "## ", repr(iterIsh), " >< ", repr(body)
  echo repr result
  echo "---------------------------------------"
