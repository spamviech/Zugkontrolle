{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}

{-|
Description: Spezielle Widgets, die für den AssistantHinzufügen benötigt werden.
-}
module Zug.UI.Gtk.StreckenObjekt.WidgetHinzufuegen
  ( -- * Datentyp und Typ-Klassen
    WidgetHinzufügen()
  , Kategorie(..)
  , KategorieText(..)
  , HinzufügenZiel(..)
    -- * Wegstrecke Hinzufügen
  , BoxWegstreckeHinzufügen
  , boxWegstreckeHinzufügenNew
  , CheckButtonWegstreckeHinzufügen
  , WegstreckeCheckButton(..)
    -- * Plan Hinzufügen
  , BoxPlanHinzufügen
  , boxPlanHinzufügenNew
  , ButtonPlanHinzufügen
    -- * Hilfsfunktionen
  , widgetHinzufügenContainerRemoveJust
  , widgetHinzufügenBoxPackNew
  , widgetHinzufügenRegistrierterCheckButtonVoid
  , widgetHinzufügenAktuelleAuswahl
  , widgetHinzufügenSetzeAuswahl
  , widgetHinzufügenToggled
  , widgetHinzufügenSetToggled
    -- * Spezielle Typ-Konvertierungen
  , widgetHinzufügenGeschwindigkeitVariante
  , widgetHinzufügenGeschwindigkeitEither
  , widgetHinzufügenZugtypEither
  ) where

import Control.Monad.Trans (MonadIO())
import Data.Kind (Type)
import Data.Text (Text)
import Data.Void (Void)
import qualified GI.Gtk as Gtk

import Zug.Enums (ZugtypEither(), GeschwindigkeitEither(), Richtung())
import Zug.Language (Sprache())
import Zug.UI.Gtk.Auswahl (AuswahlWidget(), MitAuswahlWidget(..), aktuelleAuswahl, setzeAuswahl)
import Zug.UI.Gtk.FortfahrenWennToggled
       (RegistrierterCheckButton, MitRegistrierterCheckButton(..), registrierterCheckButtonToggled
      , registrierterCheckButtonSetToggled)
import Zug.UI.Gtk.Hilfsfunktionen (containerRemoveJust, boxPackWidgetNewDefault, labelSpracheNew)
import Zug.UI.Gtk.Klassen (MitWidget(..), MitContainer(), MitBox())
import Zug.UI.Gtk.ScrollbaresWidget (ScrollbaresWidget, scrollbaresWidgetNew)
import Zug.UI.Gtk.SpracheGui (SpracheGuiReader(), TVarSprachewechselAktionen)

-- | Auswahlmöglichkeiten zu 'WidgetHinzufügen'
data HinzufügenZiel
    = HinzufügenWegstrecke
    | HinzufügenPlan

-- | Widget zum Hinzufügen einer Wegstrecke/eines Plans
newtype WidgetHinzufügen (e :: HinzufügenZiel) (w :: Type) (a :: Type) =
    WidgetHinzufügen { widgetHinzufügen :: w }
    deriving (Eq)

instance (MitWidget w) => MitWidget (WidgetHinzufügen e w a) where
    erhalteWidget :: (MonadIO m) => WidgetHinzufügen e w a -> m Gtk.Widget
    erhalteWidget = erhalteWidget . widgetHinzufügen

instance (MitRegistrierterCheckButton w)
    => MitRegistrierterCheckButton (WidgetHinzufügen e w a) where
    erhalteRegistrierterCheckButton :: WidgetHinzufügen e w a -> RegistrierterCheckButton
    erhalteRegistrierterCheckButton = erhalteRegistrierterCheckButton . widgetHinzufügen

-- | Konvertiere ein 'WidgetHinzufügen' in das zugehörige 'ZugtypEither'-Äquivalent
widgetHinzufügenZugtypEither
    :: WidgetHinzufügen e w (a z) -> WidgetHinzufügen e w (ZugtypEither a)
widgetHinzufügenZugtypEither = WidgetHinzufügen . widgetHinzufügen

