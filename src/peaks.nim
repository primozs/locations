import ./overpass
import ./utils
import ./locations
import ./processor
import std/strformat
import std/math
import std/os
import std/asyncdispatch
import std/json


type FromTo = tuple[start: float, stop: float]

proc `%`(p: FromTo): JsonNode =
  var res = newJObject()
  res["start"] = newJFloat(p.start)
  res["stop"] = newJFloat(p.stop)
  return res


type Box = object
  latMin: float
  lonMin: float
  latMax: float
  lonMax: float

type Config = object
  LatBounds: FromTo = (-90.0, 90.0)
  LonBounds: FromTo = (-180.0, 180.0)
  # LatBounds: FromTo = (45.20, 46.40)
  # LonBounds: FromTo = (12.50, 16.50)
  Step: float = 0.5
  Chunks: int = 20
  OverpassUrl: string = "http://88.99.57.50:12346/api/interpreter"
  ContinueWork: bool = true
  LastChunkIndex: int = -1


proc processBox(overpassUrl: string, box: Box, cb: proc ()): Future[seq[
        Location]] {.async.} =
  let query = fmt"""
    [out:json][timeout:25];
    (
      node["name"]["ele"]["natural"~"peak|hill|ridge|saddle|volcano"]
      ({box.latMin},{box.lonMin},{box.latMax},{box.lonMax});
    );
    out center;
  """
  let resJson = await overpassQueryAsync(query, overpassUrl)
  let locs = jsonToLocations(resJson)
  cb()
  result = locs


iterator chunckedBoxes(config: Config, data: seq[FromTo]): tuple[i: int, b: seq[Box]] =
  var count = -1
  for chunk in chunked(data, config.Chunks):
    var boxChunk: seq[Box] = @[]
    for (latMin, lonMin) in chunk:
      let latMax = latMin + config.Step
      let lonMax = lonMin + config.Step
      let b = Box(latMin: latMin, lonMin: lonMin, latMax: latMax,
          lonMax: lonMax)
      boxChunk.add b

    count.inc
    yield (count, boxChunk)


proc main() {.raises: [].} =
  try:
    let p = initProcessor(name = "peaks")
    var config = Config()

    if not p.configPath.fileExists():
      saveConfig[Config](p, config)

    config = loadConfig[Config](p)

    let outputFilePath = p.outputDir / "data.csv"
    if outputFilePath.fileExists() and config.ContinueWork == false:
      outputFilePath.removeFile()

    let minLatLons = product(
     arange(config.LatBounds, config.Step),
     arange(config.LonBounds, config.Step)
    )

    timing "Total duration":
      progressBar minLatLons.len:
        for (chunkIndex, boxes) in chunckedBoxes(config, minLatLons):
          if config.ContinueWork and chunkIndex <= config.LastChunkIndex:
            progressCalc()
            continue

          var locations: seq[Location]
          var results: seq[Future[seq[Location]]]
          for box in boxes:
            try:
              let res = processBox(config.OverpassUrl, box, progressCalc)
              results.add res
            except Exception as e:
              logError(fmt"{box.repr=}: ", e.repr)

          let awaitedResults = waitFor all(results)
          for i in awaitedResults:
            locations.add i

          let hasHeader = chunkIndex == 0
          saveCsvData[seq[Location]](p, "data", locations, hasHeader)

          config.LastChunkIndex = chunkIndex
          saveConfig(p, config)
          sleep(10)

        # processing finished, reset done index
        config.LastChunkIndex = -1
        saveConfig(p, config)
  except Exception as e:
    logError(e.repr)


when isMainModule:
  main()


