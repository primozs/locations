{.push raises: [].}
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
import pkg/progress
import pkg/results


const OverpassUrl = "https://overpass-api.de/api/interpreter"
  const LatBounds: tuple[a: float, b: float] = (-90.0, 90.0)
  const LonBounds: tuple[a: float, b: float] = (-180.0, 180.0)
# const LatBounds: tuple[a: float, b: float] = (45.20, 46.40)
# const LonBounds: tuple[a: float, b: float] = (12.50, 16.50)

const Step = 0.5

const minLatLons = product(
 arange(LatBounds, Step),
 arange(LonBounds, Step)
)

proc logError*(data: varargs[string, `$`]) =
  try:
    error(data)
  except:
    echo "logger exception: " & getCurrentExceptionMsg()

proc processBox(latMin: float, lonMin: float, latMax: float,
    lonMax: float): seq[Location] =
  # sleep(10)
  let query = fmt"""
    [out:json][timeout:25];
    (
      node["name"]["ele"]["natural"~"peak|hill|ridge|saddle|volcano"]
      ({latMin},{lonMin},{latMax},{lonMax});
    );
    out center;
  """
  let resJson = overpassQuery(query)
  let locs = jsonToLocations(resJson)
  result = locs


proc storeResults(data: seq[Location]) =
  var f: File
  try:
    let workingDir = getCurrentDir() / "data"
    let dataPath = workingDir / "data.json"
    f = open(dataPath, fmWrite)
    f.write( %* data)
  except Exception as e:
    logError("Write data error ", e.repr)
  finally:
    f.close()


proc processBoxes() =
  try:
    var bar = newProgressBar()
    bar.start()

    let p1 = (minLatLons.len.toFloat / 100.0)
    var results: seq[Location] = @[]

    for i, (latMin, lonMin) in minLatLons:
      let latMax = latMin + Step
      let lonMax = lonMin + Step
      try:
        let t1 = getTime()
        let res = processBox(latMin, lonMin, latMax, lonMax)
        results.add res
        # concat(results, res)
        let t2 = getTime()

        let duration = t2 - t1
        let percent = (i + 1).toFloat / p1
        bar.set(percent.toInt)
      except Exception as e:
        logError(fmt"{i=} {latMin=} {lonMin=} {latMax=} {lonMax=}", e.repr)

    storeResults(results)
    bar.finish()
  except Exception as e:
    logError(e.repr)


proc main() =
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
