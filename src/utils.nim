{.push raises: [].}

iterator arangeIt*[T: int | float](start: T, stop: T, step: T): T =
  var i = start
  while i < stop:
    yield i
    i = i + step


func arange*[T: int | float](start: T, stop: T, step: T): seq[T] =
  var i = start
  while i < stop:
    result.add i
    i = i + step


func arange*[T, U](r: tuple[start: T, stop: U], step: T): seq[T] =
  var i = r[0]
  while i < r[1]:
    result.add i
    i = i + step


iterator productIt*[T, U](s1: openArray[T], s2: openArray[U]): tuple[a: T, b: U] =
  ## Iterator producing tuples with Cartesian product of the arguments.
  ## Equivalent to nested for-loops.
  runnableExamples:
    let
      a = @[1, 2, 3]
      b = "ab"
    var s: seq[tuple[a: int, b: char]] = @[]
    for x in product(a, b):
      s.add(x)
    doAssert s == @[(a: 1, b: 'a'), (a: 1, b: 'b'), (a: 2, b: 'a'),
                    (a: 2, b: 'b'), (a: 3, b: 'a'), (a: 3, b: 'b')]

  for a in s1:
    for b in s2:
      yield (a, b)

func product*[T, U](s1: openArray[T], s2: openArray[U]): seq[tuple[start: T, stop: U]] =
  for a in s1:
    for b in s2:
      result.add (a, b)


iterator chunked*[T](s: openArray[T], size: Positive): seq[T] =
  ## Iterator which yields ``size``-sized chunks from ``s``.
  runnableExamples:
    let
      a = "abcde"
      b = [11, 12, 13, 14, 15, 16, 17, 18]
    var
      s1: seq[seq[char]] = @[]
      s2: seq[seq[int]] = @[]
    for x in chunked(a, 2):
      s1.add(x)
    for x in chunked(b, 3):
      s2.add(x)
    doAssert s1 == @[@['a', 'b'], @['c', 'd'], @['e']]
    doAssert s2 == @[@[11, 12, 13], @[14, 15, 16], @[17, 18]]

  var i: int
  while i + size < len(s):
    yield s[i ..< i+size]
    i += size
  yield s[i .. ^1]


