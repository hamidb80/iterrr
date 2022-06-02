import std/[macros, tables, sugar, strutils]
import macroplus
import helper

# impl ------------------------------------------

type
  AdapterInfo* = ref object
    wrapperCode*: NimNode
    loopPath*: NodePath
    iterTypePaths*, yeildPaths*, argsValuePaths*: seq[NodePath]

var customAdapters* {.compileTime.}: Table[string, AdapterInfo]

macro adapter*(iterDef): untyped =
  expectKind iterDef, nnkIteratorDef
  let
    args = iterdef.RoutineArguments
    itrblId = args[0]
  var
    argsValuePathsAcc: seq[NodePath]
    body = iterDef[RoutineBody]
    argsDef = newTree nnkLetSection

  block resolveArgs:
    var c = 0 # count
    for i in 1..args.high:
      let idef = args[i]
      for t in 0 .. idef.len-3: # for multi args like (a,b: int)
        argsDef.add newIdentDefs(idef[t], idef[IdentDefType], idef[IdentDefDefaultVal])
        argsValuePathsAcc.add @[0, c, 2]
        inc c

    body.insert 0, argsDef

  let
    adptr = AdapterInfo(
      argsValuePaths: argsValuePathsAcc,
      wrapperCode: body,
      yeildPaths: findPaths(body, (n) => n.kind == nnkYieldStmt),
      iterTypePaths: findPaths(body, (n) => n.eqIdent itrblId[IdentDefType]),
      loopPath: (
        let temp = findPaths(body,
          (n) => n.kind == nnkForStmt and eqIdent(n[ForRange], itrblId[IdentDefName]))

        assert temp.len == 1, "there must be only one for loop over main iterable"
        temp[0]
      ))

    name = nimIdentNormalize getName iterdef[RoutineName]
    typename = block:
      let i = ident name & "Type"
      if isExportedIdent(iterDef[RoutineName]):
        exported i
      else:
        i

  customAdapters[name] = adptr

  result = newProc(
    typename,
    @[ident"untyped"] & args,
    iterDef.RoutineReturnType,
    nnkTemplateDef)

  result[RoutineGenericParams] = newTree(nnkGenericParams,
    newIdentDefs(itrblId[IdentDefType], newEmptyNode()))

  # echo repr adptr
  # echo repr result

# defs ---------------------------------------

iterator cycle*(loopItems: T; `limit`: int): T {.adapter.} =
  block cycleLoop:
    var `c` = 0
    while true:
      for it in loopItems:
        yield it
        inc `c`
        if `c` == `limit`:
          break cycleLoop

iterator flatten*(loopItems: T): typeof loopItems[0] {.adapter.} =
  for it in loopItems:
    for it in it:
      yield it

iterator group*(loopItems: T; `every`: int;
  `includeInComplete`: bool = true): seq[T] {.adapter.} =

  var `acc` = newSeqOfCap[T](`every`)
  for it in loopItems:
    `acc`.add it

    if `acc`.len == `every`:
      yield `acc`
      setLen `acc`, 0

  if (`acc`.len != 0) and `includeInComplete`:
    yield `acc`

import std/deques

iterator window*(loopItems: T; `size`: int): Deque[T] {.adapter.} =
  var `acc` = initDeque[T]()

  for it in loopItems:
    `acc`.addLast it

    if `acc`.len == `size`:
      yield `acc`
      `acc`.popFirst
