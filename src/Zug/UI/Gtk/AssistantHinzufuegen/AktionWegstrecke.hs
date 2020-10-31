{-# LANGUAGE CPP #-}
#ifdef ZUGKONTROLLEGUI
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE MonoLocalBinds #-}
#endif

{-|
Description: Seite zum Hinzufügen einer 'Wegstrecke'n-'Aktion'.
-}
module Zug.UI.Gtk.AssistantHinzufuegen.AktionWegstrecke
  (
#ifdef ZUGKONTROLLEGUI
    aktionWegstreckeAuswahlPackNew
#endif
  ) where

#ifdef ZUGKONTROLLEGUI
import Control.Concurrent.STM (atomically, takeTMVar)
import Control.Monad (void)
import Control.Monad.Reader (runReaderT)
import Control.Monad.Trans (MonadIO(..))
import qualified Data.GI.Gtk.Threading as Gtk
import qualified GI.Gtk as Gtk

import Zug.Enums (ZugtypEither(..))
import Zug.Language (MitSprache(leseSprache))
import qualified Zug.Language as Language
import Zug.Objekt (ObjektAllgemein(OWegstrecke))
import Zug.Plan
       (AktionAllgemein(AWegstreckeMärklin, AWegstreckeLego), Aktion, AktionWegstrecke(Einstellen))
import Zug.UI.Gtk.Hilfsfunktionen (boxPackWidgetNewDefault, buttonNewWithEventLabel)
import Zug.UI.Gtk.Klassen (mitWidgetShow, mitWidgetHide, MitBox())
import Zug.UI.Gtk.SpracheGui (SpracheGuiReader(..), TVarSprachewechselAktionen)
import Zug.UI.Gtk.StreckenObjekt (DynamischeWidgets(..), DynamischeWidgetsReader(..))
import Zug.Util (forkIOSilent)

-- | Erzeuge die Widgets zur Auswahl einer 'Wegstrecke'n-'Aktion'.
aktionWegstreckeAuswahlPackNew
    :: (MitBox b, SpracheGuiReader r m, DynamischeWidgetsReader r m, MonadIO m)
    => b
    -> Gtk.Window
    -> Maybe TVarSprachewechselAktionen
    -> IO ()
    -> (forall rr mm. (SpracheGuiReader rr mm, MonadIO mm) => Aktion -> mm ())
    -> m Gtk.Box
aktionWegstreckeAuswahlPackNew box windowObjektAuswahl maybeTVar showWS aktionHinzufügen = do
    spracheGui <- erhalteSpracheGui
    DynamischeWidgets {dynTMVarPlanObjekt} <- erhalteDynamischeWidgets
    hBoxWegstrecke <- liftIO $ boxPackWidgetNewDefault box $ Gtk.boxNew Gtk.OrientationHorizontal 0
    boxPackWidgetNewDefault hBoxWegstrecke
        $ buttonNewWithEventLabel maybeTVar Language.einstellen
        $ void
        $ forkIOSilent
        $ do
            Gtk.postGUIASync $ flip leseSprache spracheGui $ \sprache -> do
                Gtk.setWindowTitle windowObjektAuswahl $ Language.einstellen sprache
                showWS
                mitWidgetShow windowObjektAuswahl
            maybeObjekt <- atomically $ takeTMVar dynTMVarPlanObjekt
            Gtk.postGUIASync $ mitWidgetHide windowObjektAuswahl
            flip runReaderT spracheGui $ case maybeObjekt of
                (Just (OWegstrecke (ZugtypMärklin ws)))
                    -> aktionHinzufügen $ AWegstreckeMärklin $ Einstellen ws
                (Just (OWegstrecke (ZugtypLego ws)))
                    -> aktionHinzufügen $ AWegstreckeLego $ Einstellen ws
                _sonst -> pure ()
    pure hBoxWegstrecke
#endif
--
