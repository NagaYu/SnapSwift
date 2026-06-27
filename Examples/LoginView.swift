import SwiftUI

struct WelcomeBackView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showForgotPassword: Bool = false

    var body: some View {
        VStack {
            Image(systemName: "person.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.white)
                .padding(.top, 20)

            Text("Welcome Back")
                .font(.title)
                .foregroundColor(.white)
                .padding(.top, 10)

            TextField("Email", text: $email)
                .padding(.top, 10)
                .background(Color.white)
                .cornerRadius(8)
                .padding(.horizontal, 10)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $password)
                .padding(.top, 10)
                .background(Color.white)
                .cornerRadius(8)
                .padding(.horizontal, 10)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Sign In") {
                print("Sign In button tapped")
            }
            .padding(.top, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(email.isEmpty || password.isEmpty)

            Button("Forgot password?") {
                showForgotPassword.toggle()
            }
            .padding(.top, 10)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(email.isEmpty || password.isEmpty)

            Spacer()

            if showForgotPassword {
                VStack {
                    Text("Forgot password?")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 10)

                    TextField("Enter your email", text: $email)
                        .padding(.top, 10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .padding(.horizontal, 10)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("Send reset link") {
                        print("Send reset link button tapped")
                    }
                    .padding(.top, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 20)
            }
        }
        .ignoresSafeArea()
        .background(Color.white)
        .cornerRadius(10)
    }
}

struct WelcomeBackView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeBackView()
    }
}
