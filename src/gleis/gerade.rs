//! Definition und zeichnen einer Gerade

// TODO
// non_ascii_idents might be stabilized soon
// use english names until then :(
// (nightly crashes atm on Sized-check)
// https://github.com/rust-lang/rust/issues/55467

use std::hash::Hash;
use std::marker::PhantomData;

use serde::{Deserialize, Serialize};

use super::anchor;
use super::types::*;

/// Definition einer Gerade
#[derive(zugkontrolle_derive::Clone, zugkontrolle_derive::Debug, Serialize, Deserialize)]
pub struct Gerade<Z> {
    pub zugtyp: PhantomData<Z>,
    pub länge: canvas::Abstand<canvas::X>,
    pub beschreibung: Option<String>,
}
impl<Z> Gerade<Z> {
    pub const fn new(length: Länge) -> Self {
        Gerade { zugtyp: PhantomData, länge: length.to_abstand(), beschreibung: None }
    }

    pub fn new_with_description(length: Länge, description: impl Into<String>) -> Self {
        Gerade {
            zugtyp: PhantomData,
            länge: length.to_abstand(),
            beschreibung: Some(description.into()),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Hash, Clone, Copy, anchor::Lookup)]
pub enum AnchorName {
    Anfang,
    Ende,
}

impl<Z: Zugtyp> Zeichnen for Gerade<Z> {
    type AnchorName = AnchorName;
    type AnchorPoints = AnchorPoints;

    fn size(&self) -> canvas::Size {
        size::<Z>(self.länge)
    }

    fn zeichne(&self) -> Vec<canvas::Path> {
        vec![zeichne(
            self.zugtyp,
            self.länge,
            true,
            Vec::new(),
            canvas::PathBuilder::with_normal_axis,
        )]
    }

    fn fuelle(&self) -> Vec<canvas::Path> {
        vec![fuelle(self.zugtyp, self.länge, Vec::new(), canvas::PathBuilder::with_normal_axis)]
    }

    fn beschreibung(&self) -> Option<(canvas::Position, &String)> {
        self.beschreibung.as_ref().map(|text| {
            (
                canvas::Position {
                    point: canvas::Point::new(
                        canvas::X(0.) + 0.5 * self.länge,
                        canvas::Y(0.) + 0.5 * beschränkung::<Z>(),
                    ),
                    winkel: Angle::new(0.),
                },
                text,
            )
        })
    }

    fn innerhalb(&self, relative_position: canvas::Vector) -> bool {
        innerhalb::<Z>(self.länge, relative_position)
    }

    fn anchor_points(&self) -> Self::AnchorPoints {
        let gleis_links: canvas::X = canvas::X(0.);
        let gleis_rechts: canvas::X = gleis_links + self.länge;
        let beschraenkung_mitte: canvas::Y = canvas::Y(0.) + 0.5 * beschränkung::<Z>();
        AnchorPoints {
            anfang: anchor::Anchor {
                position: canvas::Point { x: gleis_links, y: beschraenkung_mitte },
                direction: canvas::Vector::new(canvas::X(-1.), canvas::Y(0.)),
            },
            ende: anchor::Anchor {
                position: canvas::Point { x: gleis_rechts, y: beschraenkung_mitte },
                direction: canvas::Vector::new(canvas::X(1.), canvas::Y(0.)),
            },
        }
    }
}

pub(crate) fn size<Z: Zugtyp>(länge: canvas::Abstand<canvas::X>) -> canvas::Size {
    canvas::Size::new(länge, beschränkung::<Z>())
}

pub(crate) fn zeichne<Z, P, A>(
    _zugtyp: PhantomData<Z>,
    länge: canvas::Abstand<canvas::X>,
    beschränkungen: bool,
    transformations: Vec<canvas::Transformation>,
    with_invert_axis: impl FnOnce(
        &mut canvas::PathBuilder<canvas::Point, canvas::Arc>,
        Box<dyn for<'s> FnOnce(&'s mut canvas::PathBuilder<P, A>)>,
    ),
) -> canvas::Path
where
    Z: Zugtyp,
    P: From<canvas::Point> + canvas::ToPoint,
    A: From<canvas::Arc> + canvas::ToArc,
{
    let mut path_builder = canvas::PathBuilder::new();
    with_invert_axis(
        &mut path_builder,
        Box::new(move |builder| zeichne_internal::<Z, P, A>(builder, länge, beschränkungen)),
    );
    path_builder.build_under_transformations(transformations)
}

