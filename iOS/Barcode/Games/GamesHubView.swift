//
//  Barcode/GamesHubView.swift
//
//  Created by Ed Danley on 9/25/26.
//


import SwiftUI

struct GamesHubView: View {
    let returnToApp: () -> Void

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SolitaireContentView(onExitToHost: returnToApp)
                        .navigationBarBackButtonHidden(true)
                } label: {
                    Text("Cheaters Solitaire")
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.88), in: RoundedRectangle(cornerRadius: 10))
                } // Solitaire
                .buttonStyle(.plain)
                .listRowBackground(Color.red)
                .listRowSeparator(.hidden)

                NavigationLink {
                    XPaddleContentView(onExitToHost: returnToApp)
                        .navigationBarBackButtonHidden(true)
                } label: {
                    Text("eXtreme Paddle")
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.88), in: RoundedRectangle(cornerRadius: 10))
                } // XPaddle
                .buttonStyle(.plain)
                .listRowBackground(Color.red)
                .listRowSeparator(.hidden)
            } // List
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.red.ignoresSafeArea())
            .navigationTitle("Get sidetracked...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizedStringKey("Return to app"), action: returnToApp)
                        .background(.red.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.black)
                } // ToolbarItem
            } // .toolbar
        } // NavigationStack
        .toolbarBackground(Color.red, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    } // body
} // GamesHubView
