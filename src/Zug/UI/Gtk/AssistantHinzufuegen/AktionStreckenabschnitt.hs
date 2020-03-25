{-# LANGUAGE CPP #-}
#ifdef ZUGKONTROLLEGUI
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE MonoLocalBinds #-}
#endif

{-|
Description: Seite zum Hinzufügen einer 'Streckenabschnitt's-'Aktion'.
-}
module Zug.UI.Gtk.AssistantHinzufuegen.AktionStreckenabschnitt
  (
#ifdef ZUGKONTROLLEGUI
    aktionStreckenabschnittAuswahlPackNew
#endif
  ) where

#ifdef ZUGKONTROLLEGUI
import Control.Concurrent (forkIO)
import Control.Concurrent.STM (atomically, TVar, takeTMVar)
import Control.Monad (void)
import Control.Monad.Reader (runReaderT)
import Control.Monad.Trans (MonadIO(..))
import qualified Data.Text as Text
import Graphics.UI.Gtk (AttrOp((:=)))
import qualified Graphics.UI.Gtk as Gtk

import Zug.Enums (ZugtypEither(..), Strom(Fließend))
import Zug.Language (Sprache(), MitSprache(leseSprache), (<:>))
import qualified Zug.Language as Language
import Zug.Objekt (ObjektAllgemein(OStreckenabschnitt, OWegstrecke))
import Zug.Plan (Aktion(AStreckenabschnitt, AWegstreckeMärklin, AWegstreckeLego)
               , AktionStreckenabschnitt(..), AktionWegstrecke(AWSStreckenabschnitt))
import Zug.UI.Gtk.Auswahl (boundedEnumAuswahlRadioButtonNew, aktuelleAuswahl)
import Zug.UI.Gtk.Hilfsfunktionen
       (widgetShowNew, boxPackWidgetNewDefault, boxPackDefault, buttonNewWithEventLabel)
import Zug.UI.Gtk.Klassen (mitWidgetShow, mitWidgetHide, MitBox())
import Zug.UI.Gtk.SpracheGui (SpracheGuiReader(..))
import Zug.UI.Gtk.StreckenObjekt (DynamischeWidgets(..), DynamischeWidgetsReader(..))

-- | Erzeuge die Widgets zur Auswahl einer 'Streckenabschnitt'-'Aktion'.
aktionStreckenabschnittAuswahlPackNew
    :: (MitBox b, SpracheGuiReader r m, DynamischeWidgetsReader r m, MonadIO m)
    => b
    -> Gtk.Window
    -> Maybe (TVar (Maybe [Sprache -> IO ()]))
    -> IO ()
    -> (forall rr mm. (SpracheGuiReader rr mm, MonadIO mm) => Aktion -> mm ())
    -> m Gtk.HBox
aktionStreckenabschnittAuswahlPackNew box windowObjektAuswahl maybeTVar showST aktionHinzufügen = do
    spracheGui <- erhalteSpracheGui
    DynamischeWidgets {tmvarPlanObjekt} <- erhalteDynamischeWidgets
    hBoxStreckenabschnitt <- liftIO $ boxPackWidgetNewDefault box $ Gtk.hBoxNew False 0
    auswahlStrom
        <- widgetShowNew $ boundedEnumAuswahlRadioButtonNew Fließend maybeTVar $ const Text.empty
    boxPackWidgetNewDefault hBoxStreckenabschnitt
        $ buttonNewWithEventLabel maybeTVar Language.strom
        $ void
        $ do
            strom <- aktuelleAuswahl auswahlStrom
            forkIO $ do
                Gtk.postGUIAsync $ do
                    Gtk.set
                        windowObjektAuswahl
                        [Gtk.windowTitle := leseSprache (Language.strom <:> strom) spracheGui]
                    showST
                    mitWidgetShow windowObjektAuswahl
                maybeObjekt <- atomically $ takeTMVar tmvarPlanObjekt
                Gtk.postGUIAsync $ mitWidgetHide windowObjektAuswahl
                flip runReaderT spracheGui $ case maybeObjekt of
                    (Just (OStreckenabschnitt st))
                        -> aktionHinzufügen $ AStreckenabschnitt $ Strom st strom
                    (Just (OWegstrecke (ZugtypMärklin ws))) -> aktionHinzufügen
                        $ AWegstreckeMärklin
                        $ AWSStreckenabschnitt
                        $ Strom ws strom
                    (Just (OWegstrecke (ZugtypLego ws))) -> aktionHinzufügen
                        $ AWegstreckeLego
                        $ AWSStreckenabschnitt
                        $ Strom ws strom
                    _sonst -> pure ()
    boxPackDefault hBoxStreckenabschnitt auswahlStrom
    pure hBoxStreckenabschnitt
#endif
--
