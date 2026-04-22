//! This module defines the key data structures
//! contained in the export format

// -----------------------
// NAMES
// -----------------------

// { "num": { "pre": integer, "i": integer } "in": integer, }
pub const IndexedNumName = struct {
    num: NumName,
    in: u32,
};

pub const NumName = struct {
    pre: u32,
    i: u32,
};

// { "str": { "pre": integer, "str": string }, "in": integer, }
pub const IndexedStrName = struct {
    str: StrName,
    in: u32,
};

pub const StrName = struct {
    pre: u32,
    str: []const u8,
};

/// This is the `Name` data structure we'll use outside of the context of parsing
pub const Name = union(enum) {
    num: NumName,
    str: StrName,
};

// -----------------------
// LEVELS
// -----------------------

// { "succ": integer "il": integer, }
pub const IndexedSuccLevel = struct {
    succ: u32,
    il: u32,
};

// { "max": [integer, integer], "il": integer, }
pub const IndexedMaxLevel = struct {
    max: [2]u32,
    il: u32,
};

// { "imax": [integer, integer], "il": integer, }
pub const IndexedIMaxLevel = struct {
    imax: [2]u32,
    il: u32,
};

// { "param": integer, "il": integer, }
pub const IndexedParamLevel = struct {
    param: u32,
    il: u32,
};

/// This is the `Level` data structure we'll use outside of the context of parsing
pub const Level = union(enum) {
    succ: u32,

    max: struct {
        left: u32,
        right: u32,
    },

    imax: struct {
        left: u32,
        right: u32,
    },

    param: u32,
};

// -----------------------
// EXPRS
// -----------------------

/// This is the `Expr` data structure we'll use o utside of the context of parsing
pub const Expr = union(enum) {
    bvar: u32,
    sort: u32,
    @"const": struct {
        name: u32,
        us: []u32,
    },
    app: struct {
        @"fn": u32,
        arg: u32,
    },
    lam: struct {
        name: u32,
        type: u32,
        body: u32,
        binderInfo: BinderInfo,
    },
    forallE: struct {
        name: u32,
        type: u32,
        body: u32,
        binderInfo: BinderInfo,
    },
    letE: struct {
        name: u32,
        type: u32,
        value: u32,
        body: u32,
        nondep: bool,
    },
    proj: struct {
        typeName: u32,
        idx: u32,
        @"struct": u32,
    },
    natLit: struct {
        natVal: []const u8,
    },
    strLit: struct {
        strVal: []const u8,
    },
    mdata: struct {
        expr: u32,
    },
};

pub const BinderInfo = enum { default, implicit, strictImplicit, instImplicit };
