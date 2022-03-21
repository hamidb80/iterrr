import std/[strutils, sequtils, algorithm, sugar]
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
    idents: seq[NimNode]
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
    let replaceMents = collect:
      for i in (0..aliases.high):
        newTree(nnkBracketExpr, ident "it", newIntLitNode i)

    expr.replacedIdents(aliases, replaceMents)

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
    of "map": addToCallChain hoMap
    of "filter": addToCallChain hoFilter

    elif i == calls.high: # reducer
      hasReducer = true
      result.reducer = ReducerCall(
        caller: ident caller,

        idents: if n[CallIdent].kind == nnkBracketExpr:
            n[CallIdent][BracketExprParams]
          else:
            @[],

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

proc inspect(s: seq[NimNode]): seq[NimNode] {.used.} =
  ## debugging purposes
  for n in s:
    echo treeRepr n

  s

proc iterrrImpl(iterIsh, body: NimNode, code: NimNode = nil): NimNode =
  # var ipack = toIterrrPack inspect flattenNestedDotExprCall body
  var ipack = toIterrrPack flattenNestedDotExprCall body
  resolveIteratorAliases ipack

  let
    hasCustomCode = code != nil
    noAcc = hasCustomCode and ipack.reducer.caller.strval == "do"
    hasInlineReducer = ipack.reducer.caller.strVal == "reduce"

    accIdent = ident "acc"
    itIdent = ident "it"
    mainLoopIdent = ident "mainLoop"
    reducerStateUpdaterProcIdent = ipack.reducer.caller
    reducerFinalizerProcIdent = ident ipack.reducer.caller.strVal & "Finalizer"
    reducerInitProcIdent = ident ipack.reducer.caller.strval & "Init"

    accDef =
      if noAcc: newEmptyNode()

      elif hasInlineReducer:
        let initialValue = ipack.reducer.params[0]
        quote:
          var `accIdent` = `initialValue`

      elif ipack.reducer.params.len > 0:
        var reducerInitCall = newCall(reducerInitProcIdent)
        reducerInitCall.add ipack.reducer.params

        quote:
          var `accIdent` = `reducerInitCall`

      else:
        let dtype = detectType iterIsh:
          ipack.callChain.filterIt(it.kind == hoMap).mapIt(it.param)

        quote:
          var `accIdent` = `reducerInitProcIdent`[`dtype`]()

    accFinalizeCall =
      if hasInlineReducer:
        if ipack.reducer.params.len == 2: # has finalizer
          if ipack.reducer.idents.len == 2:
            ipack.reducer.params[1].replacedIdent(ipack.reducer.idents[0], accIdent)
          else:
            ipack.reducer.params[1]
        else:
          accIdent
      else:
        newCall(reducerFinalizerProcIdent, accIdent)


  var loopBody =
    if noAcc:
      code.replacedIteratorIdents(ipack.reducer.params)

    elif hasInlineReducer:
      if ipack.reducer.idents.len == 2:
        code.replacedIdents(ipack.reducer.idents, [accIdent, itIdent])
      else:
        code

    else:
      quote:
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

  newBlockStmt:
    if noAcc:
      quote:
        for `itIdent` in `iterIsh`:
          `loopBody`

    else:
      quote:
        `accDef`

        block `mainLoopIdent`:
          for `itIdent` in `iterIsh`:
            `loopBody`

        `accFinalizeCall`

# macro ---------------------------------------

template footer: untyped {.dirty.} =
  echo ". . . . . . . . . . . . . . . . . . . ."
  echo repr result
  echo "---------------------------------------"


macro `|>`*(iterIsh, body): untyped =
  iterrrImpl iterIsh, body

macro `|>`*(iterIsh, body, code): untyped =
  iterrrImpl iterIsh, body, code

macro `!>`*(iterIsh, body): untyped =
  result = iterrrImpl(iterIsh, body)
  echo "## ", repr(iterIsh), " >< ", repr(body)
  footer

macro `!>`*(iterIsh, body, code): untyped =
  result = iterrrImpl(iterIsh, body, code)
  echo "#["
  echo repr(iterIsh), " >< ", repr(body), ":\n", indent(repr code, 4)
  echo "#]"
  footer


template iterrr*(iterIsh, body): untyped =
  iterIsh |> body

template iterrr*(iterIsh, body, code): untyped =
  iterIsh |> body:
    code
