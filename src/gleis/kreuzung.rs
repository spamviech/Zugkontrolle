//! Definition und zeichnen einer Kreuzung

// TODO
// non_ascii_idents might be stabilized soon
// use english names until then :(
// (nightly crashes atm on Sized-check)
// https://github.com/rust-lang/rust/issues/55467

use std::marker::PhantomData;

use super::types::*;
use super::{anchor, gerade, kurve};

/// Definition einer Kreuzung
#[derive(zugkontrolle_derive::Clone, zugkontrolle_derive::Debug)]
pub struct Kreuzung<T> {
    pub zugtyp: PhantomData<*const T>,
    pub laenge: canvas::Abstand<canvas::X>,
    pub radius: canvas::Abstand<canvas::Radius>,
    pub variante: Variante,
    pub beschreibung: Option<&'static str>,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Variante {
    MitKurve,
    OhneKurve,
}
impl<Z> Kreuzung<Z> {
    fn angle(&self) -> Angle {
        // angle solves the formula `x = L/2 * (1 + sin(alpha)) = R * cos(alpha)`
        // https://www.wolframalpha.com/input/?i=sin%28alpha%29-C*cos%28alpha%29%3DC
        // length=0 gives angle=0, but is not properly defined,
        // since it violates the formula above (pi/2 required)
        // pi/2 doesn't work either, since it violates the formula
        // `y = L/2 * sin(alpha) = R * (1 - cos(alpha))`
        // only for radius=0 as well both formulas are satisfied by any angle
        Angle::new(2. * (0.5 * (self.laenge / self.radius)).atan())
    }
    pub const fn new(length: Length, radius: Radius, variante: Variante) -> Self {
        Kreuzung {
            zugtyp: PhantomData,
            laenge: length.to_abstand(),
            radius: radius.to_abstand(),
            variante,
            beschreibung: None,
        }
    }
    pub const fn new_with_description(
        length: Length,
        radius: Radius,
        variante: Variante,
        description: &'static str,
    ) -> Self {
        Kreuzung {
            zugtyp: PhantomData,
            laenge: length.to_abstand(),
            radius: radius.to_abstand(),
            variante,
            beschreibung: Some(description),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Hash, Clone, Copy, anchor::Lookup)]
pub enum AnchorName {
    Anfang0,
    Ende0,
    Anfang1,
    Ende1,
}

impl<Z: Zugtyp> Zeichnen for Kreuzung<Z> {
    type AnchorName = AnchorName;
    type AnchorPoints = AnchorPoints;

    fn size(&self) -> canvas::Size {
        let size_kurve = kurve::size::<Z>(self.radius, self.angle());
        let height_beschraenkung = beschraenkung::<Z>();
        let height_kurven = 2. * size_kurve.height.to_abstand() - height_beschraenkung;
        canvas::Size::new(
            canvas::X(0.) + self.laenge.max(&size_kurve.width.to_abstand()),
            canvas::Y(0.) + height_beschraenkung.max(&height_kurven),
        )
    }

    fn zeichne(&self) -> Vec<canvas::Path> {
        // utility sizes
        let size: canvas::Size = self.size();
        let width: canvas::X = size.width;
        let half_width: canvas::X = canvas::X(0.5 * width.0);
        let start_x: canvas::X = canvas::X(0.);
        let height: canvas::Y = size.height;
        let half_height: canvas::Y = canvas::Y(0.5 * height.0);
        let start_y: canvas::Y = half_height - 0.5 * beschraenkung::<Z>();
        let angle = self.angle();
        let mut paths = Vec::new();
        // Geraden
        let horizontal_transformations =
            vec![canvas::Transformation::Translate(canvas::Vector::new(start_x, start_y))];
        let gedreht_transformations = vec![
            canvas::Transformation::Translate(canvas::Vector::new(half_width, half_height)),
            canvas::Transformation::Rotate(angle),
            // transformations with assumed inverted y-Axis
            canvas::Transformation::Translate(canvas::Vector::new(-half_width, half_height)),
            canvas::Transformation::Translate(canvas::Vector::new(start_x, -start_y)),
        ];
        paths.push(gerade::zeichne(
            self.zugtyp,
            self.laenge,
            true,
            horizontal_transformations.clone(),
            canvas::PathBuilder::with_normal_axis,
        ));
        paths.push(gerade::zeichne(
            self.zugtyp,
            self.laenge,
            true,
            gedreht_transformations.clone(),
            canvas::PathBuilder::with_invert_y,
        ));
        // Kurven
        if self.variante == Variante::MitKurve {
            paths.push(kurve::zeichne(
                self.zugtyp,
                self.radius,
                angle,
                kurve::Beschraenkung::Keine,
                horizontal_transformations,
                canvas::PathBuilder::with_normal_axis,
            ));
            paths.push(kurve::zeichne(
                self.zugtyp,
                self.radius,
                angle,
                kurve::Beschraenkung::Keine,
                gedreht_transformations,
                canvas::PathBuilder::with_invert_y,
            ));
        }
        // return value
        paths
    }

