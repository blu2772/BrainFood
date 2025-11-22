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
            VStack(spacing: 24) {
                // Stats Section
                if let stats = viewModel.stats {
                    StatsCard(stats: stats)
                }
                
                // Card Display
                if viewModel.isLoading && viewModel.currentCard == nil {
                    ProgressView("Lade Karte...")
                        .frame(height: 400)
                } else if let card = viewModel.currentCard {
                    CardDisplayView(
                        card: card,
                        showAnswer: $viewModel.showAnswer,
                        onShowAnswer: {
                            viewModel.showAnswer = true
                        }
                    )
                    
                    if viewModel.showAnswer {
                        ReviewButtonsView(
                            isLoading: viewModel.isLoading,
                            onSubmit: { rating in
                                Task {
                                    await viewModel.submitReview(rating: rating)
                                }
                            }
                        )
                    }
                } else {
                    EmptyLearningState(nextDue: viewModel.stats?.nextDue)
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadStats()
            await viewModel.loadNextCard()
        }
    }
}

struct StatsCard: View {
    let stats: BoxStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistiken")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(stats.dueCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Fällig")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    if let nextDue = stats.nextDue {
                        Text(nextDue, style: .relative)
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Keine")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text("Nächste Fälligkeit")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CardDisplayView: View {
    let card: Card
    @Binding var showAnswer: Bool
    let onShowAnswer: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Front
            VStack(spacing: 12) {
                Text("Vorderseite")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(card.front)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)
            
            if !showAnswer {
                Button(action: onShowAnswer) {
                    Text("Antwort anzeigen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                // Back
                VStack(spacing: 12) {
                    Text("Rückseite")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(card.back)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if !card.tagsArray.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(card.tagsArray, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.green.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
}

struct ReviewButtonsView: View {
    let isLoading: Bool
    let onSubmit: (ReviewRating) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Wie war es?")
                .font(.headline)
            
            HStack(spacing: 12) {
                ReviewButton(
                    rating: .again,
                    color: .red,
                    action: { onSubmit(.again) },
                    disabled: isLoading
                )
                ReviewButton(
                    rating: .hard,
                    color: .orange,
                    action: { onSubmit(.hard) },
                    disabled: isLoading
                )
                ReviewButton(
                    rating: .good,
                    color: .green,
                    action: { onSubmit(.good) },
                    disabled: isLoading
                )
                ReviewButton(
                    rating: .easy,
                    color: .blue,
                    action: { onSubmit(.easy) },
                    disabled: isLoading
                )
            }
        }
    }
}

struct ReviewButton: View {
    let rating: ReviewRating
    let color: Color
    let action: () -> Void
    let disabled: Bool
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(rating.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
        }
        .disabled(disabled)
    }
}

struct EmptyLearningState: View {
    let nextDue: Date?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("Heute ist alles erledigt!")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let nextDue = nextDue {
                Text("Nächste Karte fällig:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(nextDue, style: .relative)
                    .font(.headline)
            }
        }
        .frame(height: 400)
    }
}

