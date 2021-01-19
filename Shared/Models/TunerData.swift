struct TunerData {
    var pitch: Frequency = 440
    var amplitude: Float = 0.0
    var closestNote = ScaleNote.Match(note: .A, octave: 4, distance: 0)
}

extension TunerData {
    init(pitch: Float, amplitude: Float) {
        let frequency = Frequency(floatLiteral: Double(pitch))
        self.pitch = frequency
        self.amplitude = amplitude
        self.closestNote = ScaleNote.closestNote(to: frequency)
    }
}
