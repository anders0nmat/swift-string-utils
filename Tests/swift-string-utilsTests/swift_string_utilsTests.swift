import XCTest
@testable import SwiftStringUtils

final class swift_map_replace_Tests: XCTestCase {
	func testReplacement() throws {
		XCTAssertEqual(
			"Hello World, there is Text to find here"
				.replacingOccurences(with: [
					"World": "there",
					"Text": "Gold"
				]), 
			"Hello there, there is Gold to find here"
		)
		XCTAssertEqual(
			"One upon a time in hollywood, there were actors acting accurately"
				.replacingOccurences(with: [
					"hollywood": "a land far far away",
					"actors": "fairies",
					"acting": "flying",
					"accurately": "fabolously"
				]), 
			"One upon a time in a land far far away, there were fairies flying fabolously"
		)
		XCTAssertEqual(
			#"After several years Hayato says "私はあなたが探していたものを見つけました" but Takumi asks with tears in his eyes "よく書かれた最新のドキュメントですか？""#
				.replacingOccurences(with: [
					"私はあなたが探していたものを見つけました": "i found someone on StackOverflow with the exact same problem as you",
					"よく書かれた最新のドキュメントですか？": "but are there any replies?"
				]), 
			#"After several years Hayato says "i found someone on StackOverflow with the exact same problem as you" but Takumi asks with tears in his eyes "but are there any replies?""#
		)
		XCTAssertEqual(
			"One might want to call $number to order some $food"
				.replacingOccurences(with: [
					"$number": "(800) 555-0152",
					"$food": "Soufflet"
				]), 
			"One might want to call (800) 555-0152 to order some Soufflet"
		)
	}

	func testOverlapReplacement() throws {
		XCTAssertEqual(
			"As stated above, assisting as assertive as asked astonishingly assesses no real danger"
				.replacingOccurences(with: [
					"as ": "with ",
					"assisting": "working",
					"assertive": "peers",
					"asked": "blue shirts",
					"assesses": "poses"
				]), 
			"As stated above, working with peers with blue shirts astonishingly poses no real danger"
		)

		XCTAssertEqual(
			"As stated above, assisting as assertive as asked astonishingly assesses no real danger"
				.replacingOccurences(with: [
					"as": "with",
					"assisting": "working",
					"assertive": "peers",
					"asked": "blue shirts",
					"assesses": "poses"
				], using: .shortestMatch), 
			"As stated above, withsisting with withsertive with withked withtonishingly withsesses no real danger"
		)
	}

	func testReplacementSelectionFunc() throws {
		XCTAssertEqual(
			"Sometimes, i belive i can fly, but when i try to touch the sky, i fall to rock bottom and cry"
				.replacingOccurences(with: [
					"unusedReplacement": "see/sea",
					"fly": "",
					"sky": "peers",
					"cry": "blue shirts",
				], selecting: { ("unusedReplacement", advance: $0.first?.advance) }), 
			"Sometimes, i belive i can see/sea, but when i try to touch the see/sea, i fall to rock bottom and see/sea"
		)

		XCTAssertEqual(
			"Having $01s in a $01 is actually quite $0"
				.replacingOccurences(with: [
					"$0": "cool",
					"$01": "marble",
					"$01s": "dye",
				], selecting: { $0.count > 1 ? $0[1] : $0.first }), 
			"Having marbles in a marble is actually quite cool"
		)
	}

	func testDocumentationCases() throws {
		let str = "AA AB AC"
		let replace_map = [
			"A": "B",
			"AB": "X"
		]

		// Choose shortest match
		XCTAssertEqual( str.replacingOccurences(with: replace_map) { $0.first }, "BB BB BC" ) 

		// Choose longest match
		XCTAssertEqual( str.replacingOccurences(with: replace_map) { $0.last }, "BB X BC" ) 

		// Invalid match, no replacement. Same as returning `nil`
		XCTAssertEqual( str.replacingOccurences(with: replace_map) { _ in ("XYZ", 3) }, "AA AB AC" )

		// Always choose same match and advance as far as possible
		XCTAssertEqual( str.replacingOccurences(with: replace_map) { ("AB", advance: $0.last?.advance) }, "XX X XC" ) 


		var replace_count = 0
		XCTAssertEqual( "x x x x x".replacingOccurences(with: ["x": "a"]) {
			if replace_count >= 2 {
				return nil
			}
			else {
				replace_count += 1
				return $0.last
			}
		}, "a a x x x" )

	}
}

