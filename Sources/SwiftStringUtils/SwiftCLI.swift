

/**
	Processes a list of given arguments into a easy to access interface.

	By default, any argument that is preceded by "--" or "-" (longest match counts) will be treated as a flag with a binary state (present/not present).
	One can enter a list of "known" flags that can contain additional information/parsing rules.

	The resulting object contains properties for easy access:
	- `argumentStack`: Contains the processed argument list as a list of objects conforming to the `CommandLineArgument` Protocol
	- `namedArguments`: Contains a list of all objects with a specified name. Only flags can have names
	- `unknownArguments`: A list of non-flag arguments in order of appearance as a list of RawArgument objects. Can be mapped to a `[String]` via `.map { $0.value! }`

	Example usage:
	```
	let cli = CommandLineInterface(processors: [
		.binary("verbose"), // Can only be toggled on or off, default for unknown arguments
		.keyValue("out", valueCount: 2), // Accepts `valueCount` non-flag arguments after itself and captures them
		.keyValuePair("std", separator: ["=", ":"]), // Matches otherwise unknown flags of structure `-std=c99`, `-std:4.0pre` and stores their value
		.alias("v", for: "verbose"), // Replace every "v" with "verbose" before further parsing. Can not reference other aliases
		.compound("all-options", ["-verbose", "-out", "main.exe", "log.txt", "-std=c99"]) // Process another command list instead of this argument
	])

	// program executed with arguments: "in.txt", "-v", "--all-options"
	cli.contains("verbose") // true
	cli.valueList(for: "out") // [ "main.exe", "log.txt" ]
	cli.unknownArguments.map { $0.value! } // [ "in.txt" ]
	cli.singleValueof("std") // "c99"

	```
*/
public struct CommandLineInterface {
	public internal(set) var argumentStack: [CommandLineArgument]

	public internal(set) var namedArguments: [String:[CommandLineArgument]]
	public internal(set) var unknownArguments: [RawArgument]

	public internal(set) var flags: Set<String>


	/**
		Returns a set of values registered under the specified flag. Nil if no values are specified under the given flag
	*/
	public func valueSet(for flag: String) -> Set<String>? {
		let arr = namedArguments[flag]?.compactMap({ $0.value })
		return arr != nil ? Set<String>(arr!) : nil
	}

	/**
		Returns a list of values registered under the specified flag. Duplicate values are allowed and can occure. Nil if no values are specified under the given flag
	*/
	public func valueList(for flag: String) -> [String]? { 
		namedArguments[flag]?.compactMap 
			{ 
				$0 is KeyValueArgument ? ($0 as! KeyValueArgument).values : [$0.value ?? ""] 
			}
			.flatMap { $0 }
	
	}


	/**
		Returns whether a given flag is set *as a binary flag*. Returns true if exactly one BinaryArgument is found, false otherwise
	*/
	public func contains(_ flag: String) -> Bool {
		(namedArguments[flag]?.count ?? -1) == 1 && namedArguments[flag]!.first! is BinaryArgument
	}

	/**
		Returns the value registered under the given flag. Returns nil if registered flag is not supposed to hold a value, the flag is invalid or multiple flags are found
	*/
	public func singleValueOf(_ flag: String) -> String? {
		if let arguments = namedArguments[flag],
		let firstArgument = arguments.first, arguments.count == 1 {
			if let kvArg = firstArgument as? KeyValueArgument {
				return (kvArg.values.count == 1 && kvArg.isValid) ? kvArg.values.first! : nil
			}
			else if let kvArg = firstArgument as? KeyValuePairArgument {
				return kvArg.isValid ? kvArg.value! : nil
			}
		}
		return nil
	}



	internal static func getAsFlag(_ arg: String, flagIndicator: [String]) -> String? {
		for pre in flagIndicator {
			if arg.hasPrefix(pre) {
				return arg.endIndex > pre.endIndex ? String(arg[pre.endIndex...]) : nil
			}
		}
		return nil
	}

