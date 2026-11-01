import Testing
@testable import ShowModel

@Test func templatesHaveExpectedCounts() {
    #expect(BuiltInTemplates.all.map(\.channelCount) == [1, 3, 4, 5, 8, 16])
}
