//! This module defines the key data structures
//! contained in the export format
const std = @import("std");

// -----------------------
// NAMES
// -----------------------

/// Helper to avoid code repetition on our tagged unions
fn IndexedTag(T: type, comptime tag: []const u8, comptime index_name: []const u8) type {
    // This is easy to make
    const field_names: [2][]const u8 = .{ tag, index_name };

    const type_info = @typeInfo(T);
    const fields = type_info.@"union".fields;
    const field_idx = blk: {
        for (fields, 0..) |field, idx| {
            if (std.mem.eql(u8, field.name, tag)) {
                break :blk idx;
            }
        }
        break :blk null;
    };

    const tag_type = fields[field_idx].type;
    const field_types: [field_names.len]type = .{ tag_type, u32 };

    // These are already known
    const layout: std.builtin.Type.ContainerLayout = .auto;
    const backing_integer = null;
    const field_attrs: [field_names.len]std.builtin.Type.StructField.Attributes = @splat(.{});

    return @Struct(layout, backing_integer, &field_names, &field_types, &field_attrs);
}

fn WrappedTag(T: type, comptime tag: []const u8) type {
    const layout: std.builtin.Type.ContainerLayout = .auto;
    const backing_integer = null;
    const field_name: [1][]const u8 = .{tag};
    const field_type: [1]type = .{T};
    const field_attrs: [1]std.builtin.Type.StructField.Attributes = @splat(.{});
    return @Struct(layout, backing_integer, &field_name, &field_type, &field_attrs);
}

/// This is the `Name` data structure we'll use outside of the context of parsing
pub const Name = union(enum) {
    // { "num": { "pre": integer, "i": integer } "in": integer, }
    num: struct { pre: u32, i: u32 },
    // { "str": { "pre": integer, "str": string }, "in": integer, }
    str: struct {
        pre: u32,
        str: []const u8,
    },
};

// These are the parsing targets
pub const IndexedNumName = IndexedTag(Name, "num", "in");
pub const IndexedStrName = IndexedTag(Name, "str", "in");

// -----------------------
// LEVELS
// -----------------------

/// This is the `Level` data structure we'll use outside of the context of parsing
pub const Level = union(enum) {
    // { "succ": integer "il": integer, }
    succ: u32,

    // { "max": [integer, integer], "il": integer, }
    max: [2]u32,

    // { "imax": [integer, integer], "il": integer, }
    imax: [2]u32,

    // { "param": integer, "il": integer, }
    param: u32,
};

// These are the parsing targets
pub const IndexedSuccLevel = IndexedTag(Level, "succ", "il");
pub const IndexedMaxLevel = IndexedTag(Level, "max", "il");
pub const IndexedIMaxLevel = IndexedTag(Level, "imax", "il");
pub const IndexedParamLevel = IndexedTag(Level, "param", "il");

// -----------------------
// EXPRS
// -----------------------

/// This is the `Expr` data structure we'll use outside of the context of parsing
pub const Expr = union(enum) {
    // { "bvar": integer, "ie": integer, }
    bvar: u32,

    // { "sort": integer, "ie": integer, }
    sort: u32,

    // { "const": { "name": integer, "us": [integer] }, "ie": integer, }
    @"const": struct {
        name: u32,
        us: []u32,
    },

    // { "app": { "fn": integer, "arg": integer }, "ie": integer, }
    app: struct {
        @"fn": u32,
        arg: u32,
    },

    // { "lam": { "name": integer, "type": integer, "body": integer, "binderInfo": ... }, "ie": integer, }
    lam: struct {
        name: u32,
        type: u32,
        body: u32,
        binderInfo: BinderInfo,
    },

    // { "forallE": { "name": integer, "type": integer, "body": integer, "binderInfo": ... }, "ie": integer, }
    forallE: struct {
        name: u32,
        type: u32,
        body: u32,
        binderInfo: BinderInfo,
    },

    // { "letE": { "name": integer, "type": integer, "value": integer, "body": integer, "nondep": boolean }, "ie": integer, }
    letE: struct {
        name: u32,
        type: u32,
        value: u32,
        body: u32,
        nondep: bool,
    },

    // { "proj": { "typeName": integer, "idx": integer, "struct": integer }, "ie": integer, }
    proj: struct {
        typeName: u32,
        idx: u32,
        @"struct": u32,
    },

    // { "natVal": string, "ie": integer }
    natVal: []const u8,

    // { "strVal": string, "ie": integer, }
    strVal: []const u8,

    // { "mdata": { "expr": integer, "data": object }, "ie": integer }
    mdata: struct {
        expr: u32,
        // TODO: I need to add a `data` object
    },
};

pub const BinderInfo = enum { default, implicit, strictImplicit, instImplicit };

// These are the parsing targets
pub const IndexedBVarExpr = IndexedTag(Expr, "bvar", "ie");
pub const IndexedSortExpr = IndexedTag(Expr, "sort", "ie");
pub const IndexedConstExpr = IndexedTag(Expr, "const", "ie");
pub const IndexedAppExpr = IndexedTag(Expr, "app", "ie");
pub const IndexedLamExpr = IndexedTag(Expr, "lam", "ie");
pub const IndexedForallEExpr = IndexedTag(Expr, "forallE", "ie");
pub const IndexedLetEExpr = IndexedTag(Expr, "letE", "ie");
pub const IndexedProjExpr = IndexedTag(Expr, "proj", "ie");
pub const IndexedNatValExpr = IndexedTag(Expr, "natVal", "ie");
pub const IndexedStrValExpr = IndexedTag(Expr, "strVal", "ie");
pub const IndexedMDataExpr = IndexedTag(Expr, "mdata", "ie");

