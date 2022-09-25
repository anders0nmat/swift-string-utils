
extension String {
	public enum ReplaceOverlapStrategy {
		case shortestMatch, longestMatch
	}
}

extension StringProtocol {
	/**
	Returns a String where Substrings are replaced according to a replacement dictionary.

	- Parameters:
		- mapping: The replacement dictionary to use.
		- strategy: The strategy to use if multiple replacements can take place

	Example use:
	```
	let str = "The first Element is accesed with firstEntry"
	let replace_map = [
		"first" : "last",
		"firstEntry" : "lastIndex"
	]
	str.replace(with: replace_map, using: .longestMatch) // = default
	// results in "The last Element is accesed with lastIndex"

	str.replacingOccurences(with: replace_map, using: .shortestMatch)
	// results in "The last Element is accesed with lastEntry"
	```
	*/
	public func replacingOccurences(with mapping: [String:String], using strategy: String.ReplaceOverlapStrategy = .longestMatch) -> String {
		self.replacingOccurences(with: mapping, selecting: {
			switch strategy {
				case .shortestMatch: return $0.first
				case .longestMatch: return $0.last
			}
		})
	}

	/**
	Returns a String where Substrings are replaced according to a replacement dictionary.

	- Parameters:
		- mapping: The replacement dictionary to use.
		- selecting: A function selecting a replacement from a list of possible replacements

	The `selecting` parameter is neccessary to define behavior if multiple replacement routes occure.

	In this Example, there could be multiple valid/wanted replacements.
	```
	let str = "The first Element is accesed with firstEntry"
	let replace_map = [
		"first" : "last",
		"firstEntry" : "lastIndex"
	]
	str.replacingOccurences(with: replace_map, ...)
	// Could result in the following:
	// - "The last Element is accesed with lastEntry"
	// - "The last Element is accesed with lastIndex"
	//                                     ^^^^^^^^^
	```

	To enable you to choose which replacement you want to actually take, you must provide a function that chooses from these paths.

	The `selecting` parameter takes a `[String]` and returns either
	- `String?` : A valid replacement to take place, if invalid or `nil`, no replacement is done 
	- `(String?, advance: Int?)` : A valid replacement along with a number of characters to skip after the replacement. 
		If the replacement is invalid or `nil`, no replacement is done. If `advance` is `nil`, `replacement.count` is used

	The `selecting` parameter receives a list of possible replace strings (`[String]`) sorted by length from which it **should** choose one.
	However, it is only required to return a _valid_ replacement string. If the function returns `nil` or an invalid replacement string, _no_ replacement will take place.
	```
	let str = "AA AB AC"
	let replace_map = [
		"A": "B",
		"AB": "X"
	]

	// Choose shortest match
	print( str.replacingOccurences(with: replace_map) { $0.first } ) 
	// Prints "BB BB BC"

	// Choose longest match
	print( str.replacingOccurences(with: replace_map) { $0.last } ) 
	// Prints "BB X BC"

	// Invalid match, no replacement. Same as returning `nil`
	print( str.replacingOccurences(with: replace_map) { _ in "XYZ" } ) 
	// Prints "AA AB AC"

	// Always choose same match and advance as far as possible
	print( str.replacingOccurences(with: replace_map) { ("AB", advance: $0.last?.count) } ) 
	// Prints "XX X XC"
	```
	*/
	// func replacingOccurences(with mapping: [String:String], selecting: (_ from: [String]) -> String?) -> String {
	// 	self.replacingOccurences(with: mapping, selecting: { (selecting($0), advance: nil) })
	// }

