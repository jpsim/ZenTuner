import Foundation

// MARK: - Type Definition

struct Frequency: Equatable {
    private(set) var measurement: Measurement<UnitFrequency>
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
    /// Returns the current frequency shifted by increasing or decreasing in discrete octave increments.
    ///
    /// - parameter octaves: The number of octaves to transpose this frequency. Can be positive or negative.
    ///
    /// - returns: Octave shifted frequency.
    func shifted(byOctaves octaves: Int) -> Frequency {
        var copy = self
        copy.shift(byOctaves: octaves)
        return copy
    }

    /// Shifts the frequency by increasing or decreasing in discrete octave increments.
    ///
    /// - parameter octaves: The number of octaves to transpose this frequency. Can be positive or negative.
    mutating func shift(byOctaves octaves: Int) {
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

    /// Computes the distance in octaves between the current frequency and the specified frequency. Truncates if
    /// distance is not exact octaves.
    ///
    /// - parameter frequency: Frequency to compare.
    ///
    /// - returns: Distance in octaves to specified frequency.
    func distanceInOctaves(to frequency: Frequency) -> Int {
        return Int(log2f(Float(frequency.measurement.value / measurement.value)))
    }
}
