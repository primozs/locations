import ./overpass
import ./utils
import ./locations
import std/strformat
import std/sequtils
import std/times
import std/math
import std/os
import std/logging
import std/json
import std/asyncdispatch
import pkg/progress
import pkg/results


# const LatBounds: tuple[a: float, b: float] = (-90.0, 90.0)
# const LonBounds: tuple[a: float, b: float] = (-180.0, 180.0)

const LatBounds: tuple[a: float, b: float] = (45.20, 46.40)
const LonBounds: tuple[a: float, b: float] = (12.50, 16.50)

const Step = 0.5

const minLatLons = product(
 arange(LatBounds, Step),
 arange(LonBounds, Step)
)
const p1 = (minLatLons.len.toFloat / 100.0)

proc logError*(data: varargs[string, `$`]) {.raises: [].} =
  try:
    error(data)
  except:
    echo "logger exception: " & getCurrentExceptionMsg()

proc processBox(latMin: float, lonMin: float, latMax: float,
    lonMax: float, cb: proc ()): Future[seq[Location]] {.async.} =
  let query = fmt"""
    [out:json][timeout:25];
    (
      node["name"]["ele"]["natural"~"peak|hill|ridge|saddle|volcano"]
      ({latMin},{lonMin},{latMax},{lonMax});
    );
    out center;
  """
  let resJson = await overpassQueryAsync(query)
  let locs = jsonToLocations(resJson)
  cb()
  result = locs


proc storeResults(data: seq[Location]) {.raises: [].} =
  var f: File
  try:
    let workingDir = getCurrentDir() / "data"
    let dataPath = workingDir / "data.json"
    if dataPath.fileExists():
      dataPath.removeFile()

    f = open(dataPath, fmWrite)
    # f.write(( %* data).pretty())
    f.write( %* data)
  except Exception as e:
    logError("Write data error ", e.repr)
  finally:
    f.close()


proc processBoxes() {.raises: [].} =
  try:
    let tt1 = getTime()
    var bar = newProgressBar()
    bar.start()

    var results: seq[Future[seq[Location]]]

    var count = 0
    for i, (latMin, lonMin) in minLatLons:
      let cb = proc () =
        let percent = (count + 1).toFloat / p1
        bar.set(percent.toInt)
        count.inc

      let latMax = latMin + Step
      let lonMax = lonMin + Step
      try:
        if i mod 10 == 0:
          sleep(1000)
        let res = processBox(latMin, lonMin, latMax, lonMax, cb)

        results.add res
      except Exception as e:
        logError(fmt"{i=} {latMin=} {lonMin=} {latMax=} {lonMax=}", e.repr)

    let awaitedResults = waitFor all(results)
    var locations: seq[Location] = @[]
    for i in awaitedResults:
      locations.add i

    storeResults(locations)
    bar.finish()
    let tt2 = getTime()
    echo fmt"Total duration: {tt2 - tt1}"
  except Exception as e:
    logError(e.repr)


proc main() {.raises: [].} =
  try:
    let workingDir = getCurrentDir() / "data"
    let loggerPath = workingDir / "peaks.log"
    if not workingDir.dirExists():
      workingDir.createDir()

    var consoleLog = newConsoleLogger()
      .catch.expect("Console logger to be created")
    var rollingLog = newRollingFileLogger(loggerPath)
      .catch.expect("Rolling logger to be created")

    addHandler(consoleLog)
    addHandler(rollingLog)

    processBoxes()
  except Exception as e:
    logError(e.repr)


when isMainModule:
  main()
