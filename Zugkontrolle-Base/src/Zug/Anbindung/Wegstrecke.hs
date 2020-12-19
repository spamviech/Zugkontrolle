{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GADTs #-}

{-|
Description: Zusammenfassung von Einzel-Elementen. Weichen haben eine vorgegebene Richtung.
-}
module Zug.Anbindung.Wegstrecke (Wegstrecke(..), WegstreckeKlasse(..)) where

import Control.Applicative (Alternative(..))
import Control.Monad (forM_)
import Control.Monad.Trans (MonadIO())
import Data.Aeson.Types ((.:), (.=))
import qualified Data.Aeson.Types as Aeson
import Data.List (foldl')
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Data.Word (Word8)

import Zug.Anbindung.Anschluss
       (Anschluss(..), AnschlussEither(..), AnschlussKlasse(anschlussWrite), Pin(), PCF8574Port()
      , MitInterruptPin(OhneInterruptPin), PCF8574Klasse(ohneInterruptPin), pcf8574MultiPortWrite
      , pcf8574Gruppieren, I2CReader(forkI2CReader), Value(..), InterruptReader(), warteAufÄnderung
      , IntEdge(..))
import Zug.Anbindung.Bahngeschwindigkeit
       (Bahngeschwindigkeit(..), GeschwindigkeitsAnschlüsse(..), FahrtrichtungsAnschluss(..)
      , BahngeschwindigkeitKlasse(..), umdrehenZeit, positionOderLetztes, PwmZugtyp())
import Zug.Anbindung.Klassen (StreckenAtom(..), StreckenObjekt(..), befehlAusführen, VersionReader)
import Zug.Anbindung.Kontakt (Kontakt(..), KontaktKlasse(..))
import Zug.Anbindung.Kupplung (Kupplung(..), KupplungKlasse(..), kuppelnZeit)
import Zug.Anbindung.Pwm (PwmReader())
import Zug.Anbindung.Streckenabschnitt (Streckenabschnitt(..), StreckenabschnittKlasse(..))
import Zug.Anbindung.Wartezeit (warte, Wartezeit(MilliSekunden))
import Zug.Anbindung.Weiche (Weiche(..), WeicheKlasse(stellen), weicheZeit)
import Zug.Enums (Zugtyp(..), ZugtypEither(..), ZugtypKlasse(), GeschwindigkeitVariante(..)
                , GeschwindigkeitEither(..), catPwm, catKonstanteSpannung
                , GeschwindigkeitPhantom(..), Richtung(), Strom(..), Fahrtrichtung(..))
import qualified Zug.JSONStrings as JS
import Zug.Language (Anzeige(..), Sprache(), showText, (<:>), (<=>), (<^>), (<°>))
import qualified Zug.Language as Language

-- | Zusammenfassung von Einzel-Elementen. Weichen haben eine vorgegebene Richtung.
data Wegstrecke (z :: Zugtyp) =
    Wegstrecke
    { wsName :: Text
    , wsBahngeschwindigkeiten :: Set (GeschwindigkeitEither Bahngeschwindigkeit z)
    , wsStreckenabschnitte :: Set Streckenabschnitt
    , wsWeichenRichtungen :: Set (Weiche z, Richtung)
    , wsKupplungen :: Set Kupplung
    , wsKontakte :: Set Kontakt
    }
    deriving (Eq, Ord, Show)

instance Anzeige (Wegstrecke z) where
    anzeige :: Wegstrecke z -> Sprache -> Text
    anzeige
        Wegstrecke
        {wsName, wsBahngeschwindigkeiten, wsStreckenabschnitte, wsWeichenRichtungen, wsKupplungen} =
        Language.wegstrecke
        <:> Language.name
        <=> wsName
        <^> Language.bahngeschwindigkeiten
        <=> wsBahngeschwindigkeiten
        <^> Language.streckenabschnitte
        <=> wsStreckenabschnitte
        <^> Language.weichen
        <=> map (uncurry (<°>)) (Set.toList wsWeichenRichtungen)
        <^> Language.kupplungen <=> wsKupplungen

instance StreckenObjekt (Wegstrecke z) where
    anschlüsse :: Wegstrecke z -> Set AnschlussEither
    anschlüsse
        Wegstrecke
        {wsBahngeschwindigkeiten, wsStreckenabschnitte, wsWeichenRichtungen, wsKupplungen} =
        Set.unions
        $ Set.toList
        $ Set.map anschlüsse wsBahngeschwindigkeiten
        <> Set.map anschlüsse wsStreckenabschnitte
        <> Set.map (anschlüsse . fst) wsWeichenRichtungen
        <> Set.map anschlüsse wsKupplungen

    erhalteName :: Wegstrecke z -> Text
    erhalteName Wegstrecke {wsName} = wsName

i2cZeit :: Wartezeit
i2cZeit = MilliSekunden 250

i2cForM_ :: (Foldable t, MonadIO m) => t a -> (a -> m b) -> m ()
i2cForM_ t action = forM_ t $ \a -> action a >> warte i2cZeit

instance BahngeschwindigkeitKlasse (GeschwindigkeitPhantom Wegstrecke) where
    geschwindigkeit :: (I2CReader r m, PwmReader r m, VersionReader r m, PwmZugtyp z, MonadIO m)
                    => GeschwindigkeitPhantom Wegstrecke 'Pwm z
                    -> Word8
                    -> m ()
    geschwindigkeit (GeschwindigkeitPhantom ws@Wegstrecke {wsBahngeschwindigkeiten}) wert =
        befehlAusführen
            (mapM_ (forkI2CReader . flip geschwindigkeit wert) $ catPwm wsBahngeschwindigkeiten)
            ("Geschwindigkeit (" <> showText ws <> ")->" <> showText wert)

    umdrehen :: (I2CReader r m, PwmReader r m, VersionReader r m, MonadIO m)
             => GeschwindigkeitPhantom Wegstrecke b 'Märklin
             -> m ()
    umdrehen (GeschwindigkeitPhantom ws@Wegstrecke {wsBahngeschwindigkeiten}) =
        flip befehlAusführen ("Umdrehen (" <> showText ws <> ")") $ do
            geschwindigkeit (GeschwindigkeitPhantom ws) 0
            fahrstrom (GeschwindigkeitPhantom ws) 0
            warte umdrehenZeit
            strom ws Fließend
            mapM_ (forkI2CReader . umdrehen) geschwindigkeitenPwm
            forM_ umdrehenPins $ \(pin, valueFunktion) -> forkI2CReader $ do
                anschlussWrite pin $ valueFunktion Fließend
                warte umdrehenZeit
                anschlussWrite pin $ valueFunktion Gesperrt
            i2cForM_ (Map.toList umdrehenPortMapHigh) $ \(pcf8574, ports) -> do
                pcf8574MultiPortWrite pcf8574 ports HIGH
                warte umdrehenZeit
                pcf8574MultiPortWrite pcf8574 ports LOW
            i2cForM_ (Map.toList umdrehenPortMapLow) $ \(pcf8574, ports) -> do
                pcf8574MultiPortWrite pcf8574 ports LOW
                warte umdrehenZeit
                pcf8574MultiPortWrite pcf8574 ports HIGH
        where
            (geschwindigkeitenPwm, geschwindigkeitenKonstanteSpannung) =
                foldl' splitGeschwindigkeiten ([], []) wsBahngeschwindigkeiten

            splitGeschwindigkeiten
                :: ( [Bahngeschwindigkeit 'Pwm 'Märklin]
                   , [Bahngeschwindigkeit 'KonstanteSpannung 'Märklin]
                   )
                -> GeschwindigkeitEither Bahngeschwindigkeit 'Märklin
                -> ( [Bahngeschwindigkeit 'Pwm 'Märklin]
                   , [Bahngeschwindigkeit 'KonstanteSpannung 'Märklin]
                   )
            splitGeschwindigkeiten (p, k) (GeschwindigkeitPwm bg) = (bg : p, k)
            splitGeschwindigkeiten (p, k) (GeschwindigkeitKonstanteSpannung bg) = (p, bg : k)

            (umdrehenPins, umdrehenPcf8574PortsHigh, umdrehenPcf8574PortsLow) =
                foldl' splitAnschlüsse ([], [], []) geschwindigkeitenKonstanteSpannung

            splitAnschlüsse
                :: ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
                -> Bahngeschwindigkeit 'KonstanteSpannung 'Märklin
                -> ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                bg@Bahngeschwindigkeit { bgFahrtrichtungsAnschluss = UmdrehenAnschluss
                                             {umdrehenAnschluss = AnschlussMit AnschlussPin {pin}}} =
                ((pin, flip erhalteValue bg) : pins, portsHigh, portsLow)
            splitAnschlüsse
                acc
                bg@Bahngeschwindigkeit
                { bgFahrtrichtungsAnschluss = UmdrehenAnschluss
                      {umdrehenAnschluss = AnschlussMit AnschlussPCF8574Port {pcf8574Port}}} =
                splitAnschlüsse
                    acc
                    bg
                    { bgFahrtrichtungsAnschluss = UmdrehenAnschluss
                          { umdrehenAnschluss =
                                AnschlussOhne $ AnschlussPCF8574Port $ ohneInterruptPin pcf8574Port
                          }
                    }
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                Bahngeschwindigkeit
                { bgFließend = HIGH
                , bgFahrtrichtungsAnschluss = UmdrehenAnschluss
                      {umdrehenAnschluss = AnschlussOhne AnschlussPCF8574Port {pcf8574Port}}} =
                (pins, pcf8574Port : portsHigh, portsLow)
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                Bahngeschwindigkeit
                { bgFließend = LOW
                , bgFahrtrichtungsAnschluss = UmdrehenAnschluss
                      {umdrehenAnschluss = AnschlussOhne AnschlussPCF8574Port {pcf8574Port}}} =
                (pins, portsHigh, pcf8574Port : portsLow)

            umdrehenPortMapHigh = pcf8574Gruppieren umdrehenPcf8574PortsHigh

            umdrehenPortMapLow = pcf8574Gruppieren umdrehenPcf8574PortsLow

    fahrstrom :: (I2CReader r m, VersionReader r m, MonadIO m)
              => GeschwindigkeitPhantom Wegstrecke 'KonstanteSpannung z
              -> Word8
              -> m ()
    fahrstrom (GeschwindigkeitPhantom ws@Wegstrecke {wsBahngeschwindigkeiten}) wert =
        flip befehlAusführen ("Fahrstrom (" <> showText ws <> ")->" <> showText wert) $ do
            forM_ fahrstromPins $ \(pin, value) -> forkI2CReader $ anschlussWrite pin value
            i2cForM_ (Map.toList fahrstromPortMapHigh)
                $ \(pcf8574, ports) -> pcf8574MultiPortWrite pcf8574 ports HIGH
            i2cForM_ (Map.toList fahrstromPortMapLow)
                $ \(pcf8574, ports) -> pcf8574MultiPortWrite pcf8574 ports LOW
        where
            (fahrstromPins, fahrstromPcf8574PortsHigh, fahrstromPcf8574PortsLow) =
                foldl' splitBahngeschwindigkeiten ([], [], [])
                $ catKonstanteSpannung wsBahngeschwindigkeiten

            splitBahngeschwindigkeiten
                :: ( [(Pin, Value)]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
                -> Bahngeschwindigkeit 'KonstanteSpannung z
                -> ( [(Pin, Value)]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
            splitBahngeschwindigkeiten
                acc
                bg@Bahngeschwindigkeit
                {bgGeschwindigkeitsAnschlüsse = FahrstromAnschlüsse {fahrstromAnschlüsse}} =
                foldl' (splitAnschlüsse bg) acc fahrstromAnschlüsse

            splitAnschlüsse
                :: Bahngeschwindigkeit 'KonstanteSpannung z
                -> ( [(Pin, Value)]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
                -> AnschlussEither
                -> ( [(Pin, Value)]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
            splitAnschlüsse
                bg
                (pins, portsHigh, portsLow)
                anschluss@(AnschlussMit AnschlussPin {pin}) =
                ((pin, anschlussValue bg anschluss) : pins, portsHigh, portsLow)
            splitAnschlüsse bg acc (AnschlussMit AnschlussPCF8574Port {pcf8574Port}) =
                splitAnschlüsse bg acc
                $ AnschlussOhne
                $ AnschlussPCF8574Port
                $ ohneInterruptPin pcf8574Port
            splitAnschlüsse
                bg
                (pins, portsHigh, portsLow)
                anschluss@(AnschlussOhne AnschlussPCF8574Port {pcf8574Port})
                | anschlussValue bg anschluss == HIGH = (pins, pcf8574Port : portsHigh, portsLow)
                | otherwise = (pins, portsHigh, pcf8574Port : portsLow)

            fahrstromPortMapHigh = pcf8574Gruppieren fahrstromPcf8574PortsHigh

            fahrstromPortMapLow = pcf8574Gruppieren fahrstromPcf8574PortsLow

            anschlussValue :: Bahngeschwindigkeit 'KonstanteSpannung z -> AnschlussEither -> Value
            anschlussValue
                bg@Bahngeschwindigkeit
                {bgGeschwindigkeitsAnschlüsse = FahrstromAnschlüsse {fahrstromAnschlüsse}}
                anschluss
                | positionOderLetztes wert fahrstromAnschlüsse == Just anschluss = fließend bg
                | otherwise = gesperrt bg

    fahrtrichtungEinstellen :: (I2CReader r m, PwmReader r m, VersionReader r m, MonadIO m)
                            => GeschwindigkeitPhantom Wegstrecke b 'Lego
                            -> Fahrtrichtung
                            -> m ()
    fahrtrichtungEinstellen
        (GeschwindigkeitPhantom ws@Wegstrecke {wsBahngeschwindigkeiten})
        neueFahrtrichtung =
        flip
            befehlAusführen
            ("Fahrtrichtung (" <> showText ws <> ")->" <> showText neueFahrtrichtung)
        $ do
            geschwindigkeit (GeschwindigkeitPhantom ws) 0
            fahrstrom (GeschwindigkeitPhantom ws) 0
            warte umdrehenZeit
            strom ws Fließend
            forM_ fahrtrichtungsPins $ \(pin, valueFunktion)
                -> forkI2CReader $ anschlussWrite pin $ valueFunktion $ case neueFahrtrichtung of
                    Vorwärts -> Fließend
                    Rückwärts -> Gesperrt
            i2cForM_ (Map.toList fahrtrichtungPortMapHigh) $ \(pcf8574, ports)
                -> pcf8574MultiPortWrite pcf8574 ports $ case neueFahrtrichtung of
                    Vorwärts -> HIGH
                    Rückwärts -> LOW
            i2cForM_ (Map.toList fahrtrichtungPortMapLow) $ \(pcf8574, ports)
                -> pcf8574MultiPortWrite pcf8574 ports $ case neueFahrtrichtung of
                    Vorwärts -> LOW
                    Rückwärts -> HIGH
        where
            (fahrtrichtungsPins, fahrtrichtungPcf8574PortsHigh, fahrtrichtungPcf8574PortsLow) =
                foldl' splitAnschlüsse ([], [], []) wsBahngeschwindigkeiten

            splitAnschlüsse
                :: ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
                -> GeschwindigkeitEither Bahngeschwindigkeit 'Lego
                -> ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                (GeschwindigkeitPwm
                     bg@Bahngeschwindigkeit
                     { bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                           {fahrtrichtungsAnschluss = AnschlussMit (AnschlussPin pin)}}) =
                ((pin, flip erhalteValue bg) : pins, portsHigh, portsLow)
            splitAnschlüsse
                acc
                (GeschwindigkeitPwm
                     bg@Bahngeschwindigkeit { bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                                                  { fahrtrichtungsAnschluss = AnschlussMit
                                                        AnschlussPCF8574Port {pcf8574Port}}}) =
                splitAnschlüsse acc
                $ GeschwindigkeitPwm
                $ bg
                { bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                      { fahrtrichtungsAnschluss =
                            AnschlussOhne $ AnschlussPCF8574Port $ ohneInterruptPin pcf8574Port
                      }
                }
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                (GeschwindigkeitPwm
                     Bahngeschwindigkeit { bgFließend = HIGH
                                         , bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                                               { fahrtrichtungsAnschluss = AnschlussOhne
                                                     AnschlussPCF8574Port {pcf8574Port}}}) =
                (pins, pcf8574Port : portsHigh, portsLow)
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                (GeschwindigkeitPwm
                     Bahngeschwindigkeit { bgFließend = LOW
                                         , bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                                               { fahrtrichtungsAnschluss = AnschlussOhne
                                                     AnschlussPCF8574Port {pcf8574Port}}}) =
                (pins, portsHigh, pcf8574Port : portsLow)
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                (GeschwindigkeitKonstanteSpannung
                     bg@Bahngeschwindigkeit
                     { bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                           {fahrtrichtungsAnschluss = AnschlussMit (AnschlussPin pin)}}) =
                ((pin, flip erhalteValue bg) : pins, portsHigh, portsLow)
            splitAnschlüsse
                acc
                (GeschwindigkeitKonstanteSpannung
                     bg@Bahngeschwindigkeit { bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                                                  { fahrtrichtungsAnschluss = AnschlussMit
                                                        AnschlussPCF8574Port {pcf8574Port}}}) =
                splitAnschlüsse acc
                $ GeschwindigkeitKonstanteSpannung
                $ bg
                { bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                      { fahrtrichtungsAnschluss =
                            AnschlussOhne $ AnschlussPCF8574Port $ ohneInterruptPin pcf8574Port
                      }
                }
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                (GeschwindigkeitKonstanteSpannung
                     Bahngeschwindigkeit { bgFließend = HIGH
                                         , bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                                               { fahrtrichtungsAnschluss = AnschlussOhne
                                                     AnschlussPCF8574Port {pcf8574Port}}}) =
                (pins, pcf8574Port : portsHigh, portsLow)
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                (GeschwindigkeitKonstanteSpannung
                     Bahngeschwindigkeit { bgFließend = LOW
                                         , bgFahrtrichtungsAnschluss = FahrtrichtungsAnschluss
                                               { fahrtrichtungsAnschluss = AnschlussOhne
                                                     AnschlussPCF8574Port {pcf8574Port}}}) =
                (pins, portsHigh, pcf8574Port : portsLow)

            fahrtrichtungPortMapHigh = pcf8574Gruppieren fahrtrichtungPcf8574PortsHigh

            fahrtrichtungPortMapLow = pcf8574Gruppieren fahrtrichtungPcf8574PortsLow

instance StreckenabschnittKlasse (Wegstrecke z) where
    strom :: (I2CReader r m, VersionReader r m, MonadIO m) => Wegstrecke z -> Strom -> m ()
    strom ws@Wegstrecke {wsStreckenabschnitte} an =
        flip befehlAusführen ("Strom (" <> showText ws <> ")->" <> showText an) $ do
            forM_ stromPins $ \(pin, valueFunktion) -> anschlussWrite pin $ valueFunktion an
            i2cForM_ (Map.toList stromPortMapHigh)
                $ \(pcf8574, ports) -> pcf8574MultiPortWrite pcf8574 ports $ case an of
                    Fließend -> HIGH
                    Gesperrt -> LOW
            i2cForM_ (Map.toList stromPortMapLow)
                $ \(pcf8574, ports) -> pcf8574MultiPortWrite pcf8574 ports $ case an of
                    Fließend -> LOW
                    Gesperrt -> HIGH
        where
            (stromPins, stromPcf8574PortsHigh, stromPcf8574PortsLow) =
                foldl' splitAnschlüsse ([], [], []) wsStreckenabschnitte

            splitAnschlüsse
                :: ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
                -> Streckenabschnitt
                -> ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                st@Streckenabschnitt {stromAnschluss = AnschlussMit AnschlussPin {pin}} =
                ((pin, flip erhalteValue st) : pins, portsHigh, portsLow)
            splitAnschlüsse
                acc
                st@Streckenabschnitt
                {stromAnschluss = AnschlussMit AnschlussPCF8574Port {pcf8574Port}} =
                splitAnschlüsse
                    acc
                    st
                    { stromAnschluss =
                          AnschlussOhne $ AnschlussPCF8574Port $ ohneInterruptPin pcf8574Port
                    }
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                Streckenabschnitt
                { stFließend = HIGH
                , stromAnschluss = AnschlussOhne AnschlussPCF8574Port {pcf8574Port}} =
                (pins, pcf8574Port : portsHigh, portsLow)
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                Streckenabschnitt
                { stFließend = LOW
                , stromAnschluss = AnschlussOhne AnschlussPCF8574Port {pcf8574Port}} =
                (pins, portsHigh, pcf8574Port : portsLow)

            stromPortMapHigh = pcf8574Gruppieren stromPcf8574PortsHigh

            stromPortMapLow = pcf8574Gruppieren stromPcf8574PortsLow

instance KupplungKlasse (Wegstrecke z) where
    kuppeln :: (I2CReader r m, VersionReader r m, MonadIO m) => Wegstrecke z -> m ()
    kuppeln ws@Wegstrecke {wsKupplungen} =
        flip befehlAusführen ("Kuppeln (" <> showText ws <> ")") $ do
            forM_ kupplungsPins $ \(pin, valueFunktion) -> forkI2CReader $ do
                anschlussWrite pin $ valueFunktion Fließend
                warte kuppelnZeit
                anschlussWrite pin $ valueFunktion Gesperrt
            i2cForM_ (Map.toList kupplungsPortMapHigh) $ \(pcf8574, ports) -> do
                pcf8574MultiPortWrite pcf8574 ports HIGH
                warte kuppelnZeit
                pcf8574MultiPortWrite pcf8574 ports LOW
            i2cForM_ (Map.toList kupplungsPortMapLow) $ \(pcf8574, ports) -> do
                pcf8574MultiPortWrite pcf8574 ports LOW
                warte kuppelnZeit
                pcf8574MultiPortWrite pcf8574 ports HIGH
        where
            (kupplungsPins, kupplungsPcf8574PortsHigh, kupplungsPcf8574PortsLow) =
                foldl' splitAnschlüsse ([], [], []) wsKupplungen

            splitAnschlüsse
                :: ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
                -> Kupplung
                -> ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                ku@Kupplung {kupplungsAnschluss = AnschlussMit AnschlussPin {pin}} =
                ((pin, flip erhalteValue ku) : pins, portsHigh, portsLow)
            splitAnschlüsse
                acc
                ku@Kupplung {kupplungsAnschluss = AnschlussMit AnschlussPCF8574Port {pcf8574Port}} =
                splitAnschlüsse
                    acc
                    ku
                    { kupplungsAnschluss =
                          AnschlussOhne $ AnschlussPCF8574Port $ ohneInterruptPin pcf8574Port
                    }
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                Kupplung { kuFließend = HIGH
                         , kupplungsAnschluss = AnschlussOhne AnschlussPCF8574Port {pcf8574Port}} =
                (pins, pcf8574Port : portsHigh, portsLow)
            splitAnschlüsse
                (pins, portsHigh, portsLow)
                Kupplung { kuFließend = LOW
                         , kupplungsAnschluss = AnschlussOhne AnschlussPCF8574Port {pcf8574Port}} =
                (pins, portsHigh, pcf8574Port : portsLow)

            kupplungsPortMapHigh = pcf8574Gruppieren kupplungsPcf8574PortsHigh

            kupplungsPortMapLow = pcf8574Gruppieren kupplungsPcf8574PortsLow

instance KontaktKlasse (Wegstrecke z) where
    warteAufSignal :: (InterruptReader r m, I2CReader r m, MonadIO m) => Wegstrecke z -> m ()
    warteAufSignal Wegstrecke {wsKontakte} = do
        let listeAnschlussIntEdge =
                map (\Kontakt {kontaktAnschluss, koFließend}
                     -> ( kontaktAnschluss
                        , if koFließend == LOW
                              then INT_EDGE_FALLING
                              else INT_EDGE_RISING
                        )) $ Set.toList wsKontakte
        warteAufÄnderung listeAnschlussIntEdge

-- | Sammel-Klasse für 'Wegstrecke'n-artige Typen
class (StreckenObjekt w, StreckenabschnittKlasse w, KupplungKlasse w) => WegstreckeKlasse w where
    einstellen :: (I2CReader r m, PwmReader r m, VersionReader r m, MonadIO m) => w -> m ()
    {-# MINIMAL einstellen #-}

instance (WegstreckeKlasse (w 'Märklin), WegstreckeKlasse (w 'Lego))
    => WegstreckeKlasse (ZugtypEither w) where
    einstellen
        :: (I2CReader r m, PwmReader r m, VersionReader r m, MonadIO m) => ZugtypEither w -> m ()
    einstellen (ZugtypMärklin a) = einstellen a
    einstellen (ZugtypLego a) = einstellen a

instance WegstreckeKlasse (Wegstrecke 'Märklin) where
    einstellen :: (I2CReader r m, PwmReader r m, VersionReader r m, MonadIO m)
               => Wegstrecke 'Märklin
               -> m ()
    einstellen ws@Wegstrecke {wsWeichenRichtungen} =
        flip befehlAusführen ("Einstellen (" <> showText ws <> ")") $ do
            forM_ richtungsPins $ \(pin, valueFunktion) -> forkI2CReader $ do
                anschlussWrite pin $ valueFunktion Fließend
                warte weicheZeit
                anschlussWrite pin $ valueFunktion Gesperrt
            i2cForM_ (Map.toList richtungsPortMapHigh) $ \(pcf8574, ports) -> do
                pcf8574MultiPortWrite pcf8574 ports HIGH
                warte weicheZeit
                pcf8574MultiPortWrite pcf8574 ports LOW
            i2cForM_ (Map.toList richtungsPortMapLow) $ \(pcf8574, ports) -> do
                pcf8574MultiPortWrite pcf8574 ports LOW
                warte weicheZeit
                pcf8574MultiPortWrite pcf8574 ports HIGH
        where
            (richtungsPins, richtungsPcf8574PortsHigh, richtungsPcf8574PortsLow) =
                foldl' splitAnschlüsse ([], [], []) wsWeichenRichtungen

            splitAnschlüsse
                :: ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
                -> (Weiche 'Märklin, Richtung)
                -> ( [( Pin
                      , Strom
                            -> Value
                      )]
                   , [PCF8574Port 'OhneInterruptPin]
                   , [PCF8574Port 'OhneInterruptPin]
                   )
            splitAnschlüsse
                acc@(pins, portsHigh, portsLow)
                (we@WeicheMärklin {wemFließend, wemRichtungsAnschlüsse}, richtung) =
                case getRichtungsAnschluss richtung (NonEmpty.toList wemRichtungsAnschlüsse) of
                    (Just (AnschlussMit AnschlussPin {pin}))
                        -> ((pin, flip erhalteValue we) : pins, portsHigh, portsLow)
                    (Just (AnschlussMit AnschlussPCF8574Port {pcf8574Port})) -> case wemFließend of
                        HIGH -> (pins, ohneInterruptPin pcf8574Port : portsHigh, portsLow)
                        LOW -> (pins, portsHigh, ohneInterruptPin pcf8574Port : portsLow)
                    (Just
                         (AnschlussOhne AnschlussPCF8574Port {pcf8574Port})) -> case wemFließend of
                        HIGH -> (pins, pcf8574Port : portsHigh, portsLow)
                        LOW -> (pins, portsHigh, pcf8574Port : portsLow)
                    Nothing -> acc

            getRichtungsAnschluss
                :: Richtung -> [(Richtung, AnschlussEither)] -> Maybe AnschlussEither
            getRichtungsAnschluss _richtung [] = Nothing
            getRichtungsAnschluss richtung ((ersteRichtung, ersterAnschluss):andereRichtungen)
                | richtung == ersteRichtung = Just ersterAnschluss
                | otherwise = getRichtungsAnschluss richtung andereRichtungen

            richtungsPortMapHigh = pcf8574Gruppieren richtungsPcf8574PortsHigh

            richtungsPortMapLow = pcf8574Gruppieren richtungsPcf8574PortsLow

instance WegstreckeKlasse (Wegstrecke 'Lego) where
    einstellen
        :: (I2CReader r m, PwmReader r m, VersionReader r m, MonadIO m) => Wegstrecke 'Lego -> m ()
    einstellen Wegstrecke {wsWeichenRichtungen} =
        mapM_ (forkI2CReader . uncurry stellen) wsWeichenRichtungen

-- JSON-Instanz-Deklaration für Wegstrecke
-- Kontakte optional, um Kompatibilität mit älteren yaml-Dateien zu garantieren
instance (Aeson.FromJSON (GeschwindigkeitEither Bahngeschwindigkeit z), Aeson.FromJSON (Weiche z))
    => Aeson.FromJSON (Wegstrecke z) where
    parseJSON :: Aeson.Value -> Aeson.Parser (Wegstrecke z)
    parseJSON (Aeson.Object v) =
        Wegstrecke <$> (v .: JS.name)
        <*> v .: JS.bahngeschwindigkeiten
        <*> v .: JS.streckenabschnitte
        <*> v .: JS.weichenRichtungen
        <*> v .: JS.kupplungen
        <*> (v .: JS.kontakte <|> pure Set.empty)
    parseJSON _value = empty

instance (ZugtypKlasse z) => Aeson.ToJSON (Wegstrecke z) where
    toJSON :: Wegstrecke z -> Aeson.Value
    toJSON
        Wegstrecke { wsName
                   , wsBahngeschwindigkeiten
                   , wsStreckenabschnitte
                   , wsWeichenRichtungen
                   , wsKupplungen
                   , wsKontakte} =
        Aeson.object
            [ JS.name .= wsName
            , JS.bahngeschwindigkeiten .= wsBahngeschwindigkeiten
            , JS.streckenabschnitte .= wsStreckenabschnitte
            , JS.weichenRichtungen .= wsWeichenRichtungen
            , JS.kupplungen .= wsKupplungen
            , JS.kontakte .= wsKontakte]