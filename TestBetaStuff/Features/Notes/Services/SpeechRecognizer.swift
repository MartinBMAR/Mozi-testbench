import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine

class SpeechRecognizer: ObservableObject {
  // MARK: - Published Properties
  @Published var transcribedText: String = ""
  @Published var isRecording: Bool = false
  @Published var authorizationStatus: AuthStatus = .notDetermined

  // MARK: - Private Properties
  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var audioEngine = AVAudioEngine()

  // Session management for multi-recording support
  private var previousSessionsText: String = ""
  private var currentSessionText: String = ""

  // Quality control: text preservation
  private var lastTextLength: Int = 0
  private var consecutiveShortenings: Int = 0
  private let maxConsecutiveShortenings = 3

  // 58-second auto-stop timer (before 60s limit)
  private var recordingTimer: Timer?
  private let maxRecordingDuration: TimeInterval = 58.0
  private var recordingStartTime: Date?

  // Statistics
  private var updateCount: Int = 0

  // MARK: - Authorization Status
  enum AuthStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
  }

  // MARK: - Initialization
  init() {
    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    checkAuthorizationStatus()
  }

  // MARK: - Authorization
  func checkAuthorizationStatus() {
    let speechStatus = SFSpeechRecognizer.authorizationStatus()
    let micStatus = AVAudioSession.sharedInstance().recordPermission

    switch (speechStatus, micStatus) {
    case (.authorized, .granted):
      authorizationStatus = .authorized
    case (.denied, _), (_, .denied):
      authorizationStatus = .denied
    case (.restricted, _):
      authorizationStatus = .restricted
    default:
      authorizationStatus = .notDetermined
    }
  }

  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        switch status {
        case .authorized:
          AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
              self.authorizationStatus = granted ? .authorized : .denied
              completion(granted)
            }
          }
        case .denied:
          self.authorizationStatus = .denied
          completion(false)
        case .restricted:
          self.authorizationStatus = .restricted
          completion(false)
        case .notDetermined:
          self.authorizationStatus = .notDetermined
          completion(false)
        @unknown default:
          self.authorizationStatus = .denied
          completion(false)
        }
      }
    }
  }

  // MARK: - Recording Control
  func startRecording() {
    guard authorizationStatus == .authorized else {
      print("❌ Not authorized to record")
      return
    }

    guard !isRecording else {
      print("⚠️ Already recording")
      return
    }

    // Reset state for new session
    currentSessionText = ""
    lastTextLength = 0
    consecutiveShortenings = 0
    updateCount = 0
    recordingStartTime = Date()

    do {
      try startRecognition()
      isRecording = true

      // Start 58-second auto-stop timer
      recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
        print("⏱️ 58-second limit reached, auto-stopping")
        self?.stopRecording()
      }

      print("🎤 Recording started")
    } catch {
      print("❌ Failed to start recording: \(error.localizedDescription)")
      isRecording = false
    }
  }

  func stopRecording() {
    guard isRecording else { return }

    // Cancel timer
    recordingTimer?.invalidate()
    recordingTimer = nil

    // Stop audio engine
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)

    // End recognition
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()

    // Preserve current session text
    if !currentSessionText.isEmpty {
      if previousSessionsText.isEmpty {
        previousSessionsText = currentSessionText
      } else {
        previousSessionsText += " " + currentSessionText
      }
    }

    // Update transcribed text
    transcribedText = previousSessionsText

    isRecording = false

    // Log statistics
    if let startTime = recordingStartTime {
      let duration = Date().timeIntervalSince(startTime)
      let wordCount = currentSessionText.split(separator: " ").count
      let wpm = duration > 0 ? Double(wordCount) / (duration / 60.0) : 0
      print("🛑 Recording stopped - Duration: \(String(format: "%.1f", duration))s, Words: \(wordCount), WPM: \(String(format: "%.0f", wpm)), Updates: \(updateCount)")
    }

    recordingStartTime = nil
  }

  func reset() {
    stopRecording()
    transcribedText = ""
    previousSessionsText = ""
    currentSessionText = ""
    lastTextLength = 0
    consecutiveShortenings = 0
    updateCount = 0
  }

  // MARK: - Speech Recognition
  private func startRecognition() throws {
    // Cancel any existing task
    recognitionTask?.cancel()
    recognitionTask = nil

    // Configure audio session
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    // Create recognition request
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    guard let recognitionRequest = recognitionRequest else {
      throw NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
    }

    recognitionRequest.shouldReportPartialResults = true

    // Prefer on-device recognition (faster, more private)
    if #available(iOS 13, *) {
      recognitionRequest.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
      if recognitionRequest.requiresOnDeviceRecognition {
        print("✓ Using on-device recognition")
      } else {
        print("⚠️ Using cloud-based recognition")
      }
    }

    // Get audio input node
    let inputNode = audioEngine.inputNode

    // Start recognition task
    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
      guard let self = self else { return }

      if let result = result {
        let newText = result.bestTranscription.formattedString
        self.handleTranscriptionUpdate(newText: newText, isFinal: result.isFinal)
      }

      if let error = error {
        print("❌ Recognition error: \(error.localizedDescription)")
        self.stopRecording()
      }
    }

    // Configure audio format
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    // Install tap on audio input
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
      recognitionRequest.append(buffer)
    }

    // Start audio engine
    audioEngine.prepare()
    try audioEngine.start()
  }

  // MARK: - Text Preservation Logic
  private func handleTranscriptionUpdate(newText: String, isFinal: Bool) {
    updateCount += 1
    let newLength = newText.count

    // Check for text reset (drops to 0 from >0)
    if newLength == 0 && lastTextLength > 0 {
      print("⚠️ Text reset detected, preserving previous text")
      if !currentSessionText.isEmpty {
        if previousSessionsText.isEmpty {
          previousSessionsText = currentSessionText
        } else {
          previousSessionsText += " " + currentSessionText
        }
      }
      currentSessionText = ""
      lastTextLength = 0
      consecutiveShortenings = 0
      updateTranscribedText()
      return
    }

    // Check for text shortening (quality control)
    if newLength < lastTextLength {
      consecutiveShortenings += 1
      print("⚠️ Text shortened: \(lastTextLength) → \(newLength) (strikes: \(consecutiveShortenings)/\(maxConsecutiveShortenings))")

      if consecutiveShortenings >= maxConsecutiveShortenings {
        // Save current text as "complete" and start fresh
        print("⚠️ Max shortenings reached, preserving segment")
        if !currentSessionText.isEmpty {
          if previousSessionsText.isEmpty {
            previousSessionsText = currentSessionText
          } else {
            previousSessionsText += " " + currentSessionText
          }
        }
        currentSessionText = newText
        consecutiveShortenings = 0
      } else {
        // Keep longer text
        return
      }
    } else {
      // Text is same length or growing - accept it
      consecutiveShortenings = 0
      currentSessionText = newText
    }

    lastTextLength = newLength
    updateTranscribedText()

    if isFinal {
      print("✓ Final transcription received")
    }
  }

  private func updateTranscribedText() {
    if previousSessionsText.isEmpty {
      transcribedText = currentSessionText
    } else if currentSessionText.isEmpty {
      transcribedText = previousSessionsText
    } else {
      transcribedText = previousSessionsText + " " + currentSessionText
    }
  }

  // MARK: - Cleanup
  deinit {
    recordingTimer?.invalidate()
    if audioEngine.isRunning {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
    }
    recognitionTask?.cancel()
  }
}
