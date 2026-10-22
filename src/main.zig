const std = @import("std");
const Hudu = @import("Hudu");

pub fn main(init: std.process.Init) !void {
    var hudu_server = try Hudu.init(.{ .port = 5758 }, init.io, init.arena.allocator());
    try hudu_server.run(init.io, init.arena.allocator());
}