final class swift_CLI_Tests: XCTestCase {
	func testRawArguments() throws {
		let cli = CommandLineInterface(
			arguments: ["file.txt", "output", "main.exe"],
			processors: [])
		
		XCTAssertEqual(cli.unknownArguments.map { $0.value! }, ["file.txt", "output", "main.exe"])
	}

	func testBinaryFlags() throws {
		let cli = CommandLineInterface(
			arguments: ["in.txt", "-verbose", "-testing", "-optimize"],
			processors: [
				.binary("verbose"),
				.binary("testing"),
				.binary("optimize")
			])

		XCTAssertEqual(cli.flags, ["verbose", "testing", "optimize"])
	}

	func testAssociatedValues() throws {
		let cli = CommandLineInterface(
			arguments: ["in.txt", "-verbose", "-out", "file.txt"],
			processors: [
				.binary("verbose"),
				.keyValue("out")
			])

		XCTAssertEqual(cli.singleValueOf("out"), "file.txt")
	}

	func testMultipleAssociatedValues() throws {
		let cli = CommandLineInterface(
			arguments: ["in.txt", "-process", "file1.txt", "file2.txt", "-verbose"],
			processors: [
				.binary("verbose"),
				.keyValue("process", valueCount: .oneOrMore)
			])

		XCTAssertEqual(cli.valueList(for: "process"), ["file1.txt", "file2.txt"])
	}

	func testAlias() throws {
		let cli = CommandLineInterface(arguments: ["in.txt", "-v"],
			processors: [
				.binary("verbose"),
				.alias("v", for: "verbose")
			])

		XCTAssertEqual(cli.flags, ["verbose"])
	}

	func testAssociatedCommands() throws {
		let cli = CommandLineInterface(arguments: ["-wall"],
			processors: [
				.binary("wempty"),
				.binary("wpedantic"),
				.binary("wunused"),
				.binary("wdeprecated"),
				.binary("woverflow"),

				.compound("wall", replacedBy: ["-wempty", "-wpedantic", "-wunused", "-wdeprecated", "-woverflow"])
			])
		
		XCTAssertEqual(cli.flags, ["wempty", "wpedantic", "wunused", "wdeprecated", "woverflow"])
	}

	func testAssociatedAlias() throws {
		let cli = CommandLineInterface(arguments: ["in.txt", "-default-out", "out.txt"],
			processors: [
				.binary("verbose"),
				.keyValue("version"),
				.keyValue("out"),

				.compoundAlias("default-out", for: "out", arguments: ["-verbose", "-version", "1.0"])
			])

		XCTAssert(cli.contains("verbose"))
		XCTAssertEqual(cli.singleValueOf("version"), "1.0")
		XCTAssertEqual(cli.singleValueOf("out"), "out.txt")
	}

	func testInternalKeyValue() throws {
		let cli = CommandLineInterface(arguments: ["in.txt", "-version:4.0"],
			processors: [
				.keyValuePair("version", separator: ["=", ":"])
			])

		XCTAssertEqual(cli.singleValueOf("version"), "4.0")
	}

	func testQuickAlias() throws {
		let cli = CommandLineInterface(arguments: ["in.txt", "-v"],
			processors: [
				.binary(["verbose", "v"])
			])

		XCTAssertEqual(cli.flags, ["verbose"])
	}

	func testPlain() throws {
		print("\n\n\n")

		let cli = CommandLineInterface(
			arguments: ["in.txt", "-verbose", "-wError", "-warnPedantic", "-std=c99", "-o", "out.txt", "in2.txt"],
			processors: [
				.binary("verbose"),
				.keyValuePair(["warn", "w"], separator: nil),
				.keyValue("o"),
				.keyValuePair("std")
			])

		print("CLI:", cli)


		print("Named Arguments:", cli.namedArguments)

		let warnings = Set<String>(cli.namedArguments["warn"]?.compactMap({ $0.value }) ?? [])
		print("Warning Flags:", warnings)

		if let output_arg = cli.valueList(for: "o"), !output_arg.isEmpty {
			if output_arg.count > 1 {
				print("multiple output arguments defined but at most one valid")
			}

			let out_file_name = output_arg.first!
			print("Defined output file:", out_file_name)
		}

		if cli.contains("verbose") {
			print("Using Verbose mode")
		}

		let output_file = cli.singleValueOf("out") ?? "main.txt"
		print("outputting to", output_file)

		print("\n\n\n")
	}
}
