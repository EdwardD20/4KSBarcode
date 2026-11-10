//
//  Barcode/GamesHubView.swift
//
//  Created by Ed Danley on 9/25/26.
//


import SwiftUI

enum GamesHubGame: String, Identifiable {
    case solitaire
    case xpaddle

    var id: String { rawValue }
} // GamesHubGame

struct GamesHubView: View {
    let returnToApp: () -> Void
    var onSelectGame: ((GamesHubGame) -> Void)? = nil

    @ViewBuilder
    private func gameRow(_ game: GamesHubGame, title: String) -> some View {
        if let onSelectGame {
            Button {
                onSelectGame(game)
            } label: {
                gameLabel(title)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                gameContent(game)
                    .navigationBarBackButtonHidden(true)
            } label: {
                gameLabel(title)
            }
            .buttonStyle(.plain)
        }
    } // gameRow

    @ViewBuilder
    private func gameContent(_ game: GamesHubGame) -> some View {
        switch game {
        case .solitaire:
            SolitaireContentView(onExitToHost: returnToApp)
        case .xpaddle:
            XPaddleContentView(onExitToHost: returnToApp)
        }
    } // gameContent

    private func gameLabel(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
    } // gameLabel

    var body: some View {
        NavigationStack {
            List {
                gameRow(.solitaire, title: "Cheaters Solitaire")
                    .listRowBackground(Color.red)
                    .listRowSeparator(.hidden)

                gameRow(.xpaddle, title: "eXtreme Paddle")
                    .listRowBackground(Color.red)
                    .listRowSeparator(.hidden)
            } // List
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.red.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("games_label"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: returnToApp) {
                        Text(LocalizedStringKey("Return to app"))
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                } // ToolbarItem
            } // .toolbar
        } // NavigationStack
        .toolbarBackground(Color.red, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    } // body
} // GamesHubView
