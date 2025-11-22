import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 60)
                
                Text("BrainFood")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 40)
                
                VStack(spacing: 16) {
                    TextField("E-Mail", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Passwort", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        Task {
                            await authViewModel.login(email: email, password: password)
                        }
                    }) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Anmelden")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                    
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 32)
                
                Button("Noch kein Konto? Registrieren") {
                    showRegister = true
                }
                .padding(.top)
                
                Spacer()
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
}

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Registrierung")) {
                    TextField("Name", text: $name)
                    TextField("E-Mail", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    SecureField("Passwort", text: $password)
                    SecureField("Passwort bestätigen", text: $confirmPassword)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await authViewModel.register(name: name, email: email, password: password)
                            if authViewModel.isAuthenticated {
                                dismiss()
                            }
                        }
                    }) {
                        if authViewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Registrieren")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(authViewModel.isLoading || name.isEmpty || email.isEmpty || password.isEmpty || password != confirmPassword)
                }
                
                if let error = authViewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Registrieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

