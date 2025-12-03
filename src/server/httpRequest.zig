const std = @import("std");
const net = std.net;
const mem = std.mem;
const heap = std.heap;
const enums = std.enums;
const meta = std.meta;
const log = std.log;
const Io = std.Io;
const testing = std.testing;
const httpStatus = @import("httpStatus.zig");
pub const Request = struct {
    route: []const u8,
    method: Method,
    protocol: HTTPProtocol,
    headers: std.StringHashMap([]const u8),

    pub fn init() Request {
        return .{
            .route = "",
            .method = undefined,
            .protocol = undefined,
            .headers = undefined,
        };
    }
};

pub const Method = enum {
    GET,
    POST,
    OPTIONS,
    PUT,
    DELETE,
    CONNECT,
    HEAD,
    TRACE,
    fn mapMethod(method: []const u8) !Method {
        return meta.stringToEnum(Method, method) orelse {
            std.log.err("Method {s} is not implemented", .{method});
            return HTTPErrors.NotImplemented;
        };
    }
};
pub const HTTPProtocol = enum {
    @"1.1",
    fn mapProtocol(protocol_string: []const u8) !HTTPProtocol {
        if (mem.eql(u8, protocol_string, "HTTP/1.1")) {
            return .@"1.1";
        } else {
            std.log.err("Failed to get protocal for {s}", .{protocol_string});
            return error.MissingHTTPProtocol;
        }
    }
};
// TODO LOOK how we can get the map working
// const http_protocol_map = enums.EnumMap([]const u8, HTTPProtocol).init(.{
//     .OnePointOne = "HTTP/1.1",
// });

const HTTPProtocolError = error{MalformedHTTPRequestLine};
const HTTPErrors = error{ BadRequest, NotImplemented };

// TODO: Handle Custom Methods

fn parseMethod(buf: []const u8, req: *Request) !usize {
    const endIndx = std.mem.indexOf(u8, buf, " ") orelse return HTTPErrors.BadRequest;
    const method_string = buf[0..endIndx];
    const separatorTokens = "()<>@,;:\\\"/[]?={} \t";
    const hasSeperator = std.mem.indexOfAny(u8, method_string, separatorTokens);
    if (hasSeperator != null) {
        log.err("method {s} found with separator", .{method_string});
        return HTTPErrors.BadRequest;
    }
    const method = try Method.mapMethod(method_string);
    req.method = method;
    return method_string.len + 1; // Remove the space
}
const HeaderData = struct {
    headers: std.StringHashMap([]const u8),
    pub fn parseHeader(reader: *Io.Reader, alloc: mem.Allocator) !HeaderData {
        var header = HeaderData{ .headers = std.StringHashMap([]const u8).init(alloc) };
        // Read till we find the empty line of CRLFCRLF
        var readRequestLine = false;
        read: while (reader.takeDelimiterInclusive('\n')) |data| {
            // If len is just two bytes of CRLF break We assume it's the end of headers
            if (data.len == 2) { // 2 bytes \r and \n
                break :read;
            }
            // Else check if it's first message line
            if (!readRequestLine) {
                readRequestLine = true;
                continue :read;
            }
            // Else handle a header
            const data_without_crlf = data[0 .. data.len - 2];
            const index_of_first_colon = mem.indexOfScalar(u8, data_without_crlf, ':') orelse {
                std.log.err("Missing collon in field value", .{});
                return error.MalformedHTTPHeader;
            };
            // TODO: Ensure in the future to check the validity of the field_value
            const field_value = data_without_crlf[0..index_of_first_colon];
            const field_content = data_without_crlf[index_of_first_colon + 1 ..];
            std.debug.print("Adding Header {s}: {s}\n", .{ field_value, field_content });
            try header.headers.put(field_value, field_content);
        } else |err| switch (err) {
            error.EndOfStream => break :read,
            else => return err
        }
        return header;
    }
    pub fn getHeader(self: *HeaderData, headerKey: []const u8) ?[]const u8 {
        return self.headers.get(headerKey);
    }
    pub fn deinit(self: *HeaderData) void {
        self.headers.deinit();
    }
};
pub fn parseHttpConnection(connection: *net.Server.Connection, alloc: mem.Allocator) !Request {
    var request_data = Request.init();
    const fixed_buffer_size: [1048 * 8]u8 = undefined;
    const fixed_buffer_allocator = try alloc.create(std.heap.FixedBufferAllocator);
    errdefer alloc.destroy(fixed_buffer_allocator);
    fixed_buffer_allocator.* = heap.FixedBufferAllocator.init(fixed_buffer_size);
    // const buf = try alloc.alloc(u8, 1024);
    // defer alloc.free(buf);
    var reader_wrapper = connection.stream.reader(&fixed_buffer_allocator.buffer);
    const reader = &reader_wrapper.interface_state;
    const buffer = try reader.readAlloc(fixed_buffer_allocator, fixed_buffer_size.len);
    // Get the first line
    _ = try parseMethod(buffer, &request_data);
    // var header_data = try HeaderData.parseHeader(reader, alloc);
    // defer header_data.deinit();
    // var key_it = header_data.headers.keyIterator();
    // std.debug.print("\nHEADERS:\n\n {d} headers \n", .{header_data.headers.count()});
    // while (key_it.next()) |key| {
    //     if (header_data.headers.contains(key.*)) {
    //         std.debug.print("{s}: {s}\n", .{ key.*, header_data.headers.get(key.*).? });
    //     }
    // }
    std.debug.print("request data: {} \n", .{request_data});
    return request_data;
}
test "parseMethod successfully parses Method" {
    const req_string = "GET / HTTP/1.1\r\n";
    var req = Request.init();
    const read_bytes = try parseMethod(req_string, &req);
    try testing.expectEqual(4, read_bytes);
    try testing.expectEqual(Method.GET, req.method);
}
test "parseMethod fails when the method has separator ':'" {
    const req_string = "GET:DATA / HTTP/1.1\r\n";
    var req = Request.init();
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, parseMethod(req_string, &req));
}
test "parseMethod fails when the method has separator '@'" {
    const req_string = "GET@ / HTTP/1.1\r\n";
    var req = Request.init();
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, parseMethod(req_string, &req));
}
// TODO:: We may need to handle Custom Methods
// test "parseMethod successfully parses Method when given custom method" {
//     const req_string = "GET / HTTP/1.1\r\n";
//     var req = Request.init();
//     const read_bytes = try parseMethod(req_string, &req);
//     try testing.expectEqual(4, read_bytes);
//     try testing.expectEqual(Method.GET, req.method);
// }

