const std = @import("std");
const net = std.net;
const mem = std.mem;
const enums = std.enums;
const meta = std.meta;
const Io = std.Io;
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
        const trimmed = protocol_string[0..(protocol_string.len - 2)];
        if (mem.eql(u8, trimmed, "HTTP/1.1")) {
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

const StartLineData = struct {
    route: []const u8,
    method: Method,
    protocol: HTTPProtocol,
    fn parseStartLine(reader: *Io.Reader) !StartLineData {
        const request_first_line = try reader.peekDelimiterInclusive('\n');
        var splits = mem.splitScalar(u8, request_first_line, ' ');
        // Method Route Protocol
        // TODO: Update so that we can handle a CRLF possiblity on the first line
        const method = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;
        const route = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;
        const protocol = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;

        const enumMethod = try Method.mapMethod(method);
        const enumProtocol = try HTTPProtocol.mapProtocol(protocol);
        return .{
            .method = enumMethod,
            .route = route,
            .protocol = enumProtocol,
        };
    }
};
pub fn parseHttpConnection(connection: *net.Server.Connection) !Request {
    var connection_read_buffer: [1028]u8 = undefined;
    var reader_wrapper = connection.stream.reader(&connection_read_buffer);
    const reader = &reader_wrapper.interface_state;
    // Get the first line
    const FirstLine = try StartLineData.parseStartLine(reader);
    return .{
        .route = FirstLine.route,
        .method = FirstLine.method,
        .protocol = FirstLine.protocol,
    };
}
