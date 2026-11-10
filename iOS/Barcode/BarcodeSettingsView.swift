//
//  Barcode/BarcodeSettingsView.swift
//
//  Created by Ed Danley on 4/24/26.
//


import SwiftUI
import Combine
import AVFoundation
import SafariServices

struct BarcodeSettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "en" // "en", "es", "fr", "ar"
    @AppStorage("clientDisplayStyle") private var clientDisplayStyle: String = "barcode" // "barcode", "qrcode"

    @ObservedObject var model: PassModel
    var isEmbedded: Bool = false
    @FocusState private var isClientIdFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var editingClientId: String = ""
    @State private var showingSafari = false
    @State private var url: String = ""
    @State private var showingScanner: Bool = false
    @State private var shareTheApp: Bool = false
    @State private var selectedInfo: InfoSheetContent?
    @State private var showingEarlyEntry: Bool = false


    private var appVersion: String {
        if let dict = Bundle.main.infoDictionary,
           let version = dict["CFBundleShortVersionString"] as? String {
            return version
        } // if
        return "?.?"
    } // appVersion

    var body: some View {
        VStack(spacing: 0) {
            // --- Logo + Version ---
            if let logo = model.Logo {
                VStack(spacing: 4) {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160)
                        .background(Color.red)
                        .padding(.top, 12)

                    Text("\(NSLocalizedString("version_label", comment: "")) \(appVersion)")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                } // VStack
                .frame(maxWidth: .infinity)
                .background(Color.red)
            } // if

            NavigationView {
                ZStack {
                    // Fixed red background for the app theme
                    Color.red
                        .ignoresSafeArea()

                    Form {
                        // === Client ID field + scanner button ===
                        Section {
                            HStack {
                                TextField(
                                    LocalizedStringKey("client_id_placeholder"),
                                    text: $editingClientId
                                )
                                .focused($isClientIdFocused)
                                .foregroundStyle(.black)
                                .padding(8)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .onChange(of: editingClientId) { _, newValue in
                                    let digits = newValue.filter { $0.isNumber }

                                    editingClientId = digits
                                } // onChange

                                Button(action: { showingScanner = true }) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.title3)
                                        .foregroundColor(.black)
                                        .padding(8)
                                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                                } // Button
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("Scan Barcode"))

                            } // HStack
                        } // Section
                        .listRowBackgroundModifier()
                        .padding(.vertical, -8)

                        // === Save button ===
                        Section {
                            Button {
                                let digits = editingClientId.filter { $0.isNumber }

                                model.clientId = digits
                                model.save()
                                saveClientID(digits)
                                isClientIdFocused = false
                                if !isEmbedded {
                                    dismiss()
                                }
                            } label: {
                                Text(LocalizedStringKey(isEmbedded ? "save_client_embedded_label" : "save_client_label"))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                            } // Button
                            .buttonStyle(.plain)
                            .listRowBackground(Color.red)
                        } // Section

                        // === All other buttons ===
                        Section {
                            Button(action: {
                                if let url = URL(string: link2FeedEnrollURL) {
                                    UIApplication.shared.open(url)
                                } // if
                            }) {
                                Text(LocalizedStringKey("client_enrollment"))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            } // Button
                            .listRowBackgroundModifier()
                        } // Section

                        Section {
                            Button(LocalizedStringKey("website_label")) {
                                url = websiteURL
                                showingSafari = true
                            } // Button
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackgroundModifier()
                        } // Section
                        .padding(.vertical, -8)

                        Section {
                            Button {
                                selectedInfo = .liningUp
                            } label: {
                                Text(LocalizedStringKey("lining_up_label"))
                            } // Button
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackgroundModifier()
                        } // Section
                        .padding(.vertical, -8)

                        Section {
                            Button {
                                selectedInfo = .shopping
                            } label: {
                                Text(LocalizedStringKey("shopping_label"))
                            } // Button
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackgroundModifier()
                        } // Section
                        .padding(.vertical, -8)

                        Section {
                            Button(LocalizedStringKey("early_entry_label")) {
                                showingEarlyEntry = true
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackgroundModifier()
                        } // Section
                        .padding(.vertical, -8)

                        Section {
                            Button {
                                shareTheApp = true
                            } label: {
                                Text(LocalizedStringKey("ShareTheApp_label"))
                            } // Button
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackgroundModifier()
                        } // Section
                        .padding(.vertical, -8)
                        
                        Section {
                            Picker(LocalizedStringKey("display_as_label"), selection: $clientDisplayStyle) {
                                Text(LocalizedStringKey("display_style_barcode")).tag("barcode")
                                Text(LocalizedStringKey("display_style_qrcode")).tag("qrcode")
                            } // Picker
                            .pickerStyle(.menu)
//                        } // Section
//
//                        Section {
                            Picker(LocalizedStringKey("language_label"), selection: $appLanguage) {
                                Text("English").tag("en")
                                Text("Español").tag("es")
                                Text("Français").tag("fr")
                                Text("العربية").tag("ar")
                                Text("Deutsch").tag("de")
                                Text("Polski").tag("pl")
                                Text("Українська").tag("uk")
                                Text("中文（简体）").tag("zh-Hans")
                                Text("हिन्दी").tag("hi")
                                Text("Tagalog").tag("tl")
                                Text("Tiếng Việt").tag("vi")
                                Text("한국어").tag("ko")
                                Text("Русский").tag("ru")
                                Text("ગુજરાતી").tag("gu")
                                Text("ភាសាខ្មែរ").tag("km")
                                Text("ພາສາລາວ").tag("lo")
                                Text("Lus Hmoob").tag("hmn")
                            } // Picker
                            .pickerStyle(.menu)
                        } // Section
                        } // Form
                    .foregroundColor(.black)
                    .background(Color.red)
                    .modifier(FormBackgroundModifier())
                    .modifier(ScrollContentBackgroundModifier()) // iOS 15/16 compatible
                    .modifier(FormSectionSpacingModifier())
                    .task {
                        editingClientId = model.clientId ?? ""
                    }
                    #if DEBUG
                    .onChange(of: clientDisplayStyle) { _, newStyle in
                        // Use the most recent client id from the text field or model
                        let currentId = (editingClientId.isEmpty ? (model.clientId ?? "") : editingClientId)
                        let trimmed = currentId.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        switch newStyle {
                        case "qrcode":
                            if let qr = generateQRCodeImage(from: trimmed, size: CGSize(width: 600, height: 600)) {
                                PhoneWatchSessionManager.shared.sendBarcodeAndClientId(
                                    barcodeImage: qr,
                                    clientId: trimmed
                                )
                            }
                        case "barcode": fallthrough
                        default:
                            if let code128 = generateCode128BarcodeImage(from: trimmed, size: CGSize(width: 600, height: 200)) {
                                PhoneWatchSessionManager.shared.sendBarcodeAndClientId(
                                    barcodeImage: code128,
                                    clientId: trimmed
                                )
                            }
                        }
                    }
                    #endif
                } // ZStack
            } // NavigationView
            .navigationViewStyle(StackNavigationViewStyle())
            .toolbarBackground(Color.red, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .foregroundStyle(.black)
            .tint(.black)
            .buttonStyle(MainAppButtonStyle())
        } // VStack
        .background(Color.red.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            BottomBannerView()
        }
        .fullScreenCover(isPresented: $showingScanner) {
            BarcodeScannerView(
                metadataObjectTypes: [
                    AVMetadataObject.ObjectType.code128,
                    AVMetadataObject.ObjectType.code39,
                    AVMetadataObject.ObjectType.qr
                ],
                onScanned: { scannedValue in
                    editingClientId = scannedValue.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    showingScanner = false
                },
                onCancel: {
                    showingScanner = false
                }
            ) // BarcodeScannerView
        } // fullScreenCover
        .sheet(isPresented: $showingSafari) {
            if let u = URL(string: url) {
                SafariView(url: u)
            } // if
        } // sheet
        .sheet(item: $selectedInfo) { info in
            InfoSheet(
                isPresented: Binding(
                    get: { selectedInfo != nil },
                    set: { isPresented in
                        if !isPresented { selectedInfo = nil }
                    }
                ),
                title: info.title,
                text: info.text
            ) // InfoSheet
        } // sheet
        .sheet(isPresented: $shareTheApp) {
            ShareAppSheet()
        } // sheet
        .sheet(isPresented: $showingEarlyEntry) {
            EarlyEntrySheet(isPresented: $showingEarlyEntry)
        } // sheet
    } // body
} // BarcodeSettingsView

