import SwiftUI

struct ContentView: View {
	@StateObject private var viewModel = AppViewModel()
	@State private var showSettings = false
	@State private var baseURLText = APIService.shared.baseURL.absoluteString
	@State private var pingResult: String?
	@State private var isPinging = false
	
	private func ping() async {
		isPinging = true
		defer { isPinging = false }
		do {
			let result = try await APIService.shared.health()
			pingResult = "OK: \(result)"
		} catch {
			pingResult = "Fehler: \(error.localizedDescription)"
		}
	}

	var body: some View {
        Group {
            if viewModel.token == nil {
                AuthView(viewModel: viewModel)
            } else if viewModel.boxId == nil {
                BoxSelectionView(viewModel: viewModel)
            } else {
                TabView {
                    ReviewView(viewModel: viewModel)
                        .tabItem { Label("Lernen", systemImage: "checkmark.seal.fill") }

                    LibraryView(viewModel: viewModel)
                        .tabItem { Label("Karten", systemImage: "square.grid.2x2.fill") }
                }
                .accentColor(.indigo)
            }
        }
		.task {
			if viewModel.userId != nil && viewModel.boxId != nil {
				await viewModel.loadCards()
			}
		}
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button { showSettings = true } label: { Image(systemName: "gear") }
			}
		}
		.sheet(isPresented: $showSettings) {
			NavigationStack {
				Form {
					Section(header: Text("API Basis-URL")) {
						TextField("https://…", text: $baseURLText)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
					}
                    Section(header: Text("Kontext")) {
                        Text("User ID: \(viewModel.userId ?? "–")")
                        Text("Box ID: \(viewModel.boxId ?? "–")")
                        Text("Token: \(viewModel.token?.prefix(6) ?? "–")…")
                    }
					Section {
						Button("Übernehmen und Karten neu laden") {
							if let url = URL(string: baseURLText) {
								APIService.shared.baseURL = url
								Task { await viewModel.loadCards() }
								showSettings = false
							}
						}
						Button {
							Task { await ping() }
						} label: {
							if isPinging { ProgressView() } else { Text("API Healthcheck ausführen") }
						}
						if let pingResult {
							Text(pingResult)
								.font(.caption)
								.foregroundColor(.secondary)
								.textSelection(.enabled)
						}
                        Button("Logout") {
                            viewModel.logout()
                            showSettings = false
                        }
					}
				}
				.navigationTitle("Einstellungen")
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Schließen") { showSettings = false }
					}
				}
			}
			.presentationDetents([.medium, .large])
		}
		.alert(isPresented: Binding<Bool>(
			get: { viewModel.error != nil },
			set: { _ in viewModel.error = nil }
		)) {
			Alert(title: Text("Fehler"), message: Text(viewModel.error ?? ""), dismissButton: .default(Text("OK")))
		}
	}
}

#Preview {
	ContentView()
}

struct ReviewView: View {
	@ObservedObject var viewModel: AppViewModel
	@State private var showBack = false

	private var nextCard: Card? {
		viewModel.dueCards.first ?? viewModel.cards.sorted { $0.due < $1.due }.first
	}

var body: some View {
		NavigationStack {
			ZStack {
				LinearGradient(colors: [.indigo.opacity(0.35), .blue.opacity(0.25), .mint.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
					.ignoresSafeArea()

				VStack(spacing: 16) {
					header
					if let card = nextCard {
						cardBody(card)
						ratingsRow(card)
					} else {
						emptyState
					}
					Spacer()
				}
				.padding()
			}
			.navigationTitle("FSRS Lernplan")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						Task { await viewModel.loadCards() }
					} label: {
						Image(systemName: "arrow.clockwise")
					}
				}
			}
		}
	}

	@ViewBuilder
	private var header: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text("Fällige Karten")
					.font(.caption)
					.foregroundColor(.secondary)
				Text("\(viewModel.dueCards.count)")
					.font(.largeTitle).bold()
			}
			Spacer()
			if let next = nextCard {
				VStack(alignment: .trailing, spacing: 4) {
					Text("Nächste Fälligkeit")
						.font(.caption)
						.foregroundColor(.secondary)
					Text(next.due, style: .time)
						.font(.headline)
				}
			}
		}
	}

	@ViewBuilder
	private func cardBody(_ card: Card) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Frage")
				.font(.caption)
				.foregroundColor(.secondary)
			Text(card.front)
				.font(.title3).bold()
				.frame(maxWidth: .infinity, alignment: .leading)

			if showBack {
				Divider()
				Text("Antwort")
					.font(.caption)
					.foregroundColor(.secondary)
				Text(card.back.isEmpty ? "–" : card.back)
					.font(.title3)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			Spacer()
			HStack {
				ForEach(card.tags, id: \.self) { tag in
					Text(tag)
						.font(.caption2)
						.padding(.horizontal, 8)
						.padding(.vertical, 4)
						.background(Color.black.opacity(0.06))
						.cornerRadius(12)
				}
				Spacer()
				Button(showBack ? "Antwort verstecken" : "Antwort zeigen") {
					withAnimation { showBack.toggle() }
				}
				.buttonStyle(.borderedProminent)
			}
		}
		.padding()
		.frame(maxWidth: .infinity)
		.frame(height: 260)
		.background(.ultraThinMaterial)
		.cornerRadius(20)
		.shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
	}

	@ViewBuilder
	private func ratingsRow(_ card: Card) -> some View {
		LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
			ForEach(ReviewRating.allCases) { rating in
				Button {
					Task {
						await viewModel.review(card: card, rating: rating)
						showBack = false
					}
				} label: {
					VStack(spacing: 6) {
						Text(rating.title)
							.font(.headline)
						Text(label(for: rating))
							.font(.caption)
							.opacity(0.8)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 14)
					.background(color(for: rating).opacity(0.15))
					.overlay(
						RoundedRectangle(cornerRadius: 16)
							.stroke(color(for: rating).opacity(0.2), lineWidth: 1)
					)
					.cornerRadius(16)
				}
			}
		}
	}

	private func label(for rating: ReviewRating) -> String {
		switch rating {
		case .again: return "Reset (1)"
		case .hard: return "Knapper Erfolg (2)"
		case .good: return "Gut behalten (3)"
		case .easy: return "Sehr sicher (4)"
		}
	}

	private func color(for rating: ReviewRating) -> Color {
		switch rating {
		case .again: return .red
		case .hard: return .orange
		case .good: return .green
		case .easy: return .blue
		}
	}

	@ViewBuilder
	private var emptyState: some View {
		VStack(spacing: 12) {
			Image(systemName: "sparkles")
				.font(.largeTitle)
			Text("Keine fälligen Karten")
				.font(.headline)
			Text("Erstelle neue Karten oder warte bis die nächsten Fälligkeiten erreicht sind.")
				.font(.subheadline)
				.multilineTextAlignment(.center)
				.foregroundColor(.secondary)
			Button("Jetzt Karten laden") {
				Task { await viewModel.loadCards() }
			}
		}
		.padding()
		.background(.ultraThinMaterial)
		.cornerRadius(12)
	}
}