	init(arguments: [String] = CommandLine.arguments, flagIndicator: [String] = ["--", "-"], processors: [ ProcessorFactory ]) {
		var simpleProcessors: [String: CommandLineArgument] = [:]
		var complexProcessors: [ComplexCommandLineArgument] = []

		for proc in processors {
			proc.processors.forEach {
				if let complexProcessor = $0 as? ComplexCommandLineArgument {
					complexProcessors.append(complexProcessor)
				}
				else {
					simpleProcessors[$0.name] = $0
				}
			}
		}

		self.init(arguments: arguments, flagIndicator: flagIndicator, processors: simpleProcessors, complexProcessors: complexProcessors)
	}

	init(arguments: [String] = CommandLine.arguments, flagIndicator: [String] = ["--", "-"], processors: [ String:CommandLineArgument ], complexProcessors: [ ComplexCommandLineArgument ]) {

		self.argumentStack = []
		self.namedArguments = [:]
		self.unknownArguments = []
		self.flags = []


		func processArguments(args: [String], canResolve: Bool) {
			for arg in args {
				if let arg = CommandLineInterface.getAsFlag(arg, flagIndicator: flagIndicator) {
					// Push new flag to stack
					if var processor = processors[arg] {
						processor.index = argumentStack.endIndex
						// Simple Processor. Push processor to stack
						if let alternativeArguments = processor.associatedArguments {
							processArguments(args: alternativeArguments, canResolve: false)
						}

						if let aliasName = processor.alias {
							if var processor = processors[aliasName] {
								processor.index = argumentStack.endIndex
								argumentStack.append(processor)
							}
							else {
								argumentStack.append(BinaryArgument(name: aliasName, index: argumentStack.endIndex))
							}
						}
						else {
							argumentStack.append(processor)
						}
					}
					else if var processor = complexProcessors.compactMap({ $0.handle(arg) }).first {
						processor.index = argumentStack.endIndex
						argumentStack.append(processor)
					}
					else {
						argumentStack.append(BinaryArgument(name: arg, index: argumentStack.endIndex))
					}
				}
				else {
					// Argument. Ask last processor on stack
					if argumentStack.isEmpty || !argumentStack[argumentStack.endIndex - 1].processArg(arg) {
						argumentStack.append(RawArgument(value: arg, index: argumentStack.endIndex))
					}
				}
			}
		}

		processArguments(args: arguments, canResolve: true)

		for e in argumentStack {
			if e is BinaryArgument {
				self.flags.insert(e.name)
			}
			
			if !e.name.isEmpty {
				namedArguments[e.name] = (namedArguments[e.name] ?? []) + [e]
			}
			else if let e = e as? RawArgument {
				self.unknownArguments.append(e)
			}
		}
	}
}



public struct ProcessorFactory {
	var processors: [CommandLineArgument]

	init(_ arg: CommandLineArgument) {
		processors = [arg]
	}

	init(_ args: [CommandLineArgument]) {
		processors = args
	}
}

extension ProcessorFactory {
	public static func binary(_ name: String) -> Self { Self(BinaryArgument(name: name)) }
	public static func binary(_ names: [String]) -> Self { 
		var result = Self.alias([String](names[1...]), for: names.first!)
		result.processors.append(BinaryArgument(name: names.first!))
		return result
	}

	public static func keyValue(_ name: String, valueCount: KeyValueArgument.ValueCount = 1) -> Self { Self(KeyValueArgument(name: name, valueCount: valueCount)) }
	public static func keyValue(_ names: [String], valueCount: KeyValueArgument.ValueCount = 1) -> Self {
		var result = Self.alias([String](names[1...]), for: names.first!)
		result.processors.append(KeyValueArgument(name: names.first!, valueCount: valueCount))
		return result
	}

