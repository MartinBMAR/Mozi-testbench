import SwiftUI

struct RecordButton: View {
  @ObservedObject var viewModel: NoteViewModel
  @State private var isPressed: Bool = false
  @State private var rippleAnimation1: Bool = false
  @State private var rippleAnimation2: Bool = false
  @State private var rippleAnimation3: Bool = false
  @State private var rotation: Double = 0

  private let buttonSize: CGFloat = 64
  private let rippleDelay1: Double = 0.0
  private let rippleDelay2: Double = 0.3
  private let rippleDelay3: Double = 0.6

  var body: some View {
    ZStack {
      // Ripple effects (only show when recording)
      if viewModel.speechRecognizer.isRecording {
        rippleCircle(scale: rippleAnimation1 ? 1.8 : 1.0, opacity: rippleAnimation1 ? 0.0 : 0.5)
          .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
              rippleAnimation1 = true
            }
          }

        rippleCircle(scale: rippleAnimation2 ? 1.8 : 1.0, opacity: rippleAnimation2 ? 0.0 : 0.5)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + rippleDelay2) {
              withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                rippleAnimation2 = true
              }
            }
          }

        rippleCircle(scale: rippleAnimation3 ? 1.8 : 1.0, opacity: rippleAnimation3 ? 0.0 : 0.5)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + rippleDelay3) {
              withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                rippleAnimation3 = true
              }
            }
          }
      }

      // Wave background (when recording)
      if viewModel.speechRecognizer.isRecording {
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [
                Color.blue.opacity(0.3),
                Color.blue.opacity(0.1),
                Color.clear
              ]),
              center: .center,
              startRadius: 0,
              endRadius: buttonSize
            )
          )
          .frame(width: buttonSize * 1.5, height: buttonSize * 1.5)
          .rotationEffect(.degrees(rotation))
          .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
              rotation = 360
            }
          }
      }

      // Main button
      Circle()
        .fill(viewModel.speechRecognizer.isRecording ? Color.red : Color.blue)
        .frame(width: buttonSize, height: buttonSize)
        .shadow(color: viewModel.speechRecognizer.isRecording ? .red.opacity(0.5) : .blue.opacity(0.3), radius: isPressed ? 20 : 10)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .overlay(
          Image(systemName: viewModel.speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
            .font(.system(size: 28))
            .foregroundColor(.white)
        )
    }
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          if !isPressed {
            isPressed = true
            viewModel.startRecording()
          }
        }
        .onEnded { _ in
          isPressed = false
          viewModel.stopRecording()

          // Reset ripple animations
          rippleAnimation1 = false
          rippleAnimation2 = false
          rippleAnimation3 = false
          rotation = 0
        }
    )
  }

  // MARK: - Helper Views
  private func rippleCircle(scale: CGFloat, opacity: Double) -> some View {
    Circle()
      .stroke(Color.blue, lineWidth: 2)
      .frame(width: buttonSize, height: buttonSize)
      .scaleEffect(scale)
      .opacity(opacity)
  }
}

