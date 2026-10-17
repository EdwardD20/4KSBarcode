//
// Cheater's Solitaire
// CheatersSolitaireApp.kt
//

@file:OptIn(ExperimentalFoundationApi::class)

package org.danleys.solitaire

import android.content.Context
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.MediaPlayer
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.time.Duration.Companion.milliseconds

enum class Suit(val symbol: String, val isRed: Boolean) {
    HEARTS("♥", true),
    DIAMONDS("♦", true),
    CLUBS("♣", false),
    SPADES("♠", false);
} // end enum Suit

enum class Rank(val value: Int, val label: String) {
    ACE(1, "A"),
    TWO(2, "2"),
    THREE(3, "3"),
    FOUR(4, "4"),
    FIVE(5, "5"),
    SIX(6, "6"),
    SEVEN(7, "7"),
    EIGHT(8, "8"),
    NINE(9, "9"),
    TEN(10, "10"),
    JACK(11, "J"),
    QUEEN(12, "Q"),
    KING(13, "K");
} // end enum Rank

data class SolitaireCard(
    val id: String = UUID.randomUUID().toString(),
    val suit: Suit,
    val rank: Rank,
    var isFaceUp: Boolean = false
) {
    val isRed: Boolean get() = suit.isRed
} // end data class SolitaireCard

sealed class SelectedCardSource {
    data object Waste : SelectedCardSource()
    data class Tableau(val pileIndex: Int, val cardIndex: Int) : SelectedCardSource()
    data class Foundation(val suit: Suit) : SelectedCardSource()
} // end sealed class SelectedCardSource

data class GameStateSnapshot(
    val stock: List<SolitaireCard>,
    val waste: List<SolitaireCard>,
    val foundations: Map<Suit, List<SolitaireCard>>,
    val tableau: List<List<SolitaireCard>>,
    val hasWon: Boolean
)

data class GameScore(
    val dateTime: String,
    val timeSeconds: Long,
    val isCheat: Boolean = false
)

object ScoreStorage {
    private const val PREFS_NAME = "cheaters_solitaire_scores"
    private const val KEY_SCORES = "top_scores"

    fun getScores(context: Context): List<GameScore> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_SCORES, null) ?: return emptyList()
        return raw.split(";").mapNotNull { entry ->
            val parts = entry.split("|")
            if (parts.size >= 2) {
                GameScore(
                    dateTime = parts[0],
                    timeSeconds = parts[1].toLongOrNull() ?: 0L,
                    isCheat = parts.getOrNull(2)?.toBoolean() ?: false
                )
            } else null
        }
    }

    fun addScore(context: Context, score: GameScore) {
        val current = getScores(context).toMutableList()
        current.add(score)
        val sorted = current.sortedBy { it.timeSeconds }.take(10)
        val encoded = sorted.joinToString(";") { "${it.dateTime}|${it.timeSeconds}|${it.isCheat}" }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_SCORES, encoded).apply()
    }
}

private fun formatTime(seconds: Long): String {
    val mins = seconds / 60
    val secs = seconds % 60
    return String.format("%02d:%02d", mins, secs)
}

class SolitaireGameState {
    var stock = mutableStateListOf<SolitaireCard>()
    var waste = mutableStateListOf<SolitaireCard>()
    var foundations = mutableMapOf<Suit, MutableList<SolitaireCard>>(
        Suit.HEARTS to mutableStateListOf(),
        Suit.DIAMONDS to mutableStateListOf(),
        Suit.CLUBS to mutableStateListOf(),
        Suit.SPADES to mutableStateListOf()
    )
    var tableau = List(7) { mutableStateListOf<SolitaireCard>() }
    var selectedSource by mutableStateOf<SelectedCardSource?>(null)
    var hasWon by mutableStateOf(false)
    var isDeadlocked by mutableStateOf(false)
    var hasTriggeredDeadlock by mutableStateOf(false)
    var stockCycleCount = 0
    var cardsPlayedFromWasteThisPass = false
    val undoStack = mutableStateListOf<GameStateSnapshot>()

    var hasCheated by mutableStateOf(false)
    var cheatTriggerCount by mutableStateOf(0)

    fun triggerCheat() {
        hasCheated = true
        cheatTriggerCount++
    }

    fun shuffleStockCheat() {
        startTimer()
        if (undoStack.isEmpty()) {
            saveStateForUndo()
            while (waste.isNotEmpty()) {
                stock.add(waste.removeAt(waste.size - 1))
            } // end while
            if (stock.isEmpty()) {
                for (pile in tableau) {
                    while (pile.isNotEmpty()) {
                        stock.add(pile.removeAt(pile.size - 1))
                    } // end while
                } // end for
            } // end if

            if (stock.isNotEmpty()) {
                stock.shuffle()
                stock.forEach { it.isFaceUp = false }
                triggerCheat()
                isDeadlocked = false
                hasTriggeredDeadlock = false
                stockCycleCount = 0
            } // end if
        } // end if
    } // end fun shuffleStockCheat

    var elapsedTimeSeconds by mutableStateOf(0L)
    var isTimerRunning by mutableStateOf(false)
    var hasStartedTimer by mutableStateOf(false)
    var scoreSaved by mutableStateOf(false)

    fun startTimer() {
        if (!hasStartedTimer) {
            hasStartedTimer = true
            isTimerRunning = true
        } // end if
    } // end fun startTimer

    fun stopTimer() {
        isTimerRunning = false
    } // end fun stopTimer

