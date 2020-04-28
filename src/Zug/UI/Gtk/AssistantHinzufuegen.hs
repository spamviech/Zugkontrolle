{-# LANGUAGE CPP #-}
#ifdef ZUGKONTROLLEGUI
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
#endif

{-|
Description : Erstellen eines Assistant zum Hinzufügen eines 'StreckenObjekt'es.
-}
module Zug.UI.Gtk.AssistantHinzufuegen
  (
#ifdef ZUGKONTROLLEGUI
    assistantHinzufügenNew
  , AssistantHinzufügen()
  , assistantHinzufügenAuswerten
  , HinzufügenErgebnis(..)
#endif
  ) where

#ifdef ZUGKONTROLLEGUI
import Control.Concurrent.STM (atomically, TVar, TMVar, newEmptyTMVar, putTMVar, takeTMVar)
import Control.Monad (forM_, foldM)
import Control.Monad.Reader (runReaderT)
import Control.Monad.Trans (MonadIO(..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes)
import qualified Graphics.UI.Gtk as Gtk
import Graphics.UI.Gtk (AttrOp((:=)))

import Zug.Enums (Zugtyp(), unterstützteZugtypen)
import Zug.Language (Sprache())
import qualified Zug.Language as Language
import Zug.Objekt (Objekt)
import Zug.UI.Gtk.AssistantHinzufuegen.HinzufuegenSeite
       (HinzufügenSeite(), ButtonHinzufügen(ButtonHinzufügen), spezifischerButtonHinzufügen
      , seiteErgebnis, hinzufügenBahngeschwindigkeitNew, hinzufügenStreckenabschnittNew
      , hinzufügenWeicheNew, hinzufügenKupplungNew, hinzufügenKontaktNew
      , hinzufügenWegstreckeNew, hinzufügenPlanNew)
import Zug.UI.Gtk.Auswahl (AuswahlWidget, auswahlComboBoxNew)
import Zug.UI.Gtk.Fliessend (FließendAuswahlWidget, fließendAuswahlNew)
import Zug.UI.Gtk.Hilfsfunktionen
       (widgetShowNew, containerAddWidgetNew, boxPackDefault, notebookAppendPageNew
      , buttonNewWithEventLabel, boxPackWidgetNew, Position(End), positionDefault, Packing(PackGrow)
      , packingDefault, paddingDefault)
import Zug.UI.Gtk.Klassen
       (MitWidget(..), mitWidgetShow, mitWidgetHide, MitWindow(..), MitButton(..))
import Zug.UI.Gtk.SpracheGui (SpracheGuiReader(), verwendeSpracheGui)
import Zug.UI.Gtk.StreckenObjekt (StatusVarGui, StatusVarGuiReader, DynamischeWidgetsReader)
import Zug.UI.StatusVar (StatusVarReader(..))

-- | Seiten des Hinzufügen-'Assistant'
data AssistantHinzufügen =
    AssistantHinzufügen
    { window :: Gtk.Window
    , notebook :: Gtk.Notebook
    , fließendAuswahl :: FließendAuswahlWidget
    , zugtypAuswahl :: AuswahlWidget Zugtyp
    , indexSeiten :: Map Int HinzufügenSeite
    , tmVarErgebnis :: TMVar HinzufügenErgebnis
    }
    deriving (Eq)

instance MitWidget AssistantHinzufügen where
    erhalteWidget :: AssistantHinzufügen -> Gtk.Widget
    erhalteWidget = Gtk.toWidget . window

-- | Hat der 'AssistantHinzufügen' ein Ergebnis geliefert?
data HinzufügenErgebnis
    = HinzufügenErfolgreich Objekt
    | HinzufügenAbbrechen
    | HinzufügenBeenden

-- | Zeige den 'AssistantHinzufügen' an und warte bis ein 'HinzufügenErgebnis' vorliegt.
--
-- Es wird erwartet, dass diese Funktion in einem eigenen Thread ausgeführt wird.
assistantHinzufügenAuswerten :: (MonadIO m) => AssistantHinzufügen -> m HinzufügenErgebnis
assistantHinzufügenAuswerten AssistantHinzufügen {window, tmVarErgebnis} = liftIO $ do
    Gtk.postGUIAsync $ mitWidgetShow window
    ergebnis <- atomically $ takeTMVar tmVarErgebnis
    Gtk.postGUIAsync $ mitWidgetHide window
    pure ergebnis

-- | Erhalte das Ergebnis einer 'HinzufügenSeite'.
hinzufügenErgebnis :: (StatusVarGuiReader r m, MonadIO m) => AssistantHinzufügen -> m ()
hinzufügenErgebnis
    AssistantHinzufügen {notebook, fließendAuswahl, zugtypAuswahl, indexSeiten, tmVarErgebnis} =
    do
        aktuelleSeite <- liftIO $ Gtk.get notebook Gtk.notebookPage
        ergebnis <- seiteErgebnis fließendAuswahl zugtypAuswahl $ indexSeiten Map.! aktuelleSeite
        liftIO $ atomically $ putTMVar tmVarErgebnis $ HinzufügenErfolgreich ergebnis

-- | Erstelle einen neuen 'AssistantHinzufügen'.
assistantHinzufügenNew
    :: forall p r m.
    ( MitWindow p
    , SpracheGuiReader r m
    , StatusVarGuiReader r m
    , DynamischeWidgetsReader r m
    , MonadIO m
    )
    => p
    -> Maybe (TVar (Maybe [Sprache -> IO ()]))
    -> m AssistantHinzufügen
assistantHinzufügenNew parent maybeTVar = do
    (tmVarErgebnis, window, vBox, notebook) <- liftIO $ do
        tmVarErgebnis <- atomically newEmptyTMVar
        window <- Gtk.windowNew
        Gtk.set window [Gtk.windowTransientFor := erhalteWindow parent, Gtk.windowModal := True]
        Gtk.on window Gtk.deleteEvent $ liftIO $ do
            atomically (putTMVar tmVarErgebnis HinzufügenBeenden)
            pure True
        vBox <- containerAddWidgetNew window $ Gtk.vBoxNew False 0
        notebook <- boxPackWidgetNew vBox PackGrow paddingDefault positionDefault Gtk.notebookNew
        pure (tmVarErgebnis, window, vBox, notebook)
    zugtypAuswahl
        <- widgetShowNew $ auswahlComboBoxNew unterstützteZugtypen maybeTVar Language.zugtyp
    fließendAuswahl <- widgetShowNew $ fließendAuswahlNew maybeTVar
    indexSeiten <- foldM
        (\acc (konstruktor, name) -> do
             (seite, seitenIndex) <- notebookAppendPageNew notebook maybeTVar name konstruktor
             pure $ Map.insert seitenIndex seite acc)
        Map.empty
        [ (hinzufügenBahngeschwindigkeitNew zugtypAuswahl maybeTVar, Language.bahngeschwindigkeit)
        , (hinzufügenStreckenabschnittNew maybeTVar, Language.streckenabschnitt)
        , (hinzufügenWeicheNew zugtypAuswahl maybeTVar, Language.weiche)
        , (hinzufügenKupplungNew maybeTVar, Language.kupplung)
        , (hinzufügenKontaktNew maybeTVar, Language.kontakt)
        , (hinzufügenWegstreckeNew zugtypAuswahl maybeTVar, Language.wegstrecke)
        , (hinzufügenPlanNew window zugtypAuswahl maybeTVar, Language.plan)]
    let assistantHinzufügen =
            AssistantHinzufügen
            { window
            , notebook
            , fließendAuswahl
            , zugtypAuswahl
            , indexSeiten
            , tmVarErgebnis
            }
    functionBox
        <- liftIO $ boxPackWidgetNew vBox packingDefault paddingDefault End $ Gtk.hBoxNew False 0
    statusVar <- erhalteStatusVar :: m StatusVarGui
    buttonHinzufügen <- liftIO $ do
        buttonHinzufügen <- widgetShowNew Gtk.buttonNew
        let alleButtonHinzufügen =
                ButtonHinzufügen buttonHinzufügen
                : catMaybes (spezifischerButtonHinzufügen <$> Map.elems indexSeiten)
        forM_ alleButtonHinzufügen $ \button -> do
            boxPackDefault functionBox button
            Gtk.on (erhalteButton button) Gtk.buttonActivated
                $ flip runReaderT statusVar
                $ hinzufügenErgebnis assistantHinzufügen
        Gtk.on notebook Gtk.switchPage $ \pageIndex -> do
            mapM_ mitWidgetHide alleButtonHinzufügen
            case Map.lookup pageIndex indexSeiten >>= spezifischerButtonHinzufügen of
                (Just button) -> mitWidgetShow button
                _otherwise -> mitWidgetShow buttonHinzufügen
        boxPackDefault functionBox fließendAuswahl
        boxPackDefault functionBox zugtypAuswahl
        pure buttonHinzufügen
    boxPackWidgetNew functionBox packingDefault paddingDefault End
        $ buttonNewWithEventLabel maybeTVar Language.abbrechen
        $ atomically
        $ putTMVar tmVarErgebnis HinzufügenAbbrechen
    verwendeSpracheGui maybeTVar $ \sprache -> do
        Gtk.set window [Gtk.windowTitle := Language.hinzufügen sprache]
        Gtk.set buttonHinzufügen [Gtk.buttonLabel := Language.hinzufügen sprache]
    pure assistantHinzufügen
#endif
--