private enum InfoSheetContent: String, Identifiable {
    case liningUp
    case shopping

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .liningUp: return "lining_up_label"
        case .shopping: return "shopping_label"
        }
    }

    var text: LocalizedStringKey {
        switch self {
        case .liningUp: return "lining_up_text"
        case .shopping: return "shopping_text"
        }
    }
}

// MARK: - View Modifiers

extension View {
    func listRowBackgroundModifier() -> some View {
        self.listRowBackground(Color.red)
    } // listRowBackgroundModifier
} // extension View

struct FormBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            UITableView.appearance().backgroundColor = UIColor.red
        }
    } // body
} // FormBackgroundModifier

// iOS 15/16 compatible scroll content background modifier
struct ScrollContentBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        } // if
    } // body
} // ScrollContentBackgroundModifier

struct FormSectionSpacingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                UITableView.appearance().sectionHeaderHeight = 2
                UITableView.appearance().sectionFooterHeight = 2
                UITableView.appearance().estimatedSectionHeaderHeight = 2
                UITableView.appearance().estimatedSectionFooterHeight = 2
            } // onAppear
            .onDisappear {
                UITableView.appearance().sectionHeaderHeight = UITableView.automaticDimension
                UITableView.appearance().sectionFooterHeight = UITableView.automaticDimension
                UITableView.appearance().estimatedSectionHeaderHeight = UITableView.automaticDimension
                UITableView.appearance().estimatedSectionFooterHeight = UITableView.automaticDimension
            } // onDisappear
    } // body
} // FormSectionSpacingModifier