    var draggingSource by mutableStateOf<SelectedCardSource?>(null)
    var dragStartRootPosition by mutableStateOf(Offset.Zero)
    var dragCurrentOffset by mutableStateOf(Offset.Zero)

    val foundationBounds = mutableMapOf<Suit, Rect>()
    val tableauBounds = mutableMapOf<Int, Rect>()

    fun startDrag(source: SelectedCardSource, rootPos: Offset) {
        startTimer()
        draggingSource = source
        dragStartRootPosition = rootPos
        dragCurrentOffset = Offset.Zero
        selectedSource = source
    } // end fun startDrag

    fun updateDrag(offset: Offset) {
        dragCurrentOffset += offset
    } // end fun updateDrag

    fun endDrag() {
        val source = draggingSource
        if (source != null) {
            val dropPos = dragStartRootPosition + dragCurrentOffset
            var moved = false

            for ((suit, rect) in foundationBounds) {
                if (rect.contains(dropPos)) {
                    if (tryMoveToFoundation(source, suit)) {
                        moved = true
                        break
                    } // end if
                } // end if
            } // end for

            if (!moved) {
                for (colIndex in 0 until 7) {
                    val rect = tableauBounds[colIndex]
                    if (rect != null && rect.contains(dropPos)) {
                        if (tryMoveToTableauColumn(source, colIndex)) {
                            moved = true
                            break
                        } // end if
                    } // end if
                } // end for
            } // end if

            if (moved) {
                selectedSource = null
                checkWinCondition()
            } // end if
        } // end if
        draggingSource = null
        dragCurrentOffset = Offset.Zero
    } // end fun endDrag

    fun cancelDrag() {
        draggingSource = null
        dragCurrentOffset = Offset.Zero
    } // end fun cancelDrag

    fun getMovableCardsForDrag(source: SelectedCardSource): List<SolitaireCard>? {
        return getMovingCards(source)
    } // end fun getMovableCardsForDrag

    fun saveStateForUndo() {
        undoStack.add(
            GameStateSnapshot(
                stock = stock.map { it.copy() },
                waste = waste.map { it.copy() },
                foundations = foundations.mapValues { (_, pile) -> pile.map { it.copy() } },
                tableau = tableau.map { pile -> pile.map { it.copy() } },
                hasWon = hasWon
            )
        )
    }

    fun undo() {
        if (undoStack.isNotEmpty()) {
            val snapshot = undoStack.removeAt(undoStack.size - 1)
            stock.clear()
            stock.addAll(snapshot.stock)
            waste.clear()
            waste.addAll(snapshot.waste)
            foundations.forEach { (suit, pile) ->
                pile.clear()
                snapshot.foundations[suit]?.let { pile.addAll(it) }
            }
            tableau.forEachIndexed { index, pile ->
                pile.clear()
                snapshot.tableau.getOrNull(index)?.let { pile.addAll(it) }
            }
            hasWon = snapshot.hasWon
            selectedSource = null
        }
    }

    fun resetGame() {
        val deck = mutableListOf<SolitaireCard>()
        for (suit in Suit.entries) {
            for (rank in Rank.entries) {
                deck.add(SolitaireCard(suit = suit, rank = rank, isFaceUp = false))
            } // end for rank
        } // end for suit
        deck.shuffle()

        stock.clear()
        waste.clear()
        foundations.values.forEach { it.clear() }
        tableau.forEach { it.clear() }
        selectedSource = null
        hasWon = false
        isDeadlocked = false
        hasTriggeredDeadlock = false
        stockCycleCount = 0
        cardsPlayedFromWasteThisPass = false
        elapsedTimeSeconds = 0L
        isTimerRunning = false
        hasStartedTimer = false
        scoreSaved = false
        hasCheated = false
        cheatTriggerCount = 0
        undoStack.clear()

        var deckIdx = 0
        for (col in 0 until 7) {
            for (row in 0..col) {
                val card = deck[deckIdx++]
                if (row == col) {
                    card.isFaceUp = true
                } // end if (row == col)
                tableau[col].add(card)
            } // end for row
        } // end for col

        while (deckIdx < deck.size) {
            stock.add(deck[deckIdx++])
        } // end while
    } // end fun resetGame

    fun drawCardFromStock() {
        if (stock.isNotEmpty() || waste.isNotEmpty()) {
            saveStateForUndo()
        }
        startTimer()
        if (stock.isNotEmpty()) {
            repeat(3) {
                if (stock.isNotEmpty()) {
                    val card = stock.removeAt(stock.size - 1)
                    card.isFaceUp = true
                    waste.add(card)
                } // end if
            } // end repeat
            if (stock.isEmpty()) {
                if (!cardsPlayedFromWasteThisPass) {
                    stockCycleCount++
                    android.util.Log.d("SolitaireDebug", "Unproductive stock pass completed. stockCycleCount = $stockCycleCount")
                } else {
                    android.util.Log.d("SolitaireDebug", "Productive stock pass completed (cards played from waste). stockCycleCount reset to 0.")
                    stockCycleCount = 0
                } // end if/else
                cardsPlayedFromWasteThisPass = false
            } // end if
        } else if (waste.isNotEmpty()) {
            while (waste.isNotEmpty()) {
                val card = waste.removeAt(waste.size - 1)
                card.isFaceUp = false
                stock.add(card)
            } // end while
            cardsPlayedFromWasteThisPass = false
        } // end if/else

        isDeadlocked = false
        hasTriggeredDeadlock = false
        selectedSource = null
        checkWinCondition()
    } // end fun drawCardFromStock

