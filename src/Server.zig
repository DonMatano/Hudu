const std = @import("std");
const hudu_types = @import("server/types.zig");
const Router = @import("server/Router.zig");
const Allocator = std.mem.Allocator;
const http = std.http;
const Io = std.Io;
const net = Io.net;

const server_log = std.log.scoped(.ServerLog);

const Server = @This();

config: hudu_types.Config,
local_server: net.Server,
router: ?Router = null,

pub fn init(config: hudu_types.Config, io: Io, allocator: Allocator) !Server {
    _ = allocator;
    const address = try net.IpAddress.parseIp4("127.0.0.1", config.port);
    const s = try address.listen(io, .{ .reuse_address = true });

    return .{
        .config = config,
        .local_server = s,
    };
}

pub fn addRouter(s: *Server, r: Router) void {
    s.router = r;
}

pub fn listen(s: *Server, io: Io, allocator: Allocator) !void {
    std.log.info("\nStarting server on port: {d}\n", .{s.config.port});
    const receive_buffer = try allocator.alloc(u8, s.config.max_req_size);
    const send_buffer = try allocator.alloc(u8, s.config.max_res_size);

    // const response = "Hello World!";

    while (true) {
        var connection = try s.local_server.accept(io);
        defer connection.close(io);
        // const req = try httpRequest.parseHttpConnection(&connection, alloc);

        // std.debug.print("Request: {any}\n", .{req});
        var conn_reader = connection.reader(io, receive_buffer);
        var conn_writer = connection.writer(io, send_buffer);
        var http_server = std.http.Server.init(&conn_reader.interface, &conn_writer.interface);
        while (http_server.reader.state == .ready) {
            server_log.debug("server status {any}", .{http_server.reader.state});
            var request = http_server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => return,
                else => {
                    server_log.err("closing http connection: {s}", .{@errorName(err)});
                    return;
                },
            };
            const route = try getRoute(&request, s.router.?);
            const context: hudu_types.Context = .{};
            const req: hudu_types.HttpRequest = .{ .method = route.method, .path = route.path };
            try route.handler(context, req);
            // server_log.debug("Got route of path {s}", .{route.path});
            // server_log.debug("server status {any}", .{http_server.reader.state});
            // var body_payload = try allocator.alloc(u8, s.config.max_res_size);
            // if (request.head.content_length != null) {
            //     server_log.debug("content length {d}", .{request.head.content_length.?});
            // }
            // var body_reader = http_server.reader.bodyReader(body_payload, request.head.transfer_encoding, request.head.content_length);
            // const read_bytes = try body_reader.readSliceShort(body_payload);
            // server_log.debug("Received Body: \n{s}\n", .{body_payload[0..read_bytes]});
            // try request.respond(response, .{ .status = .ok });
        }
        // var read_slice_buffer: [1028]u8 = undefined;
        // std.debug.print("{s}", .{byte_as_string});
        // try stdout.print("{s}", .{se});
        // try stdout.flush();

        // std.log.info("\nResponse: \n {s}", .{response});
        // try writer.writeAll(response);
        // try writer.flush();
    }
}

fn getRoute(req: *http.Server.Request, router: Router) !Router.Route {
    return switch (req.head.method) {
        .GET => return router.get_routes.get(req.head.target) orelse {
            server_log.err("Failed to get route path {s}", .{req.head.target});
            return error.MissingGetRoute;
        },
        else => {
            server_log.err("Failed to get method {s}", .{@tagName(req.head.method)});
            return error.MissingMethodImplementation;
        },
    };
}

pub fn deinit(s: *Server, io: Io) void {
    s.local_server.deinit(io);
}
