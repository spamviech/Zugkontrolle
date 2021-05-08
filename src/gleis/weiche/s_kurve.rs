//! Definition und zeichnen einer Weiche

use std::marker::PhantomData;

use serde::{Deserialize, Serialize};

use super::Richtung;
use crate::gleis::typen::*;
use crate::gleis::weiche;
use crate::gleis::{anchor, gerade, kurve};

/// Definition einer Weiche mit S-Kurve
///
/// Bei extremen Winkeln (<0, >90°, angle_reverse>winkel) wird in negativen x,y-Werten gezeichnet!
/// Zeichnen::width berücksichtigt nur positive x-Werte.
/// Zeichnen::height berücksichtigt nur positive y-Werte.
#[derive(zugkontrolle_derive::Clone, zugkontrolle_derive::Debug, Serialize, Deserialize)]
pub struct SKurvenWeiche<Z> {
    pub zugtyp: PhantomData<Z>,
    pub länge: Skalar,
    pub radius: Skalar,
    pub winkel: Winkel,
    pub radius_reverse: Skalar,
    pub winkel_reverse: Winkel,
    pub richtung: Richtung,
    pub beschreibung: Option<String>,
}
impl<Z> SKurvenWeiche<Z> {
    pub const fn new(
        länge: Länge,
        radius: Radius,
        winkel: Winkel,
        radius_reverse: Radius,
        angle_reverse: Winkel,
        direction: Richtung,
    ) -> Self {
        SKurvenWeiche {
            zugtyp: PhantomData,
            länge: länge.als_skalar(),
            radius: radius.als_skalar(),
            winkel,
            radius_reverse: radius_reverse.als_skalar(),
            winkel_reverse: angle_reverse,
            richtung: direction,
            beschreibung: None,
        }
    }

    pub fn new_with_description(
        länge: Länge,
        radius: Radius,
        winkel: Winkel,
        radius_reverse: Radius,
        angle_reverse: Winkel,
        direction: Richtung,
        beschreibung: impl Into<String>,
    ) -> Self {
        SKurvenWeiche {
            zugtyp: PhantomData,
            länge: länge.als_skalar(),
            radius: radius.als_skalar(),
            winkel,
            radius_reverse: radius_reverse.als_skalar(),
            winkel_reverse: angle_reverse,
            richtung: direction,
            beschreibung: Some(beschreibung.into()),
        }
    }
}

impl<Z: Zugtyp> Zeichnen for SKurvenWeiche<Z> {
    type AnchorName = weiche::gerade::AnchorName;
    type AnchorPoints = weiche::gerade::AnchorPoints;

    fn size(&self) -> Vektor {
        let SKurvenWeiche { länge, radius, winkel, radius_reverse, winkel_reverse, .. } = *self;
        let angle_difference = winkel - winkel_reverse;
        let size_gerade = gerade::size::<Z>(länge);

        //Breiten-Berechnung
        let factor_width = Skalar(if winkel.abs() < winkel::FRAC_PI_2 { winkel.sin() } else { 1. });
        let factor_width_reverse = Skalar(
            if angle_difference.abs() < winkel::FRAC_PI_2 {
                winkel.sin() - angle_difference.sin()
            } else {
                1.
            }
            .max(0.),
        );
        let radius_außen = radius_begrenzung_außen::<Z>(radius);
        let radius_innen = radius_begrenzung_innen::<Z>(radius);
        let radius_reverse_außen = radius_begrenzung_außen::<Z>(radius_reverse);
        let radius_reverse_innen = radius_begrenzung_innen::<Z>(radius_reverse);
        // obere Beschränkung
        let width_oben1: Skalar = radius_außen * factor_width;
        let width_oben2: Skalar =
            radius_außen * Skalar(winkel.sin()) + radius_reverse_innen * factor_width_reverse;
        let width_oben: Skalar = width_oben1.max(&width_oben2);
        // untere Beschränkung
        let width_unten1: Skalar = radius_innen * factor_width;
        let width_unten2: Skalar =
            radius_innen * Skalar(winkel.sin()) + radius_reverse_außen * factor_width_reverse;
        let width_unten: Skalar = width_unten1.max(&width_unten2);

        // Höhen-Berechnung
        let factor_height = Skalar(if winkel.abs() < winkel::PI { 1. - winkel.cos() } else { 1. });
        let factor_height_reverse = Skalar(
            if angle_difference.abs() < winkel::PI {
                angle_difference.cos() - winkel.cos()
            } else {
                1.
            }
            .max(0.),
        );
        let radius_außen: Skalar = radius_begrenzung_außen::<Z>(radius);
        let radius_reverse_innen: Skalar = radius_begrenzung_innen::<Z>(radius_reverse);
        // obere Beschränkung
        let height_oben1: Skalar = radius_außen * factor_height;
        let height_oben2: Skalar =
            radius_außen * Skalar(1. - winkel.cos()) + radius_reverse_innen * factor_height_reverse;
        let height_oben: Skalar = height_oben1.max(&height_oben2);
        // untere Beschränkung
        let gleis_unten_start = beschränkung::<Z>();
        let radius_innen: Skalar = radius_begrenzung_innen::<Z>(radius);
        let radius_reverse_außen: Skalar = radius_begrenzung_außen::<Z>(radius_reverse);
        let height_unten1 = gleis_unten_start + radius_innen * factor_height;
        let height_unten2 = gleis_unten_start
            + radius_innen * Skalar(1. - winkel.cos())
            + radius_reverse_außen * factor_height_reverse;
        let height_unten = height_unten1.max(&height_unten2);

        Vektor {
            x: size_gerade.x.max(&width_oben.max(&width_unten)),
            y: height_oben.max(&height_unten),
        }
    }