    fun onCardTapped(source: SelectedCardSource) {
        startTimer()
        if (selectedSource == source) {
            selectedSource = null
            return
        } // end if

        val currentSelection = selectedSource
        if (currentSelection == null) {
            selectedSource = source
        } else {
            val moved = tryMove(from = currentSelection, to = source)
            if (!moved) {
                selectedSource = source
            } else {
                selectedSource = null
                checkWinCondition()
            } // end if/else
        } // end if/else
    } // end fun onCardTapped

    fun onTableauColumnTapped(colIndex: Int) {
        startTimer()
        val currentSelection = selectedSource
        if (currentSelection != null) {
            val moved = tryMoveToTableauColumn(from = currentSelection, targetCol = colIndex)
            if (moved) {
                selectedSource = null
                checkWinCondition()
            } // end if
        } // end if
    } // end fun onTableauColumnTapped

    fun onFoundationTapped(suit: Suit) {
        startTimer()
        val currentSelection = selectedSource
        if (currentSelection == null) {
            val topCard = foundations[suit]?.lastOrNull()
            if (topCard != null) {
                selectedSource = SelectedCardSource.Foundation(suit)
            } // end if
        } else if (currentSelection == SelectedCardSource.Foundation(suit)) {
            selectedSource = null
        } else {
            val moved = tryMoveToFoundation(from = currentSelection, targetSuit = suit)
            if (moved) {
                selectedSource = null
                checkWinCondition()
            } // end if
        } // end if
    } // end fun onFoundationTapped



    private fun tryMove(from: SelectedCardSource, to: SelectedCardSource): Boolean {
        return when (to) {
            is SelectedCardSource.Tableau -> tryMoveToTableauColumn(from, to.pileIndex)
            is SelectedCardSource.Foundation -> tryMoveToFoundation(from, to.suit)
            else -> false
        } // end when
    } // end fun tryMove

    private fun tryMoveToTableauColumn(from: SelectedCardSource, targetCol: Int): Boolean {
        startTimer()
        val movingCards = getMovingCards(from) ?: return false
        val targetPile = tableau[targetCol]
        val topTargetCard = targetPile.lastOrNull()

        val isValidMove = if (topTargetCard == null) {
            movingCards.first().rank == Rank.KING
        } else {
            val firstMoving = movingCards.first()
            firstMoving.isRed != topTargetCard.isRed && firstMoving.rank.value == topTargetCard.rank.value - 1
        } // end if/else

        if (isValidMove) {
            saveStateForUndo()

            var exposesFaceDown = false
            if (from is SelectedCardSource.Tableau) {
                val sourcePile = tableau[from.pileIndex]
                val cardIndex = from.cardIndex
                if (cardIndex > 0 && !sourcePile[cardIndex - 1].isFaceUp) {
                    exposesFaceDown = true
                } // end if
            } // end if

            if (from is SelectedCardSource.Waste) {
                cardsPlayedFromWasteThisPass = true
            } // end if

            removeMovingCards(from)
            targetPile.addAll(movingCards)
            revealTopCard(from)

            if (from is SelectedCardSource.Waste || from is SelectedCardSource.Foundation || exposesFaceDown) {
                stockCycleCount = 0
                hasTriggeredDeadlock = false
                isDeadlocked = false
            } // end if

            checkWinCondition()
            return true
        } // end if
        return false
    } // end fun tryMoveToTableauColumn

    private fun tryMoveToFoundation(from: SelectedCardSource, targetSuit: Suit): Boolean {
        startTimer()
        val movingCards = getMovingCards(from) ?: return false
        if (movingCards.size != 1) return false

        val card = movingCards.first()
        val foundationPile = foundations[targetSuit] ?: return false
        val topFoundationCard = foundationPile.lastOrNull()

        val isValid = if (card.suit == targetSuit) {
            if (topFoundationCard == null) {
                card.rank == Rank.ACE
            } else {
                card.rank.value == topFoundationCard.rank.value + 1
            } // end if/else
        } else {
            false
        } // end if/else

        if (isValid) {
            saveStateForUndo()
            if (from is SelectedCardSource.Waste) {
                cardsPlayedFromWasteThisPass = true
            } // end if

            removeMovingCards(from)
            foundationPile.add(card)
            revealTopCard(from)

            stockCycleCount = 0
            hasTriggeredDeadlock = false
            isDeadlocked = false

            checkWinCondition()
            return true
        } // end if
        return false
    } // end fun tryMoveToFoundation

    fun autoMoveCard(from: SelectedCardSource) {
        startTimer()
        val movingCards = getMovingCards(from) ?: return
        if (movingCards.isEmpty()) return
        val card = movingCards.first()

        // 1. Try foundation if available (movingCards.size must be 1)
        if (movingCards.size == 1) {
            val foundationPile = foundations[card.suit]
            val topFoundationCard = foundationPile?.lastOrNull()
            val isValidFoundation = if (topFoundationCard == null) {
                card.rank == Rank.ACE
            } else {
                card.rank.value == topFoundationCard.rank.value + 1
            } // end if/else

            if (isValidFoundation) {
                if (tryMoveToFoundation(from, card.suit)) {
                    selectedSource = null
                    checkWinCondition()
                    return
                } // end if
            } // end if
        } // end if

        // 2. Try valid spot in tableau, assuming only 1 spot exists
        val validTargetCols = mutableListOf<Int>()
        for (colIndex in 0 until 7) {
            if (from is SelectedCardSource.Tableau && from.pileIndex == colIndex) {
                continue
            } // end if
            val targetPile = tableau[colIndex]
            val topTargetCard = targetPile.lastOrNull()

            val isValidTableau = if (topTargetCard == null) {
                movingCards.first().rank == Rank.KING
            } else {
                val firstMoving = movingCards.first()
                firstMoving.isRed != topTargetCard.isRed && firstMoving.rank.value == topTargetCard.rank.value - 1
            } // end if/else

            if (isValidTableau) {
                validTargetCols.add(colIndex)
            } // end if
        } // end for

        if (validTargetCols.size == 1) {
            val targetCol = validTargetCols.first()
            if (tryMoveToTableauColumn(from, targetCol)) {
                selectedSource = null
                checkWinCondition()
            } // end if
        } // end if
    } // end fun autoMoveCard

