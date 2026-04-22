pub const ExporterHeader = struct { name: []const u8, version: []const u8 };

pub const LeanHeader = struct { githash: []const u8, version: []const u8 };

pub const FormatHeader = struct { version: []const u8 };

pub const MetaHeader = struct {
    exporter: ExporterHeader,
    lean: LeanHeader,
    format: FormatHeader,
};

pub const Header = struct { meta: MetaHeader };