-- | Konvertiere ein 'WidgetHinzufügen' in das zugehörige 'GeschwindigkeitEither'-Äquivalent.
widgetHinzufügenGeschwindigkeitEither
    :: WidgetHinzufügen e w (a g z) -> WidgetHinzufügen e w (GeschwindigkeitEither a z)
widgetHinzufügenGeschwindigkeitEither = WidgetHinzufügen . widgetHinzufügen

-- | Konvertiere ein 'WidgetHinzufügen' in eine beliebiges 'GeschwindigkeitVariante'-Äquivalent.
widgetHinzufügenGeschwindigkeitVariante
    :: WidgetHinzufügen e w (GeschwindigkeitEither a z) -> WidgetHinzufügen e w (a g z)
widgetHinzufügenGeschwindigkeitVariante = WidgetHinzufügen . widgetHinzufügen

-- | Konvertiere ein 'WidgetHinzufügen'-'MitRegistrierterCheckButton' in den zugehörigen 'Void'-Typ
widgetHinzufügenRegistrierterCheckButtonVoid
    :: (MitRegistrierterCheckButton r)
    => WidgetHinzufügen e r a
    -> WidgetHinzufügen e RegistrierterCheckButton Void
widgetHinzufügenRegistrierterCheckButtonVoid =
    WidgetHinzufügen . erhalteRegistrierterCheckButton . widgetHinzufügen

-- | Erhalte die aktuelle Auswahl des inkludierten 'MitAuswahlWidget'.
widgetHinzufügenAktuelleAuswahl
    :: (Eq b, MitAuswahlWidget w b, MonadIO m) => WidgetHinzufügen e w a -> m b
widgetHinzufügenAktuelleAuswahl = aktuelleAuswahl . erhalteAuswahlWidget . widgetHinzufügen

-- | Setze die aktuelle Auswahl des inkludierten 'MitAuswahlWidget'.
widgetHinzufügenSetzeAuswahl
    :: (Eq b, MitAuswahlWidget w b, MonadIO m) => WidgetHinzufügen e w a -> b -> m ()
widgetHinzufügenSetzeAuswahl
    WidgetHinzufügen {widgetHinzufügen} = setzeAuswahl $ erhalteAuswahlWidget widgetHinzufügen

-- | Überprüfe ob der inkludierte 'MitRegistrierterCheckButton' aktuell gedrückt ist.
widgetHinzufügenToggled
    :: (MitRegistrierterCheckButton t, MonadIO m) => WidgetHinzufügen e t a -> m Bool
widgetHinzufügenToggled =
    registrierterCheckButtonToggled . erhalteRegistrierterCheckButton . widgetHinzufügen

-- | Bestimme ob der inkludierte 'MitRegistrierterCheckButton' aktuell gedrückt ist.
widgetHinzufügenSetToggled
    :: (MitRegistrierterCheckButton t, MonadIO m) => WidgetHinzufügen e t a -> Bool -> m ()
widgetHinzufügenSetToggled widgetHinzufügen =
    registrierterCheckButtonSetToggled $ erhalteRegistrierterCheckButton widgetHinzufügen

-- | Entferne ein 'WidgetHinzufügen' (falls vorhanden) aus dem zugehörigen Container
widgetHinzufügenContainerRemoveJust
    :: (MitContainer c, MitWidget w, MonadIO m)
    => WidgetHinzufügen e c a
    -> Maybe (WidgetHinzufügen e w a)
    -> m ()
widgetHinzufügenContainerRemoveJust c w =
    containerRemoveJust (widgetHinzufügen c) $ widgetHinzufügen <$> w

-- | Füge ein 'WidgetHinzufügen' zu einer zugehörigen Box hinzu
widgetHinzufügenBoxPackNew :: (MitBox b, MitWidget w, MonadIO m)
                            => WidgetHinzufügen e b a
                            -> m w
                            -> m (WidgetHinzufügen e w a)
widgetHinzufügenBoxPackNew b =
    fmap WidgetHinzufügen . boxPackWidgetNewDefault (widgetHinzufügen b)

-- | Text mit Typ-Annotation
newtype KategorieText a = KategorieText { kategorieText :: Sprache -> Text }

-- | Label für 'BoxWegstreckeHinzufügen'/'BoxPlanHinzufügen'
class Kategorie a where
    kategorie :: KategorieText a