    private fun getMovingCards(from: SelectedCardSource): List<SolitaireCard>? {
        return when (from) {
            is SelectedCardSource.Waste -> waste.lastOrNull()?.let { listOf(it) }
            is SelectedCardSource.Foundation -> foundations[from.suit]?.lastOrNull()?.let { listOf(it) }
            is SelectedCardSource.Tableau -> {
                val pile = tableau[from.pileIndex]
                if (from.cardIndex in pile.indices && pile[from.cardIndex].isFaceUp) {
                    pile.subList(from.cardIndex, pile.size).toList()
                } else null
            } // end Tableau
        } // end when
    } // end fun getMovingCards

    private fun removeMovingCards(from: SelectedCardSource) {
        when (from) {
            is SelectedCardSource.Waste -> if (waste.isNotEmpty()) waste.removeAt(waste.size - 1)
            is SelectedCardSource.Foundation -> foundations[from.suit]?.let { if (it.isNotEmpty()) it.removeAt(it.size - 1) }
            is SelectedCardSource.Tableau -> {
                val pile = tableau[from.pileIndex]
                val cards = getMovingCards(from) ?: return
                repeat(cards.size) {
                    if (pile.isNotEmpty()) pile.removeAt(pile.size - 1)
                } // end repeat
            } // end Tableau
        } // end when
    } // end fun removeMovingCards

    private fun revealTopCard(from: SelectedCardSource) {
        if (from is SelectedCardSource.Tableau) {
            val pile = tableau[from.pileIndex]
            if (pile.isNotEmpty() && !pile.last().isFaceUp) {
                pile[pile.size - 1] = pile.last().copy(isFaceUp = true)
            } // end if
        } // end if
    } // end fun revealTopCard

    private fun checkWinCondition() {
        val totalInFoundations = foundations.values.sumOf { it.size }
        if (totalInFoundations == 52) {
            hasWon = true
            isDeadlocked = false
            stopTimer()
            return
        } // end if

        if (!hasWon) {
            val stockEmpty = stock.isEmpty()
            val wasteEmpty = waste.isEmpty()
            val allTableauFaceUp = tableau.all { pile -> pile.all { it.isFaceUp } }
            if (stockEmpty && wasteEmpty && allTableauFaceUp) {
                hasWon = true
                isDeadlocked = false
                stopTimer()
                return
            } // end if

            if (stockCycleCount >= 2) {
                if (checkIfDeadlocked()) {
                    if (!hasTriggeredDeadlock) {
                        hasTriggeredDeadlock = true
                        isDeadlocked = true
                    } // end if
                } else {
                    hasTriggeredDeadlock = false
                    isDeadlocked = false
                } // end if/else
            } else {
                hasTriggeredDeadlock = false
                isDeadlocked = false
            } // end if/else
        } // end if
    } // end fun checkWinCondition

    private fun checkIfDeadlocked(): Boolean {
        if (stockCycleCount < 2) return false

        // 1. Check if any tableau card can move to foundation
        for (colIndex in tableau.indices) {
            val pile = tableau[colIndex]
            if (pile.isNotEmpty()) {
                val card = pile.last()
                if (card.isFaceUp) {
                    for (suit in Suit.entries) {
                        val foundationPile = foundations[suit]!!
                        val topFoundation = foundationPile.lastOrNull()
                        val canMove = if (topFoundation == null) {
                            card.rank == Rank.ACE
                        } else {
                            card.suit == suit && card.rank.value == topFoundation.rank.value + 1
                        } // end if/else
                        if (canMove) {
                            android.util.Log.d("SolitaireDebug", "Viable move found: Tableau -> Foundation ($suit)")
                            return false
                        } // end if
                    } // end for
                } // end if
            } // end if
        } // end for

        // 2. Check if waste card can move to foundation or tableau
        val wasteCard = waste.lastOrNull()
        if (wasteCard != null) {
            for (suit in Suit.entries) {
                val foundationPile = foundations[suit]!!
                val topFoundation = foundationPile.lastOrNull()
                val canMove = if (topFoundation == null) {
                    wasteCard.rank == Rank.ACE
                } else {
                    wasteCard.suit == suit && wasteCard.rank.value == topFoundation.rank.value + 1
                } // end if/else
                if (canMove) {
                    android.util.Log.d("SolitaireDebug", "Viable move found: Waste -> Foundation ($suit)")
                    return false
                } // end if
            } // end for
            for (colIndex in tableau.indices) {
                val targetPile = tableau[colIndex]
                val topTarget = targetPile.lastOrNull()
                val canMove = if (topTarget == null) {
                    wasteCard.rank == Rank.KING
                } else {
                    wasteCard.isRed != topTarget.isRed && wasteCard.rank.value == topTarget.rank.value - 1
                } // end if/else
                if (canMove) {
                    android.util.Log.d("SolitaireDebug", "Viable move found: Waste -> Tableau col $colIndex")
                    return false
                } // end if
            } // end for
        } // end if

        // 3. Check if any tableau -> tableau move that EXPOSES a face-down card exists
        for (colIndex in tableau.indices) {
            val pile = tableau[colIndex]
            for (cardIndex in pile.indices) {
                val card = pile[cardIndex]
                if (!card.isFaceUp) continue
                for (targetCol in tableau.indices) {
                    if (targetCol == colIndex) continue
                    val targetPile = tableau[targetCol]
                    val topTarget = targetPile.lastOrNull()
                    val isValidTableauMove = if (topTarget == null) {
                        card.rank == Rank.KING
                    } else {
                        card.isRed != topTarget.isRed && card.rank.value == topTarget.rank.value - 1
                    } // end if/else

                    if (isValidTableauMove) {
                        val exposesFaceDown = cardIndex > 0 && !pile[cardIndex - 1].isFaceUp
                        if (exposesFaceDown) {
                            android.util.Log.d("SolitaireDebug", "Viable progressive tableau move found (exposes face-down)")
                            return false
                        } // end if
                    } // end if
                } // end targetCol
            } // end cardIndex
        } // end for

        android.util.Log.d("SolitaireDebug", "Stock played through twice (count: $stockCycleCount). No progressive moves found. Deadlocked!")
        return true
    } // end fun checkIfDeadlocked
} // end class SolitaireGameState

