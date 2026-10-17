# Cheaters Solitaire — ToDo

## Basic game play

1. Normal 3-draw rules of Klondike apply
2. FogHorn sounds when no more game plays are avaialble
3. Applause sounds when all cards have been exposed


## Current accepted/known/allowed cheats

1. Triple click the stock resorts the stock
2. Triple click a face down card to expose it for 2 seconds
3. Drag the top card from the stock behind a face up card in a tableau column
4. Any of the cards in the draw are available picking. If not top card, it is a cheat.

## Penalties for cheating

1. Reverse the colors of the cards for 123 seconds, face cards (K, Q, J) go negative
2. Flip the top card of an exposed column with 2 or more cards exposed to be face down

## New Claude conversations

Upload the latest zip and give a short summary — something like:

This is Cheaters Solitaire, a SwiftUI Klondike variant with hidden cheats; it currently builds and runs but problems are still being found; here's what is still outstanding at this time:



## Old Ideas

Fixed Bug: Cannot place King on empty tableau column
New: Softly play FogHorn.m4a if no more moves are available and deck has been fully exposed.
Fixed Bug: The tableau should be the full width of the table. ALso make sure there is room for all cards to fill down and still fit on the tableau. If I adjust the table size, the cards should re-size to fit.
Fixed New: Add a ? button that explains the rules: If you can cheat, then so can I.
Fixed New: Mirror the card an suit in the bottom right corner (upside down)
Fixed New: Add big color matching number in the middle of each faced card (suit for Ace). Use Jack-Spades.png (for example) for Jack, Queen, King.
Fixed New: An empty column in the tableau needs a better shape recognition. Make the fill area black.
New: The image for a face card is now working, however it is still a little too large and I don't want a frame around the image.
New: The empty stock needs a darker fill as well. Use same as empty tableau column.
New: New Game button and entire tableau not visible at all on iPhone. Reduce the space between the stock and the tableau.
New: When in DEBUG mode, all cheats should have a print to the console explaining the cheat that just occurred
New: Do landscape lock for iPhoneOS, not for iPadOS.
New: Also the Empty Aces piles are still not darkened.
New: The debug display saying things like "Phase: Playing" on iOS is overlaying the stock and Aces. Move it in line with New Game, but shorten width to fit
New: "hasAnyLegalMove: YES — pile 2 index 3 (4 of diamonds) -> pile 5" - Once again a useless legal move. Moving 4 of diamonds from a black 5 in pile 2 to a black 5 in pile 5 accomplishes nothing. With each new game, I'm seeing additional variations of this same situation. You already acknowledged this before I ran out of tokens.
New: Double clicking a King should move it to an empty pile if one is available, like with the Aces and cards that follow.
New: If this is legal in Klondike, a card placed on the Aces stack should be able to be moved back to a Tableau pile
New: On my physical iPhone 17 Pro Max, in landscape mode and at night in Dark mode, the face symbols are properly colored but nothing else is colored.
New: When there no legal moves of value (see hasAnyLegalMove above) in the Tableau, and the user went though the stack and there was no legal moves that the player did or they missed but the game spotted, then play the FogHorn.m4a sound. This is basically telling the user the game has been lost.
New: Still getting "SoundManager: missing audio asset FogHorn.m4a — check target membership / Copy Bundle Resources". Remember, FogHorn.m4a is a loose file, not in Assets.
New: Once all cards have been legally exposed, play an applause sound (not provided - do I need to find one?)
New: First, I realized I named my FogHorn sound wrong. I fixed that and it is now heard. However, it is playing whenever the draw pile has completed and no moved left on that round of the draw, not when there were no moves made or remaining.
New: In iPhone mode, have the Tableau top align with the draw pile and the Aces stack. Move the Aces stack to the right edge of the screen. This give more space top to bottom. Hopefully this will allow the cards to be slightly bigger in size. Also add the ability to zoom in on the entire table.
New: iPad in portrait mode. The Foundations stack still does not fit on display. There is plenty of room to bring them closer to the stock, much like the display in Landscape mode.
New: iPad landscape mode cannot see all visible cards on the bottom of the tableau. Only 9 cards are visible in a column
New: The stock is not show the cards in the same order each time. They appear to be reversing the display of the 3 cards each time.
New: Double tapping a King to move to an empty tableau pile should also happen if there are other valid cards on the King. 
New: Zoom in should happen anywhere on the table, not just the tableau. Also be careful on zoom in to not select (expose/cheat) a card.
New: Verify the draw pile cards never shuffle unless double clicked, and that double click countrs as a cheat.
New: On an iPad in portrait mode, the game board is not entirely visible. When I rotate an iPad into landscape mode, the gameboard is too wide, making the cards tiny.
New: All empty card locations should have a white background so the suit can be seen better
New: Like tapping on a card to go to the Aces stack, add double tap a card to land on a single choice, and only a single choice, in the tableau.
New: Double clicking to move a card to the Aces Foundation should not be automatic if the card can also be played on the tableau.
New: Turn off Debug console display at top of game board.
Bug: Zoom blocking at the top needs to consider the Debug display and New Game. Zoom top currently gets lost under the Debug display and can't be moved back down.
New: Add a header to all source files looking like:

