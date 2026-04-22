// NAMES

// {
//     "num": {
//         "pre": integer,
//         "i": integer
//     }
//     "in": integer,
// }
pub const IndexedNumName = struct {
    num: NumName,
    in: u32,
};
pub const NumName = struct {
    pre: u32,
    i: u32,
};

// {
//     "str": {
//         "pre": integer,
//         "str": string
//     },
//     "in": integer,
// }
pub const IndexedStrName = struct {
    str: StrName,
    in: u32,
};

pub const StrName = struct {
    pre: u32,
    str: []const u8,
};

pub const Name = union(enum) {
    num: NumName,
    str: StrName,
};

// LEVELS

pub const IndexedSuccLevel = struct {};

pub const LevelExpr = union(enum) {
    // {
    //     "succ": integer
    //     "il": integer,
    // }
    succ: struct {
        inner: u32,
    },

    // {
    //     "max": [integer, integer],
    //     "il": integer,
    // }
    max: struct {
        left: u32,
        right: u32,
    },

    // {
    //     "imax": [integer, integer],
    //     "il": integer,
    // }
    imax: struct {
        left: u32,
        right: u32,
    },

    // {
    //     "param": integer,
    //     "il": integer,
    // }
    param: struct {
        param: u32,
    },
};