class CheatersSolitaireViewModel(
    private val savedStateHandle: SavedStateHandle
) : ViewModel() {
    val game = SolitaireGameState()

    var shufflePlayed: Boolean
        get() = savedStateHandle["shuffle_played"] ?: false
        set(value) {
            savedStateHandle["shuffle_played"] = value
        }

    init {
        val isInitialized = savedStateHandle.get<Boolean>("is_initialized") ?: false
        if (!isInitialized) {
            game.resetGame()
            savedStateHandle["is_initialized"] = true
        } // end if
    } // end init

    fun startNewGame() {
        game.resetGame()
        shufflePlayed = false
    } // end fun startNewGame
} // end class CheatersSolitaireViewModel

private fun playShuffleSound(context: Context) {
    try {
        val afd = context.resources.openRawResourceFd(R.raw.shuffle)
        val mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build()
            )
            setDataSource(afd.fileDescriptor, afd.startOffset, afd.declaredLength)
            afd.close()
            prepare()
            start()
            setOnCompletionListener { mp ->
                mp.release()
            } // end setOnCompletionListener
        } // end apply
    } catch (e: Exception) {
        e.printStackTrace()
    } // end try/catch
} // end fun playShuffleSound

private fun playApplauseSound(context: Context) {
    try {
        val afd = context.resources.openRawResourceFd(R.raw.applause)
        val mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build()
            )
            setDataSource(afd.fileDescriptor, afd.startOffset, afd.declaredLength)
            afd.close()
            prepare()
            start()
            setOnCompletionListener { mp ->
                mp.release()
            } // end setOnCompletionListener
        } // end apply
    } catch (e: Exception) {
        e.printStackTrace()
    } // end try/catch
} // end fun playApplauseSound

private fun playFoghornSound(context: Context) {
    try {
        val afd = context.resources.openRawResourceFd(R.raw.foghorn)
        val mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build()
            )
            setDataSource(afd.fileDescriptor, afd.startOffset, afd.declaredLength)
            afd.close()
            prepare()
            start()
            setOnCompletionListener { mp ->
                mp.release()
            } // end setOnCompletionListener
        } // end apply
    } catch (e: Exception) {
        e.printStackTrace()
    } // end try/catch
} // end fun playFoghornSound

private fun playChickenSound(context: Context) {
    try {
        val afd = context.resources.openRawResourceFd(R.raw.chicken)
        val mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build()
            )
            setDataSource(afd.fileDescriptor, afd.startOffset, afd.declaredLength)
            afd.close()
            prepare()
            start()
            setOnCompletionListener { mp ->
                mp.release()
            } // end setOnCompletionListener
        } // end apply
    } catch (e: Exception) {
        e.printStackTrace()
    } // end try/catch
} // end fun playChickenSound

@Composable
private fun TopScoresDialog(
    context: Context,
    onDismiss: () -> Unit
) {
    val scores = remember { ScoreStorage.getScores(context) }

    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Top 10 Scores", fontWeight = FontWeight.Bold) },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (scores.isEmpty()) {
                    Text("No scores recorded yet. Win a game to set a score!")
                } else {
                    scores.forEachIndexed { index, score ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("${index + 1}. ${score.dateTime}${if (score.isCheat) " ☹️" else ""}")
                            Text(formatTime(score.timeSeconds), fontWeight = FontWeight.Bold)
                        } // end Row
                    } // end forEach
                } // end if/else
            } // end Column
        },
        confirmButton = {
            Button(onClick = onDismiss) {
                Text("Close")
            } // end Button
        }
    )
} // end fun TopScoresDialog