//
//  <folder>/<source file name>.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on mm/dd/yy.
//
//  This file accomplishes: <insert brief overview>
//

New: Add Undo button next to New Game. (Make it worth 1/4 cheat point - not yet)
New: Add a timer for how long the game lasts.
New: Add a top results, date & time played, length of game.
Bug: The FogHorn should not play until no valid moves on the Tableau and the entire stock has been played with no moves available. Right now it is playing mid-draw and I still find valid moves.
Bug: With the Debug Console no longer being displayed, that space is now white, not the tablefelt color.
New: Timer does not display properly (clipped) if iPhone Accessibility has font size greater than default.
New: Change of layout for iPhone. Add portrait mode and remove landscape mode. Remove zoom feature. Put tableau below stock and Foundations. Make the screen scrollable so if the  tableau columns become too many cards, user can simply scroll down to see them. All of the cards should adjust in size to be perhaps 50% bigger.
Bug: SoundManager, line 42, p.prepareToPlay() "AVAudioSession_iOS.mm:978 This method can lead to UI unresponsiveness if called on the main thread. Consider using the asynchronous activate/deactivate API instead for calls from the main thread."
New: On any cheat, play the chicken sound.
New: When the first cheat occurs, reverse the colors of the clock timer. If the game is won, record the win as a cheat.
Bug: In particular, if a facedown card has been revealed via cheat, a new game must reset all cheats. This particular cheat was being left behind.
New: Add amimation to drag a card from one place to another (in addition to tapping).
New: I am personally red-green colorblind. When playing my solitaire game on the small screen of an iPhone, I have trouble seeing the red color cards as red. Can red be made more vivid red? Another possibility might be to lighten the green of table-felt background.
New Cheat: All cheats should be isolated with an a check to see if cheating is turned on. Default to on for now, it may become a paid option in the future.
New Cheat: When in DEBUG mode, all cheats should have a print to the console explaining the cheat
New: Change of layout for iPad. Remove zoom feature. Borh portrait and  landscape mode layout should match iPhone. Put tableau below stock and Foundations. Make the screen scrollable up and down so if the  tableau columns become too many cards, user can simply scroll down to see them. In summary, both iPhone and iPad should match layouts in iPhone portrait mode and both iPad portrait and landscape modes.
New cheat: Long pressing on a faced down card on tableau (> 2 seconds) lets you see the hidden card while holding the press.
New penality: Randomly change the red colors to black and the black colors to red and the face card cards negative, for 2 minuntes.
New penality: Randomly take the top card of an exposed tableau stack (2 or more cards faced up) and turn it back faced down.
New cheat: Take a faced up card from either the stock or exposed on the tableau and insert it face up behind an exposed otherwise valid tableau card, for example stick a black 8 from the stack above a red 7 in the tableau.
Bug: I have a tabletau column of facedown, 9, diamonds, 8, 7. I am trying to drag a 10 of clubs above the 9 and it won't go. It seems to only work on a single card column pile
Bug: For a cheat penality, you are turning the bottom most card face down. It should be the top (back) card turning face down.
Bug: For iPhone landscape view, the height is still not tall enough. WHen an almost full (Q-2) stack is on 3 or more face down cards, I can scroll to the bottom but when I let go, it bounces back to the bottom cards not being visible.


## New Ideas
Update: A lot has happened when you were out of free messages. Attached is the current layout. Namely, ContentView is now called SolitaireContentView and the iPhone landscape view is taller to allow all cards in a column to be visible via scroll.
Bug: Double clicking on a card should default to placement on the Foundation if available.
Cheat Bug: Only count a illegal draw as a cheat if it is placed in a position. If it returns from where it came from (like dragged by accident), don't count as a cheat.
Cheat Bug: When inserting a card behind another card, it only works now if 1 card is visible. It should allow behind a stack of cards in the tableau column.

## Cheats

New cheat; For example, clicking on a red 4 and another red 4 will swap the cards.

## Future

New: What all cards are exposed and the game is won, "slowly" (but not slow motion) animate move all cards one at a time to their foundation.

Remember, primary play is holding the deck faced down in the left hand, dealing with the right hand. 10% of the time do the opposite.
Add animation to have the primary hand holding the faced down deck of cards. Hand should be about a 10° angle?
Add animation to exposing faced down cards from the deck to the pile faced up (see below).
Add animation to have the opposite hand place the cards. The hand should be rotated to a side view (see side of thumb) when placing that card.
