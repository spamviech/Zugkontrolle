{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}

module Zug.UI.Gtk.StreckenObjekt.BGWidgets
  ( BGWidgets()
  , bahngeschwindigkeitPackNew
  , hScaleGeschwindigkeitPackNew
  , auswahlFahrstromPackNew
  , buttonUmdrehenPackNew
  , auswahlFahrtrichtungEinstellenPackNew
  ) where

import Control.Concurrent.STM.TVar (TVar)
import qualified Control.Lens as Lens
import Control.Monad.Reader.Class (asks)
import Control.Monad.Trans (MonadIO())
import qualified Data.Aeson as Aeson
import Data.Kind (Type)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Set (Set)
import qualified Data.Set as Set
import qualified Data.Text as Text
import Data.Text (Text)
import Data.Void (Void)
import Data.Word (Word8)
import qualified Graphics.UI.Gtk as Gtk
import Numeric.Natural (Natural)

import Zug.Anbindung (StreckenObjekt(..), Bahngeschwindigkeit(..), BahngeschwindigkeitKlasse(..)
                    , Wegstrecke(..), Anschluss(), I2CReader(), PwmReader())
import Zug.Enums
       (GeschwindigkeitEither(..), GeschwindigkeitVariante(..), GeschwindigkeitEitherKlasse()
      , Zugtyp(..), ZugtypEither(..), ZugtypKlasse(), Fahrtrichtung())
import Zug.Language (Sprache())
import qualified Zug.Language as Language
import Zug.Objekt (Objekt, ObjektElement(..))
import Zug.UI.Base (MStatusAllgemeinT)
import Zug.UI.Gtk.Auswahl (AuswahlWidget)
import Zug.UI.Gtk.Klassen (MitWidget(..), MitBox())
import Zug.UI.Gtk.ScrollbaresWidget (ScrollbaresWidget)
import Zug.UI.Gtk.SpracheGui (SpracheGuiReader())
import Zug.UI.Gtk.StreckenObjekt.ElementKlassen (WegstreckenElement(..), PlanElement(..))
import Zug.UI.Gtk.StreckenObjekt.STWidgets (STWidgetsKlasse(..))
import Zug.UI.Gtk.StreckenObjekt.WidgetHinzufügen
       (Kategorie(..), KategorieText(..), BoxWegstreckeHinzufügen, CheckButtonWegstreckeHinzufügen
      , BoxPlanHinzufügen, ButtonPlanHinzufügen)
import Zug.UI.Gtk.StreckenObjekt.WidgetsTyp (WidgetsTyp(..), WidgetsTypReader, EventAusführen())
import Zug.UI.StatusVar (StatusVar, StatusVarReader(..))

instance Kategorie (BGWidgets g z) where
    kategorie :: KategorieText (BGWidgets g z)
    kategorie = KategorieText Language.bahngeschwindigkeiten

instance Kategorie (GeschwindigkeitEither BGWidgets z) where
    kategorie :: KategorieText (GeschwindigkeitEither BGWidgets z)
    kategorie = KategorieText Language.bahngeschwindigkeiten

