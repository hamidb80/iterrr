import std/[macros, tables, sugar]
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

        assert temp.len == 1, "there must be only one main loop"
        temp[0]
      ))

    name = getName iterdef[RoutineName]
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

iterator cycle*(itrbl: T; `limit`: int): T {.adapter.} =
  block cycleLoop:
    var `c` = 0
    while true:
      for it in itrbl:
        yield it
        inc `c`
        if `c` == `limit`:
          break cycleLoop

iterator flatten*(itrbl: T): typeof itrbl[0] {.adapter.} =
  for it in itrbl:
    for it in it:
      yield it

iterator group*(loop: T; `every`: int;
  `excludeInComplete`: bool = false): seq[T] {.adapter.} =

  var `gacc` = newSeqOfCap[T](`every`)
  for it in loop:
    `gacc`.add it
    if `gacc`.len == `every`:
      yield `gacc`
      setLen `gacc`, 0

  if (`gacc`.len != 0) and not `excludeInComplete`:
    yield `gacc`
