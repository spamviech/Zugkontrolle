{-# LANGUAGE CPP #-}
#ifdef ZUGKONTROLLEGUI
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
#endif

{-|
Description: Allgemeine Hilfsfunktionen
-}
module Zug.UI.Gtk.Hilfsfunktionen
  (
#ifdef ZUGKONTROLLEGUI
    -- * Widget
    widgetShowNew
  , widgetShowIf
    -- * Container
  , containerAddWidgetNew
  , containerRemoveJust
    -- * Box
  , boxPack
  , boxPackDefault
  , boxPackWidgetNew
  , boxPackWidgetNewDefault
  , Packing(..)
  , packingDefault
  , Padding(..)
  , paddingDefault
  , Position(..)
  , positionDefault
    -- * Notebook
  , notebookAppendPageNew
    -- * Dialog
  , dialogGetUpper
  , dialogEval
  , ResponseId
    -- * Button
  , buttonNewWithEvent
  , buttonNewWithEventLabel -- buttonNewWithEventMnemonic,
    -- * ToggleButton
  , toggleButtonNewWithEvent
  , toggleButtonNewWithEventLabel
    -- * Label
  , labelSpracheNew
    -- * Name
  , NameWidget()
  , namePackNew
  , NameAuswahlWidget()
  , nameAuswahlPackNew
  , aktuellerName
#endif
  ) where

#ifdef ZUGKONTROLLEGUI
import Control.Concurrent.STM.TVar (TVar)
import Control.Monad.Trans (MonadIO(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Graphics.UI.Gtk (Packing(..), ResponseId)
import Graphics.UI.Gtk (AttrOp(..))
import qualified Graphics.UI.Gtk as Gtk

-- Abhängigkeiten von anderen Modulen
import Zug.Anbindung (StreckenObjekt(..))
import Zug.Language (Sprache(..), (<:>))
import qualified Zug.Language as Language
import Zug.UI.Gtk.Klassen
       (MitWidget(..), mitWidgetShow, mitWidgetHide, MitLabel(..), MitEntry(..), MitContainer(..)
      , mitContainerAdd, mitContainerRemove, MitButton(..), MitToggleButton(..), MitDialog(..)
      , MitBox(..), mitBoxPackStart, mitBoxPackEnd, MitNotebook(..), mitNotebookAppendPage)
import Zug.UI.Gtk.SpracheGui (SpracheGuiReader, verwendeSpracheGui)

-- | 'Widget' erstellen und anzeigen
widgetShowNew :: (MonadIO m, MitWidget w) => m w -> m w
widgetShowNew konstruktor = do
    widget <- konstruktor
    mitWidgetShow widget
    pure widget

-- | Neu erstelltes 'Widget' zu 'Container' hinzufügen
containerAddWidgetNew :: (MonadIO m, MitContainer c, MitWidget w) => c -> m w -> m w
containerAddWidgetNew container konstruktor = do
    widget <- widgetShowNew konstruktor
    mitContainerAdd container widget
    pure widget

-- | 'Widget' in eine 'Box' packen
boxPack :: (MonadIO m, MitBox b, MitWidget w) => b -> w -> Packing -> Padding -> Position -> m ()
boxPack box widget packing padding position =
    liftIO $ boxPackPosition position box widget packing $ fromPadding padding
    where
        boxPackPosition :: (MitBox b, MitWidget w) => Position -> b -> w -> Packing -> Int -> IO ()
        boxPackPosition Start = mitBoxPackStart
        boxPackPosition End = mitBoxPackEnd

-- | Neu erstelltes Widget in eine Box packen
boxPackWidgetNew
    :: (MonadIO m, MitBox b, MitWidget w) => b -> Packing -> Padding -> Position -> m w -> m w
boxPackWidgetNew box packing padding start konstruktor = do
    widget <- widgetShowNew konstruktor
    boxPack box widget packing padding start
    pure widget

-- | Normale Packing-Einstellung
packingDefault :: Packing
packingDefault = PackNatural

-- | Abstand zwischen 'Widget's
newtype Padding = Padding { fromPadding :: Int }
    deriving (Bounded, Enum, Eq, Integral, Num, Ord, Read, Real, Show)

-- | Standart-Abstand zwischen 'Widget's in einer 'Box'
paddingDefault :: Padding
paddingDefault = 0

-- | Position zum Hinzufügen zu einer 'Box'
data Position
    = Start
    | End
    deriving (Show, Read, Eq, Ord)

-- | Standart-Position zum Hinzufügen zu einer 'Box'
positionDefault :: Position
positionDefault = Start

-- | Neu erstelltes Widget mit Standard Packing, Padding und Positionierung in eine Box packen
boxPackWidgetNewDefault :: (MonadIO m, MitBox b, MitWidget w) => b -> m w -> m w
boxPackWidgetNewDefault box = boxPackWidgetNew box packingDefault paddingDefault positionDefault

-- | Widget mit Standard Packing, Padding und Positionierung in eine Box packen
boxPackDefault :: (MonadIO m, MitBox b, MitWidget w) => b -> w -> m ()
boxPackDefault box widget = boxPack box widget packingDefault paddingDefault positionDefault

-- | Neu erstelltes 'MitWidget' zu einem 'MitNotebook' hinzufügen.
--
-- Wird eine 'TVar' übergeben kann das Anpassen des Labels aus 'Zug.UI.Gtk.SpracheGui.sprachwechsel' gelöscht werden.
-- Dazu muss deren Inhalt auf 'Nothing' gesetzt werden.
notebookAppendPageNew
    :: (SpracheGuiReader r m, MonadIO m, MitNotebook n, MitWidget w)
    => n
    -> Maybe (TVar (Maybe [Sprache -> IO ()]))
    -> (Sprache -> Text)
    -> m w
    -> m (w, Int)
notebookAppendPageNew notebook maybeTVar name konstruktor = do
    widget <- widgetShowNew konstruktor
    page <- mitNotebookAppendPage notebook widget $ name Deutsch
    verwendeSpracheGui maybeTVar $ \sprache
        -> Gtk.notebookSetMenuLabelText (erhalteNotebook notebook) (erhalteWidget widget)
        $ name sprache
    pure (widget, page)

-- | Entferne ein vielleicht vorhandenes 'MitWidget' aus einem 'MitContainer'
containerRemoveJust :: (MonadIO m, MitContainer c, MitWidget w) => c -> Maybe w -> m ()
containerRemoveJust _container Nothing = pure ()
containerRemoveJust container (Just w) = mitContainerRemove container w

-- | Zeige widget, falls eine Bedingung erfüllt ist
widgetShowIf :: (MonadIO m, MitWidget w) => Bool -> w -> m ()
widgetShowIf True = mitWidgetShow
widgetShowIf False = mitWidgetHide

-- | 'MitDialog' anzeigen, auswerten und wieder verstecken
dialogEval :: (MonadIO m, MitDialog d) => d -> m ResponseId
dialogEval dialog = liftIO $ do
    mitWidgetShow dialog
    antwort <- Gtk.dialogRun $ erhalteDialog dialog
    mitWidgetHide dialog
    pure antwort

-- | dialogGetUpper fehlt in gtk3, daher hier ersetzt
dialogGetUpper :: (MitDialog d) => d -> IO Gtk.Box
dialogGetUpper dialog = fmap Gtk.castToBox $ Gtk.dialogGetActionArea $ erhalteDialog dialog

-- * Knöpfe mit einer Funktion
-- | Knopf mit Funktion erstellen
buttonNewWithEvent :: (MonadIO m, MitButton b) => m b -> IO () -> m b
buttonNewWithEvent konstruktor event = do
    button <- widgetShowNew konstruktor
    liftIO $ Gtk.on (erhalteButton button) Gtk.buttonActivated event
    pure button

-- -- | Knopf mit Mnemonic-Label und Funktion erstellen
-- buttonNewWithEventMnemonic :: (SpracheGuiReader r m, MonadIO m) => (Sprache -> Text) -> IO () -> m Gtk.Button
-- buttonNewWithEventMnemonic label event = do
--     button <- liftIO $ buttonNewWithEvent Gtk.buttonNew event
--     verwendeSpracheGui $ \sprache -> do
--         let labelSprache = label sprache
--         Gtk.set button [Gtk.buttonLabel := (Language.addMnemonic labelSprache)]
--         _adjustMnemonic $ Text.head labelSprache
--     pure button
-- | Knopf mit Label und Funktion erstellen.
--
-- Wird eine 'TVar' übergeben kann das Anpassen des Labels aus 'Zug.UI.Gtk.SpracheGui.sprachwechsel' gelöscht werden.
-- Dazu muss deren Inhalt auf 'Nothing' gesetzt werden.
buttonNewWithEventLabel :: (SpracheGuiReader r m, MonadIO m)
                        => Maybe (TVar (Maybe [Sprache -> IO ()]))
                        -> (Sprache -> Text)
                        -> IO ()
                        -> m Gtk.Button
buttonNewWithEventLabel maybeTVar label event = do
    button <- liftIO $ buttonNewWithEvent Gtk.buttonNew event
    verwendeSpracheGui maybeTVar $ \sprache -> Gtk.set button [Gtk.buttonLabel := label sprache]
    pure button

-- * ToggleButton
-- | ToggleButton mit Funktion erstellen
toggleButtonNewWithEvent :: (MonadIO m, MitToggleButton b) => m b -> (Bool -> IO ()) -> m b
toggleButtonNewWithEvent konstruktor event = do
    mitToggleButton <- widgetShowNew konstruktor
    let toggleButton = erhalteToggleButton mitToggleButton
    liftIO
        $ Gtk.on toggleButton Gtk.toggled
        $ Gtk.get toggleButton Gtk.toggleButtonActive >>= event
    pure mitToggleButton

-- | ToggleButton mit Label und Funktion erstellen.
--
-- Wird eine 'TVar' übergeben kann das Anpassen des Labels aus 'Zug.UI.Gtk.SpracheGui.sprachwechsel' gelöscht werden.
-- Dazu muss deren Inhalt auf 'Nothing' gesetzt werden.
toggleButtonNewWithEventLabel
    :: (SpracheGuiReader r m, MonadIO m)
    => Maybe (TVar (Maybe [Sprache -> IO ()]))
    -> (Sprache -> Text)
    -> (Bool -> IO ())
    -> m Gtk.ToggleButton
toggleButtonNewWithEventLabel maybeTVar label event = do
    toggleButton <- liftIO $ toggleButtonNewWithEvent Gtk.toggleButtonNew event
    verwendeSpracheGui maybeTVar
        $ \sprache -> Gtk.set toggleButton [Gtk.buttonLabel := label sprache]
    pure toggleButton

-- * Label
-- | Erzeuge ein Label, welches bei 'Zug.UI.Gtk.SpracheGui.sprachwechsel' den angezeigten Text anpasst.
--
-- Wird eine 'TVar' übergeben kann das Anpassen des Labels aus 'Zug.UI.Gtk.SpracheGui.sprachwechsel' gelöscht werden.
-- Dazu muss deren Inhalt auf 'Nothing' gesetzt werden.
labelSpracheNew :: (SpracheGuiReader r m, MonadIO m)
                => Maybe (TVar (Maybe [Sprache -> IO ()]))
                -> (Sprache -> Text)
                -> m Gtk.Label
labelSpracheNew maybeTVar text = do
    label <- liftIO $ Gtk.labelNew (Nothing :: Maybe Text)
    verwendeSpracheGui maybeTVar $ \sprache -> Gtk.set label [Gtk.labelText := text sprache]
    pure label

-- * Namen
-- | Widget zur Anzeige eines Namen
newtype NameWidget = NameWidget Gtk.Label
    deriving (Eq)

instance MitWidget NameWidget where
    erhalteWidget :: NameWidget -> Gtk.Widget
    erhalteWidget (NameWidget w) = erhalteWidget w

instance MitLabel NameWidget where
    erhalteLabel :: NameWidget -> Gtk.Label
    erhalteLabel (NameWidget w) = w

-- | Name anzeigen
namePackNew :: (MonadIO m, MitBox b, StreckenObjekt s) => b -> s -> m NameWidget
namePackNew box objekt = liftIO $ do
    label <- boxPackWidgetNewDefault box $ Gtk.labelNew $ Just $ erhalteName objekt
    Gtk.set label [Gtk.widgetMarginRight := 5]
    pure $ NameWidget label

-- | Widget zur Eingabe eines Namen
newtype NameAuswahlWidget = NameAuswahlWidget Gtk.Entry
    deriving (Eq)

instance MitWidget NameAuswahlWidget where
    erhalteWidget :: NameAuswahlWidget -> Gtk.Widget
    erhalteWidget (NameAuswahlWidget w) = erhalteWidget w

instance MitEntry NameAuswahlWidget where
    erhalteEntry :: NameAuswahlWidget -> Gtk.Entry
    erhalteEntry (NameAuswahlWidget w) = w

-- | Name abfragen
nameAuswahlPackNew :: (SpracheGuiReader r m, MonadIO m, MitBox b)
                   => b
                   -> Maybe (TVar (Maybe [Sprache -> IO ()]))
                   -> m NameAuswahlWidget
nameAuswahlPackNew box maybeTVar = do
    hBox <- liftIO $ boxPackWidgetNewDefault box $ Gtk.hBoxNew False 0
    boxPackWidgetNewDefault hBox $ labelSpracheNew maybeTVar $ Language.name <:> Text.empty
    entry <- liftIO $ boxPackWidgetNewDefault hBox Gtk.entryNew
    verwendeSpracheGui maybeTVar $ \sprache
        -> Gtk.set entry [Gtk.entryPlaceholderText := Just (Language.name sprache)]
    pure $ NameAuswahlWidget entry

-- | Erhalte den aktuell gewählten Namen
aktuellerName :: (MonadIO m) => NameAuswahlWidget -> m Text
aktuellerName = liftIO . Gtk.entryGetText . erhalteEntry
#endif
















