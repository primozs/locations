# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import os
from locations import searchLocations

test "search location":
  const appName = "igcstats"
  const locationDirName = "location"
  let confDir = getConfigDir()
  let path = confDir / appName / locationDirName

  let res = path.searchLocations(14.01362, 46.2326, 0.005)
  check res.len == 2
