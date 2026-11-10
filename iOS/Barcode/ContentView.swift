//
//  Barcode/ContentView.swift
//
//  Created by Ed Danley on 4/24/26.
//


import SwiftUI
import Combine
import PassKit

// Use the live window shape and both size classes. Large iPhones can have a
// regular horizontal size class in landscape, but their vertical class is compact.
// iPad and the Duo inner display have regular size classes in both dimensions.
enum MainDisplayLayout {
    static func usesTwoColumns(size: CGSize, regularWidth: Bool, regularHeight: Bool) -> Bool {
        regularWidth && regularHeight && size.width > size.height
    } // usesTwoColumns
} // enum MainDisplayLayout

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        GeometryReader { geometry in
            MainScreen(usesTwoColumns: MainDisplayLayout.usesTwoColumns(
                size: geometry.size,
                regularWidth: horizontalSizeClass == .regular,
                regularHeight: verticalSizeClass == .regular
            ))
        } // GeometryReader
        .background(Color.red.ignoresSafeArea())
        .foregroundStyle(.black)
        // Keyboard appearance must not turn a portrait window into landscape.
        .ignoresSafeArea(.keyboard)
    } // body
} // ContentView

private enum DuoRightPanel {
    case games
    case settings
}

struct MainScreen: View {
    var usesTwoColumns: Bool = false
    @Environment(\.layoutDirection) private var layoutDirection
    @AppStorage("appLanguage") private var appLanguage: String = ""
    @AppStorage("clientDisplayStyle") private var clientDisplayStyle: String = "barcode"
    @StateObject private var model = PassModel.load()
    @State private var showingSettings = false
    @State private var showingGames = false
    @State private var selectedGame: GamesHubGame?
    @State private var duoRightPanel: DuoRightPanel = .games
    @State private var showingEarlyEntryCard = false

    private var earlyEntryStatus: String {
        UserDefaults.standard.string(forKey: "EarlyEntryStatus") ?? ""
    } // earlyEntryStatus

    private var earlyEntryIssueDate: Date? {
        UserDefaults.standard.object(forKey: "earlyEntryIssueDate") as? Date
    } // earlyEntryIssueDate

    private var shouldShowEarlyEntryButton: Bool {
        let clientId = model.clientId?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""

        guard !clientId.isEmpty else {
            return false
        } // guard clientId

        let trimmedStatus = earlyEntryStatus.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedStatus.isEmpty,
              let issueDate = earlyEntryIssueDate else {
            return false
        } // guard

        let calendar = Calendar.current

        let issueYear = calendar.component(.year, from: issueDate)

        // Force currentYear to be next year
        //let currentYear = calendar.component(.year, from: Date()) + 1
        let currentYear = calendar.component(.year, from: Date())

        return issueYear == currentYear
    } // shouldShowEarlyEntryButton
    
    private func localizedFormattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale.current

