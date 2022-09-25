import XCTest
@testable import SwiftStringUtils

final class swift_string_utilsTests: XCTestCase {
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
