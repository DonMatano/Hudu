const std = @import("std");
const types = @import("types.zig");
const Allocator = std.mem.Allocator;

// TODO: When handling dynamic params and query we'll update this to Radix tree.
// Currently just using maps to get things rolling.

get_routes: std.StringHashMap(Route),

const Router = @This();
pub const Route = struct {
    path: []const u8,
    method: types.HTTP_METHOD,
    handler: types.Handler,
};

pub fn init(alloc: Allocator) Router {
    // const get_routes = std.StringHashMap(Route).init(alloc);
    return .{
        .get_routes = .init(alloc),
    };
}

pub fn addRoute(router: *Router, comptime route: Route) !void {
    return switch (route.method) {
        .get => router.get_routes.put(route.path, route),
        else => return error.UnhandledRouteMethod,
    };
}
