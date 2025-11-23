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
    let error: String?
    let rawContent: String?
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
                
                if let jsonData = jsonString.data(using: .utf8) {
                    do {
                        let event = try JSONDecoder().decode(SSEEvent.self, from: jsonData)
                        DispatchQueue.main.async {
                            self.onEvent(event)
                        }
                    } catch {
                        print("SSE Parse Error: \(error)")
                    }
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