@Composable
fun CheatersSolitaireApp(
    viewModel: CheatersSolitaireViewModel = viewModel(),
    onExitToHost: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val game = viewModel.game
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    var showScoresDialog by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (!viewModel.shufflePlayed) {
            playShuffleSound(context)
            viewModel.shufflePlayed = true
        } // end if
    } // end LaunchedEffect

    LaunchedEffect(game.cheatTriggerCount) {
        if (game.cheatTriggerCount > 0) {
            playChickenSound(context)
        } // end if
    } // end LaunchedEffect

    LaunchedEffect(game.isTimerRunning) {
        if (game.isTimerRunning) {
            while (true) {
                kotlinx.coroutines.delay(1000L.milliseconds)
                game.elapsedTimeSeconds++
            } // end while
        } // end if
    } // end LaunchedEffect

    LaunchedEffect(game.hasWon) {
        if (game.hasWon) {
            playApplauseSound(context)
            if (!game.scoreSaved) {
                game.scoreSaved = true
                val dateTimeStr = SimpleDateFormat("MMM dd, yyyy, h:mm a", Locale.getDefault()).format(Date())
                ScoreStorage.addScore(context, GameScore(dateTimeStr, game.elapsedTimeSeconds, game.hasCheated))
            } // end if

            while (true) {
                var movedCard = false
                for (colIndex in game.tableau.indices) {
                    val pile = game.tableau[colIndex]
                    if (pile.isNotEmpty()) {
                        val card = pile.last()
                        val foundationPile = game.foundations[card.suit]!!
                        val topFoundationCard = foundationPile.lastOrNull()
                        val canMove = if (topFoundationCard == null) {
                            card.rank == Rank.ACE
                        } else {
                            card.rank.value == topFoundationCard.rank.value + 1
                        } // end if/else
                        if (canMove) {
                            pile.removeAt(pile.size - 1)
                            foundationPile.add(card)
                            movedCard = true
                            kotlinx.coroutines.delay(100.milliseconds)
                            break
                        } // end if
                    } // end if
                } // end for
                if (!movedCard) {
                    if (game.tableau.all { it.isEmpty() }) {
                        break
                    } // end if
                    kotlinx.coroutines.delay(100.milliseconds)
                } // end if
            } // end while
        } // end if
    } // end LaunchedEffect

    LaunchedEffect(game.isDeadlocked) {
        if (game.isDeadlocked) {
            playFoghornSound(context)
        } // end if
    } // end LaunchedEffect

    if (showScoresDialog) {
        TopScoresDialog(context = context, onDismiss = { showScoresDialog = false })
    } // end if

    val feltGreen = Color(0xFF005A20)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(feltGreen)
    ) {
        val draggingSource = game.draggingSource
        if (draggingSource != null) {
            val movingCards = game.getMovableCardsForDrag(draggingSource)
            if (!movingCards.isNullOrEmpty()) {
                Box(
                    modifier = Modifier
                        .zIndex(1000f)
                        .offset(
                            x = with(LocalDensity.current) { (game.dragStartRootPosition.x + game.dragCurrentOffset.x).toDp() },
                            y = with(LocalDensity.current) { (game.dragStartRootPosition.y + game.dragCurrentOffset.y).toDp() }
                        )
                ) {
                    Column {
                        movingCards.forEachIndexed { idx, movingCard ->
                            Box(modifier = Modifier.offset(y = (idx * 15.5).dp)) {
                                FaceUpCard(card = movingCard, isSelected = true)
                            }
                        } // end forEachIndexed
                    } // end Column
                } // end Box
            } // end if
        } // end if

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp)
        ) {
            // --- Top Navigation & Control Bar ---
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (onExitToHost != null) {
                    Button(
                        onClick = onExitToHost,
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Red.copy(alpha = 0.4f)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("Return to app", color = Color.Black, fontWeight = FontWeight.Bold)
                    } // end Button Return to app
                } else {
                    Spacer(modifier = Modifier.width(8.dp))
                } // end if/else

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = formatTime(game.elapsedTimeSeconds),
                        color = if (game.hasCheated) Color.Black else Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    ) // end Text timer

                    Button(
                        onClick = { showScoresDialog = true },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4CAF50)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("🏆", fontSize = 18.sp)
                    } // end Button Scores

                    Button(
                        onClick = { game.undo() },
                        enabled = game.undoStack.isNotEmpty(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFF9C27B0),
                            disabledContainerColor = Color(0xFF9C27B0).copy(alpha = 0.4f)
                        ),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("↶", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    } // end Button Undo

                    Button(
                        onClick = {
                            viewModel.startNewGame()
                            playShuffleSound(context)
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2196F3)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("New", color = Color.White, fontWeight = FontWeight.Bold)
                    } // end Button New
                } // end Row controls
            } // end Row top bar

            // --- Scrollable Table Area ---
            if (!isLandscape) {
                // Portrait Layout
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        StockAndWasteSection(game = game)
                        FoundationsSection(game = game)
                    } // end Row

                    Spacer(modifier = Modifier.height(16.dp))

                    TableauSection(game = game)
                } // end Column
            } else {
                // Landscape Layout: Stock & Waste on left, Tableau condensed in middle (between waste & foundation), Foundations on right
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Top
                ) {
                    StockAndWasteSection(game = game)

                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 8.dp)
                    ) {
                        TableauSection(game = game)
                    } // end Box

                    FoundationsSection(game = game)
                } // end Row
            } // end if/else isLandscape

            if (game.hasWon) {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    shape = RoundedCornerShape(12.dp),
                    color = Color.Yellow,
                    tonalElevation = 8.dp
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text("★ YOU WON! ★", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color.Black)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = {
                            viewModel.startNewGame()
                            playShuffleSound(context)
                        }) {
                            Text("Play Again")
                        } // end Button
                    } // end Column
                } // end Surface
            } // end if (game.hasWon)
        } // end Column Main Layout
    } // end Box
} // end fun CheatersSolitaireApp