    fn zeichne(
        &self,
        zu_iced_vektor: impl Fn(Vektor) -> iced::Point + 'static,
        zu_iced_bogen: impl Fn(Bogen) -> iced::canvas::path::Arc + 'static,
    ) -> Vec<Pfad> {
        // utility sizes
        let radius_begrenzung_außen = radius_begrenzung_außen::<Z>(self.radius);
        let s_kurve_transformations = |multiplier: Skalar| {
            let winkel = multiplier.0 * self.winkel;
            vec![
                Transformation::Translation(Vektor {
                    x: multiplier * radius_begrenzung_außen * Skalar(winkel.sin()),
                    y: multiplier * radius_begrenzung_außen * Skalar(1. - winkel.cos()),
                }),
                Transformation::Rotation(winkel),
                Transformation::Translation(Vektor {
                    x: Skalar(0.),
                    y: multiplier * beschränkung::<Z>(),
                }),
            ]
        };
        // Zeichne Pfad
        let mut paths = Vec::new();
        if self.richtung == Richtung::Links {
            let mut transformations =
                vec![Transformation::Translation(Vektor { x: Skalar(0.), y: self.size().y })];
            // Gerade
            paths.push(gerade::zeichne(
                self.zugtyp,
                self.länge,
                true,
                transformations.clone(),
                pfad::Erbauer::with_invert_y,
                zu_iced_vektor,
            ));
            // Kurve nach außen
            paths.push(kurve::zeichne(
                self.zugtyp,
                self.radius,
                self.winkel,
                kurve::Beschränkung::Keine,
                transformations.clone(),
                pfad::Erbauer::with_invert_y,
                zu_iced_vektor,
                zu_iced_bogen,
            ));
            // Kurve nach innen
            transformations.extend(s_kurve_transformations(Skalar(-1.)));
            paths.push(kurve::zeichne(
                self.zugtyp,
                self.radius_reverse,
                self.winkel_reverse,
                kurve::Beschränkung::Ende,
                transformations,
                pfad::Erbauer::with_normal_axis,
                zu_iced_vektor,
                zu_iced_bogen,
            ));
        } else {
            // Gerade
            paths.push(gerade::zeichne(
                self.zugtyp,
                self.länge,
                true,
                Vec::new(),
                pfad::Erbauer::with_normal_axis,
                zu_iced_vektor,
            ));
            // Kurve nach außen
            paths.push(kurve::zeichne(
                self.zugtyp,
                self.radius,
                self.winkel,
                kurve::Beschränkung::Keine,
                Vec::new(),
                pfad::Erbauer::with_normal_axis,
                zu_iced_vektor,
                zu_iced_bogen,
            ));
            // Kurve nach innen
            paths.push(kurve::zeichne(
                self.zugtyp,
                self.radius_reverse,
                self.winkel_reverse,
                kurve::Beschränkung::Ende,
                s_kurve_transformations(Skalar(1.)),
                pfad::Erbauer::with_invert_y,
                zu_iced_vektor,
                zu_iced_bogen,
            ));
        }
        // return value
        paths
    }