fn zeichne_internal<Z, P, A>(
    path_builder: &mut canvas::PathBuilder<P, A>,
    länge: canvas::Abstand<canvas::X>,
    beschränkungen: bool,
) where
    Z: Zugtyp,
    P: From<canvas::Point> + canvas::ToPoint,
    A: From<canvas::Arc> + canvas::ToArc,
{
    let gleis_links: canvas::X = canvas::X(0.);
    let gleis_rechts: canvas::X = gleis_links + länge;
    let beschraenkung_oben: canvas::Y = canvas::Y(0.);
    let beschraenkung_unten: canvas::Y = beschraenkung_oben + beschränkung::<Z>();
    let gleis_oben: canvas::Y = beschraenkung_oben + abstand::<Z>();
    let gleis_unten: canvas::Y = gleis_oben + Z::SPURWEITE.to_abstand();
    // Beschränkungen
    if beschränkungen {
        path_builder.move_to(canvas::Point::new(gleis_links, beschraenkung_oben).into());
        path_builder.line_to(canvas::Point::new(gleis_links, beschraenkung_unten).into());
        path_builder.move_to(canvas::Point::new(gleis_rechts, beschraenkung_oben).into());
        path_builder.line_to(canvas::Point::new(gleis_rechts, beschraenkung_unten).into());
    }
    // Gleis
    path_builder.move_to(canvas::Point::new(gleis_links, gleis_oben).into());
    path_builder.line_to(canvas::Point::new(gleis_rechts, gleis_oben).into());
    path_builder.move_to(canvas::Point::new(gleis_links, gleis_unten).into());
    path_builder.line_to(canvas::Point::new(gleis_rechts, gleis_unten).into());
    // Beschreibung
}

pub(crate) fn fuelle<Z, P, A>(
    _zugtyp: PhantomData<Z>,
    länge: canvas::Abstand<canvas::X>,
    transformations: Vec<canvas::Transformation>,
    with_invert_axis: impl FnOnce(
        &mut canvas::PathBuilder<canvas::Point, canvas::Arc>,
        Box<dyn for<'s> FnOnce(&'s mut canvas::PathBuilder<P, A>)>,
    ),
) -> canvas::Path
where
    Z: Zugtyp,
    P: From<canvas::Point> + canvas::ToPoint,
    A: From<canvas::Arc> + canvas::ToArc,
{
    let mut path_builder = canvas::PathBuilder::new();
    with_invert_axis(
        &mut path_builder,
        Box::new(move |builder| fuelle_internal::<Z, P, A>(builder, länge)),
    );
    path_builder.build_under_transformations(transformations)
}

fn fuelle_internal<Z, P, A>(
    path_builder: &mut canvas::PathBuilder<P, A>,
    länge: canvas::Abstand<canvas::X>,
) where
    Z: Zugtyp,
    P: From<canvas::Point> + canvas::ToPoint,
    A: From<canvas::Arc> + canvas::ToArc,
{
    // Koordinaten
    let gleis_links: canvas::X = canvas::X(0.);
    let gleis_rechts: canvas::X = gleis_links + länge;
    let beschraenkung_oben: canvas::Y = canvas::Y(0.);
    let gleis_oben: canvas::Y = beschraenkung_oben + abstand::<Z>();
    let gleis_unten: canvas::Y = gleis_oben + Z::SPURWEITE.to_abstand();
    // Zeichne Umriss
    path_builder.move_to(canvas::Point::new(gleis_links, gleis_oben).into());
    path_builder.line_to(canvas::Point::new(gleis_links, gleis_unten).into());
    path_builder.line_to(canvas::Point::new(gleis_rechts, gleis_unten).into());
    path_builder.line_to(canvas::Point::new(gleis_rechts, gleis_oben).into());
    path_builder.line_to(canvas::Point::new(gleis_links, gleis_oben).into());
}

pub(crate) fn innerhalb<Z: Zugtyp>(
    länge: canvas::Abstand<canvas::X>,
    relative_position: canvas::Vector,
) -> bool {
    relative_position.dx >= canvas::X(0.).to_abstand()
        && relative_position.dx <= länge
        && relative_position.dy >= abstand::<Z>()
        && relative_position.dy <= abstand::<Z>() + Z::SPURWEITE.to_abstand()
}