// MARK: - Existing Helper Views (unchanged)

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    } // makeUIViewController

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { } // updateUIViewController
} // SafariView

struct InfoSheet: View {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        NavigationView {
            ZStack {
                Color.red.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(title)
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.black)
                            .padding(.bottom, 8)

                        Text(text)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.black)

                        Spacer(minLength: 20)
                    } // VStack
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                } // ScrollView
                .modifier(ScrollContentBackgroundModifier())
                .foregroundStyle(.black)
            } // ZStack
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.red, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { isPresented = false }) {
                        Text(LocalizedStringKey("close_button"))
                    } // Button
                    .buttonStyle(WhiteCompactButtonStyle())
                    .fixedSize(horizontal: true, vertical: false)
                } // ToolbarItem
            } // toolbar
        } // NavigationView
        .navigationViewStyle(StackNavigationViewStyle())
        .background(Color.red.ignoresSafeArea())
        .tint(.black)
        .buttonStyle(MainAppButtonStyle())
    } // body
} // InfoSheet

struct ShareAppSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    VStack(spacing: 12) {
                        Image("app-store-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: UIScreen.main.bounds.width * 0.5) // 50% of screen width
                        if let image = generateQRCode(from: appleStoreURL),
                           let destination = URL(string: appleStoreURL) {
                            Link(destination: destination) {
                                Image(uiImage: image)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width * 0.75)
                            }
                        } // if
                    } // VStack
                    .padding(.bottom, 24)

                    VStack(spacing: 12) {
                        Image("google-play-store-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: UIScreen.main.bounds.width * 0.5) // 50% of screen width
                        if let image = generateQRCode(from: googleStoreURL) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width * 0.75) // 75% of screen width
                        } // if
                    } // VStack

                    Spacer(minLength: 20)

                } // VStack
                .padding()
            } // ScrollView
            .background(Color.red.ignoresSafeArea())
            .foregroundStyle(.black)
            .navigationTitle(LocalizedStringKey("ShareTheApp_label"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.red, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text(LocalizedStringKey("close_button"))
                    } // Button
                    .buttonStyle(WhiteCompactButtonStyle())
                    .fixedSize(horizontal: true, vertical: false)
                } // ToolbarItem
            } // toolbar
        } // NavigationView
        .tint(.black)
        .buttonStyle(MainAppButtonStyle())
    } // body

    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        } // if

        return nil
    } // generateQRCode
} // ShareAppSheet

struct EarlyEntrySheet: View {
    @Binding var isPresented: Bool

    @State private var isSubmitting: Bool = false
    @State private var requestStatusMessage: String? = nil
    @State private var errorMessage: String? = nil

    private struct RequestApprovalResponse: Decodable { let requestId: String } // RequestApprovalResponse