@Composable
private fun StockAndWasteSection(game: SolitaireGameState) {
    val context = LocalContext.current
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        // Stock Pile
        Box(
            modifier = Modifier
                .width(44.dp)
                .height(62.dp)
                .clip(RoundedCornerShape(6.dp))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(6.dp))
                .background(Color.White.copy(alpha = 0.05f))
                .pointerInput(Unit) {
                    detectTapGestures(
                        onTap = { game.drawCardFromStock() },
                        onLongPress = {
                            if (game.undoStack.isEmpty()) {
                                game.shuffleStockCheat()
                                playShuffleSound(context)
                            } // end if
                        }
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            if (game.stock.isNotEmpty()) {
                FaceDownCard()
            } else {
                Text(
                    text = "↺",
                    fontSize = 20.sp,
                    color = Color.White.copy(alpha = 0.7f),
                    fontWeight = FontWeight.Bold
                )
            } // end if/else
        } // end Box Stock Pile

        // Waste Pile
        var wasteRootPos by remember { mutableStateOf(Offset.Zero) }
        val visibleWaste = game.waste.takeLast(3)
        val isWasteSelected = game.selectedSource == SelectedCardSource.Waste
        Box(
            modifier = Modifier
                .width(88.dp)
                .height(62.dp)
                .clip(RoundedCornerShape(6.dp))
                .border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                .background(Color.LightGray)
                .onGloballyPositioned { coordinates ->
                    wasteRootPos = coordinates.positionInRoot()
                }
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { offset ->
                            if (game.waste.isNotEmpty()) {
                                game.startDrag(SelectedCardSource.Waste, wasteRootPos + offset)
                            } // end if
                        },
                        onDragEnd = { game.endDrag() },
                        onDragCancel = { game.cancelDrag() },
                        onDrag = { _, dragAmount -> game.updateDrag(dragAmount) }
                    )
                }
                .combinedClickable(
                    onClick = {
                        if (game.waste.isNotEmpty()) {
                            game.onCardTapped(SelectedCardSource.Waste)
                        } // end if
                    },
                    onDoubleClick = {
                        if (game.waste.isNotEmpty()) {
                            game.autoMoveCard(SelectedCardSource.Waste)
                        } // end if
                    }
                ),
            contentAlignment = Alignment.CenterStart
        ) {
            if (visibleWaste.isNotEmpty()) {
                visibleWaste.forEachIndexed { index, card ->
                    val isTopCard = (index == visibleWaste.size - 1)
                    val cardSelected = isWasteSelected && isTopCard
                    val isDraggingThis = game.draggingSource == SelectedCardSource.Waste && isTopCard
                    Box(
                        modifier = Modifier
                            .offset(x = (index * 20).dp)
                    ) {
                        if (!isDraggingThis) {
                            FaceUpCard(card = card, isSelected = cardSelected)
                        } // end if
                    } // end Box
                } // end forEachIndexed
            } // end if
        } // end Box Waste Pile
    } // end Row
} // end fun StockAndWasteSection

@Composable
private fun FoundationsSection(game: SolitaireGameState) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Suit.entries.forEach { suit ->
            val foundationPile = game.foundations[suit]
            val topCard = foundationPile?.lastOrNull()
            val isSelected = game.selectedSource == SelectedCardSource.Foundation(suit)
            var foundationRootPos by remember { mutableStateOf(Offset.Zero) }
            val source = SelectedCardSource.Foundation(suit)
            val isDraggingThis = game.draggingSource == source

            CardSlot(
                modifier = Modifier
                    .onGloballyPositioned { coordinates ->
                        game.foundationBounds[suit] = coordinates.boundsInRoot()
                        foundationRootPos = coordinates.positionInRoot()
                    }
                    .pointerInput(topCard) {
                        detectDragGestures(
                            onDragStart = { offset ->
                                if (topCard != null) {
                                    game.startDrag(source, foundationRootPos + offset)
                                } // end if
                            },
                            onDragEnd = { game.endDrag() },
                            onDragCancel = { game.cancelDrag() },
                            onDrag = { _, dragAmount -> game.updateDrag(dragAmount) }
                        )
                    },
                onClick = { game.onFoundationTapped(suit) }
            ) {
                if (topCard != null) {
                    if (!isDraggingThis) {
                        FaceUpCard(card = topCard, isSelected = isSelected)
                    } // end if
                } else {
                    Text(
                        text = suit.symbol,
                        fontSize = 24.sp,
                        color = if (suit.isRed) Color.Red else Color.DarkGray
                    )
                } // end if/else
            } // end CardSlot Foundation
        } // end forEach suit
    } // end Row
} // end fun FoundationsSection

