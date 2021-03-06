//! Take a sum-type enum and produce an associated enum without any data

use proc_macro2::TokenStream;
use quote::{format_ident, quote};

pub fn make_enum(args: Vec<syn::NestedMeta>, ast: syn::ItemEnum) -> TokenStream {
    // parse args
    let mut arg_vis: Option<syn::Visibility> = None;
    let mut arg_ident: Option<syn::Ident> = None;
    let mut errors = Vec::new();
    for arg in &args {
        match arg {
            syn::NestedMeta::Meta(meta) => match meta {
                syn::Meta::List(list) => {
                    errors.push(format!(
                        "List arguments not supported, but {} was given",
                        quote!(#list)
                    ));
                },
                syn::Meta::NameValue(name) => {
                    errors.push(format!(
                        "NameValue arguments not supported, but {} was given",
                        quote!(#name)
                    ));
                },
                syn::Meta::Path(syn::Path { segments, .. }) => {
                    let mut iter = segments.into_iter();
                    if let Some(syn::PathSegment { ident, .. }) = iter.next() {
                        if iter.count() == 0 {
                            let id = ident.to_string();
                            if let Ok(vis) = syn::parse_str(&id) {
                                if arg_vis.is_none() {
                                    arg_vis = Some(vis);
                                } else {
                                    errors.push(format!(
                                        "duplicate visibility argument {}",
                                        quote!(#id)
                                    ));
                                }
                            } else if arg_ident.is_none() {
                                arg_ident = Some(ident.clone());
                            } else {
                                errors.push(format!(
                                    "misspelled visibility of leftover argument {}",
                                    quote!(#id)
                                ));
                            }
                        } else {
                            errors.push(format!("leftover path segments {}", quote! {iter}));
                        }
                    } else {
                        errors.push(format!("empty path segments {}", quote!(#segments)))
                    }
                },
            },
            syn::NestedMeta::Lit(lit) => {
                errors.push(format!(
                    "Literal arguments not supported, but {} was given",
                    quote!(#lit)
                ));
            },
        }
    }
    if errors.len() > 0 {
        let error_message = errors.join("\n");
        return quote! {
            compile_error!(#error_message);
            #ast
        }
    }

    let syn::ItemEnum { vis, ident, variants, .. } = &ast;
    let enum_vis = arg_vis.unwrap_or(vis.clone());
    let enum_ident = arg_ident.unwrap_or(format_ident!("{}Enum", ident));
    let enum_variants: Vec<syn::Ident> = variants.iter().map(|v| v.ident.clone()).collect();
    let enum_variants_str: Vec<String> = enum_variants.iter().map(syn::Ident::to_string).collect();
    quote!(
        #ast

        #[derive(Debug, Clone, Copy, PartialEq, Eq)]
        #enum_vis enum #enum_ident {
            #(#enum_variants),*
        }
        impl std::fmt::Display for #enum_ident {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                let display = match self {
                    #(#enum_ident::#enum_variants => #enum_variants_str),*
                };
                write!(f, "{}", display)
            }
        }
        impl From<#enum_ident> for String {
            fn from(modus: #enum_ident) -> Self {
                format!("{}", modus)
            }
        }

        impl std::str::FromStr for #enum_ident {
            type Err = String;

            fn from_str(s: &str) -> Result<Self, Self::Err> {
                match s {
                    #(#enum_variants_str => Ok(#enum_ident::#enum_variants)),*,
                    _ => Err(s.to_string()),
                }
            }
        }
    )
}
