# https://osm-queries.ldodds.com/tutorial/index.html
# https://overpass-turbo.eu/

import ./locations
import std/asyncdispatch
import std/httpclient
import std/json
import std/strformat
import std/strutils

const OverpassUrl = "https://overpass-api.de/api/interpreter"

proc jsonToLocations*(data: JsonNode): seq[Location] {.raises: [].} =
  try:
    if data["elements"].kind == JArray:
      for item in data["elements"]:
        var loc = Location()
        loc.name = item["tags"]["name"].getStr()

        case item["type"].getStr():
        of "node":
          loc.lat = item["lat"].getFloat()
          loc.lon = item["lon"].getFloat()
        of "way":
          loc.lat = item["center"]["lat"].getFloat()
          loc.lon = item["center"]["lon"].getFloat()

        if item["tags"].hasKey "natural":
          loc.file = "natural"
        if item["tags"].hasKey "sport":
          loc.file = "takeoffs"
        if item["tags"].hasKey "place":
          loc.file = "cities"
        if item["tags"].hasKey "aeroway":
          loc.file = "airports"
        if item["tags"].hasKey "ele":
          loc.ele = item["tags"]["ele"].getStr().strip().parseFloat().toInt()

        result.add loc
  except Exception as e:
    echo e.repr

proc getQuery(lon: float, lat: float): string {.raises: [].} =
  result = fmt"""
  [out:json][timeout:25];
  (
    node["name"]["natural"~"peak|hill|ridge|saddle|volcano"](around:500,{lat},{lon});
    node["name"][sport=free_flying](around:500,{lat},{lon});
      nw["name"]["aeroway"~"aerodrome|airstrip|heliport"](around:1000,{lat},{lon});
    node["place"~"city|town|village"](around:2000,{lat},{lon});
  );
  out center;
  """

proc overpassQuery*(query: string, url: string = OverpassUrl): JsonNode {.raises: [].} =
  var client: HttpClient
  try:
    client = newHttpClient()
    client.headers = newHttpHeaders({"Content-Type": "application/json"})
    let res = client.post(url = url, body = "data=" & query)
    let resJson = res.body.parseJson()
    result = resJson
  except Exception as e:
    echo e.repr
  finally:
    try:
      client.close()
    except:
      echo getCurrentExceptionMsg()


proc overpassQueryAsync*(query: string, url: string = OverpassUrl): Future[
    JsonNode] {.async.} =
  var client: AsyncHttpClient
  try:
    client = newAsyncHttpClient()
    client.headers = newHttpHeaders({"Content-Type": "application/json"})
    let res = await client.post(url = url, body = "data=" & query)
    let resBody = await body (res)
    let resJson = resBody.parseJson()
    result = resJson
  except Exception as e:
    echo e.repr
  finally:
    client.close()


proc searchLocationsOverpass*(lon: float, lat: float,
    url: string = OverpassUrl): seq[Location] {.raises: [].} =
  let query = getQuery(lon, lat)
  let resJson = overpassQuery(query, url)
  result = jsonToLocations(resJson)


proc searchLocationOverpassAsync*(lon: float, lat: float,
    url: string = OverpassUrl): Future[seq[Location]] {.async.} =
  try:
    let query = getQuery(lon, lat)
    let resJson = await overpassQueryAsync(query, url)
    result = jsonToLocations(resJson)
  except Exception as e:
    echo e.repr


when isMainModule:
  echo searchLocationsOverpass(14.01362, 46.2326)
  echo waitFor searchLocationOverpassAsync(14.454425, 46.312227)


