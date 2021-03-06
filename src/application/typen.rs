//! newtypes auf f32, um zwischen mm-basierten und Pixel-basierten Größen zu unterscheiden

pub mod canvas;
pub mod mm;
pub mod skalar;
pub mod winkel;

// re-exports
pub use canvas::{pfad, Bogen, Cache, Frame, Pfad, Position, Transformation};
pub use mm::*;
pub use skalar::Skalar;
pub use winkel::*;
pub mod vektor;
pub use vektor::Vektor;

use super::anchor;
use crate::steuerung::{kontakt::Kontakt, weiche::Weiche};
pub use crate::zugtyp::Zugtyp;

// abgeleitete Größe unter der Umrechnung von /mm/ auf /Pixel/
/// Abstand beider Schienen
pub fn spurweite<Z: Zugtyp>() -> Skalar {
    Z::SPURWEITE.als_skalar()
}
/// Abstand seitlich der Schienen zum Anzeigen des Gleisendes
pub fn abstand<Z: Zugtyp>() -> Skalar {
    spurweite::<Z>() / Skalar(3.)
}
/// Länge der Beschränkung (Spurweite + Abstand auf beiden Seiten)
pub fn beschränkung<Z: Zugtyp>() -> Skalar {
    spurweite::<Z>() + abstand::<Z>().doppelt()
}
/// Innerster Radius (inklusive Beschränkung) einer Kurve
pub fn radius_begrenzung_innen<Z: Zugtyp>(radius: Skalar) -> Skalar {
    radius - Skalar(0.5) * spurweite::<Z>() - abstand::<Z>()
}
/// Äußerster Radius (inklusive Beschränkung) einer Kurve
pub fn radius_begrenzung_außen<Z: Zugtyp>(radius: Skalar) -> Skalar {
    radius + Skalar(0.5) * spurweite::<Z>() + abstand::<Z>()
}

pub trait Zeichnen
where
    Self::AnchorPoints: anchor::Lookup<Self::AnchorName>,
{
    /// Maximale x,y-Werte
    fn size(&self) -> Vektor;

    /// Erzeuge die Pfade für Färben des Hintergrunds.
    /// Alle Pfade werden mit /canvas::FillRule::EvenOdd/ gefüllt.
    fn fülle(&self) -> Vec<Pfad>;

    /// Erzeuge die Pfade für Darstellung der Linien.
    fn zeichne(&self) -> Vec<Pfad>;

    /// Position, Beschreibung und Name (falls verfügbar)
    fn beschreibung_und_name(&self) -> (Position, Option<&String>, Option<&String>);

    /// Zeigt der /Vektor/ auf das Gleis?
    fn innerhalb(&self, relative_position: Vektor) -> bool;

    /// Identifier for AnchorPoints.
    /// Ein enum wird empfohlen, aber andere Typen funktionieren ebenfalls.
    type AnchorName;
    /// Speicher-Typ für /anchor::Anchor/. Muss /anchor::Lookup<Self::AnchorName>/ implementieren.
    type AnchorPoints;
    /// AnchorPoints (Anschluss-Möglichkeiten für andere Gleise).
    ///
    /// Position ausgehend von zeichnen bei (0,0),
    /// Richtung nach außen zeigend.
    fn anchor_points(&self) -> Self::AnchorPoints;
}

pub trait MitName {
    fn name(&self) -> Option<&String>;
}
impl MitName for () {
    fn name(&self) -> Option<&String> {
        None
    }
}
impl<R, A> MitName for Option<Weiche<R, A>> {
    fn name(&self) -> Option<&String> {
        self.as_ref().map(|weiche| &weiche.name.0)
    }
}
impl<A> MitName for Option<Kontakt<A>> {
    fn name(&self) -> Option<&String> {
        self.as_ref().map(|kontakt| &kontakt.name.0)
    }
}
