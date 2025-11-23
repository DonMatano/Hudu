const std = @import("std");
const net = std.net;
const mem = std.mem;
const enums = std.enums;
const meta = std.meta;
pub const Request = struct {
    route: []const u8,
    method: Method,
    protocol: HTTPProtocol,
};

pub const Method = enum {
    GET,
    fn mapMethod(method: []const u8) !Method {
        return meta.stringToEnum(Method, method) orelse error.MissingHTTPMethod;
    }
};
pub const HTTPProtocol = enum {
    @"1.1",
    fn mapProtocol(protocol_string: []const u8) !HTTPProtocol {
        std.debug.print("got protocol {s}", .{protocol_string});
        if (mem.eql(u8, mem.trim(u8, protocol_string, "\r\n"), "HTTP/1.1")) {
            return .@"1.1";
        } else {
            return error.MissingHTTPProtocol;
        }
    }
};
// TODO LOOK how we can get the map working
// const http_protocol_map = enums.EnumMap([]const u8, HTTPProtocol).init(.{
//     .OnePointOne = "HTTP/1.1",
// });

const HTTPProtocolError = error{MalformedHTTPRequestLine};
pub fn parseHttpConnection(connection: *net.Server.Connection) !Request {
    var connection_read_buffer: [1028]u8 = undefined;
    var reader_wrapper = connection.stream.reader(&connection_read_buffer);
    var reader = &reader_wrapper.interface_state;
    // Get the first line
    const request_first_line = try reader.takeDelimiterInclusive('\n');
    var splits = mem.splitScalar(u8, request_first_line, ' ');
    // Method Route Protocol
    const method = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;
    const route = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;
    const protocol = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;

    const enumMethod = try Method.mapMethod(method);
    const enumProtocol = try HTTPProtocol.mapProtocol(protocol);
    return .{
        .route = route,
        .method = enumMethod,
        .protocol = enumProtocol,
    };
}