-- | 'Bahngeschwindigkeit' mit zugehörigen Widgets
data BGWidgets (g :: GeschwindigkeitVariante) (z :: Zugtyp) where
    BGWidgetsPwmMärklin
        :: { bgpm :: Bahngeschwindigkeit 'Pwm 'Märklin
           , bgpmWidget :: Gtk.VBox
           , bgpmFunctionBox :: Gtk.HBox
           , bgpmHinzWS :: CheckButtonWegstreckeHinzufügen Void (BGWidgets 'Pwm 'Märklin)
           , bgpmHinzPL :: ( ButtonPlanHinzufügen (BGWidgets 'Pwm 'Märklin)
                           , ButtonPlanHinzufügen (GeschwindigkeitEither BGWidgets 'Märklin)
                           )
           , bgpmTVarSprache :: TVar (Maybe [Sprache -> IO ()])
           , bgpmTVarEvent :: TVar EventAusführen
           , bgpmScaleGeschwindigkeit :: Gtk.HScale
           } -> BGWidgets 'Pwm 'Märklin
    BGWidgetsKonstanteSpannungMärklin
        :: { bgkm :: Bahngeschwindigkeit 'KonstanteSpannung 'Märklin
           , bgkmWidget :: Gtk.VBox
           , bgkmFunctionBox :: Gtk.HBox
           , bgkmHinzWS
                 :: CheckButtonWegstreckeHinzufügen Void (BGWidgets 'KonstanteSpannung 'Märklin)
           , bgkmHinzPL :: ( ButtonPlanHinzufügen (BGWidgets 'KonstanteSpannung 'Märklin)
                           , ButtonPlanHinzufügen (GeschwindigkeitEither BGWidgets 'Märklin)
                           )
           , bgkmTVarSprache :: TVar (Maybe [Sprache -> IO ()])
           , bgkmTVarEvent :: TVar EventAusführen
           , bgkmAuswahlFahrstrom :: AuswahlWidget Word8
           } -> BGWidgets 'KonstanteSpannung 'Märklin
    BGWidgetsPwmLego
        :: { bgpl :: Bahngeschwindigkeit 'Pwm 'Lego
           , bgplWidget :: Gtk.VBox
           , bgplFunctionBox :: Gtk.HBox
           , bgplHinzWS :: CheckButtonWegstreckeHinzufügen Void (BGWidgets 'Pwm 'Lego)
           , bgplHinzPL :: ( ButtonPlanHinzufügen (BGWidgets 'Pwm 'Lego)
                           , ButtonPlanHinzufügen (GeschwindigkeitEither BGWidgets 'Lego)
                           )
           , bgplTVarSprache :: TVar (Maybe [Sprache -> IO ()])
           , bgplTVarEvent :: TVar EventAusführen
           , bgplScaleGeschwindigkeit :: Gtk.HScale
           , bgplAuswahlFahrtrichtung :: AuswahlWidget Fahrtrichtung
           } -> BGWidgets 'Pwm 'Lego
    BGWidgetsKonstanteSpannungLego
        :: { bgkl :: Bahngeschwindigkeit 'KonstanteSpannung 'Lego
           , bgklWidget :: Gtk.VBox
           , bgklFunctionBox :: Gtk.HBox
           , bgklHinzWS
                 :: CheckButtonWegstreckeHinzufügen Void (BGWidgets 'KonstanteSpannung 'Lego)
           , bgklHinzPL :: ( ButtonPlanHinzufügen (BGWidgets 'KonstanteSpannung 'Lego)
                           , ButtonPlanHinzufügen (GeschwindigkeitEither BGWidgets 'Lego)
                           )
           , bgklTVarSprache :: TVar (Maybe [Sprache -> IO ()])
           , bgklTVarEvent :: TVar EventAusführen
           , bgklAuswahlFahrstrom :: AuswahlWidget Word8
           , bgklAuswahlFahrtrichtung :: AuswahlWidget Fahrtrichtung
           } -> BGWidgets 'KonstanteSpannung 'Lego

deriving instance (Eq (ObjektTyp (BGWidgets g z))) => Eq (BGWidgets g z)

instance MitWidget (BGWidgets g z) where
    erhalteWidget :: BGWidgets g z -> Gtk.Widget
    erhalteWidget BGWidgetsPwmMärklin {bgpmWidget} = erhalteWidget bgpmWidget
    erhalteWidget BGWidgetsKonstanteSpannungMärklin {bgkmWidget} = erhalteWidget bgkmWidget
    erhalteWidget BGWidgetsPwmLego {bgplWidget} = erhalteWidget bgplWidget
    erhalteWidget BGWidgetsKonstanteSpannungLego {bgklWidget} = erhalteWidget bgklWidget

data BGWidgetsBoxen =
    BGWidgetsBoxen
    { vBoxBahngeschwindigkeiten :: ScrollbaresWidget Gtk.VBox
    , vBoxHinzufügenWegstreckeBahngeschwindigkeitenMärklin
          :: BoxWegstreckeHinzufügen (GeschwindigkeitEither BGWidgets 'Märklin)
    , vBoxHinzufügenWegstreckeBahngeschwindigkeitenLego
          :: BoxWegstreckeHinzufügen (GeschwindigkeitEither BGWidgets 'Lego)
    , vBoxHinzufügenPlanBahngeschwindigkeitenMärklin
          :: BoxPlanHinzufügen (GeschwindigkeitEither BGWidgets 'Märklin)
    , vBoxHinzufügenPlanBahngeschwindigkeitenMärklinPwm
          :: BoxPlanHinzufügen (BGWidgets 'Pwm 'Märklin)
    , vBoxHinzufügenPlanBahngeschwindigkeitenMärklinKonstanteSpannung
          :: BoxPlanHinzufügen (BGWidgets 'KonstanteSpannung 'Märklin)
    , vBoxHinzufügenPlanBahngeschwindigkeitenLego
          :: BoxPlanHinzufügen (GeschwindigkeitEither BGWidgets 'Lego)
    , vBoxHinzufügenPlanBahngeschwindigkeitenLegoPwm :: BoxPlanHinzufügen (BGWidgets 'Pwm 'Lego)
    , vBoxHinzufügenPlanBahngeschwindigkeitenLegoKonstanteSpannung
          :: BoxPlanHinzufügen (BGWidgets 'KonstanteSpannung 'Lego)
    }

class MitBGWidgetsBoxen r where
    bgWidgetsBoxen :: r -> BGWidgetsBoxen

instance (WegstreckenElement (BGWidgets g z), PlanElement (BGWidgets g z))
    => WidgetsTyp (BGWidgets g z) where
    type ObjektTyp (BGWidgets g z) = Bahngeschwindigkeit g z

    type ReaderConstraint (BGWidgets g z) = MitBGWidgetsBoxen

    erhalteObjektTyp :: BGWidgets g z -> Bahngeschwindigkeit g z
    erhalteObjektTyp BGWidgetsPwmMärklin {bgpm} = bgpm
    erhalteObjektTyp BGWidgetsKonstanteSpannungMärklin {bgkm} = bgkm
    erhalteObjektTyp BGWidgetsPwmLego {bgpl} = bgpl
    erhalteObjektTyp BGWidgetsKonstanteSpannungLego {bgkl} = bgkl

    entferneWidgets :: (MonadIO m, WidgetsTypReader r (BGWidgets g z) m) => BGWidgets g z -> m ()
    entferneWidgets bgWidgets = do
        vBoxBahngeschwindigkeiten <- asks vBoxBahngeschwindigkeiten
        mitContainerRemove vBoxBahngeschwindigkeiten bgWidgets
        entferneHinzufügenWegstreckeWidgets bgWidgets
        entferneHinzufügenPlanWidgets bgWidgets
        liftIO $ atomically $ writeTVar (tvarSprache bgWidgets) Nothing

    boxButtonEntfernen :: BGWidgets g z -> Gtk.Box
    boxButtonEntfernen BGWidgetsPwmMärklin {bgpmFunctionBox} = erhalteBox bgpmFunctionBox
    boxButtonEntfernen
        BGWidgetsKonstanteSpannungMärklin {bgkmFunctionBox} = erhalteBox bgkmFunctionBox
    boxButtonEntfernen BGWidgetsPwmLego {bgplFunctionBox} = erhalteBox bgplFunctionBox
    boxButtonEntfernen
        BGWidgetsKonstanteSpannungLego {bgklFunctionBox} = erhalteBox bgklFunctionBox

    tvarSprache :: BGWidgets g z -> TVar (Maybe [Sprache -> IO ()])
    tvarSprache BGWidgetsPwmMärklin {bgpmTVarSprache} = bgpmTVarSprache
    tvarSprache BGWidgetsKonstanteSpannungMärklin {bgkmTVarSprache} = bgkmTVarSprache
    tvarSprache BGWidgetsPwmLego {bgplTVarSprache} = bgplTVarSprache
    tvarSprache BGWidgetsKonstanteSpannungLego {bgklTVarSprache} = bgklTVarSprache

    tvarEvent :: BGWidgets g z -> TVar EventAusführen
    tvarEvent BGWidgetsPwmMärklin {bgpmTVarEvent} = bgpmTVarEvent
    tvarEvent BGWidgetsKonstanteSpannungMärklin {bgkmTVarEvent} = bgkmTVarEvent
    tvarEvent BGWidgetsPwmLego {bgplTVarEvent} = bgplTVarEvent
    tvarEvent BGWidgetsKonstanteSpannungLego {bgklTVarEvent} = bgklTVarEvent

instance WegstreckenElement (BGWidgets g 'Märklin) where
    getterWegstrecke
        :: Lens.Getter (BGWidgets g 'Märklin) (CheckButtonWegstreckeHinzufügen Void (BGWidgets g 'Märklin))
    getterWegstrecke = Lens.to erhalteCheckbuttonWegstrecke
        where
            erhalteCheckbuttonWegstrecke
                :: BGWidgets g 'Märklin
                -> CheckButtonWegstreckeHinzufügen Void (BGWidgets g 'Märklin)
            erhalteCheckbuttonWegstrecke BGWidgetsPwmMärklin {bgpmHinzWS} = bgpmHinzWS
            erhalteCheckbuttonWegstrecke
                BGWidgetsKonstanteSpannungMärklin {bgkmHinzWS} = bgkmHinzWS

    boxWegstrecke :: (ReaderConstraint (BGWidgets g 'Märklin) r)
                  => Bahngeschwindigkeit g 'Märklin
                  -> Lens.Getter r (BoxWegstreckeHinzufügen (BGWidgets g 'Märklin))
    boxWegstrecke _bahngeschwindigkeit =
        Lens.to
        $ widgetHinzufügenGeschwindigkeitVariante
        . vBoxHinzufügenWegstreckeBahngeschwindigkeitenMärklin

instance WegstreckenElement (BGWidgets g 'Lego) where
    getterWegstrecke
        :: Lens.Getter (BGWidgets g 'Lego) (CheckButtonWegstreckeHinzufügen Void (BGWidgets g 'Lego))
    getterWegstrecke = Lens.to erhalteCheckbuttonWegstrecke
        where
            erhalteCheckbuttonWegstrecke
                :: BGWidgets g 'Lego -> CheckButtonWegstreckeHinzufügen Void (BGWidgets g 'Lego)
            erhalteCheckbuttonWegstrecke BGWidgetsPwmLego {bgplHinzWS} = bgplHinzWS
            erhalteCheckbuttonWegstrecke BGWidgetsKonstanteSpannungLego {bgklHinzWS} = bgklHinzWS

    boxWegstrecke :: (ReaderConstraint (BGWidgets g 'Lego) r)
                  => Bahngeschwindigkeit g 'Lego
                  -> Lens.Getter r (BoxWegstreckeHinzufügen (BGWidgets g 'Lego))
    boxWegstrecke _bahngeschwindigkeit =
        Lens.to
        $ widgetHinzufügenGeschwindigkeitVariante
        . vBoxHinzufügenWegstreckeBahngeschwindigkeitenLego

instance MitWidget (GeschwindigkeitEither BGWidgets z) where
    erhalteWidget :: GeschwindigkeitEither BGWidgets z -> Gtk.Widget
    erhalteWidget = ausGeschwindigkeitEither erhalteWidget

instance WegstreckenElement (GeschwindigkeitEither BGWidgets 'Märklin) where
    getterWegstrecke
        :: Lens.Getter (GeschwindigkeitEither BGWidgets 'Märklin) (CheckButtonWegstreckeHinzufügen Void (GeschwindigkeitEither BGWidgets 'Märklin))
    getterWegstrecke =
        Lens.to
        $ ausGeschwindigkeitEither
        $ widgetHinzufügenGeschwindigkeitEither . Lens.view getterWegstrecke

    boxWegstrecke
        :: (ReaderConstraint (GeschwindigkeitEither BGWidgets 'Märklin) r)
        => GeschwindigkeitEither Bahngeschwindigkeit 'Märklin
        -> Lens.Getter r (BoxWegstreckeHinzufügen (GeschwindigkeitEither BGWidgets 'Märklin))
    boxWegstrecke _bgWidgets = Lens.to $ vBoxHinzufügenWegstreckeBahngeschwindigkeitenMärklin

instance WegstreckenElement (GeschwindigkeitEither BGWidgets 'Lego) where
    getterWegstrecke
        :: Lens.Getter (GeschwindigkeitEither BGWidgets 'Lego) (CheckButtonWegstreckeHinzufügen Void (GeschwindigkeitEither BGWidgets 'Lego))
    getterWegstrecke =
        Lens.to
        $ ausGeschwindigkeitEither
        $ widgetHinzufügenGeschwindigkeitEither . Lens.view getterWegstrecke

    boxWegstrecke
        :: (ReaderConstraint (GeschwindigkeitEither BGWidgets 'Lego) r)
        => GeschwindigkeitEither Bahngeschwindigkeit 'Lego
        -> Lens.Getter r (BoxWegstreckeHinzufügen (GeschwindigkeitEither BGWidgets 'Lego))
    boxWegstrecke _bgWidgets = Lens.to vBoxHinzufügenWegstreckeBahngeschwindigkeitenLego

instance ( WegstreckenElement (BGWidgets 'Pwm z)
         , WegstreckenElement (BGWidgets 'KonstanteSpannung z)
         ) => WidgetsTyp (GeschwindigkeitEither BGWidgets z) where
    type ObjektTyp (GeschwindigkeitEither BGWidgets z) =
        GeschwindigkeitEither Bahngeschwindigkeit z

    type ReaderConstraint (GeschwindigkeitEither BGWidgets z) = MitBGWidgetsBoxen

    erhalteObjektTyp
        :: GeschwindigkeitEither BGWidgets z -> GeschwindigkeitEither Bahngeschwindigkeit z
    erhalteObjektTyp (GeschwindigkeitPwm bg) = GeschwindigkeitPwm $ erhalteObjektTyp bg
    erhalteObjektTyp (GeschwindigkeitKonstanteSpannung bg) =
        GeschwindigkeitKonstanteSpannung $ erhalteObjektTyp bg

    entferneWidgets :: (MonadIO m, WidgetsTypReader r (BGWidgets 'Pwm z) m)
                    => GeschwindigkeitEither BGWidgets z
                    -> m ()
    entferneWidgets (GeschwindigkeitPwm bgWidgets) = entferneWidgets bgWidgets
    entferneWidgets (GeschwindigkeitKonstanteSpannung bgWidgets) = entferneWidgets bgWidgets

    boxButtonEntfernen :: GeschwindigkeitEither BGWidgets z -> Gtk.Box
    boxButtonEntfernen (GeschwindigkeitPwm bgWidgets) = boxButtonEntfernen bgWidgets
    boxButtonEntfernen (GeschwindigkeitKonstanteSpannung bgWidgets) = boxButtonEntfernen bgWidgets

    tvarSprache :: GeschwindigkeitEither BGWidgets z -> TVar (Maybe [Sprache -> IO ()])
    tvarSprache (GeschwindigkeitPwm bgWidgets) = tvarSprache bgWidgets
    tvarSprache (GeschwindigkeitKonstanteSpannung bgWidgets) = tvarSprache bgWidgets

    tvarEvent :: GeschwindigkeitEither BGWidgets z -> TVar EventAusführen
    tvarEvent (GeschwindigkeitPwm bgWidgets) = tvarEvent bgWidgets
    tvarEvent (GeschwindigkeitKonstanteSpannung bgWidgets) = tvarEvent bgWidgets

instance WidgetsTyp (ZugtypEither (GeschwindigkeitEither BGWidgets)) where
    type ObjektTyp (ZugtypEither (GeschwindigkeitEither BGWidgets)) =
        ZugtypEither (GeschwindigkeitEither Bahngeschwindigkeit)

    type ReaderConstraint (ZugtypEither (GeschwindigkeitEither BGWidgets)) = MitBGWidgetsBoxen

    erhalteObjektTyp :: ZugtypEither (GeschwindigkeitEither BGWidgets)
                     -> ZugtypEither (GeschwindigkeitEither Bahngeschwindigkeit)
    erhalteObjektTyp (ZugtypMärklin (GeschwindigkeitPwm bg)) =
        ZugtypMärklin $ GeschwindigkeitPwm $ erhalteObjektTyp bg
    erhalteObjektTyp (ZugtypMärklin (GeschwindigkeitKonstanteSpannung bg)) =
        ZugtypMärklin $ GeschwindigkeitKonstanteSpannung $ erhalteObjektTyp bg
    erhalteObjektTyp (ZugtypLego (GeschwindigkeitPwm bg)) =
        ZugtypLego $ GeschwindigkeitPwm $ erhalteObjektTyp bg
    erhalteObjektTyp (ZugtypLego (GeschwindigkeitKonstanteSpannung bg)) =
        ZugtypLego $ GeschwindigkeitKonstanteSpannung $ erhalteObjektTyp bg

    entferneWidgets :: (MonadIO m, WidgetsTypReader r (GeschwindigkeitEither BGWidgets) m)
                    => ZugtypEither (GeschwindigkeitEither BGWidgets)
                    -> m ()
    entferneWidgets (ZugtypMärklin (GeschwindigkeitPwm bgWidgets)) = entferneWidgets bgWidgets
    entferneWidgets (ZugtypMärklin (GeschwindigkeitKonstanteSpannung bgWidgets)) =
        entferneWidgets bgWidgets
    entferneWidgets (ZugtypLego (GeschwindigkeitPwm bgWidgets)) = entferneWidgets bgWidgets
    entferneWidgets (ZugtypLego (GeschwindigkeitKonstanteSpannung bgWidgets)) =
        entferneWidgets bgWidgets

    boxButtonEntfernen :: ZugtypEither (GeschwindigkeitEither BGWidgets) -> Gtk.Box
    boxButtonEntfernen (ZugtypMärklin (GeschwindigkeitPwm bgWidgets)) =
        boxButtonEntfernen bgWidgets
    boxButtonEntfernen (ZugtypMärklin (GeschwindigkeitKonstanteSpannung bgWidgets)) =
        boxButtonEntfernen bgWidgets
    boxButtonEntfernen (ZugtypLego (GeschwindigkeitPwm bgWidgets)) = boxButtonEntfernen bgWidgets
    boxButtonEntfernen (ZugtypLego (GeschwindigkeitKonstanteSpannung bgWidgets)) =
        boxButtonEntfernen bgWidgets

    tvarSprache :: ZugtypEither (GeschwindigkeitEither BGWidgets)
                -> TVar (Maybe [Sprache -> IO ()])
    tvarSprache (ZugtypMärklin (GeschwindigkeitPwm bgWidgets)) = tvarSprache bgWidgets
    tvarSprache (ZugtypMärklin (GeschwindigkeitKonstanteSpannung bgWidgets)) =
        tvarSprache bgWidgets
    tvarSprache (ZugtypLego (GeschwindigkeitPwm bgWidgets)) = tvarSprache bgWidgets
    tvarSprache (ZugtypLego (GeschwindigkeitKonstanteSpannung bgWidgets)) = tvarSprache bgWidgets

    tvarEvent :: ZugtypEither (GeschwindigkeitEither BGWidgets) -> TVar EventAusführen
    tvarEvent (ZugtypMärklin (GeschwindigkeitPwm bgWidgets)) = tvarEvent bgWidgets
    tvarEvent (ZugtypMärklin (GeschwindigkeitKonstanteSpannung bgWidgets)) = tvarEvent bgWidgets
    tvarEvent (ZugtypLego (GeschwindigkeitPwm bgWidgets)) = tvarEvent bgWidgets
    tvarEvent (ZugtypLego (GeschwindigkeitKonstanteSpannung bgWidgets)) = tvarEvent bgWidgets

instance WegstreckenElement (ZugtypEither (GeschwindigkeitEither BGWidgets)) where
    getterWegstrecke
        :: Lens.Getter (ZugtypEither (GeschwindigkeitEither BGWidgets)) (CheckButtonWegstreckeHinzufügen Void (ZugtypEither (GeschwindigkeitEither BGWidgets)))
    getterWegstrecke = Lens.to erhalteCheckbuttonWegstrecke
        where
            erhalteCheckbuttonWegstrecke
                :: ZugtypEither (GeschwindigkeitEither BGWidgets)
                -> CheckButtonWegstreckeHinzufügen Void (ZugtypEither (GeschwindigkeitEither BGWidgets))
            erhalteCheckbuttonWegstrecke (ZugtypMärklin bg) =
                widgetHinzufügenZugtypEither $ bg ^. getterWegstrecke
            erhalteCheckbuttonWegstrecke (ZugtypLego bg) =
                widgetHinzufügenZugtypEither $ bg ^. getterWegstrecke

    boxWegstrecke
        :: (ReaderConstraint (ZugtypEither (GeschwindigkeitEither BGWidgets)) r)
        => ZugtypEither (GeschwindigkeitEither Bahngeschwindigkeit)
        -> Lens.Getter r (BoxWegstreckeHinzufügen (ZugtypEither (GeschwindigkeitEither BGWidgets)))
    boxWegstrecke (ZugtypMärklin _bgWidgets) =
        Lens.to
        $ widgetHinzufügenZugtypEither . vBoxHinzufügenWegstreckeBahngeschwindigkeitenMärklin
    boxWegstrecke (ZugtypLego _bgWidgets) =
        Lens.to
        $ widgetHinzufügenZugtypEither . vBoxHinzufügenWegstreckeBahngeschwindigkeitenLego

instance PlanElement (BGWidgets b 'Märklin) where
    foldPlan
        :: Lens.Fold (BGWidgets b 'Märklin) (Maybe (ButtonPlanHinzufügen (BGWidgets b 'Märklin)))
    foldPlan = Lens.folding $ map Just . erhalteButtonPlanHinzufügen
        where
            erhalteButtonPlanHinzufügen
                :: BGWidgets b 'Märklin -> [ButtonPlanHinzufügen (BGWidgets b 'Märklin)]
            erhalteButtonPlanHinzufügen
                BGWidgetsPwmMärklin {bgpmHinzPL = (buttonSpezifisch, buttonAllgemein)} =
                [buttonSpezifisch, widgetHinzufügenGeschwindigkeitVariante buttonAllgemein]
            erhalteButtonPlanHinzufügen
                BGWidgetsKonstanteSpannungMärklin
                {bgkmHinzPL = (buttonSpezifisch, buttonAllgemein)} =
                [buttonSpezifisch, widgetHinzufügenGeschwindigkeitVariante buttonAllgemein]

    boxenPlan :: (ReaderConstraint (BGWidgets b 'Märklin) r)
              => Bahngeschwindigkeit b 'Märklin
              -> Lens.Fold r (BoxPlanHinzufügen (BGWidgets b 'Märklin))
    boxenPlan MärklinBahngeschwindigkeitPwm {} =
        Lens.folding
        $ \BGWidgetsBoxen { vBoxHinzufügenPlanBahngeschwindigkeitenMärklinPwm
                          , vBoxHinzufügenPlanBahngeschwindigkeitenMärklin}
        -> [ vBoxHinzufügenPlanBahngeschwindigkeitenMärklinPwm
           , widgetHinzufügenGeschwindigkeitVariante
                 vBoxHinzufügenPlanBahngeschwindigkeitenMärklin]
    boxenPlan MärklinBahngeschwindigkeitKonstanteSpannung {} =
        Lens.folding
        $ \BGWidgetsBoxen { vBoxHinzufügenPlanBahngeschwindigkeitenMärklinKonstanteSpannung
                          , vBoxHinzufügenPlanBahngeschwindigkeitenMärklin}
        -> [ vBoxHinzufügenPlanBahngeschwindigkeitenMärklinKonstanteSpannung
           , widgetHinzufügenGeschwindigkeitVariante
                 vBoxHinzufügenPlanBahngeschwindigkeitenMärklin]

instance PlanElement (BGWidgets b 'Lego) where
    foldPlan :: Lens.Fold (BGWidgets b 'Lego) (Maybe (ButtonPlanHinzufügen (BGWidgets b 'Lego)))
    foldPlan = Lens.folding $ map Just . erhalteButtonPlanHinzufügen
        where
            erhalteButtonPlanHinzufügen
                :: BGWidgets b 'Lego -> [ButtonPlanHinzufügen (BGWidgets b 'Lego)]
            erhalteButtonPlanHinzufügen
                BGWidgetsPwmLego {bgplHinzPL = (buttonSpezifisch, buttonAllgemein)} =
                [buttonSpezifisch, widgetHinzufügenGeschwindigkeitVariante buttonAllgemein]
            erhalteButtonPlanHinzufügen
                BGWidgetsKonstanteSpannungLego {bgklHinzPL = (buttonSpezifisch, buttonAllgemein)} =
                [buttonSpezifisch, widgetHinzufügenGeschwindigkeitVariante buttonAllgemein]

    boxenPlan :: (ReaderConstraint (BGWidgets b 'Lego) r)
              => Bahngeschwindigkeit b 'Lego
              -> Lens.Fold r (BoxPlanHinzufügen (BGWidgets b 'Lego))
    boxenPlan LegoBahngeschwindigkeit {} =
        Lens.folding
        $ \BGWidgetsBoxen { vBoxHinzufügenPlanBahngeschwindigkeitenLegoPwm
                          , vBoxHinzufügenPlanBahngeschwindigkeitenLego}
        -> [ vBoxHinzufügenPlanBahngeschwindigkeitenLegoPwm
           , widgetHinzufügenGeschwindigkeitVariante vBoxHinzufügenPlanBahngeschwindigkeitenLego]

instance PlanElement (ZugtypEither (GeschwindigkeitEither BGWidgets)) where
    foldPlan :: Lens.Fold (ZugtypEither (GeschwindigkeitEither BGWidgets)) (Maybe (ButtonPlanHinzufügen (ZugtypEither (GeschwindigkeitEither BGWidgets))))
    foldPlan = Lens.folding $ \bgWidgets -> Just <$> ausZugtypEither buttonList bgWidgets
        where
            buttonList :: (GeschwindigkeitEither BGWidgets) z
                       -> [ButtonPlanHinzufügen (ZugtypEither (GeschwindigkeitEither BGWidgets))]
            buttonList
                (GeschwindigkeitPwm
                     BGWidgetsPwmMärklin {bgpmHinzPL = (buttonSpezifisch, buttonAllgemein)}) =
                widgetHinzufügenZugtypEither
                <$> [widgetHinzufügenGeschwindigkeitEither buttonSpezifisch, buttonAllgemein]
            buttonList
                (GeschwindigkeitPwm
                     BGWidgetsPwmLego {bgplHinzPL = (buttonSpezifisch, buttonAllgemein)}) =
                widgetHinzufügenZugtypEither
                <$> [widgetHinzufügenGeschwindigkeitEither buttonSpezifisch, buttonAllgemein]
            buttonList
                (GeschwindigkeitKonstanteSpannung
                     BGWidgetsKonstanteSpannungMärklin
                     {bgkmHinzPL = (buttonSpezifisch, buttonAllgemein)}) =
                widgetHinzufügenZugtypEither
                <$> [widgetHinzufügenGeschwindigkeitEither buttonSpezifisch, buttonAllgemein]
            buttonList
                (GeschwindigkeitKonstanteSpannung
                     BGWidgetsKonstanteSpannungLego
                     {bgklHinzPL = (buttonSpezifisch, buttonAllgemein)}) =
                widgetHinzufügenZugtypEither
                <$> [widgetHinzufügenGeschwindigkeitEither buttonSpezifisch, buttonAllgemein]

    boxenPlan :: (ReaderConstraint (ZugtypEither (GeschwindigkeitEither BGWidgets)) r)
              => ZugtypEither (GeschwindigkeitEither Bahngeschwindigkeit)
              -> Lens.Fold r (BoxPlanHinzufügen (ZugtypEither (GeschwindigkeitEither BGWidgets)))
    boxenPlan (ZugtypMärklin (GeschwindigkeitPwm _bahngeschwindigkeit)) =
        Lens.folding
        $ \BGWidgetsBoxen
        { vBoxHinzufügenPlanBahngeschwindigkeitenMärklinPwm
        , vBoxHinzufügenPlanBahngeschwindigkeitenMärklin} -> widgetHinzufügenZugtypEither
        <$> [ widgetHinzufügenGeschwindigkeitEither
                  vBoxHinzufügenPlanBahngeschwindigkeitenMärklinPwm
            , vBoxHinzufügenPlanBahngeschwindigkeitenMärklin]
    boxenPlan (ZugtypMärklin (GeschwindigkeitKonstanteSpannung _bahngeschwindigkeit)) =
        Lens.folding
        $ \BGWidgetsBoxen
        { vBoxHinzufügenPlanBahngeschwindigkeitenMärklinKonstanteSpannung
        , vBoxHinzufügenPlanBahngeschwindigkeitenMärklin} -> widgetHinzufügenZugtypEither
        <$> [ widgetHinzufügenGeschwindigkeitEither
                  vBoxHinzufügenPlanBahngeschwindigkeitenMärklinKonstanteSpannung
            , vBoxHinzufügenPlanBahngeschwindigkeitenMärklin]
    boxenPlan (ZugtypLego (GeschwindigkeitPwm _bahngeschwindigkeit)) =
        Lens.folding
        $ \BGWidgetsBoxen
        { vBoxHinzufügenPlanBahngeschwindigkeitenLegoPwm
        , vBoxHinzufügenPlanBahngeschwindigkeitenLego} -> widgetHinzufügenZugtypEither
        <$> [ widgetHinzufügenGeschwindigkeitEither
                  vBoxHinzufügenPlanBahngeschwindigkeitenLegoPwm
            , vBoxHinzufügenPlanBahngeschwindigkeitenLego]
    boxenPlan (ZugtypLego (GeschwindigkeitKonstanteSpannung _bahngeschwindigkeit)) =
        Lens.folding
        $ \BGWidgetsBoxen
        { vBoxHinzufügenPlanBahngeschwindigkeitenLegoKonstanteSpannung
        , vBoxHinzufügenPlanBahngeschwindigkeitenLego} -> widgetHinzufügenZugtypEither
        <$> [ widgetHinzufügenGeschwindigkeitEither
                  vBoxHinzufügenPlanBahngeschwindigkeitenLegoKonstanteSpannung
            , vBoxHinzufügenPlanBahngeschwindigkeitenLego]

instance StreckenObjekt (BGWidgets g z) where
    anschlüsse :: BGWidgets g z -> Set Anschluss
    anschlüsse BGWidgetsPwmMärklin {bgpm} = anschlüsse bgpm
    anschlüsse BGWidgetsKonstanteSpannungMärklin {bgkm} = anschlüsse bgkm
    anschlüsse BGWidgetsPwmLego {bgpl} = anschlüsse bgpl
    anschlüsse BGWidgetsKonstanteSpannungLego {bgkl} = anschlüsse bgkl

    erhalteName :: BGWidgets g z -> Text
    erhalteName BGWidgetsPwmMärklin {bgpm} = erhalteName bgpm
    erhalteName BGWidgetsKonstanteSpannungMärklin {bgkm} = erhalteName bgkm
    erhalteName BGWidgetsPwmLego {bgpl} = erhalteName bgpl
    erhalteName BGWidgetsKonstanteSpannungLego {bgkl} = erhalteName bgkl

instance (ZugtypKlasse z) => ObjektElement (BGWidgets g z) where
    zuObjekt :: BGWidgets g z -> Objekt
    zuObjekt BGWidgetsPwmMärklin {bgpm} = zuObjekt bgpm
    zuObjekt BGWidgetsKonstanteSpannungMärklin {bgkm} = zuObjekt bgkm
    zuObjekt BGWidgetsPwmLego {bgpl} = zuObjekt bgpl
    zuObjekt BGWidgetsKonstanteSpannungLego {bgkl} = zuObjekt bgkl

instance Aeson.ToJSON (BGWidgets g z) where
    toJSON :: BGWidgets g z -> Aeson.Value
    toJSON BGWidgetsPwmMärklin {bgpm} = Aeson.toJSON bgpm
    toJSON BGWidgetsKonstanteSpannungMärklin {bgkm} = Aeson.toJSON bgkm
    toJSON BGWidgetsPwmLego {bgpl} = Aeson.toJSON bgpl
    toJSON BGWidgetsKonstanteSpannungLego {bgkl} = Aeson.toJSON bgkl

instance BahngeschwindigkeitKlasse BGWidgets where
    geschwindigkeit
        :: (I2CReader r m, PwmReader r m, MonadIO m) => BGWidgets 'Pwm z -> Word8 -> m ()
    geschwindigkeit BGWidgetsPwmMärklin {bgpm, bgpmScaleGeschwindigkeit, bgpmTVarEvent} wert = do
        eventAusführen bgpmTVarEvent $ geschwindigkeit bgpm wert
        liftIO
            $ ohneEvent bgpmTVarEvent
            $ Gtk.set bgpmScaleGeschwindigkeit [Gtk.rangeValue := fromIntegral wert]
    geschwindigkeit BGWidgetsPwmLego {bgpl, bgplScaleGeschwindigkeit, bgplTVarEvent} wert = do
        eventAusführen bgplTVarEvent $ geschwindigkeit bgpl wert
        liftIO
            $ ohneEvent bgplTVarEvent
            $ Gtk.set bgplScaleGeschwindigkeit [Gtk.rangeValue := fromIntegral wert]

    fahrstrom :: (I2CReader r m, MonadIO m) => BGWidgets 'KonstanteSpannung z -> Word8 -> m ()
    fahrstrom BGWidgetsKonstanteSpannungMärklin {bgkm, bgkmAuswahlFahrstrom, bgkmTVarEvent} wert =
        do
            eventAusführen bgkmTVarEvent $ fahrstrom bgkm wert
            liftIO $ ohneEvent bgkmTVarEvent $ setzeAuswahl bgkmAuswahlFahrstrom wert
    fahrstrom BGWidgetsKonstanteSpannungLego {bgkl, bgklAuswahlFahrstrom, bgklTVarEvent} wert = do
        eventAusführen bgklTVarEvent $ fahrstrom bgkl wert
        liftIO $ ohneEvent bgklTVarEvent $ setzeAuswahl bgklAuswahlFahrstrom wert

    umdrehen :: (I2CReader r m, PwmReader r m, MonadIO m) => BGWidgets b 'Märklin -> m ()
    umdrehen
        BGWidgetsPwmMärklin {bgpm, bgpmTVarEvent} = eventAusführen bgpmTVarEvent $ umdrehen bgpm
    umdrehen BGWidgetsKonstanteSpannungMärklin {bgkm, bgkmTVarEvent} =
        eventAusführen bgkmTVarEvent $ umdrehen bgkm

    fahrtrichtungEinstellen
        :: (I2CReader r m, PwmReader r m, MonadIO m) => BGWidgets b 'Lego -> Fahrtrichtung -> m ()
    fahrtrichtungEinstellen BGWidgetsPwmLego {bgpl, bgplAuswahlFahrtrichtung, bgplTVarEvent} wert =
        do
            eventAusführen bgplTVarEvent $ fahrtrichtungEinstellen bgpl wert
            liftIO $ ohneEvent bgplTVarEvent $ setzeAuswahl bgplAuswahlFahrtrichtung wert
    fahrtrichtungEinstellen
        BGWidgetsKonstanteSpannungLego {bgkl, bgklAuswahlFahrtrichtung, bgklTVarEvent}
        wert = do
        eventAusführen bgklTVarEvent $ fahrtrichtungEinstellen bgkl wert
        liftIO $ ohneEvent bgklTVarEvent $ setzeAuswahl bgklAuswahlFahrtrichtung wert

-- | 'Bahngeschwindigkeit' darstellen und zum Status hinzufügen
bahngeschwindigkeitPackNew
    :: ( WidgetsTypReader r (BGWidgets g z) m
       , MonadIO m
       , ZugtypKlasse z
       , GeschwindigkeitEitherKlasse g
       , WegstreckenElement (BGWidgets g z)
       , PlanElement (BGWidgets g z)
       )
    => Bahngeschwindigkeit g z
    -> MStatusAllgemeinT o m (BGWidgets g z)
bahngeschwindigkeitPackNew bahngeschwindigkeit = do
    BGWidgetsBoxen {vBoxBahngeschwindigkeiten} <- asks bgWidgetsBoxen
    (tvarSprache, tvarEvent) <- liftIO $ do
        tvarSprache <- newTVarIO $ Just []
        tvarEvent <- newTVarIO EventAusführen
        pure (tvarSprache, tvarEvent)
    let justTVarSprache = Just tvarSprache
    -- Widget erstellen
    vBox <- liftIO $ boxPackWidgetNewDefault vBoxBahngeschwindigkeiten $ Gtk.vBoxNew False 0
    namePackNew vBox bahngeschwindigkeit
    (expanderAnschlüsse, vBoxAnschlüsse) <- liftIO $ do
        expanderAnschlüsse <- boxPackWidgetNew vBox PackGrow paddingDefault positionDefault
            $ Gtk.expanderNew Text.empty
        vBoxAnschlüsse <- containerAddWidgetNew expanderAnschlüsse
            $ scrollbaresWidgetNew
            $ Gtk.vBoxNew False 0
        pure (expanderAnschlüsse, vBoxAnschlüsse)
    verwendeSpracheGui justTVarSprache $ \sprache
        -> Gtk.set expanderAnschlüsse [Gtk.expanderLabel := Language.anschlüsse sprache]
    bgWidgets <- geschwindigkeitsWidgetsPackNew
        vBox
        bahngeschwindigkeit
        vBoxAnschlüsse
        tvarSprache
        tvarEvent
    fließendPackNew vBoxAnschlüsse bahngeschwindigkeit justTVarSprache
    buttonEntfernenPackNew bgWidgets
        $ entfernenBahngeschwindigkeit
        $ zuZugtypEither
        $ zuGeschwindigkeitEither bgWidgets
    -- Widgets merken
    ausführenBefehl
        $ Hinzufügen
        $ OBahngeschwindigkeit
        $ zuZugtypEither
        $ zuGeschwindigkeitEither bgWidgets
    pure bgWidgets
    where
        hinzufügenWidgetsPackNew
            :: ( WidgetsTypReader r (BGWidgets g z) m
               , MonadIO m
               , WegstreckenElement (BGWidgets g z)
               , PlanElement (BGWidgets g z)
               , ZugtypKlasse z
               )
            => Bahngeschwindigkeit g z
            -> TVar (Maybe [Sprache -> IO ()])
            -> m ( CheckButtonWegstreckeHinzufügen Void (BGWidgets g z)
                 , ButtonPlanHinzufügen (BGWidgets g z)
                 , ButtonPlanHinzufügen (GeschwindigkeitEither BGWidgets z)
                 )
        hinzufügenWidgetsPackNew bahngeschwindigkeit tvarSprache = do
            dynamischeWidgets <- erhalteDynamischeWidgets
            hinzufügenWidgetWegstrecke
                <- hinzufügenWidgetWegstreckePackNew bahngeschwindigkeit tvarSprache
            hinzufügenWidgetPlanSpezifisch <- hinzufügenWidgetPlanPackNew
                (fromJust $ Lens.firstOf (boxenPlan bahngeschwindigkeit) dynamischeWidgets)
                bahngeschwindigkeit
                tvarSprache
            hinzufügenWidgetPlanAllgemein <- widgetHinzufügenGeschwindigkeitEither
                <$> hinzufügenWidgetPlanPackNew
                    (fromJust $ Lens.lastOf (boxenPlan bahngeschwindigkeit) dynamischeWidgets)
                    bahngeschwindigkeit
                    tvarSprache
            pure
                ( hinzufügenWidgetWegstrecke
                , hinzufügenWidgetPlanSpezifisch
                , hinzufügenWidgetPlanAllgemein
                )

        geschwindigkeitsWidgetsPackNew
            :: (WidgetsTypReader r (BGWidgets g z) m, MonadIO m)
            => Gtk.VBox
            -> Bahngeschwindigkeit g z
            -> ScrollbaresWidget Gtk.VBox
            -> TVar (Maybe [Sprache -> IO ()])
            -> TVar EventAusführen
            -> m (BGWidgets g z)
        geschwindigkeitsWidgetsPackNew
            box
            bahngeschwindigkeit@MärklinBahngeschwindigkeitPwm {bgmpGeschwindigkeitsPin}
            vBoxAnschlüsse
            bgpmTVarSprache
            bgpmTVarEvent = do
            boxPackWidgetNewDefault vBoxAnschlüsse
                $ pinNew (Just bgpmTVarSprache) Language.geschwindigkeit bgmpGeschwindigkeitsPin
            bgpmFunctionBox <- liftIO $ boxPackWidgetNewDefault box $ Gtk.hBoxNew False 0
            bgpmScaleGeschwindigkeit
                <- hScaleGeschwindigkeitPackNew bgpmFunctionBox bahngeschwindigkeit bgpmTVarEvent
            buttonUmdrehenPackNew bgpmFunctionBox bahngeschwindigkeit bgpmTVarSprache bgpmTVarEvent
            -- Zum Hinzufügen-Dialog von Wegstrecke/Plan hinzufügen
            (bgpmHinzWS, hinzufügenWidgetPlanSpezifisch, hinzufügenWidgetPlanAllgemein)
                <- hinzufügenWidgetsPackNew bahngeschwindigkeit bgpmTVarSprache
            pure
                BGWidgetsPwmMärklin
                { bgpm = bahngeschwindigkeit
                , bgpmWidget = box
                , bgpmFunctionBox
                , bgpmHinzWS
                , bgpmHinzPL = (hinzufügenWidgetPlanSpezifisch, hinzufügenWidgetPlanAllgemein)
                , bgpmTVarSprache
                , bgpmTVarEvent
                , bgpmScaleGeschwindigkeit
                }
        geschwindigkeitsWidgetsPackNew
            box
            bahngeschwindigkeit@MärklinBahngeschwindigkeitKonstanteSpannung
            {bgmkFahrstromAnschlüsse, bgmkUmdrehenAnschluss}
            vBoxAnschlüsse
            bgkmTVarSprache
            bgkmTVarEvent = do
            let justTVarSprache = Just bgkmTVarSprache
            let erstelleFahrstromAnschlussWidget
                    :: (MonadIO m, SpracheGuiReader r m) => Natural -> Anschluss -> m Natural
                erstelleFahrstromAnschlussWidget i anschluss = do
                    boxPackWidgetNewDefault vBoxAnschlüsse
                        $ anschlussNew justTVarSprache (Language.fahrstrom <> anzeige i) anschluss
                    pure $ succ i
            foldM_ erstelleFahrstromAnschlussWidget 1 bgmkFahrstromAnschlüsse
            bgkmFunctionBox <- liftIO $ boxPackWidgetNewDefault box $ Gtk.hBoxNew False 0
            bgkmAuswahlFahrstrom <- auswahlFahrstromPackNew
                bgkmFunctionBox
                bahngeschwindigkeit
                (fromIntegral $ length bgmkFahrstromAnschlüsse)
                bgkmTVarSprache
                bgkmTVarEvent
            boxPackWidgetNewDefault vBoxAnschlüsse
                $ anschlussNew justTVarSprache Language.umdrehen bgmkUmdrehenAnschluss
            buttonUmdrehenPackNew bgkmFunctionBox bahngeschwindigkeit bgkmTVarSprache bgkmTVarEvent
            -- Zum Hinzufügen-Dialog von Wegstrecke/Plan hinzufügen
            (bgkmHinzWS, hinzufügenWidgetPlanSpezifisch, hinzufügenWidgetPlanAllgemein)
                <- hinzufügenWidgetsPackNew bahngeschwindigkeit bgkmTVarSprache
            pure
                BGWidgetsKonstanteSpannungMärklin
                { bgkm = bahngeschwindigkeit
                , bgkmWidget = box
                , bgkmFunctionBox
                , bgkmHinzWS
                , bgkmHinzPL = (hinzufügenWidgetPlanSpezifisch, hinzufügenWidgetPlanAllgemein)
                , bgkmTVarSprache
                , bgkmTVarEvent
                , bgkmAuswahlFahrstrom
                }
        geschwindigkeitsWidgetsPackNew
            box
            bahngeschwindigkeit@LegoBahngeschwindigkeit
            {bglGeschwindigkeitsPin, bglFahrtrichtungsAnschluss}
            vBoxAnschlüsse
            bgplTVarSprache
            bgplTVarEvent = do
            let justTVarSprache = Just bgplTVarSprache
            boxPackWidgetNewDefault vBoxAnschlüsse
                $ pinNew justTVarSprache Language.geschwindigkeit bglGeschwindigkeitsPin
            bgplFunctionBox <- liftIO $ boxPackWidgetNewDefault box $ Gtk.hBoxNew False 0
            bgplScaleGeschwindigkeit
                <- hScaleGeschwindigkeitPackNew bgplFunctionBox bahngeschwindigkeit bgplTVarEvent
            boxPackWidgetNewDefault vBoxAnschlüsse
                $ anschlussNew justTVarSprache Language.fahrtrichtung bglFahrtrichtungsAnschluss
            bgplAuswahlFahrtrichtung <- auswahlFahrtrichtungEinstellenPackNew
                bgplFunctionBox
                bahngeschwindigkeit
                bgplTVarSprache
                bgplTVarEvent
            -- Zum Hinzufügen-Dialog von Wegstrecke/Plan hinzufügen
            (bgplHinzWS, hinzufügenWidgetPlanSpezifisch, hinzufügenWidgetPlanAllgemein)
                <- hinzufügenWidgetsPackNew bahngeschwindigkeit bgplTVarSprache
            pure
                BGWidgetsPwmLego
                { bgpl = bahngeschwindigkeit
                , bgplWidget = box
                , bgplFunctionBox
                , bgplHinzWS
                , bgplHinzPL = (hinzufügenWidgetPlanSpezifisch, hinzufügenWidgetPlanAllgemein)
                , bgplTVarSprache
                , bgplTVarEvent
                , bgplScaleGeschwindigkeit
                , bgplAuswahlFahrtrichtung
                }

-- | Hilfsklasse um Widgets zu synchronisieren.
class ( WidgetsTyp (bg 'Pwm 'Märklin)
      , WidgetsTyp (bg 'KonstanteSpannung 'Märklin)
      , WidgetsTyp (bg 'Pwm 'Lego)
      , WidgetsTyp (bg 'KonstanteSpannung 'Lego)
      , BahngeschwindigkeitKlasse bg
      ) => BGWidgetsKlasse bg where
    scaleGeschwindigkeit :: bg 'Pwm z -> Maybe Gtk.HScale
    auswahlFahrstrom :: bg 'KonstanteSpannung z -> Maybe (AuswahlWidget Word8)
    auswahlFahrtrichtung :: bg g 'Lego -> Maybe (AuswahlWidget Fahrtrichtung)

-- | Füge 'Scale' zum einstellen der Geschwindigkeit zur Box hinzu
hScaleGeschwindigkeitPackNew
    :: forall b bg o r m z.
    ( MitBox b
    , BahngeschwindigkeitKlasse bg
    , BGWidgetsKlasse bg
    , WidgetsTypReader r (bg 'Pwm z) m
    , StatusVarReader r o m
    , BGWidgetsKlasse (BG o)
    , BGWidgetsKlasse (WS o)
    , STWidgetsKlasse (WS o)
    , MonadIO m
    , ZugtypKlasse z
    )
    => b
    -> bg 'Pwm z
    -> TVar EventAusführen
    -> m Gtk.HScale
hScaleGeschwindigkeitPackNew box bahngeschwindigkeit tvarEventAusführen = do
    statusVar <- erhalteStatusVar :: m (StatusVar o)
    objektReader <- ask
    liftIO $ do
        scale <- boxPackWidgetNew box PackGrow paddingDefault positionDefault
            $ widgetShowNew
            $ Gtk.hScaleNewWithRange 0 (fromIntegral (maxBound :: Word8)) 1
        Gtk.widgetSetSizeRequest scale 100 (-1)
        Gtk.on scale Gtk.valueChanged $ eventAusführen tvarEventAusführen $ do
            wert <- floor <$> Gtk.get scale Gtk.rangeValue
            flip runReaderT objektReader $ flip auswertenStatusVarMStatusT statusVar $ do
                ausführenAktion $ Geschwindigkeit bahngeschwindigkeit wert
                -- Widgets synchronisieren
                bahngeschwindigkeiten <- getBahngeschwindigkeiten
                liftIO $ forM_ bahngeschwindigkeiten $ flip bgWidgetsSynchronisieren wert
                wegstrecken <- getWegstrecken
                liftIO $ forM_ wegstrecken $ flip wsWidgetsSynchronisieren wert
        pure scale
    where
        bgWidgetsSynchronisieren
            :: ZugtypEither (GeschwindigkeitEither BGWidgets) -> Word8 -> IO ()
        bgWidgetsSynchronisieren
            (ZugtypMärklin
                 (GeschwindigkeitPwm
                      BGWidgetsPwmMärklin {bgpm, bgpmTVarEvent, bgpmScaleGeschwindigkeit}))
            wert
            | elem (ZugtypMärklin $ GeschwindigkeitPwm bgpm)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgpmTVarEvent
                $ Gtk.set bgpmScaleGeschwindigkeit [Gtk.rangeValue := fromIntegral wert]
        bgWidgetsSynchronisieren
            (ZugtypLego
                 (GeschwindigkeitPwm
                      BGWidgetsPwmLego {bgpl, bgplTVarEvent, bgplScaleGeschwindigkeit}))
            wert
            | elem (ZugtypLego $ GeschwindigkeitPwm bgpl)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgplTVarEvent
                $ Gtk.set bgplScaleGeschwindigkeit [Gtk.rangeValue := fromIntegral wert]
        bgWidgetsSynchronisieren _bgWidgets _wert = pure ()

        wsWidgetsSynchronisieren :: ZugtypEither WSWidgets -> Word8 -> IO ()
        wsWidgetsSynchronisieren
            (ZugtypMärklin
                 WSWidgets { ws = Wegstrecke {wsBahngeschwindigkeiten}
                           , wsTVarEvent
                           , wsScaleGeschwindigkeit = Just scaleGeschwindigkeit})
            wert
            | Set.isSubsetOf (Set.map zuZugtypEither wsBahngeschwindigkeiten)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent wsTVarEvent
                $ Gtk.set scaleGeschwindigkeit [Gtk.rangeValue := fromIntegral wert]
        wsWidgetsSynchronisieren
            (ZugtypLego
                 WSWidgets { ws = Wegstrecke {wsBahngeschwindigkeiten}
                           , wsTVarEvent
                           , wsScaleGeschwindigkeit = Just scaleGeschwindigkeit})
            wert
            | Set.isSubsetOf (Set.map zuZugtypEither wsBahngeschwindigkeiten)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent wsTVarEvent
                $ Gtk.set scaleGeschwindigkeit [Gtk.rangeValue := fromIntegral wert]
        wsWidgetsSynchronisieren _wsWidget _wert = pure ()

-- | Füge 'AuswahlWidget' zum einstellen des Fahrstroms zur Box hinzu
auswahlFahrstromPackNew
    :: forall b bg m z.
    ( MitBox b
    , BahngeschwindigkeitKlasse bg
    , BGWidgetsKlasse bg
    , ObjektGuiReader m
    , MonadIO m
    , ZugtypKlasse z
    )
    => b
    -> bg 'KonstanteSpannung z
    -> Word8
    -> TVar (Maybe [Sprache -> IO ()])
    -> TVar EventAusführen
    -> m (AuswahlWidget Word8)
auswahlFahrstromPackNew box bahngeschwindigkeit maxWert tvarSprachwechsel tvarEventAusführen = do
    statusVar <- erhalteStatusVar :: m StatusVarGui
    objektReader <- ask
    auswahlWidget <- boxPackWidgetNewDefault box
        $ widgetShowNew
        $ (if maxWert < 5
               then auswahlRadioButtonNew
               else auswahlComboBoxNew)
            (NonEmpty.fromList $ [maxWert, pred maxWert .. 0])
            (Just tvarSprachwechsel)
            Language.fahrstrom
    setzeAuswahl auswahlWidget 0
    beiAuswahl auswahlWidget $ \wert -> eventAusführen tvarEventAusführen
        $ flip runReaderT objektReader
        $ flip auswertenStatusVarMStatusT statusVar
        $ do
            ausführenAktion $ Fahrstrom bahngeschwindigkeit wert
            -- Widgets synchronisieren
            bahngeschwindigkeiten <- getBahngeschwindigkeiten
            liftIO $ forM_ bahngeschwindigkeiten $ flip bgWidgetsSynchronisieren wert
            wegstrecken <- getWegstrecken
            liftIO $ forM_ wegstrecken $ flip wsWidgetsSynchronisieren wert
    pure auswahlWidget
    where
        bgWidgetsSynchronisieren
            :: ZugtypEither (GeschwindigkeitEither BGWidgets) -> Word8 -> IO ()
        bgWidgetsSynchronisieren
            (ZugtypMärklin
                 (GeschwindigkeitKonstanteSpannung
                      BGWidgetsKonstanteSpannungMärklin
                      {bgkm, bgkmTVarEvent, bgkmAuswahlFahrstrom}))
            wert
            | elem (ZugtypMärklin $ GeschwindigkeitKonstanteSpannung bgkm)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgkmTVarEvent $ setzeAuswahl bgkmAuswahlFahrstrom wert
        bgWidgetsSynchronisieren
            (ZugtypLego
                 (GeschwindigkeitKonstanteSpannung
                      BGWidgetsKonstanteSpannungLego {bgkl, bgklTVarEvent, bgklAuswahlFahrstrom}))
            wert
            | elem (ZugtypLego $ GeschwindigkeitKonstanteSpannung bgkl)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgklTVarEvent $ setzeAuswahl bgklAuswahlFahrstrom wert
        bgWidgetsSynchronisieren _bgWidgets _wert = pure ()

        wsWidgetsSynchronisieren :: ZugtypEither WSWidgets -> Word8 -> IO ()
        wsWidgetsSynchronisieren
            (ZugtypMärklin
                 WSWidgets { ws = Wegstrecke {wsBahngeschwindigkeiten}
                           , wsTVarEvent
                           , wsAuswahlFahrstrom = Just auswahlFahrstrom})
            wert
            | Set.isSubsetOf (Set.map zuZugtypEither wsBahngeschwindigkeiten)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent wsTVarEvent $ setzeAuswahl auswahlFahrstrom wert
        wsWidgetsSynchronisieren
            (ZugtypLego
                 WSWidgets { ws = Wegstrecke {wsBahngeschwindigkeiten}
                           , wsTVarEvent
                           , wsAuswahlFahrstrom = Just auswahlFahrstrom})
            wert
            | Set.isSubsetOf (Set.map zuZugtypEither wsBahngeschwindigkeiten)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent wsTVarEvent $ setzeAuswahl auswahlFahrstrom wert
        wsWidgetsSynchronisieren _wsWidget _wert = pure ()

-- | Füge 'Gtk.Button' zum 'umdrehen' zur Box hinzu.
--
-- Mit der übergebenen 'TVar' kann das Anpassen der Label aus 'Zug.UI.Gtk.SpracheGui.sprachwechsel' gelöscht werden.
-- Dazu muss deren Inhalt auf 'Nothing' gesetzt werden.
buttonUmdrehenPackNew
    :: forall b bg g m.
    ( MitBox b
    , BahngeschwindigkeitKlasse bg
    , BGWidgetsKlasse bg
    , STWidgetsKlasse (bg g 'Märklin)
    , ObjektGuiReader m
    , MonadIO m
    , GeschwindigkeitEitherKlasse g
    )
    => b
    -> bg g 'Märklin
    -> TVar (Maybe [Sprache -> IO ()])
    -> TVar EventAusführen
    -> m Gtk.Button
buttonUmdrehenPackNew box bahngeschwindigkeit tvarSprachwechsel tvarEventAusführen = do
    statusVar <- erhalteStatusVar :: m StatusVarGui
    objektReader <- ask
    boxPackWidgetNewDefault box
        $ buttonNewWithEventLabel (Just tvarSprachwechsel) Language.umdrehen
        $ eventAusführen tvarEventAusführen
        $ flip runReaderT objektReader
        $ flip auswertenStatusVarMStatusT statusVar
        $ do
            ausführenAktion $ Umdrehen bahngeschwindigkeit
            -- Widgets synchronisieren
            bahngeschwindigkeiten <- getBahngeschwindigkeiten
            liftIO $ forM_ bahngeschwindigkeiten $ bgWidgetsSynchronisieren
            streckenabschnitte <- getStreckenabschnitte
            liftIO $ forM_ streckenabschnitte $ stWidgetsSynchronisieren
            wegstrecken <- getWegstrecken
            liftIO $ forM_ wegstrecken $ wsWidgetsSynchronisieren
    where
        bgWidgetsSynchronisieren :: ZugtypEither (GeschwindigkeitEither BGWidgets) -> IO ()
        bgWidgetsSynchronisieren
            (ZugtypMärklin
                 (GeschwindigkeitPwm
                      BGWidgetsPwmMärklin {bgpm, bgpmTVarEvent, bgpmScaleGeschwindigkeit}))
            | elem (ZugtypMärklin $ GeschwindigkeitPwm bgpm)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgpmTVarEvent $ Gtk.set bgpmScaleGeschwindigkeit [Gtk.rangeValue := 0]
        bgWidgetsSynchronisieren
            (ZugtypMärklin
                 (GeschwindigkeitKonstanteSpannung
                      BGWidgetsKonstanteSpannungMärklin
                      {bgkm, bgkmTVarEvent, bgkmAuswahlFahrstrom}))
            | elem (ZugtypMärklin $ GeschwindigkeitKonstanteSpannung bgkm)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgkmTVarEvent $ setzeAuswahl bgkmAuswahlFahrstrom 0
        bgWidgetsSynchronisieren
            (ZugtypLego
                 (GeschwindigkeitPwm
                      BGWidgetsPwmLego {bgpl, bgplTVarEvent, bgplScaleGeschwindigkeit}))
            | elem (ZugtypLego $ GeschwindigkeitPwm bgpl)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgplTVarEvent $ Gtk.set bgplScaleGeschwindigkeit [Gtk.rangeValue := 0]
        bgWidgetsSynchronisieren
            (ZugtypLego
                 (GeschwindigkeitKonstanteSpannung
                      BGWidgetsKonstanteSpannungLego {bgkl, bgklTVarEvent, bgklAuswahlFahrstrom}))
            | elem (ZugtypLego $ GeschwindigkeitKonstanteSpannung bgkl)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgklTVarEvent $ setzeAuswahl bgklAuswahlFahrstrom 0
        bgWidgetsSynchronisieren _bgWidgets = pure ()

        stWidgetsSynchronisieren :: STWidgets -> IO ()
        stWidgetsSynchronisieren STWidgets {st, stTVarEvent, stTogglebuttonStrom}
            | elem st $ enthalteneStreckenabschnitte bahngeschwindigkeit =
                ohneEvent stTVarEvent
                $ Gtk.set stTogglebuttonStrom [Gtk.toggleButtonActive := True]
        stWidgetsSynchronisieren _stWidgets = pure ()

        wsWidgetsSynchronisieren :: ZugtypEither WSWidgets -> IO ()
        wsWidgetsSynchronisieren (ZugtypMärklin wsWidgets) = wsWidgetsSynchronisierenAux wsWidgets
        wsWidgetsSynchronisieren (ZugtypLego wsWidgets) = wsWidgetsSynchronisierenAux wsWidgets

        wsWidgetsSynchronisierenAux :: (ZugtypKlasse z) => WSWidgets z -> IO ()
        wsWidgetsSynchronisierenAux
            WSWidgets { ws = Wegstrecke {wsBahngeschwindigkeiten, wsStreckenabschnitte}
                      , wsTVarEvent
                      , wsToggleButtonStrom
                      , wsScaleGeschwindigkeit
                      , wsAuswahlFahrstrom} = do
            case wsToggleButtonStrom of
                (Just toggleButtonStrom)
                    | Set.isSubsetOf wsStreckenabschnitte
                        $ enthalteneStreckenabschnitte bahngeschwindigkeit -> ohneEvent wsTVarEvent
                        $ Gtk.set toggleButtonStrom [Gtk.toggleButtonActive := True]
                _otherwise -> pure ()
            let istBahngeschwindigkeitTeilmenge =
                    Set.isSubsetOf (Set.map zuZugtypEither wsBahngeschwindigkeiten)
                    $ Set.map zuZugtypEither
                    $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit
            case wsScaleGeschwindigkeit of
                (Just scaleGeschwindigkeit)
                    | istBahngeschwindigkeitTeilmenge -> ohneEvent wsTVarEvent
                        $ Gtk.set scaleGeschwindigkeit [Gtk.rangeValue := 0]
                _otherwise -> pure ()
            case wsAuswahlFahrstrom of
                (Just auswahlFahrstrom)
                    | istBahngeschwindigkeitTeilmenge
                        -> ohneEvent wsTVarEvent $ setzeAuswahl auswahlFahrstrom 0
                _otherwise -> pure ()

-- | Füge 'AuswahlWidget' zum Fahrtrichtung einstellen zur Box hinzu.
--
-- Mit der übergebenen 'TVar' kann das Anpassen der Label aus 'Zug.UI.Gtk.SpracheGui.sprachwechsel' gelöscht werden.
-- Dazu muss deren Inhalt auf 'Nothing' gesetzt werden.
auswahlFahrtrichtungEinstellenPackNew
    :: forall b bg g m.
    ( MitBox b
    , BahngeschwindigkeitKlasse bg
    , BGWidgetsKlasse bg
    , ObjektGuiReader m
    , MonadIO m
    , GeschwindigkeitEitherKlasse g
    )
    => b
    -> bg g 'Lego
    -> TVar (Maybe [Sprache -> IO ()])
    -> TVar EventAusführen
    -> m (AuswahlWidget Fahrtrichtung)
auswahlFahrtrichtungEinstellenPackNew box bahngeschwindigkeit tvarSprachwechsel tvarEventAusführen =
    do
        statusVar <- erhalteStatusVar :: m StatusVarGui
        objektReader <- ask
        auswahlFahrtrichtung <- boxPackWidgetNewDefault box
            $ boundedEnumAuswahlRadioButtonNew
                Vorwärts
                (Just tvarSprachwechsel)
                Language.fahrtrichtung
        beiAuswahl auswahlFahrtrichtung $ \fahrtrichtung -> eventAusführen tvarEventAusführen
            $ flip runReaderT objektReader
            $ flip auswertenStatusVarMStatusT statusVar
            $ do
                ausführenAktion $ FahrtrichtungEinstellen bahngeschwindigkeit fahrtrichtung
                -- Widgets synchronisieren
                bahngeschwindigkeiten <- getBahngeschwindigkeiten
                liftIO $ forM_ bahngeschwindigkeiten $ flip bgWidgetsSynchronisieren fahrtrichtung
                wegstrecken <- getWegstrecken
                liftIO $ forM_ wegstrecken $ flip wsWidgetsSynchronisieren fahrtrichtung
        pure auswahlFahrtrichtung
    where
        bgWidgetsSynchronisieren
            :: ZugtypEither (GeschwindigkeitEither BGWidgets) -> Fahrtrichtung -> IO ()
        bgWidgetsSynchronisieren
            (ZugtypLego
                 (GeschwindigkeitPwm
                      BGWidgetsPwmLego
                      {bgpl, bgplTVarEvent, bgplScaleGeschwindigkeit, bgplAuswahlFahrtrichtung}))
            fahrtrichtung
            | elem (ZugtypLego $ GeschwindigkeitPwm bgpl)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgplTVarEvent $ do
                    Gtk.set bgplScaleGeschwindigkeit [Gtk.rangeValue := 0]
                    setzeAuswahl bgplAuswahlFahrtrichtung fahrtrichtung
        bgWidgetsSynchronisieren
            (ZugtypLego
                 (GeschwindigkeitKonstanteSpannung
                      BGWidgetsKonstanteSpannungLego
                      {bgkl, bgklTVarEvent, bgklAuswahlFahrstrom, bgklAuswahlFahrtrichtung}))
            fahrtrichtung
            | elem (ZugtypLego $ GeschwindigkeitKonstanteSpannung bgkl)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent bgklTVarEvent $ do
                    setzeAuswahl bgklAuswahlFahrstrom 0
                    setzeAuswahl bgklAuswahlFahrtrichtung fahrtrichtung
        bgWidgetsSynchronisieren _bgWidgets _wert = pure ()

        wsWidgetsSynchronisieren :: ZugtypEither WSWidgets -> Fahrtrichtung -> IO ()
        wsWidgetsSynchronisieren
            (ZugtypLego
                 WSWidgets { ws = Wegstrecke {wsBahngeschwindigkeiten}
                           , wsTVarEvent
                           , wsScaleGeschwindigkeit
                           , wsAuswahlFahrstrom
                           , wsAuswahlFahrtrichtung})
            fahrtrichtung
            | Set.isSubsetOf (Set.map zuZugtypEither wsBahngeschwindigkeiten)
                $ Set.map zuZugtypEither
                $ enthalteneBahngeschwindigkeiten bahngeschwindigkeit =
                ohneEvent wsTVarEvent $ do
                    case wsScaleGeschwindigkeit of
                        (Just scaleGeschwindigkeit)
                            -> Gtk.set scaleGeschwindigkeit [Gtk.rangeValue := 0]
                        Nothing -> pure ()
                    case wsAuswahlFahrstrom of
                        (Just auswahlFahrstrom) -> setzeAuswahl auswahlFahrstrom 0
                        Nothing -> pure ()
                    case wsAuswahlFahrtrichtung of
                        (Just auswahlFahrtrichtung)
                            -> setzeAuswahl auswahlFahrtrichtung fahrtrichtung
                        Nothing -> pure ()
        wsWidgetsSynchronisieren _wsWidget _wert = pure ()