// -----------------------
// DECLS
// -----------------------

/// This is the `Decl` data structure we'll use outside of the context of parsing
pub const Decl = union(enum) {
    axiom: Axiom,
    def: Def,
    @"opaque": Opaque,
    thm: Thm,
    quot: Quot,
    inductive: Inductive,
};

// {
//     "axiom": {
//         "name": integer,
//         "levelParams": Array<integer>,
//         "type": integer,
//         "isUnsafe": boolean
//     }
// }
pub const Axiom = struct {
    name: u32,
    levelParams: []u32,
    type: u32,
    isUnsafe: bool,
};
pub const WrappedAxiom = WrappedTag(Axiom, "axiom");

// {
//     "def": {
//         "name": integer,
//         "levelParams": Array<integer>,
//         "type": integer,
//         "value": integer,
//         "hints": "opaque" | "abbrev" | {"regular": integer}
//         "safety": "unsafe" | "safe" | "partial"
//         "all": Array<integer>
//     }
// }
pub const Def = struct {
    name: u32,
    levelParams: []u32,
    type: u32,
    value: u32,
    hints: Hints,
    safety: Safety,
    all: []u32,
};
pub const WrappedDef = WrappedTag(Def, "def");

// {
//     "opaque": {
//         "name": integer,
//         "levelParams": Array<integer>,
//         "type": integer,
//         "value": integer,
//         "isUnsafe": boolean,
//         "all": Array<integer>
//     }
// }
pub const Opaque = struct {
    name: u32,
    levelParams: []u32,
    type: u32,
    value: u32,
    isUnsafe: bool,
    all: []u32,
};
pub const WrappedOpaque = WrappedTag(Opaque, "opaque");

// {
//     "thm": {
//         "name": integer,
//         "levelParams": Array<integer>,
//         "type": integer,
//         "value": integer,
//         "all": Array<integer>
//     }
// }
pub const Thm = struct {
    name: u32,
    levelParams: []u32,
    type: u32,
    value: u32,
    all: []u32,
};
pub const WrappedThm = WrappedTag(Thm, "thm");

// {
//     "quot": {
//         "name": integer,
//         "levelParams": Array<integer>,
//         "type": integer,
//         "kind": "type" | "ctor" | "lift" | "ind"
//     }
// }
pub const Quot = struct {
    name: u32,
    levelParams: []u32,
    type: u32,
    kind: QuotKind,
};
pub const WrappedQuot = WrappedTag(Quot, "quot");

const Hints = union(enum) {
    @"opaque",
    abbrev,
    regular: u32,
};

const Safety = enum { unsafe, safe, partial };

const QuotKind = enum { type, ctor, lift, ind };

// -----------------------
// INDUCTIVES
// -----------------------

// {
//     "inductive": {
//         "types": Array<InductiveVal>,
//         "ctors": Array<ConstructorVal>,
//         "recs": Array<RecursorVal>
//     }
// }
pub const Inductive = struct {
    types: []InductiveVal,
    ctors: []ConstructorVal,
    recs: []RecursorVal,
};
pub const WrappedInductive = WrappedTag(Inductive, "inductive");

// {
//     "name": integer,
//     "levelParams": Array<integer>,
//     "type": integer,
//     "numParams": integer,
//     "numIndices": integer,
//     "all": Array<integer>,
//     "ctors": Array<integer>,
//     "numNested": integer,
//     "isRec": boolean,
//     "isUnsafe": boolean,
//     "isReflexive": boolean,
// }
pub const InductiveVal = struct {
    name: u32,
    levelParams: []u32,
    type: u32,
    numParams: u32,
    numIndices: u32,
    all: []u32,
    ctors: []u32,
    numNested: u32,
    isRec: bool,
    isUnsafe: bool,
    isReflexive: bool,
};

// {
//     "name": integer,
//     "levelParams": Array<integer>,
//     "type": integer,
//     "induct": integer,
//     "cidx": integer,
//     "numParams": integer,
//     "numFields": integer,
//     "isUnsafe": boolean
// }
pub const ConstructorVal = struct {
    name: u32,
    levelParams: []u32,
    type: u32,
    induct: u32,
    cidx: u32,
    numParams: u32,
    numFields: u32,
    isUnsafe: bool,
};

// {
//     "name": integer,
//     "levelParams": Array<integer>,
//     "type": integer,
//     "all": Array<integer>,
//     "numParams": integer,
//     "numIndices": integer,
//     "numMotives": integer,
//     "numMinors": integer,
//     "rules": Array<RecursorRule>,
//     "k": boolean,
//     "isUnsafe": boolean
// }
pub const RecursorVal = struct {
    name: u32,
    levelParams: []u32,
    type: u32,
    all: []u32,
    numParams: u32,
    numIndices: u32,
    numMotives: u32,
    numMinors: u32,
    rules: []RecursorRule,
    k: bool,
    isUnsafe: bool,
};

// {
//     "ctor": integer,
//     "nfields": integer,
//     "rhs": integer
// }
pub const RecursorRule = struct {
    ctor: u32,
    nfields: u32,
    rhs: u32,
};
