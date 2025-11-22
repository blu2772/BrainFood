//
//  LearningView.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import SwiftUI

struct LearningView: View {
    let boxId: String
    @StateObject private var viewModel: LearningViewModel
    
    init(boxId: String) {
        self.boxId = boxId
        _viewModel = StateObject(wrappedValue: LearningViewModel(boxId: boxId))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Section
                if let stats = viewModel.stats {
                    StatsCard(stats: stats)
                }
                
                // Card Display
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else if let card = viewModel.currentCard {
                    CardView(card: card, showAnswer: viewModel.showAnswer)
                        .padding()
                    
                    if !viewModel.showAnswer {
                        Button("Antwort anzeigen") {
                            viewModel.showAnswer = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        // Rating Buttons
                        HStack(spacing: 15) {
                            RatingButton(title: "Again", color: .red, rating: "again") {
                                Task {
                                    await viewModel.reviewCard(rating: "again")
                                }
                            }
                            RatingButton(title: "Hard", color: .orange, rating: "hard") {
                                Task {
                                    await viewModel.reviewCard(rating: "hard")
                                }
                            }
                            RatingButton(title: "Good", color: .green, rating: "good") {
                                Task {
                                    await viewModel.reviewCard(rating: "good")
                                }
                            }
                            RatingButton(title: "Easy", color: .blue, rating: "easy") {
                                Task {
                                    await viewModel.reviewCard(rating: "easy")
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Heute ist alles erledigt!")
                            .font(.headline)
                        if let nextDue = viewModel.stats?.nextDue {
                            Text("Nächste Karte fällig: \(formatDate(nextDue))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadStats()
            await viewModel.loadNextCard()
        }
        .refreshable {
            await viewModel.loadStats()
            await viewModel.loadNextCard()
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct StatsCard: View {
    let stats: BoxStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Statistiken")
                .font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text("\(stats.dueCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Fällig")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("\(stats.totalCards)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Gesamt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("\(stats.totalReviews)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Wiederholungen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CardView: View {
    let card: Card
    let showAnswer: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Frage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(card.front)
                    .font(.title2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            if showAnswer {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Antwort")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(card.back)
                        .font(.title3)
                    
                    if let tags = card.tags, !tags.isEmpty {
                        Text("Tags: \(tags)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

struct RatingButton: View {
    let title: String
    let color: Color
    let rating: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .cornerRadius(8)
        }
    }
}

#Preview {
    LearningView(boxId: "1")
}

