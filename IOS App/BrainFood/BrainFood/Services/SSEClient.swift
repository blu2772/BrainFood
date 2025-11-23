//
//  SSEClient.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation
import Combine

struct SSEEvent: Codable {
    let type: String
    let message: String
    let data: SSEEventData?
}

struct SSEEventData: Codable {
    let cards: [CardSuggestion]?
    let partial: String?
    let partialCards: [[String: AnyCodable]]? // Für live erkannte Karten während des Streams
    let error: AnyCodable? // Kann String oder Dictionary sein
    let rawContent: String?
}

// Helper für AnyCodable, da [String: Any] nicht direkt Codable ist
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.value = string
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map(AnyCodable.init))
        } else if let dictionary = value as? [String: Any] {
            try container.encode(dictionary.mapValues(AnyCodable.init))
        } else {
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Cannot encode AnyCodable")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

class SSEClient: NSObject, URLSessionDataDelegate {
    private var task: URLSessionDataTask?
    private var buffer = ""
    private let onEvent: (SSEEvent) -> Void
    private let onError: (Error) -> Void
    private var requestBody: Data?
    
    init(onEvent: @escaping (SSEEvent) -> Void, onError: @escaping (Error) -> Void) {
        self.onEvent = onEvent
        self.onError = onError
        super.init()
    }
    
    func start(url: URL, headers: [String: String], body: Data?) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // WICHTIG: Content-Type wird von APIClient gesetzt, nicht überschreiben
        // Nur wenn nicht in headers vorhanden, dann setzen
        if let body = body {
            request.httpBody = body
            requestBody = body
            
            // Prüfe ob Content-Type bereits in headers ist
            if !headers.keys.contains(where: { $0.lowercased() == "content-type" }) {
                // Content-Type sollte bereits vom APIClient gesetzt sein
                // Falls nicht, wird es hier nicht gesetzt, da wir multipart/form-data brauchen
            }
        }
        
        // Setze alle Header (inkl. Content-Type von APIClient)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: request)
        task?.resume()
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        
        buffer += string
        
        // Parse SSE Events (Format: "data: {...}\n\n")
        while let range = buffer.range(of: "\n\n") {
            let eventString = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            
            if eventString.hasPrefix("data: ") {
                let jsonString = String(eventString.dropFirst(6)) // Remove "data: "
                
                // DEBUG: Logge rohe JSON-Antwort
                print("🔵 [SSEClient] Rohe JSON-Antwort von Server:")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print(jsonString)
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                if let jsonData = jsonString.data(using: .utf8) {
                    do {
                        let decoder = JSONDecoder()
                        // Erlaube fehlende oder ungültige Felder
                        decoder.dataDecodingStrategy = .base64
                        let event = try decoder.decode(SSEEvent.self, from: jsonData)
                        
                        // DEBUG: Logge geparstes Event
                        print("✅ [SSEClient] Event erfolgreich geparst:")
                        print("   Type: \(event.type)")
                        print("   Message: \(event.message)")
                        if let data = event.data {
                            print("   Data vorhanden:")
                            if let cards = data.cards {
                                print("   - Cards: \(cards.count) Karten")
                                for (index, card) in cards.enumerated() {
                                    print("     [\(index)] Front: '\(card.front.prefix(50))...' | Back: '\(card.back.prefix(50))...'")
                                }
                            }
                            if let partial = data.partial {
                                print("   - Partial: \(partial.prefix(100))...")
                            }
                            if let error = data.error {
                                print("   - Error: \(error)")
                            }
                            if let rawContent = data.rawContent {
                                print("   - RawContent: \(rawContent.prefix(200))...")
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.onEvent(event)
                        }
                    } catch {
                        print("❌ [SSEClient] SSE Parse Error: \(error)")
                        print("   Error Details: \(error.localizedDescription)")
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .keyNotFound(let key, let context):
                                print("   Missing Key: \(key.stringValue)")
                                print("   Context: \(context.debugDescription)")
                            case .typeMismatch(let type, let context):
                                print("   Type Mismatch: Expected \(type)")
                                print("   Context: \(context.debugDescription)")
                            case .valueNotFound(let type, let context):
                                print("   Value Not Found: \(type)")
                                print("   Context: \(context.debugDescription)")
                            case .dataCorrupted(let context):
                                print("   Data Corrupted: \(context.debugDescription)")
                            @unknown default:
                                print("   Unknown Decoding Error")
                            }
                        }
                        print("   JSON String (erste 1000 Zeichen):")
                        print("   \(jsonString.prefix(1000))")
                        
                        // Sende Error-Event statt zu crashen
                        DispatchQueue.main.async {
                            self.onEvent(SSEEvent(
                                type: "error",
                                message: "JSON Parse Fehler: \(error.localizedDescription)",
                                data: SSEEventData(cards: nil, partial: nil, partialCards: nil, error: error.localizedDescription, rawContent: jsonString)
                            ))
                        }
                    }
                } else {
                    print("⚠️ [SSEClient] Konnte JSON-String nicht zu Data konvertieren")
                    print("   String: \(jsonString.prefix(500))")
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onError(error)
            }
        }
    }
}