	public static func keyValuePair(_ name: String, separator: Set<Character>? = ["=", ":"]) -> Self { Self(KeyValuePairArgument(names: [name], separator: separator)) }
	public static func keyValuePair(_ names: [String], separator: Set<Character>? = ["=", ":"]) -> Self { Self(KeyValuePairArgument(names: names, separator: separator)) }

	public static func alias(_ name: String, for flag: String) -> Self { Self(MetaArgument(name: name, alias: flag)) }
	public static func alias(_ names: [String], for flag: String) -> Self {
		Self(names.map({ MetaArgument(name: $0, alias: flag) }))
	}

	public static func compound(_ name: String, replacedBy args: [String]) -> Self { Self(MetaArgument(name: name, associatedArguments: args)) }
	public static func compoundAlias(_ name: String, for flag: String, arguments: [String]) -> Self { Self(MetaArgument(name: name, associatedArguments: arguments, alias: flag)) }
}



public protocol CommandLineArgument {
	var name: String { get }
	var value: String? { get }
	var index: Array.Index! { get set }
	var isValid: Bool { get }

	var associatedArguments: [String]? { get }
	var alias: String? { get }

	mutating func processArg(_ arg: String) -> Bool
}

extension CommandLineArgument {
	public var associatedArguments: [String]? { nil }
	public var alias: String? { nil }
}

public protocol ComplexCommandLineArgument: CommandLineArgument {
	func handle(_ arg: String) -> Self?
}



public struct RawArgument: CommandLineArgument {
	public var name: String { "" }
	public var value: String?
	public var index: Int!
	public var isValid: Bool { value != nil && !value!.isEmpty }

	public mutating func processArg(_ arg: String) -> Bool { false }
}

public struct BinaryArgument: CommandLineArgument {
	public var name: String
	public var index: Int!
	public var isValid: Bool { true }
	public var value: String? { nil }

	public mutating func processArg(_ arg: String) -> Bool { false }
}

public struct KeyValueArgument: CommandLineArgument {
	public var name: String
	public typealias ValueCount = Int
	public var valueCount: ValueCount
	public var index: Int!
	public var isValid: Bool {
		valueCount == .zeroOrMore || 
		valueCount == .oneOrMore && !values.isEmpty ||
		valueCount == values.count
	}

	public var value: String? { values.first }
	public var values: [String] = []

	public mutating func processArg(_ arg: String) -> Bool {
		if valueCount == 0 { return false }
		if valueCount < 0 || values.count < valueCount {
			values.append(arg)
			return true
		}
		return false
	}
}

extension KeyValueArgument.ValueCount {
	public static var zeroOrMore: Self { -1 }
	public static var oneOrMore: Self { -2 }
}

public struct KeyValuePairArgument: ComplexCommandLineArgument {
	public var name: String { names.first ?? "" }
	public var names: [String]
	public var separator: Set<Character>? = ["=", ":"]
	public var isValid: Bool { value != nil }
	public var value: String?
	public var index: Int!

	public mutating func processArg(_ arg: String) -> Bool { false }

	public func handle(_ arg: String) -> Self? {
		if let separator = separator {
			if let separatorIndex = arg.firstIndex(where: { separator.contains($0) }) {
				if names.contains(String(arg[..<separatorIndex])) {
					var result = self
					result.value = String(arg.suffix(from: arg.index(after: separatorIndex)))
					return result
				}
			}
		}
		else if let appliedName = names.first(where: { arg.starts(with: $0) }) {
			var result = self
			result.value = String(arg.suffix(from: arg.index(arg.startIndex, offsetBy: appliedName.count)))
			return result
		}
		return nil
	}
}

public struct MetaArgument: CommandLineArgument {
	public var name: String
	public var associatedArguments: [String]?
	public var alias: String?
	public var index: Int!
	public var isValid: Bool { false }
	public var value: String? { nil }

	public mutating func processArg(_ arg: String) -> Bool { false }
}

