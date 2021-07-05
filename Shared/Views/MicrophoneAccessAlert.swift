import SwiftUI

func MicrophoneAccessAlert() -> Alert {
    Alert(
        title: Text("No microphone access"),
        message: Text(
            """
            Please grant microphone access in the Settings app in the "Privacy ⇾ Microphone" section.
            """
        )
    )
}
