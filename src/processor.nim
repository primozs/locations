import std/os
import std/logging
import std/strformat
import std/json
import pkg/results
import pkg/tabby
import std/times
import pkg/progress

type Processor* = object
  name*: string = "processor"
  workingDir*: string = "data"
  inputDir*: string = "data" / "input"
  outputDir*: string = "data" / "output"
  configPath*: string = "data" / "config.json"


proc initProcessor*(name: string): Processor {.raises: [].} =
  var processor = Processor(name: name)

  let workingDirExists = processor.workingDir.dirExists()
    .catch.expect("Working dir check")

  if not workingDirExists:
    discard catch:
      processor.workingDir.createDir()

  let inputDirExists = processor.inputDir.dirExists()
    .catch.expect("Input dir check")
  if not inputDirExists:
    discard catch:
      processor.inputDir.createDir()

  let outputDirExists = processor.outputDir.dirExists()
    .catch.expect("Output dir check")
  if not outputDirExists:
    discard catch:
      processor.outputDir.createDir()

  let loggerPath = "data" / fmt"{processor.name}.log"
  var consoleLog = newConsoleLogger()
    .catch.expect("Console logger to be created")
  var rollingLog = newRollingFileLogger(loggerPath)
    .catch.expect("Rolling logger to be created")

  addHandler(consoleLog)
  addHandler(rollingLog)

  return processor


proc logError*(data: varargs[string, `$`]) {.raises: [].} =
  try:
    error(data)
  except:
    echo "logger exception: " & getCurrentExceptionMsg()


proc loadConfig*[T](p: Processor): T {.raises: [].} =
  var f: File
  try:
    f = open(p.configPath, fmRead)
    let text = f.readAll()
    let textJson = text.parseJson()
    let config: T = textJson.to(T)
    return config
  except Exception as e:
    logError("Load config ", e.repr)
  finally:
    f.close()


proc saveConfig*[T](p: Processor, data: T) {.raises: [].} =
  var f: File
  try:
    f = open(p.configPath, fmWrite)
    f.write(( %* data).pretty())
  except Exception as e:
    logError("Write config error ", e.repr)
  finally:
    f.close()


proc saveJsonData*[T](p: Processor, fName: string = "data", data: T,
    pretty: bool = false) {.raises: [].} =
  var f: File
  try:
    let dataPath = p.outputDir / fmt"{fName}.json"
    if dataPath.fileExists():
      dataPath.removeFile()

    f = open(dataPath, fmWrite)

    if pretty:
      f.write(( %* data).pretty())
    else:
      f.write( %* data)
  except Exception as e:
    logError("Write data error ", e.repr)
  finally:
    f.close()


proc saveCsvData*[T](p: Processor, fName: string = "data", data: T,
    hasHeader: bool) {.raises: [].} =
  var f: File
  try:
    let dataPath = p.outputDir / fmt"{fName}.csv"
    let csvData = toCsv(data, hasHeader = hasHeader)

    f = open(dataPath, fmAppend)
    f.write(csvData)
  except Exception as e:
    logError("Write data error ", e.repr)
  finally:
    f.close()


template timing*(desc: string, body: untyped): untyped =
  let t1 = getTime()
  body
  let t2 = getTime()
  echo desc, ": ", t2 - t1


template progressBar*(totalCount: int, body: untyped): untyped =
  let p1 = (totalCount.toFloat / 100.0)
  var bar = newProgressBar()
  bar.start()

  var count = 0
  proc progressCalc() =
    let percent = (count + 1).toFloat / p1
    bar.set(percent.toInt)
    count.inc

  body
  bar.finish()



