//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const Server = @import("Server.zig");
pub const types = @import("server/types.zig");

pub const Router = @import("server/Router.zig");

pub fn init(config: types.Config, io: std.Io, alloc: std.mem.Allocator) !Server {
    return Server.init(config, io, alloc);
}

pub fn run(server: *Server, io: std.Io, alloc: std.mem.Allocator) !void {
    server.run(io, alloc);
}
