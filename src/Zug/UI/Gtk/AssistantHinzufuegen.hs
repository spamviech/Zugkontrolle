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
-- Bibliotheken
import Control.Concurrent.STM (atomically, TVar, TMVar, newEmptyTMVar, putTMVar, takeTMVar)
import Control.Monad (void, forM_, foldM)
import Control.Monad.Reader (runReaderT)
import Control.Monad.Trans (MonadIO(..))
import Data.Map.Lazy (Map)
import qualified Data.Map.Lazy as Map
import Data.Maybe (catMaybes)
import qualified Graphics.UI.Gtk as Gtk
import Graphics.UI.Gtk (AttrOp((:=)))

-- Abhängigkeiten von anderen Modulen
import Zug.Enums (Zugtyp(), unterstützteZugtypen)
import Zug.Language (Sprache())
import qualified Zug.Language as Language
import Zug.Objekt (Objekt)
import Zug.UI.Gtk.AssistantHinzufuegen.HinzufuegenSeite
       (HinzufügenSeite(), ButtonHinzufügen(ButtonHinzufügen), spezifischerButtonHinzufügen
      , seiteErgebnis, hinzufügenBahngeschwindigkeitNew, hinzufügenStreckenabschnittNew
      , hinzufügenWeicheNew, hinzufügenKupplungNew, hinzufügenWegstreckeNew, hinzufügenPlanNew)
import Zug.UI.Gtk.Auswahl (AuswahlWidget, auswahlComboBoxNew)
import Zug.UI.Gtk.Fliessend (FließendAuswahlWidget, fließendAuswahlNew)
import Zug.UI.Gtk.Hilfsfunktionen (containerAddWidgetNew, boxPackWidgetNewDefault, boxPackDefault
                                 , notebookAppendPageNew, buttonNewWithEventLabel)
import Zug.UI.Gtk.Klassen (MitWidget(..), mitWidgetShow, mitWidgetHide, MitWindow(..))
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
    (window, vBox, notebook) <- liftIO $ do
        window <- Gtk.windowNew
        Gtk.set window [Gtk.windowTransientFor := erhalteWindow parent, Gtk.windowModal := True]
        vBox <- containerAddWidgetNew window $ Gtk.vBoxNew False 0
        notebook <- boxPackWidgetNewDefault vBox Gtk.notebookNew
        pure (window, vBox, notebook)
    zugtypAuswahl <- auswahlComboBoxNew unterstützteZugtypen maybeTVar Language.zugtyp
    fließendAuswahl <- fließendAuswahlNew maybeTVar
    indexSeiten <- foldM
        (\acc (konstruktor, name) -> do
             (seite, seitenIndex) <- notebookAppendPageNew notebook maybeTVar name konstruktor
             pure $ Map.insert seitenIndex seite acc)
        Map.empty
        [ (hinzufügenBahngeschwindigkeitNew zugtypAuswahl maybeTVar, Language.bahngeschwindigkeit)
        , (hinzufügenStreckenabschnittNew maybeTVar, Language.streckenabschnitt)
        , (hinzufügenWeicheNew zugtypAuswahl maybeTVar, Language.weiche)
        , (hinzufügenKupplungNew maybeTVar, Language.kupplung)
        , (hinzufügenWegstreckeNew zugtypAuswahl maybeTVar, Language.wegstrecke)
        , (hinzufügenPlanNew zugtypAuswahl maybeTVar, Language.plan)]
    (functionBox, tmVarErgebnis) <- liftIO $ do
        functionBox <- boxPackWidgetNewDefault vBox $ Gtk.hBoxNew False 0
        tmVarErgebnis <- atomically newEmptyTMVar
        pure (functionBox, tmVarErgebnis)
    let assistantHinzufügen =
            AssistantHinzufügen
            { window
            , notebook
            , fließendAuswahl
            , zugtypAuswahl
            , indexSeiten
            , tmVarErgebnis
            }
    statusVar <- erhalteStatusVar :: m StatusVarGui
    buttonHinzufügen <- boxPackWidgetNewDefault functionBox
        $ buttonNewWithEventLabel maybeTVar Language.hinzufügen
        $ void
        $ flip runReaderT statusVar
        $ hinzufügenErgebnis assistantHinzufügen
    liftIO $ do
        let alleButtonHinzufügen =
                ButtonHinzufügen buttonHinzufügen
                : catMaybes (spezifischerButtonHinzufügen <$> Map.elems indexSeiten)
        forM_ alleButtonHinzufügen $ boxPackDefault functionBox
        Gtk.on notebook Gtk.switchPage $ \pageIndex -> do
            mapM_ mitWidgetHide alleButtonHinzufügen
            case Map.lookup pageIndex indexSeiten >>= spezifischerButtonHinzufügen of
                (Just button) -> mitWidgetShow button
                _otherwise -> pure ()
        boxPackDefault functionBox fließendAuswahl
        boxPackDefault functionBox zugtypAuswahl
    verwendeSpracheGui maybeTVar
        $ \sprache -> Gtk.set window [Gtk.windowTitle := Language.hinzufügen sprache]
    pure assistantHinzufügen
#endif
--
