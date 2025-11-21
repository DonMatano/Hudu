//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const server = @import("server/init.zig");

pub fn init() !void {
    try server.run();
}
