import std/[strutils, sequtils, algorithm, strformat]
import std/macros, macroplus
import ./iterrr/[reducers, helper]

export reducers

# def ------------------------------------------

type
  HigherOrderCallers = enum
    hoMap, hoFilter

  HigherOrderCall = object
    kind: HigherOrderCallers
    iteratorIdentAliases: seq[NimNode]
    param: NimNode

  ReducerCall = object
    caller: NimNode
    params: seq[NimNode]

  IterrrPack = object
    callChain: seq[HigherOrderCall]
    reducer: ReducerCall

# impl -----------------------------------------

func getIteratorIdents(call: NimNode): seq[NimNode] =
  if call[CallIdent].kind == nnkBracketExpr:
    result = call[CallIdent][BracketExprParams]

func replacedIteratorIdents(expr: NimNode, aliases: seq[NimNode]): NimNode =
  case aliases.len:
  of 0: expr
  of 1: expr.replacedIdent(aliases[0], ident "it")
  else:
    var cur = expr

    for i, a in aliases:
      let replacement = newTree(nnkBracketExpr, ident "it", newIntLitNode i)
      cur = replacedIdent(cur, a, replacement)

    cur

proc toIterrrPack(calls: seq[NimNode]): IterrrPack =
  var hasReducer = false

  for i, n in calls:
    template addToCallChain(higherOrderKind): untyped =
      result.callChain.add HigherOrderCall(
        kind: higherOrderKind,
        iteratorIdentAliases: getIteratorIdents n,
        param: n[CallArgs][0])

    let caller = normalize:
      if n[CallIdent].kind == nnkBracketExpr:
        n[CallIdent][BracketExprIdent].strVal
      else:
        n[CallIdent].strVal

    case caller:
    of "imap": addToCallChain hoMap
    of "ifilter": addToCallChain hoFilter

    elif i == calls.high: # reducer
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
    target = replacedIdent(operation, ident "it", target)

  inlineQuote typeof(`target`)

proc resolveIteratorAliases(ipack: var IterrrPack) =
  for c in ipack.callChain.mitems:
    c.param = c.param.replacedIteratorIdents(c.iteratorIdentAliases)

proc iterrrImpl(iterIsh, body: NimNode): NimNode =
  var ipack = toIterrrPack flattenNestedDotExprCall body
  resolveIteratorAliases ipack

  let
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

    loopBody = block:
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