@Composable
private fun TableauSection(game: SolitaireGameState) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        game.tableau.forEachIndexed { colIndex, columnCards ->
            val columnHeight = if (columnCards.isEmpty()) {
                62.dp
            } else {
                (62.0 + (columnCards.size - 1) * 15.5).dp
            }
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(columnHeight)
                    .padding(horizontal = 1.dp)
                    .onGloballyPositioned { coordinates ->
                        game.tableauBounds[colIndex] = coordinates.boundsInRoot()
                    },
                contentAlignment = Alignment.TopCenter
            ) {
                if (columnCards.isEmpty()) {
                    EmptyCardSlot(onClick = { game.onTableauColumnTapped(colIndex) })
                } else {
                    columnCards.forEachIndexed { cardIndex, card ->
                        val isSelected = game.selectedSource == SelectedCardSource.Tableau(colIndex, cardIndex)
                        var cardRootPos by remember { mutableStateOf(Offset.Zero) }
                        var isPeeking by remember { mutableStateOf(false) }
                        val source = SelectedCardSource.Tableau(colIndex, cardIndex)
                        val isDraggingThis = game.draggingSource == source
                        Box(
                            modifier = Modifier
                                .offset(y = (cardIndex * 15.5).dp)
                                .then(if (isPeeking) Modifier.zIndex(1000f) else Modifier)
                                .onGloballyPositioned { coordinates ->
                                    cardRootPos = coordinates.positionInRoot()
                                }
                                .pointerInput(card) {
                                    if (!card.isFaceUp) {
                                        detectTapGestures(
                                            onPress = { _ ->
                                                game.startTimer()
                                                isPeeking = true
                                                game.triggerCheat()
                                                try {
                                                    awaitRelease()
                                                } catch (_: Exception) {}
                                                isPeeking = false
                                            }
                                        )
                                    } else {
                                        detectDragGestures(
                                            onDragStart = { offset ->
                                                if (card.isFaceUp) {
                                                    game.startDrag(source, cardRootPos + offset)
                                                } // end if
                                            },
                                            onDragEnd = { game.endDrag() },
                                            onDragCancel = { game.cancelDrag() },
                                            onDrag = { _, dragAmount -> game.updateDrag(dragAmount) }
                                        )
                                    } // end if/else
                                }
                                .then(
                                    if (card.isFaceUp) {
                                        Modifier.combinedClickable(
                                            onClick = { game.onCardTapped(source) },
                                            onDoubleClick = { game.autoMoveCard(source) }
                                        )
                                    } else {
                                        Modifier
                                    }
                                )
                        ) {
                            if (!isDraggingThis) {
                                if (card.isFaceUp || isPeeking) {
                                    FaceUpCard(card = card, isSelected = isSelected)
                                } else {
                                    FaceDownCard()
                                } // end if/else
                            } // end if
                        } // end Box
                    } // end forEachIndexed card
                } // end if/else
            } // end Box tableau column
        } // end forEachIndexed colIndex
    } // end Row Tableau
} // end fun TableauSection

@Composable
private fun CardSlot(
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .width(44.dp)
            .height(62.dp)
            .clip(RoundedCornerShape(6.dp))
            .border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
            .background(Color.LightGray)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        content()
    } // end Box
} // end fun CardSlot

@Composable
private fun EmptyCardSlot(
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .width(44.dp)
            .height(62.dp)
            .clip(RoundedCornerShape(6.dp))
            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(6.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .clickable { onClick() }
    )
} // end fun EmptyCardSlot

private fun getCardFaceImageRes(rank: Rank, suit: Suit): Int? {
    return when (rank) {
        Rank.JACK -> {
            when (suit) {
                Suit.HEARTS -> R.drawable.jack_hearts
                Suit.DIAMONDS -> R.drawable.jack_diamonds
                Suit.CLUBS -> R.drawable.jack_clubs
                Suit.SPADES -> R.drawable.jack_spades
            }
        }
        Rank.QUEEN -> {
            when (suit) {
                Suit.HEARTS -> R.drawable.queen_hearts
                Suit.DIAMONDS -> R.drawable.queen_diamonds
                Suit.CLUBS -> R.drawable.queen_clubs
                Suit.SPADES -> R.drawable.queen_spades
            }
        }
        Rank.KING -> {
            when (suit) {
                Suit.HEARTS -> R.drawable.king_hearts
                Suit.DIAMONDS -> R.drawable.king_diamonds
                Suit.CLUBS -> R.drawable.king_clubs
                Suit.SPADES -> R.drawable.king_spades
            }
        }
        else -> null
    }
}

@Composable
private fun FaceUpCard(card: SolitaireCard, isSelected: Boolean = false) {
    val faceImageRes = getCardFaceImageRes(card.rank, card.suit)
    Card(
        modifier = Modifier
            .width(44.dp)
            .height(62.dp)
            .border(
                width = if (isSelected) 2.5.dp else 0.5.dp,
                color = if (isSelected) Color.Yellow else Color.Gray,
                shape = RoundedCornerShape(6.dp)
            ),
        shape = RoundedCornerShape(6.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(2.dp)
        ) {
            Column(
                modifier = Modifier.align(Alignment.TopStart),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = card.rank.label,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (card.isRed) Color.Red else Color.Black
                )
                Text(
                    text = card.suit.symbol,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (card.isRed) Color.Red else Color.Black
                )
            }

            if (faceImageRes != null) {
                Image(
                    painter = painterResource(id = faceImageRes),
                    contentDescription = "${card.rank} of ${card.suit}",
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 20.dp, bottom = 2.dp, start = 8.dp, end = 2.dp),
                    contentScale = ContentScale.Fit
                )
            } else if (card.rank == Rank.ACE) {
                Text(
                    text = card.suit.symbol,
                    fontSize = 26.sp,
                    color = if (card.isRed) Color.Red else Color.Black,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .offset(y = 5.dp)
                )
            } else {
                Text(
                    text = card.rank.label,
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (card.isRed) Color.Red else Color.Black,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .offset(y = 5.dp)
                )
            }
        } // end Box
    } // end Card
} // end fun FaceUpCard

@Composable
private fun FaceDownCard() {
    Card(
        modifier = Modifier
            .width(44.dp)
            .height(62.dp)
            .border(0.5.dp, Color.White, RoundedCornerShape(6.dp)),
        shape = RoundedCornerShape(6.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Image(
            painter = painterResource(id = R.drawable.cardback),
            contentDescription = "Card Back",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        ) // end Image
    } // end Card
} // end fun FaceDownCard
