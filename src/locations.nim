import std/strutils
import std/asyncdispatch
import std/httpclient
import std/os
import std/json
import pkg/spacy
import pkg/vmath
import pkg/bumpy

type BaseLocation = object
  name: string
  lat: float
  lon: float

type Location* = object
  name*: string
  lat*: float
  lon*: float
  file*: string
  ele*: int = -1

const locationsFilename = "locations.json"

proc getHttpResponse(url: string): Future[seq[
    BaseLocation]] {.async.} =
  let client = newAsyncHttpClient()
  try:
    let res = await client.getContent(url)
    let resJson = res.parseJson()
    result = resJson.to(seq[BaseLocation])
  except Exception:
    echo getCurrentExceptionMsg()
    echo url
  finally:
    client.close()

proc downloadLocations(path: string) {.async.} =
  let locationsPath = path / locationsFilename
  var file: File
  try:
    const sources = @[
      "https://raw.githubusercontent.com/primozs/airports-json/refs/heads/master/data/airports.json",
      "https://raw.githubusercontent.com/primozs/cities-json/refs/heads/master/data/cities.json",
      "https://raw.githubusercontent.com/primozs/pg-sites-json/refs/heads/master/data/takeoffs.json",
      "https://raw.githubusercontent.com/primozs/pg-sites-json/refs/heads/master/data/landings.json"
    ]
    var f: seq[Future[seq[BaseLocation]]]
    for item in sources:
      let future = getHttpResponse(item)
      f.add future

    let results = waitFor all(f)
    var data: seq[Location]

    for i, d in results:
      let urlParts = sources[i].splitFile()
      let fileName = urlParts.name
      for loc in d:
        data.add Location(name: loc.name, lat: loc.lat, lon: loc.lon,
            file: fileName)
    file = open(locationsPath, fmWrite)
    file.write( %* data)
  except Exception as e:
    echo e.repr
  finally:
    file.close()

proc setupLocation*(path: string) {.raises: [].} =
  try:
    if not path.dirExists():
      path.createDir()

    let locationsPath = path / locationsFilename
    # locationsPath.removeFile()
    if not locationsPath.fileExists():
      echo "Installing locations data"
      waitFor downloadLocations(path)
  except Exception as e:
    echo e.repr

proc readLocations(path: string): seq[Location] {.raises: [].} =
  var file: File
  try:
    let locationsPath = path / locationsFilename
    echo locationsPath
    if not locationsPath.fileExists():
      return

    file = open(locationsPath, fmRead)
    let text = file.readAll()
    let locJson = text.parseJson()
    result = locJson.to(seq[Location])
  except Exception as e:
    echo e.repr
  finally:
    file.close()

var locations: seq[Location]
var space: QuadSpace
proc searchLocations*(path: string, lon: float, lat: float,
    radius: float = 0.05): seq[Location] {.raises: [].} =

  setupLocation(path)
  if locations.len == 0:
    locations = readLocations(path)
    space = newQuadSpace(rect(-180.0, -90.0, 360.0, 180.0))

    for i in 0 .. locations.high:
      let loc = locations[i]
      try:
        space.insert(Entry(id: i.uint32, pos: vec2(loc.lon, loc.lat)))
      except:
        echo "error insert ", i

  var res: seq[Location]
  for v in space.findInRange(Entry(pos: vec2(lon, lat)), radius):
    res.add locations[v.id]

  return res


when isMainModule:
  const appName = "igcstats"
  const locationDirName = "location"
  let confDir = getConfigDir()
  let path = confDir / appName / locationDirName

  echo path.searchLocations(14.01362, 46.2326, 0.05)
  echo path.searchLocations(14.01362, 46.2326, 0.1)

