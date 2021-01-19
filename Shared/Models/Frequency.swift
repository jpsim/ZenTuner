import Foundation

// MARK: - Type Definition

struct Frequency: Equatable {
    var measurement: Measurement<UnitFrequency>
}

// MARK: - Expressible By Literal Protocols

extension Frequency: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        measurement = Measurement(value: value, unit: .hertz)
    }
}

extension Frequency: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        measurement = Measurement(value: Double(value), unit: .hertz)
    }
}

// MARK: - Localized String

private let kFrequencyFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.numberFormatter.minimumFractionDigits = 1
    formatter.numberFormatter.maximumFractionDigits = 1
    return formatter
}()

extension Frequency {
    func localizedString() -> String {
        return kFrequencyFormatter.string(from: measurement)
    }
}

// MARK: - Comparable

extension Frequency: Comparable {
    static func < (lhs: Frequency, rhs: Frequency) -> Bool {
        return lhs.measurement < rhs.measurement
    }
}

// MARK: - Octave Operations

extension Frequency {
    mutating func shifted(byOctaves octaves: Int) {
        if octaves == 0 {
            return
        } else if octaves > 0 {
            for _ in 0..<octaves {
                measurement.value *= 2
            }
        } else {
            for _ in 0..<(-octaves) {
                measurement.value /= 2
            }
        }
    }

    func distanceInOctaves(to frequency: Frequency) -> Int {
        return Int(log2f(Float(frequency.measurement.value / measurement.value)))
    }
}
