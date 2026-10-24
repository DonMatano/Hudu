const std = @import("std");
const Hudu = @import("Hudu");

const Context = Hudu.types.Context;
const HttpRequest = Hudu.types.HttpRequest;

const app_log = std.log.scoped(.AppLog);

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();
    var hudu_server = try Hudu.init(.{ .port = 5758 }, io, allocator);
    var router = Hudu.Router.init(allocator);
    try router.addRoute(.{
        .handler = getAll,
        .path = "/",
        .method = .get,
    });
    hudu_server.addRouter(router);
    try hudu_server.listen(io, allocator);
    defer hudu_server.deinit(io);
}

fn getAll(context: Hudu.types.Context, request: HttpRequest) !void {
    _ = context;
    app_log.info("Got get of path {s}", .{request.path});
}
