const std = @import("std");
pub const Config = struct {
    port: u16,
    max_req_size: usize = 4 * 1024,
    max_res_size: usize = 1024,
};

const DynamicParamsValue = union(enum) {
    int: i64,
    string: []const u8,
    boolean: bool,
};

pub const Context = struct {
    params: std.StringHashMap(DynamicParamsValue),
};

pub const HTTP_METHOD = enum {
    get,
    post,
    delete,
    create,
    patch,
    put,
};

pub const HttpRequest = struct {
    path: []const u8,
    method: HTTP_METHOD,
};

pub const Handler = *const fn (context: Context, request: HttpRequest) anyerror!void;
