{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE RecursiveDo #-}

{-|
Description: Seite zum Hinzufügen einer 'Weiche'n-'Aktion'.
-}
module Zug.UI.Gtk.AssistantHinzufuegen.AktionWeiche (aktionWeicheAuswahlPackNew) where

import Control.Concurrent.STM (atomically, takeTMVar)
import Control.Monad (void)
import Control.Monad.Fix (MonadFix())
import Control.Monad.Reader (runReaderT)
import Control.Monad.Trans (MonadIO())
import qualified Data.GI.Gtk.Threading as Gtk
import Data.List.NonEmpty (NonEmpty())
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import qualified GI.Gtk as Gtk

import Zug.Enums (Richtung())
import Zug.Language (MitSprache(leseSprache), (<:>))
import qualified Zug.Language as Language
import Zug.Objekt (ObjektAllgemein(OWeiche))
import Zug.Plan (AktionAllgemein(AWeiche), Aktion, AktionWeiche(..))
import Zug.UI.Gtk.Auswahl (boundedEnumAuswahlRadioButtonNew, aktuelleAuswahl)
import Zug.UI.Gtk.Hilfsfunktionen (boxPackWidgetNewDefault, buttonNewWithEventLabel)
import Zug.UI.Gtk.Klassen (mitWidgetShow, mitWidgetHide, MitBox())
import Zug.UI.Gtk.SpracheGui (SpracheGuiReader(..), TVarSprachewechselAktionen)
import Zug.UI.Gtk.StreckenObjekt (DynamischeWidgets(..), DynamischeWidgetsReader(..))
import Zug.Util (forkIOSilent)

-- | Erzeuge die Widgets zur Auswahl einer 'Weiche'n-'Aktion'.
aktionWeicheAuswahlPackNew
    :: (MitBox b, SpracheGuiReader r m, DynamischeWidgetsReader r m, MonadFix m, MonadIO m)
    => b
    -> Gtk.Window
    -> Maybe TVarSprachewechselAktionen
    -> NonEmpty (Richtung, IO ())
    -> (forall rr mm. (SpracheGuiReader rr mm, MonadIO mm) => Aktion -> mm ())
    -> m Gtk.Box
aktionWeicheAuswahlPackNew box windowObjektAuswahl maybeTVar showRichtungen aktionHinzufügen = mdo
    spracheGui <- erhalteSpracheGui
    DynamischeWidgets {dynTMVarPlanObjekt} <- erhalteDynamischeWidgets
    hBoxWeiche <- boxPackWidgetNewDefault box $ Gtk.boxNew Gtk.OrientationHorizontal 0
    boxPackWidgetNewDefault hBoxWeiche
        $ buttonNewWithEventLabel maybeTVar Language.stellen
        $ void
        $ do
            richtung <- aktuelleAuswahl auswahlRichtung
            forkIOSilent $ do
                Gtk.postGUIASync $ flip leseSprache spracheGui $ \sprache -> do
                    Gtk.setWindowTitle windowObjektAuswahl
                        $ Language.stellen <:> richtung
                        $ sprache
                    snd $ head $ NonEmpty.filter ((== richtung) . fst) showRichtungen
                    mitWidgetShow windowObjektAuswahl
                maybeObjekt <- atomically $ takeTMVar dynTMVarPlanObjekt
                Gtk.postGUIASync $ mitWidgetHide windowObjektAuswahl
                flip runReaderT spracheGui $ case maybeObjekt of
                    (Just (OWeiche we)) -> aktionHinzufügen $ AWeiche $ Stellen we richtung
                    _sonst -> pure ()
    auswahlRichtung <- boxPackWidgetNewDefault hBoxWeiche
        $ boundedEnumAuswahlRadioButtonNew (fst $ NonEmpty.head showRichtungen) maybeTVar
        $ const Text.empty
    pure hBoxWeiche