        return formatter.string(from: date)
    } // localizedFormattedDate

    private var renderedEarlyEntryCardText: String {
        let clientId = model.clientId ?? ""

        var text = NSLocalizedString(
            "early_entry_card",
            comment: ""
        )

        text = text.replacingOccurrences(
            of: "?????",
            with: earlyEntryStatus
        )

        text = text.replacingOccurrences(
            of: "_____",
            with: clientId
        )

        if let medicalDate = earlyEntryIssueDate {
            text = text.replacingOccurrences(
                of: "-----",
                with: localizedFormattedDate(from: medicalDate)
            )
        } // if medicalDate

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale.current

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        var components = DateComponents()
        components.year = currentYear
        components.month = 12
        components.day = 31

        if let december31 = calendar.date(from: components) {
            let localizedDateString = formatter.string(from: december31)
            text = text.replacingOccurrences(
                of: "~~~~~",
                with: localizedDateString
            )
        } // if

        return text
    } // renderedEarlyEntryCardText

    private var mainDisplay: some View {
        GeometryReader { geo in
            let buttonWidth = geo.size.width * 0.75
            ScrollView {

                VStack(spacing: 16) {

                    // --- Logo ---
                    if let logo = model.Logo {
                        Button(action: openWebsite) {
                            Image(uiImage: logo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: max(buttonWidth - 16, 0))
                                .frame(maxHeight: geo.size.height * 0.18)
                                .cornerRadius(6)
                                .padding(8)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                                .padding(.top, 12)
                        } // Button action: openWebsite
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open 4 K.I.D.S. Sake website")
                        .accessibilityAddTraits(.isButton)
                    } else {
                        Color.red
                            .frame(height: geo.size.height * 0.14)
                            .overlay(Text("Logo").foregroundColor(.black))
                            .cornerRadius(6)
                            .padding(.top, 12)
                    } // if/else logo

                    // --- Title ---
                    Text(LocalizedStringKey("app_title"))
                        .font(.title2.weight(.semibold))

                    // --- Barcode section ---
                    VStack(spacing: 8) {
                        let isLandscape = geo.size.width > geo.size.height
                        let barcodeTargetWidth: CGFloat = isLandscape
                            ? geo.size.width * 0.5
                            : geo.size.width * 0.9

                        let qrTargetWidth: CGFloat = min(
                            isLandscape
                                ? geo.size.width * 0.5
                                : geo.size.width * 0.75,
                            barcodeTargetWidth
                        )

                        let targetHeight = barcodeTargetWidth / 2.0

                        let cid = model.clientId ?? ""

                        if !cid.isEmpty {
                            switch clientDisplayStyle {
                            case "barcode":
                                BarcodeView(code: cid)
                                    .frame(width: barcodeTargetWidth, height: targetHeight)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 8)

                                Text(cid)
                                    .font(.title2.weight(.semibold))
                                    .padding(.bottom, 8)
                                    .lineLimit(1)

                            case "qrcode":
                                if let qrImage = generateQRCodeImage(
                                    from: cid,
                                    size: CGSize(width: qrTargetWidth, height: qrTargetWidth)
                                ) {
                                    ZStack {
                                        Color.red

                                        Image(uiImage: qrImage)
                                            .interpolation(.none)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(28)
                                    } // ZStack
                                    .frame(width: qrTargetWidth, height: qrTargetWidth)
                                } // if qrImage

                                Text(cid)
                                    .font(.title2.weight(.semibold))
                                    .padding(.bottom, 8)
                                    .lineLimit(1)

                            case "number":
                                Text(cid)
                                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 20)

                            default:
                                BarcodeView(code: cid)
                                    .frame(width: barcodeTargetWidth, height: targetHeight)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 8)

                                Text(cid)
                                    .font(.title2.weight(.semibold))
                                    .padding(.bottom, 8)
                                    .lineLimit(1)
                            } // switch
                        } else {
                            Text(LocalizedStringKey("no_client"))
                                .foregroundColor(.black)
                                .padding(.bottom, 8)
                        } // if cid
                    } // VStack barcode
                    .padding()
                    .padding(.horizontal, 12)

                    if #available(iOS 17.0, *) {
                        // --- Wallet Button ---
                        if let clientId = model.clientId, !clientId.isEmpty {
                            Button(action: {
                                Task {
                                    do {
                                        let passData = try await PassService.shared.fetchPass(clientID: clientId)
                                        if let rootVC = UIApplication.shared.connectedScenes
                                            .compactMap({ $0 as? UIWindowScene })
                                            .first?.windows.first?.rootViewController {
                                            try WalletManager.shared.presentPass(from: passData, in: rootVC)
                                        }
                                    } catch {
                                        print("Wallet error:", error)
                                    }
                                } // Task
                            })
                            {
                                Image("apple-wallet")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                                    .padding(8)
                                    .frame(width: buttonWidth)
                                    .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
                            } // Button action: present wallet pass
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .accessibilityLabel("Add to Apple Wallet")
                            .accessibilityHint("Opens wallet pass for this client")
                        } // if clientID
                        
                        Spacer(minLength: 10)
                    } // if iOS 17+

                    // --- Early Entry Button ---
                    if shouldShowEarlyEntryButton {
                        Button(action: {
                            showingEarlyEntryCard = true
                        }) {
                            Text(LocalizedStringKey("early_entry_label"))
                                .padding(.horizontal, 12)
                                .frame(width: buttonWidth, alignment: .center)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 8)
                        } // Button action: show early entry card
                        .buttonStyle(.plain)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                        .accessibilityLabel(Text(LocalizedStringKey("early_entry_label")))
                    } // if shouldShowEarlyEntryButton

                    // --- Facebook button ---
                    HStack {
                        Button(action: openFacebook) {
                            HStack(spacing: 8) {
                                Image("Facebook_Logo_Primary")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 20)
                                Text("Facebook")
                            } // HStack facebook content
                            .padding(.horizontal, 12)
                            .frame(width: buttonWidth, alignment: .center)
                            .padding(.vertical, 8)
                        } // Button action: openFacebook
                        .buttonStyle(.plain)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                        .accessibilityLabel("Facebook")
                        .accessibilityAddTraits(.isButton)
                    } // HStack facebook

                    // --- Games button ---
                    Button {
                        if usesTwoColumns {
                            duoRightPanel = .games
                        } else {
                            showingGames = true
                        }
                    } label: {
                        Text(LocalizedStringKey("games_label"))
                            .padding(.horizontal, 12)
                            .frame(width: buttonWidth, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    } // Games button
                    .buttonStyle(.plain)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.black)
                    
                    // --- Settings Button ---
                    HStack {
                        Button(action: {
                            if usesTwoColumns {
                                duoRightPanel = .settings
                            } else {
                                showingSettings = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text(LocalizedStringKey("settings_button_label"))
                            } // HStack settings content
                            .padding(.horizontal, 12)
                            .frame(width: buttonWidth, alignment: .center)
                            .padding(.vertical, 8)
                        } // Button action: show settings
                        .buttonStyle(.plain)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                    } // HStack settings
                    .padding(.bottom, 20)
                } // VStack main content
                .frame(width: geo.size.width, alignment: .center)
            } // ScrollView
        } // GeometryReader
    } // mainDisplay

    var body: some View {
        HStack(spacing: 0) {
            NavigationView {
                ZStack {
                    Color.red
                        .ignoresSafeArea()

                    mainDisplay
                        .padding(.bottom, 30)
                        .overlay(alignment: .bottom) {
                            BottomBannerView()
                        }
                }
                .foregroundStyle(.black)
                .toolbarBackground(Color.red, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .environment(\.layoutDirection, layoutDirection)
            .frame(maxWidth: .infinity)
            
            if usesTwoColumns {
                Divider()
                Group {
                    switch duoRightPanel {
                    case .games:
                        GamesHubView(
                            returnToApp: {},
                            onSelectGame: { game in
                                selectedGame = game
                            }
                        )
                    case .settings:
                        BarcodeSettingsView(model: model, isEmbedded: true)
                    }
                }
                .environment(\.locale, Locale(identifier: appLanguage))
                .environment(\.layoutDirection, layoutDirection)
                .frame(maxWidth: .infinity)
            }
        }
        // Keep the requested physical column order in right-to-left languages.
        .environment(\.layoutDirection, .leftToRight)
        .onChange(of: usesTwoColumns) { _, isExpanded in
            if isExpanded {
                showingSettings = false
                duoRightPanel = .games
            }
        }
        .onAppear {
            LanguageBundle.set(appLanguage) // ensure bundle matches stored language
            if appLanguage.isEmpty {
                let preferred = Locale.preferredLanguages.first ?? "en"
                let code = String(preferred.prefix(2))
                if preferred.hasPrefix("hmn") {
                    appLanguage = "hmn"
                } else if preferred.hasPrefix("arz") {
                    appLanguage = "arz"
                } else if preferred.hasPrefix("zh-Hans") {
                    appLanguage = "zh-Hans"
                } else if ["en", "es", "fr", "ar", "de", "pl", "uk", "hi", "tl", "vi", "ko", "ru", "gu", "km", "lo"].contains(code) {
                    appLanguage = code
                } else {
                    appLanguage = "en"
                } // if/else preferred
            } // if appLanguage.isEmpty
            if (model.clientId?.isEmpty ?? true) && !usesTwoColumns {
                // Let the initial language update settle before presenting the sheet.
                DispatchQueue.main.async {
                    guard !usesTwoColumns,
                          model.clientId?.isEmpty ?? true else { return }
                    showingSettings = true
                }
            } // if clientId empty

            if let barcode = UserDefaults.standard.string(forKey: "LastScannedBarcode"),
               let clientId = model.clientId {

                switch clientDisplayStyle {
                case "qrcode":
                    if let qrImage = generateQRCodeImage(
                        from: barcode,
                        size: CGSize(width: 280, height: 280)
                    ) {
                        PhoneWatchSessionManager.shared.sendBarcodeAndClientId(
                            barcodeImage: qrImage,
                            clientId: clientId
                        )
                    }

                case "number":
                    // Render a simple image containing just the number so the Watch mirrors the setting
                    let rendererSize = CGSize(width: 800, height: 200)
                    let numberImage = UIGraphicsImageRenderer(size: rendererSize).image { ctx in
                        // Fill background with system background color
                        ctx.fill(CGRect(origin: .zero, size: rendererSize))

                        // Draw the number centered with a monospaced bold font
                        let paragraph = NSMutableParagraphStyle()
                        paragraph.alignment = .center

                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.monospacedSystemFont(ofSize: 64, weight: .bold),
                            .foregroundColor: UIColor.label,
                            .paragraphStyle: paragraph
                        ]

                        let attributed = NSAttributedString(string: barcode, attributes: attrs)
                        let textRect = CGRect(x: 0, y: (rendererSize.height - 72) / 2, width: rendererSize.width, height: 72)
                        attributed.draw(in: textRect)
                    }
                    PhoneWatchSessionManager.shared.sendBarcodeAndClientId(
                        barcodeImage: numberImage,
                        clientId: clientId
                    )

                case "barcode": fallthrough
                default:
                    if let barcodeImage = generateCode128BarcodeImage(from: barcode, size: CGSize(width: 600, height: 200)) {
                        PhoneWatchSessionManager.shared.sendBarcodeAndClientId(
                            barcodeImage: barcodeImage,
                            clientId: clientId
                        )
                    }
                }
            }
        } // onAppear
        .sheet(isPresented: Binding(
            get: { showingSettings && !usesTwoColumns },
            set: { showingSettings = $0 }
        )) {
            BarcodeSettingsView(model: model)
                .environment(\.locale, Locale(identifier: appLanguage))
        } // sheet
        .sheet(isPresented: $showingEarlyEntryCard) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(.init(renderedEarlyEntryCardText))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } // VStack
                    .padding()
                } // ScrollView
                .background(Color.red.ignoresSafeArea())
                .foregroundStyle(.black)
                .navigationTitle(Text(LocalizedStringKey("early_entry_label")))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.red, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                            showingEarlyEntryCard = false
                        } // Button close
                    } // ToolbarItem
                } // toolbar
            } // NavigationView
            .tint(.black)
        } // sheet early entry
        .fullScreenCover(item: $selectedGame) { game in
            Group {
                switch game {
                case .solitaire:
                    SolitaireContentView(onExitToHost: {
                        selectedGame = nil
                    }, expandsToAvailableWidth: true)
                case .xpaddle:
                    XPaddleContentView(onExitToHost: {
                        selectedGame = nil
                    })
                }
            }
            .environment(\.locale, Locale(identifier: appLanguage))
            .id(appLanguage)
        }
        .fullScreenCover(isPresented: $showingGames) {
            GamesHubView(
                returnToApp: {
                    showingGames = false
                }
            )
            .environment(\.locale, Locale(identifier: appLanguage))
            .id(appLanguage)
        } // .fullScreenCover $showingGames
        .navigationBarTitleDisplayMode(.inline)
    } // body

    private func openWebsite() {
        if let url = URL(string: websiteURL) {
            UIApplication.shared.open(url)
        } // if open url
    } // openWebsite

    private func openFacebook() {
        if let url = URL(string: facebookURL) {
            UIApplication.shared.open(url)
        } // if open url
    } // openFacebook

} // MainScreen