    fn fülle(
        &self,
        zu_iced_vektor: impl Fn(Vektor) -> iced::Point + 'static,
        zu_iced_bogen: impl Fn(Bogen) -> iced::canvas::path::Arc + 'static,
    ) -> Vec<Pfad> {
        // utility sizes
        let radius_begrenzung_außen = radius_begrenzung_außen::<Z>(self.radius);
        let s_kurve_transformations = |multiplier: Skalar| {
            let winkel = multiplier.0 * self.winkel;
            vec![
                Transformation::Translation(Vektor {
                    x: multiplier * radius_begrenzung_außen * Skalar(winkel.sin()),
                    y: multiplier * radius_begrenzung_außen * Skalar(1. - winkel.cos()),
                }),
                Transformation::Rotation(winkel),
                Transformation::Translation(Vektor {
                    x: Skalar(0.),
                    y: multiplier * beschränkung::<Z>(),
                }),
            ]
        };
        // Zeichne Pfad
        let mut paths = Vec::new();
        if self.richtung == Richtung::Links {
            let mut transformations =
                vec![Transformation::Translation(Vektor { x: Skalar(0.), y: self.size().y })];
            // Gerade
            paths.push(gerade::fülle(
                self.zugtyp,
                self.länge,
                transformations.clone(),
                pfad::Erbauer::with_invert_y,
                zu_iced_vektor,
            ));
            // Kurve nach außen
            paths.push(kurve::fülle(
                self.zugtyp,
                self.radius,
                self.winkel,
                transformations.clone(),
                pfad::Erbauer::with_invert_y,
                zu_iced_vektor,
                zu_iced_bogen,
            ));
            // Kurve nach innen
            transformations.extend(s_kurve_transformations(Skalar(-1.)));
            paths.push(kurve::fülle(
                self.zugtyp,
                self.radius_reverse,
                self.winkel_reverse,
                transformations,
                pfad::Erbauer::with_normal_axis,
                zu_iced_vektor,
                zu_iced_bogen,
            ));
        } else {
            // Gerade
            paths.push(gerade::fülle(
                self.zugtyp,
                self.länge,
                Vec::new(),
                pfad::Erbauer::with_normal_axis,
                zu_iced_vektor,
            ));
            // Kurve nach außen
            paths.push(kurve::fülle(
                self.zugtyp,
                self.radius,
                self.winkel,
                Vec::new(),
                pfad::Erbauer::with_normal_axis,
                zu_iced_vektor,
                zu_iced_bogen,
            ));
            // Kurve nach innen
            paths.push(kurve::fülle(
                self.zugtyp,
                self.radius_reverse,
                self.winkel_reverse,
                s_kurve_transformations(Skalar(1.)),
                pfad::Erbauer::with_invert_y,
                zu_iced_vektor,
                zu_iced_bogen,
            ));
        }
        // return value
        paths
    }

    fn beschreibung(&self) -> Option<(Position, &String)> {
        self.beschreibung.as_ref().map(|text| {
            let start_height: Skalar;
            let multiplier: Skalar;
            match self.richtung {
                Richtung::Rechts => {
                    start_height = Skalar(0.);
                    multiplier = Skalar(1.);
                },
                Richtung::Links => {
                    start_height = self.size().y;
                    multiplier = Skalar(-1.);
                },
            };
            (
                Position {
                    punkt: Vektor {
                        x: self.länge.halbiert(),
                        y: start_height + multiplier * beschränkung::<Z>().halbiert(),
                    },
                    winkel: Winkel(0.),
                },
                text,
            )
        })
    }

    fn innerhalb(&self, relative_position: Vektor) -> bool {
        // utility sizes
        let start_height: Skalar;
        let multiplier: Skalar;
        match self.richtung {
            Richtung::Rechts => {
                start_height = Skalar(0.);
                multiplier = Skalar(1.);
            },
            Richtung::Links => {
                start_height = self.size().y;
                multiplier = Skalar(-1.);
            },
        };
        let start_vector = Vektor { x: Skalar(0.), y: start_height };
        let radius_begrenzung_außen = radius_begrenzung_außen::<Z>(self.radius);
        let multiplied_winkel = multiplier.0 * self.winkel;
        let s_kurve_start_vector = Vektor {
            x: multiplier * radius_begrenzung_außen * Skalar(multiplied_winkel.sin()),
            y: radius_begrenzung_außen * Skalar(1. - multiplied_winkel.cos()),
        };
        // sub-checks
        let mut relative_vector = relative_position - start_vector;
        relative_vector.y *= multiplier;
        let mut s_kurve_vector = (relative_vector - s_kurve_start_vector).rotiere(-self.winkel);
        s_kurve_vector -= Vektor { x: Skalar(0.), y: beschränkung::<Z>() };
        s_kurve_vector.y = -s_kurve_vector.y;
        gerade::innerhalb::<Z>(self.länge, relative_vector)
            || kurve::innerhalb::<Z>(self.radius, self.winkel, relative_vector)
            || kurve::innerhalb::<Z>(self.radius_reverse, self.winkel_reverse, s_kurve_vector)
    }

    fn anchor_points(&self) -> Self::AnchorPoints {
        let start_height: Skalar;
        let multiplier: Skalar;
        match self.richtung {
            Richtung::Rechts => {
                start_height = Skalar(0.);
                multiplier = Skalar(1.);
            },
            Richtung::Links => {
                start_height = self.size().y;
                multiplier = Skalar(-1.);
            },
        };
        let angle_difference = self.winkel - self.winkel_reverse;
        let anfang = Vektor {
            x: Skalar(0.),
            y: start_height + multiplier * beschränkung::<Z>().halbiert(),
        };
        weiche::gerade::AnchorPoints {
            anfang: anchor::Anchor { position: anfang, richtung: winkel::PI },
            gerade: anchor::Anchor {
                position: anfang + Vektor { x: self.länge, y: Skalar(0.) },
                richtung: winkel::ZERO,
            },
            kurve: anchor::Anchor {
                position: anfang
                    + Vektor {
                        x: self.radius * Skalar(self.winkel.sin())
                            + self.radius_reverse
                                * Skalar(self.winkel.sin() - angle_difference.sin()),
                        y: multiplier
                            * (self.radius * Skalar(1. - self.winkel.cos())
                                + self.radius_reverse
                                    * Skalar(angle_difference.cos() - self.winkel.cos())),
                    },
                richtung: multiplier.0 * angle_difference,
            },
        }
    }
}