	/**
	Returns a String where Substrings are replaced according to a replacement dictionary.

	- Parameters:
		- mapping: The replacement dictionary to use.
		- selecting: A function selecting a replacement from a list of possible replacements

	- Note:
		If `advance` is below 1, 1 is used instead to prevent infinite loops

	The `selecting` parameter is neccessary to define behavior if multiple replacement routes occure.

	In this Example, there could be multiple valid/wanted replacements.
	```
	let str = "The first Element is accesed with firstEntry"
	let replace_map = [
		"first" : "last",
		"firstEntry" : "lastIndex"
	]
	str.replacingOccurences(with: replace_map, ...)
	// Could result in the following:
	// - "The last Element is accesed with lastEntry"
	// - "The last Element is accesed with lastIndex"
	//                                     ^^^^^^^^^
	```

	To enable you to choose which replacement you want to actually take, you must provide a function that chooses from these paths.

	The `selecting` parameter takes a `[(key: String, advance: Int)]` and returns a `(key: String, advance: Int?)?`. A valid replacement along with a number of characters to skip after the replacement. 
	If the replacement is invalid or `nil` is returned, no replacement is done. If `advance` is `nil`, `key.count` is used
	If `advance` is less than 1, 1 is used instead to prevent infinite loops.
	
	The `selecting` parameter receives a list of possible replace strings along with their character count (`[(String, Int)]`) sorted by length from which it **should** choose one.
	However, it is only required to return a _valid_ replacement string. If the function returns `nil` or an invalid replacement string, _no_ replacement will take place.
	```
	let str = "AA AB AC"
	let replace_map = [
		"A": "B",
		"AB": "X"
	]

	// Choose shortest match
	print( str.replacingOccurences(with: replace_map) { $0.first } ) 
	// Prints "BB BB BC"

	// Choose longest match
	print( str.replacingOccurences(with: replace_map) { $0.last } ) 
	// Prints "BB X BC"

	// Invalid match, no replacement. Same as returning `nil`
	print( str.replacingOccurences(with: replace_map) { _ in ("XYZ", 3) } ) 
	// Prints "AA AB AC"

	// Always choose same match and advance as far as possible
	print( str.replacingOccurences(with: replace_map) { ("AB", advance: $0.last?.advance) } ) 
	// Prints "XX X XC"
	```
	*/
	public func replacingOccurences(with mapping: [String:String], selecting: (_ from: [(key: String, advance: Int)]) -> (key: String, advance: Int?)?) -> String {
		var mapPrefixes: [String : [String]] = [:]

		// Group all overlapping replace cases, e.g. "as", "assist" and "assert" to [ "as": ["as", "assist", "assert"] ]
		for key in mapping.keys {
			if key.isEmpty { continue } // Prevent infinite loops
			if let idxKey = mapPrefixes.keys.first(where: { $0.starts(with: key) }) {
				// When we insert something that is a prefix of other elements
				// New shortest prefix, delete old shortest and append to new shortest
				mapPrefixes[key] = mapPrefixes[idxKey]! + [key]
				mapPrefixes.removeValue(forKey: idxKey)
			}
			else if let idxKey = mapPrefixes.keys.first(where: { key.starts(with: $0) }) {
				// When we insert something that already has a registered prefix
				// Add it to the overlapping prefix list
				mapPrefixes[idxKey]!.append(key)
			}
			else {
				// No collision so far, just insert it
				mapPrefixes[key] = [ key ]
			}
		}

		// Sort overlap lists by length
		mapPrefixes.forEach { mapPrefixes[$0] = $1.sorted(by: { $0.count < $1.count }) }

		// Get all interesting substring lengths for later quick lookup
		let prefixLengths = mapPrefixes.map { $0.key.count }.sorted(by: <)

		var newString = ""

		var idx = self.startIndex
		mainLoop: while idx < self.endIndex {
			let searchRange = self[idx...]
			for preLen in prefixLengths {
				if let matchPrefix = mapPrefixes[String(searchRange.prefix(preLen))] {
					let matches = matchPrefix.compactMap { searchRange.hasPrefix($0) ? ($0, $0.count) : nil }

					if let replace = selecting(matches),
						let replacement = mapping[replace.key] {
						newString += replacement
						let advance = replace.advance ?? replace.key.count
						// Prevent infinite loops on faulty user Input (advance < 1 or "" in mapping.keys)
						self.formIndex(&idx, offsetBy: advance > 0 ? advance : 1)
						continue mainLoop
					}
				}
			}

			newString.append(self[idx])
			self.formIndex(after: &idx)
		}

		return newString
	}
}