-- | CheckButton zum hinzufügen zu einer Wegstrecke
type CheckButtonWegstreckeHinzufügen e a =
    WidgetHinzufügen 'HinzufügenWegstrecke (WegstreckeCheckButton e) a

-- | Box zur Auswahl der 'Wegstrecke'n-Elemente
type BoxWegstreckeHinzufügen a =
    WidgetHinzufügen 'HinzufügenWegstrecke (ScrollbaresWidget Gtk.Box) a

-- | Erstelle eine neue 'BoxWegstreckeHinzufügen'.
boxWegstreckeHinzufügenNew :: (MonadIO m) => m (BoxWegstreckeHinzufügen a)
boxWegstreckeHinzufügenNew =
    fmap WidgetHinzufügen $ scrollbaresWidgetNew $ Gtk.boxNew Gtk.OrientationVertical 0

deriving instance (Eq e) => Eq (WegstreckeCheckButton e)

-- | 'RegistrierterCheckButton', potentiell mit zusätzlicher Richtungsauswahl.
data WegstreckeCheckButton e where
    WegstreckeCheckButton :: { wcbvRegistrierterCheckButton :: RegistrierterCheckButton }
        -> WegstreckeCheckButton Void
    WegstreckeCheckButtonRichtung :: { wcbrWidget :: Gtk.Widget
                                     , wcbrRegistrierterCheckButton :: RegistrierterCheckButton
                                     , wcbrRichtungsAuswahl :: AuswahlWidget Richtung
                                     } -> WegstreckeCheckButton Richtung

instance MitWidget (WegstreckeCheckButton e) where
    erhalteWidget :: (MonadIO m) => WegstreckeCheckButton e -> m Gtk.Widget
    erhalteWidget WegstreckeCheckButton {wcbvRegistrierterCheckButton} =
        erhalteWidget wcbvRegistrierterCheckButton
    erhalteWidget WegstreckeCheckButtonRichtung {wcbrWidget} = pure wcbrWidget

instance MitRegistrierterCheckButton (WegstreckeCheckButton e) where
    erhalteRegistrierterCheckButton :: WegstreckeCheckButton e -> RegistrierterCheckButton
    erhalteRegistrierterCheckButton
        WegstreckeCheckButton {wcbvRegistrierterCheckButton} = wcbvRegistrierterCheckButton
    erhalteRegistrierterCheckButton
        WegstreckeCheckButtonRichtung {wcbrRegistrierterCheckButton} = wcbrRegistrierterCheckButton

instance MitAuswahlWidget (WegstreckeCheckButton Richtung) Richtung where
    erhalteAuswahlWidget :: WegstreckeCheckButton Richtung -> AuswahlWidget Richtung
    erhalteAuswahlWidget
        WegstreckeCheckButtonRichtung {wcbrRichtungsAuswahl} = wcbrRichtungsAuswahl

-- | Button zum hinzufügen eines Plans
type ButtonPlanHinzufügen a = WidgetHinzufügen 'HinzufügenPlan Gtk.Button a

-- | Box zum hinzufügen eines Plans
type BoxPlanHinzufügen a = WidgetHinzufügen 'HinzufügenPlan (ScrollbaresWidget Gtk.Box) a

-- | Erstelle eine neue 'BoxPlanHinzufügen'.
--
-- Mit der übergebenen 'TVar' kann das Anpassen der Label aus
-- 'Zug.UI.Gtk.SpracheGui.sprachwechsel' gelöscht werden.
-- Dazu muss deren Inhalt auf 'Nothing' gesetzt werden.
boxPlanHinzufügenNew :: forall a r m.
                      (Kategorie a, SpracheGuiReader r m, MonadIO m)
                      => Maybe TVarSprachewechselAktionen
                      -> m (BoxPlanHinzufügen a)
boxPlanHinzufügenNew maybeTVar = fmap WidgetHinzufügen $ scrollbaresWidgetNew $ do
    box <- Gtk.boxNew Gtk.OrientationVertical 0
    boxPackWidgetNewDefault box
        $ labelSpracheNew maybeTVar
        $ kategorieText (kategorie :: KategorieText a)
    pure box