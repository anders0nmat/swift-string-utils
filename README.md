# swift-string-utils

This Package contains a collection of string manipulation functions you may need.

Currently available functions:

- `replacingOccurences(with: [String: String])` : Replace substrings according to a replacement dictionary

## Functions

### `replacingOccurences(with: [String: String])`

Available to `StringProtocol`.

**Returns:** `String`.

**Description:** Providing a `Dictionary<Key = String, Value = String>` where `Key` is the occuring substring and `Value` is the string to replace with, this function replaces all occurences of `Key` with the according `Value`.

**Note:** Empty Keys will be ignored completely (e.g. `["" : "x"]`). Function variant with callback will default `advance` to at least `1` to prevent infinite loops.

**Discussion:** Constructing a replacement function based on multiple values to replace brings some problems and conciderations with it. Assume the following example:

```swift
let str = "The first Element is accesed with firstEntry"
let replace_map = [
	"first" : "last",
	"firstEntry" : "lastIndex"
]
```

If we call `str.replacingOccurences(with: replace_map)` which output do we expect? Two come to mind:
- `"The last Element is accesed with lastEntry"`
- `"The last Element is accesed with lastIndex"`

_Notice how the last word is different_

This is because replacement can take place in two ways here: Either we replace a sequence as soon as it matches any `Key` _or_ we see a sequence to replace, look for alternative replacements that could also apply and choose one of those.

This function chooses the latter and asks you to provide a function to decide which route to take. Through the variations, an interface is provided to tackle this problem, along with default behavior.

**Variations**:
- `replacingOccurences(with: [String: String])` :  
  Replaces the _longest_ match (`Key`) with its replacement (`Value`)
- `replacingOccurences(with: [String: String], using: String.ReplaceOverlapStrategy)` :  
  Replaces the match (`Key`) with its replacement (`Value`). If multiple matches apply, the `using`-parameter defines which match is used. Possible values: `.longestMatch`, `.shortestMatch`. Default: `.longestMatch`
- `replacingOccurences(with: [String:String], selecting: ([(key: String, advance: Int)]) -> (key: String, advance: Int?)?)` :  
  Replaces the longest match (`Key`) with its replacement (`Value`). For every match, `selecting` is called with all applying matches (as `[(key: String, advance: Int)]`, sorted by length, shortest `key` first). `selecting` returns a `(String, Int?)?` indicating a replacement from `with` to use as well as the amount of characters to advance. If the returned `key` is not in replacement map or `nil` is returned, no replacement is made. If `advance` is `nil`, `key.count` is used.

  ```swift
  let str = "x x x x x"
  var replace_count = 0
  
  // Replaces the first two occurences
  str = str.replacingOccurences(with: ["x": "a"]) {
    if replace_count >= 2 {
      return nil // No replacement
    }
    else {
      replace_count += 1
      return $0.last // Choose longest possible replacement
    }
  }

  // str is "a a x x x"
  ```


