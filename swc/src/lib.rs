// #[macro_use]
extern crate libc;
extern crate swc_common;
extern crate swc_ecma_parser;
use std::ffi::CStr;

use libc::c_char;
use swc_common::sync::Lrc;
use swc_common::{
    errors::{ColorConfig, Handler},
    FileName,
    // FilePathMapping,
    SourceMap,
};
use swc_ecma_parser::{lexer::Lexer, Parser, StringInput, Syntax};

#[no_mangle]
pub extern "C" fn swc_is_valid_javascript(s: *const c_char) -> bool {
    let cm: Lrc<SourceMap> = Default::default();

    let c_str = unsafe {
        assert!(!s.is_null());

        CStr::from_ptr(s)
    };

    let r_str = c_str.to_str().unwrap();
    let handler = Handler::with_tty_emitter(ColorConfig::Auto, true, false, Some(cm.clone()));

    // Real usage
    // let fm = cm
    //     .load_file(Path::new("test.js"))
    //     .expect("failed to load test.js");
    let fm = cm.new_source_file(FileName::Custom("test.js".into()), r_str.into());
    let lexer = Lexer::new(
        // We want to parse ecmascript
        Syntax::Es(Default::default()),
        // EsVersion defaults to es5
        Default::default(),
        StringInput::from(&*fm),
        None,
    );

    let mut parser = Parser::new_from(lexer);

    // for e in parser.take_errors() {
    //     e.into_diagnostic(&handler).emit();
    //     return false;
    // }

    let _module = parser.parse_script().map_err(|mut e| {
        // Unrecoverable fatal error occurred
        println!("errors {:?}", e);
        e.into_diagnostic(&handler).emit();
        return false;
    });

    return true;
}