    fn fuelle(&self) -> Vec<canvas::Path> {
        // utility sizes
        let size: canvas::Size = self.size();
        let width: canvas::X = size.width;
        let half_width: canvas::X = canvas::X(0.5 * width.0);
        let start_x: canvas::X = canvas::X(0.);
        let height: canvas::Y = size.height;
        let half_height: canvas::Y = canvas::Y(0.5 * height.0);
        let start_y: canvas::Y = half_height - 0.5 * beschraenkung::<Z>();
        let angle = self.angle();
        let mut paths = Vec::new();
        // Geraden
        let horizontal_transformations =
            vec![canvas::Transformation::Translate(canvas::Vector::new(start_x, start_y))];
        let gedreht_transformations = vec![
            canvas::Transformation::Translate(canvas::Vector::new(half_width, half_height)),
            canvas::Transformation::Rotate(angle),
            // transformations with assumed inverted y-Axis
            canvas::Transformation::Translate(canvas::Vector::new(-half_width, half_height)),
            canvas::Transformation::Translate(canvas::Vector::new(start_x, -start_y)),
        ];
        paths.push(gerade::fuelle(
            self.zugtyp,
            self.laenge,
            horizontal_transformations.clone(),
            canvas::PathBuilder::with_normal_axis,
        ));
        paths.push(gerade::fuelle(
            self.zugtyp,
            self.laenge,
            gedreht_transformations.clone(),
            canvas::PathBuilder::with_invert_y,
        ));
        // Kurven
        if self.variante == Variante::MitKurve {
            paths.push(kurve::fuelle(
                self.zugtyp,
                self.radius,
                angle,
                horizontal_transformations,
                canvas::PathBuilder::with_normal_axis,
            ));
            paths.push(kurve::fuelle(
                self.zugtyp,
                self.radius,
                angle,
                gedreht_transformations,
                canvas::PathBuilder::with_invert_y,
            ));
        }
        // return value
        paths
    }

    fn beschreibung(&self) -> Option<(canvas::Position, &'static str)> {
        self.beschreibung.map(|text| {
            // utility sizes
            let size: canvas::Size = self.size();
            let start_x: canvas::X = canvas::X(0.);
            let height: canvas::Y = size.height;
            let half_height: canvas::Y = canvas::Y(0.5 * height.0);
            let start_y: canvas::Y = half_height - 0.5 * beschraenkung::<Z>();
            (
                canvas::Position {
                    point: canvas::Point::new(
                        start_x + 0.5 * self.laenge,
                        start_y + 0.5 * beschraenkung::<Z>(),
                    ),
                    winkel: Angle::new(0.),
                },
                text,
            )
        })
    }

    fn anchor_points(&self) -> Self::AnchorPoints {
        let canvas::Size { width, height } = self.size();
        let anfang0_x: canvas::X = canvas::X(0.);
        let ende0_x: canvas::X = anfang0_x + self.laenge;
        let half_height: canvas::Y = canvas::Y(0.) + 0.5 * height.to_abstand();
        let radius_abstand: canvas::Abstand<canvas::Radius> = self.radius;
        let radius_abstand_x: canvas::Abstand<canvas::X> = radius_abstand.as_x();
        let radius_abstand_y: canvas::Abstand<canvas::Y> = radius_abstand.as_y();
        let angle = self.angle();
        let anfang1_x: canvas::X = canvas::X(0.) + radius_abstand_x * angle.sin();
        let anfang1_y: canvas::Y = half_height + radius_abstand_y * (1. - angle.cos());
        let ende1_x: canvas::X = width - radius_abstand_x * angle.sin();
        let ende1_y: canvas::Y = half_height - radius_abstand_y * (1. - angle.cos());
        AnchorPoints {
            anfang_0: anchor::Anchor {
                position: canvas::Point { x: anfang0_x, y: half_height },
                direction: canvas::Vector { dx: canvas::X(-1.), dy: canvas::Y(0.) },
            },
            ende_0: anchor::Anchor {
                position: canvas::Point { x: ende0_x, y: half_height },
                direction: canvas::Vector { dx: canvas::X(1.), dy: canvas::Y(0.) },
            },
            anfang_1: anchor::Anchor {
                position: canvas::Point { x: anfang1_x, y: anfang1_y },
                direction: canvas::Vector {
                    dx: canvas::X(angle.cos()),
                    dy: canvas::Y(angle.sin()),
                },
            },
            ende_1: anchor::Anchor {
                position: canvas::Point { x: ende1_x, y: ende1_y },
                direction: canvas::Vector {
                    dx: canvas::X(-angle.cos()),
                    dy: canvas::Y(-angle.sin()),
                },
            },
        }
    }
}
