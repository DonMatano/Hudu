const std = @import("std");
const Alloc = std.mem.Allocator;

const types = @import("types.zig");

const Router = @This();
const router_log = std.log.scoped(.RouterLog);

pub const Route = struct {
    name: []u8 = "Unnamed route",
    method: types.HTTP_METHOD,
    path: []u8,
    handler: *const fn (anytype) void,
};

list_of_routes: std.ArrayList(Route),

routes_map: std.StringHashMap(Route),

pub fn init(alloc: Alloc) !Router {
    return .{
        .list_of_routes = try .initCapacity(alloc, 10),
        .routes_map = .init(alloc),
    };
}

pub fn addRoute(self: *Router, route: Route) !void {
    try self.list_of_routes.addOne(route);
    try self.routes_map.put(route.name, route);
}

pub fn handlePath(self: Router, path: []u8) !void {
    const route = self.routes_map.get(path) orelse {
        router_log.err("Missing Route for path {s}", .{path});
        return error.MissingRoute;
    };

    route.handler();
}

pub fn deinit(self: *Router, alloc: Alloc) void {
    try self.list_of_routes.deinit(alloc);
    try self.routes_map.clearAndFree();
}
