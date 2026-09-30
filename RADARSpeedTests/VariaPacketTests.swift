import Foundation
import Testing
@testable import RADARSpeed

struct VariaPacketTests {
    @Test func headerOnlyIsNoTargets() {
        #expect(VariaPacket.parse(Data([0x30])) == [])
    }

    @Test func parsesTargetsInOrder() {
        let frame = Data([0x30, 0x81, 87, 59, 0x82, 120, 44])
        #expect(VariaPacket.parse(frame) == [
            RadarTarget(id: 0x81, rangeMetres: 87, speedKPH: 59),
            RadarTarget(id: 0x82, rangeMetres: 120, speedKPH: 44),
        ])
    }

    @Test func speedIsUnsigned() {
        #expect(VariaPacket.parse(Data([0x30, 1, 10, 200]))?.first?.speedKPH == 200)
    }

    @Test(arguments: [Data(), Data([0x30, 1]), Data([0x30, 1, 2, 3, 4])])
    func rejectsMisalignedLength(_ frame: Data) {
        #expect(VariaPacket.parse(frame) == nil)
    }

    @Test func rejectsDuplicateThreatID() {
        #expect(VariaPacket.parse(Data([0x30, 7, 50, 40, 7, 60, 45])) == nil)
    }
}