    private func submitApprovalRequest(clientId: String) async throws -> String {
        guard let url = URL(string: walletURL + "/api/request-approval") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["clientId": clientId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(RequestApprovalResponse.self, from: data)
        return decoded.requestId
    } // submitApprovalRequest

    private func fetchRequestStatus(requestId: String) async throws -> String {
        let urlString = walletURL + "/api/request-status/" + requestId
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // The API may return either a single object or a list; try to decode both.
        struct StatusItem: Decodable { let requestId: String; let status: String }
        if let single = try? JSONDecoder().decode(StatusItem.self, from: data) { return "\(single.status) (\(single.requestId))" }
        if let list = try? JSONDecoder().decode([StatusItem].self, from: data), let first = list.first { return "\(first.status) (\(first.requestId))" }
        // Fallback to raw string
        if let raw = String(data: data, encoding: .utf8) { return raw }
        return "Unknown status"
    } // fetchRequestStatus

    private func saveEarlyEntryStatus(_ status: String) {
        UserDefaults.standard.set(status, forKey: "EarlyEntryStatus")
    } // saveEarlyEntryStatus

    private func saveEarlyEntryIssueDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "earlyEntryIssueDate")
    } // saveEarlyEntryIssueDate

    private func pollStatusUntilComplete(requestId: String) async -> String? {
        let terminalStatuses: Set<String> = ["Senior", "Medical", "Denied"]
        let maxDuration: TimeInterval = 180 // 3 minutes
        let interval: TimeInterval = 5
        let start = Date()

        while Date().timeIntervalSince(start) < maxDuration {
            do {
                let status = try await fetchRequestStatus(requestId: requestId)
                // Extract plain status if formatted like "Status (requestId)"
                let plainStatus: String = {
                    if let parenIndex = status.firstIndex(of: "(") {
                        return String(status[..<parenIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return status.trimmingCharacters(in: .whitespacesAndNewlines)
                }()

                if terminalStatuses.contains(plainStatus) {
                    return plainStatus
                }
            } catch {
                // Ignore transient errors and continue polling
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        return nil
    } // pollStatusUntilComplete

    private func runEarlyEntryFlow() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let clientId = UserDefaults.standard.string(forKey: "LastScannedBarcode") ?? ""
        let trimmed = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            #if DEBUG
            errorMessage = NSLocalizedString("no_client_id_error", comment: "No client ID available")
            #endif
            return
        } // guard
        do {
            let requestId = try await submitApprovalRequest(clientId: trimmed)
            #if DEBUG
            requestStatusMessage = "Request submitted: \(requestId)"
            #endif
            if let finalStatus = await pollStatusUntilComplete(requestId: requestId) {
                #if DEBUG
                requestStatusMessage = "Completed with status: \(finalStatus)"
                #endif
                let now = Date()
                saveEarlyEntryIssueDate(now)
                if finalStatus == "Senior" || finalStatus == "Medical" {
                    saveEarlyEntryStatus(finalStatus)
                    if finalStatus == "Medical" {
                        #if DEBUG
                        let formatter = ISO8601DateFormatter()
                        let iso = formatter.string(from: now)
                        if let existing = requestStatusMessage, !existing.isEmpty {
                            requestStatusMessage = existing + " (\(iso))"
                        } else {
                            requestStatusMessage = "Medical date: \(iso)"
                        }
                        #endif
                    }
                } else if finalStatus == "Denied" {
                    // Do not modify stored early entry status
                } // if finalStatus
            } else {
                #if DEBUG
                requestStatusMessage = "Timed out waiting for status."
                #endif
            } // if pollStatusUntilComplete/else
        } catch {
            #if DEBUG
            errorMessage = error.localizedDescription
            #endif
        } // do/catch
    } // runEarlyEntryFlow

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Render localized markdown content
                    Text(LocalizedStringKey("early_entry_text"))
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 20)

#if DEBUG
                    HStack(spacing: 12) {
                        Button(action: {
                            Task.detached { await runEarlyEntryFlow() }
                        }) {
                            Text(isSubmitting ? "Processing…" : ".")
                        }
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .buttonStyle(MainAppButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(isSubmitting)

                        Button(action: {
                            UserDefaults.standard.removeObject(forKey: "EarlyEntryStatus")
                            UserDefaults.standard.removeObject(forKey: "earlyEntryIssueDate")
                        }) {
                            Text("Erase")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MainAppButtonStyle())
                        .padding(.horizontal, 12)
                    }
#else
                    Button(action: {
                        Task.detached { await runEarlyEntryFlow() }
                    }) {
                        Text(LocalizedStringKey("."))
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .buttonStyle(MainAppButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isSubmitting)
#endif

#if DEBUG
                    if let msg = requestStatusMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    if let err = errorMessage, !err.isEmpty {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
#endif
                } // VStack
                .padding()
            } // ScrollView
            .background(Color.red.ignoresSafeArea())
            .foregroundStyle(.black)
            .toolbarBackground(Color.red, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { isPresented = false }) {
                        Text(LocalizedStringKey("close_button"))
                    } // Button
                    .buttonStyle(WhiteCompactButtonStyle())
                    .fixedSize(horizontal: true, vertical: false)
                } // ToolbarItem
            } // toolbar
        } // NavigationView
        .buttonStyle(MainAppButtonStyle())
    } // body
} // EarlyEntrySheet

func saveClientID(_ clientId: String) {
    let trimmed = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
    UserDefaults.standard.set(trimmed, forKey: PassModel.clientKey)
    PhoneWatchSessionManager.shared.sendClientIdText(trimmed)
    guard !trimmed.isEmpty else { return }

    // Store the barcode and notify the session manager once, after Save is tapped.
    UserDefaults.standard.set(trimmed, forKey: "LastScannedBarcode")
    NotificationCenter.default.post(name: .barcodeDidChange, object: nil)
} // saveClientID
