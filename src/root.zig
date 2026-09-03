//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const server = @import("server/init.zig");

pub fn init(io: std.Io) !void {
    try server.run(.{ .port = 5758 }, io);
}