struct LibraryView: View {
	@ObservedObject var viewModel: AppViewModel
	@State private var query = ""

	var body: some View {
		NavigationStack {
			List {
				ForEach(filteredCards, id: \.id) { card in
					VStack(alignment: .leading, spacing: 6) {
						Text(card.front)
							.font(.headline)
						Text(card.back)
							.foregroundStyle(.secondary)
						HStack {
							Label("\(card.reps) Wiederholungen", systemImage: "clock")
							Spacer()
							Text(card.due, style: .date)
						}
						.font(.caption)
						.foregroundStyle(.secondary)
					}
					.padding(.vertical, 4)
				}
			}
			.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
			.navigationTitle("Karten")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						viewModel.isShowingCreate = true
					} label: {
						Image(systemName: "plus")
					}
				}
			}
			.sheet(isPresented: $viewModel.isShowingCreate) {
				CreateCardSheet(viewModel: viewModel)
					.presentationDetents([.medium, .large])
			}
		}
	}

	private var filteredCards: [Card] {
		if query.trimmingCharacters(in: .whitespaces).isEmpty {
			return viewModel.cards
		}
		return viewModel.cards.filter {
			$0.front.localizedCaseInsensitiveContains(query) ||
			$0.back.localizedCaseInsensitiveContains(query)
		}
	}
}

struct CreateCardSheet: View {
	@ObservedObject var viewModel: AppViewModel
	@Environment(\.dismiss) private var dismiss
	@State private var front = ""
	@State private var back = ""
	@State private var tags = ""

	var body: some View {
		NavigationStack {
			Form {
				Section(header: Text("Karte")) {
					TextField("Front (z. B. Wort oder Frage)", text: $front)
					TextField("Back (Übersetzung/Antwort)", text: $back)
					TextField("Tags (Komma-separiert)", text: $tags)
				}
			}
			.navigationTitle("Neue Karte")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Abbrechen") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Speichern") {
						Task {
							let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
							await viewModel.createCard(front: front, back: back, tags: tagList)
							dismiss()
						}
					}
					.disabled(front.isEmpty || back.isEmpty)
				}
			}
		}
	}
}

struct AuthView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isRegister = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("BrainFood")
                        .font(.largeTitle.bold())
                    Text(isRegister ? "Konto erstellen" : "Bitte anmelden")
                        .foregroundColor(.secondary)
                }
                VStack(spacing: 12) {
                    if isRegister {
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                    }
                    TextField("E-Mail", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Passwort", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Button {
                    Task {
                        isSubmitting = true
                        defer { isSubmitting = false }
                        if isRegister {
                            await viewModel.register(name: name, email: email, password: password)
                        } else {
                            await viewModel.login(email: email, password: password)
                        }
                    }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(isRegister ? "Registrieren" : "Anmelden")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(email.isEmpty || password.isEmpty || (isRegister && name.isEmpty))

                Button(isRegister ? "Bereits Konto? Anmelden" : "Noch kein Konto? Registrieren") {
                    isRegister.toggle()
                }
                .foregroundColor(.indigo)

                if let error = viewModel.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(isRegister ? "Registrieren" : "Anmelden")
        }
    }
}

struct BoxSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var newBoxName = ""

var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("Box auswählen")
                            .font(.title.bold())
                        Text("Organisiere deine Themen")
                            .foregroundColor(.secondary)
                    }
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.boxes, id: \.id) { box in
                                Button {
                                    viewModel.selectBox(box)
                                    Task { await viewModel.loadCards() }
                                } label: {
                                    BoxCard(title: box.name, subtitle: box.id, selected: viewModel.boxId == box.id)
                                }
                            }
                            VStack(spacing: 10) {
                                TextField("Neue Box", text: $newBoxName)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    Task {
                                        await viewModel.createBox(name: newBoxName)
                                        await viewModel.loadBoxes()
                                        newBoxName = ""
                                    }
                                } label: {
                                    Text("Box erstellen")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(newBoxName.isEmpty)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .task { await viewModel.loadBoxes() }
        }
    }
}

private struct BoxCard: View {
    let title: String
    let subtitle: String
    let selected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.indigo)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.indigo.opacity(0.15) : Color.white.opacity(0.7))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
}