// test "parseStartLine successfully parses startline" {
//     const req = "GET / HTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const request = try RequestLineData.parseStartLine(&reader);
//     try testing.expectEqual(Method.GET, request.method);
//     try testing.expectEqualStrings("/", request.route);
//     try testing.expectEqual(HTTPProtocol.@"1.1", request.protocol);
// }
//
// test "parseStartLine successfully parses request with complex URI" {
//     const req = "POST /api/v1/users?sort=desc&limit=50 HTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const request = try RequestLineData.parseStartLine(&reader);
//     try testing.expectEqual(Method.POST, request.method);
//     try testing.expectEqualStrings("/api/v1/users?sort=desc&limit=50", request.route);
//     try testing.expectEqual(HTTPProtocol.@"1.1", request.protocol);
// }
//
// test "parseStartLine successfully parses request with full proxy(http://) URI" {
//     const req = "GET http://www.example.com/index.html HTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const request = try RequestLineData.parseStartLine(&reader);
//     try testing.expectEqual(Method.GET, request.method);
//     try testing.expectEqualStrings("http://www.example.com/index.html", request.route);
//     try testing.expectEqual(HTTPProtocol.@"1.1", request.protocol);
// }
//
// test "parseStartLine successfully parses request with OPTION and a * as URI" {
//     const req = "OPTIONS * HTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const request = try RequestLineData.parseStartLine(&reader);
//     try testing.expectEqual(Method.OPTIONS, request.method);
//     try testing.expectEqualStrings("*", request.route);
//     try testing.expectEqual(HTTPProtocol.@"1.1", request.protocol);
// }
// test "parseStartLine throws error when parsing a extra spaced malformed URI" {
//     const req = "GET    /     HTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const expectedError = error.BadRequest;
//     try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
// }
// test "parseStartLine throws error when parsing a truncated Line" {
//     const req = "GET /api/data\r\n";
//     var reader = Io.Reader.fixed(req);
//     const expectedError = error.BadRequest;
//     try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
// }
// test "parseStartLine throws error when protocol doesn't start with HTTP" {
//     const req = "POST / HTTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const expectedError = error.BadRequest;
//     try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
// }
// test "parseStartLine throws error when it's a garbage request" {
//     const req = "12345 INVALID REQUEST\r\n";
//     var reader = Io.Reader.fixed(req);
//     const expectedError = error.BadRequest;
//     try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
// }
// test "parseStartLine throws error when method is lowercase" {
//     const req = "get / HTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const expectedError = error.BadRequest;
//     try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
// }
// test "parseStartLine throws error when line ends with just LF" {
//     const req = "GET / HTTP/1.1\n";
//     var reader = Io.Reader.fixed(req);
//     const expectedError = error.BadRequest;
//     try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
// }
// test "parseStartLine throws error when there is unencoded space on the URI" {
//     const req = "GET /my file.html HTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const expectedError = error.BadRequest;
//     try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
// }
// test "parseStartLine throws error when the Request line is too long. " {
//     const req = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA / HTTP/1.1\r\n";
//     var reader = Io.Reader.fixed(req);
//     const expectedError = error.BadRequest;
//     try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
// }
