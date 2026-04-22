//! This file has all the parsing logic

const std = @import("std");
const json = std.json;
const data = @import("data.zig");

pub fn findLineKind(obj: json.ObjectMap) ?LineKind {
    var it = obj.iterator();
    while (it.next()) |entry| {
        if (std.meta.stringToEnum(LineKind, entry.key_ptr.*)) |k| return k;
    }
    return null;
}

pub const Kind = enum {
    name,
    level,
    expr,
    decl,

    pub fn associateData(self: Kind) type {
        switch (self) {
            .name => return data.Name,
            .level => return data.Level,
            .expr => return data.Expr,
            .decl => return data.Decl,
        }
    }
};

pub const LineKind = enum {
    // Names
    str,
    num,
    // Levels
    succ,
    max,
    imax,
    param,
    // Exprs
    bvar,
    sort,
    @"const",
    app,
    lam,
    forallE,
    letE,
    proj,
    natVal,
    strVal,
    mdata,
    // Decls
    axiom,
    def,
    @"opaque",
    thm,
    quot,
    inductive,

    pub fn toKind(self: LineKind) Kind {
        switch (self) {
            .str, .num => return .name,
            .succ, .max, .imax, .param => return .level,
            .bvar, .sort, .@"const", .app, .lam, .forallE, .letE, .proj, .natVal, .strVal, .mdata => return .expr,
            .axiom, .def, .@"opaque", .thm, .quot, .inductive => return .decl,
        }
    }

    pub fn associatedType(self: LineKind) type {
        switch (self) {
            .str => return data.IndexedStrName,
            .num => return data.IndexedNumName,
            .succ => return data.IndexedSuccLevel,
            .max => return data.IndexedMaxLevel,
            .imax => return data.IndexedIMaxLevel,
            .param => return data.IndexedParamLevel,
            .bvar => return data.IndexedBVarExpr,
            .sort => return data.IndexedSortExpr,
            .@"const" => return data.IndexedConstExpr,
            .app => return data.IndexedAppExpr,
            .lam => return data.IndexedLamExpr,
            .forallE => return data.IndexedForallEExpr,
            .letE => return data.IndexedLetEExpr,
            .proj => return data.IndexedProjExpr,
            .natVal => return data.IndexedNatValExpr,
            .strVal => return data.IndexedStrValExpr,
            .mdata => return data.IndexedMDataExpr,
            .axiom => return data.WrappedAxiom,
            .def => return data.WrappedDef,
            .@"opaque" => return data.WrappedOpaque,
            .thm => return data.WrappedThm,
            .quot => return data.WrappedQuot,
            .inductive => return data.WrappedInductive,
        }
    }
};
