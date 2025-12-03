const std = @import("std");

/// Represents standard HTTP Status Codes as defined in RFC 7231 and others.
/// Backed by u16 for easy conversion to integer values.
pub const HttpStatus = enum(u16) {
    // 1xx Informational
    continue_request = 100,
    switching_protocols = 101,
    processing = 102,
    early_hints = 103,

    // 2xx Success
    ok = 200,
    created = 201,
    accepted = 202,
    non_authoritative_information = 203,
    no_content = 204,
    reset_content = 205,
    partial_content = 206,
    multi_status = 207,
    already_reported = 208,
    im_used = 226,

    // 3xx Redirection
    multiple_choices = 300,
    moved_permanently = 301,
    found = 302,
    see_other = 303,
    not_modified = 304,
    use_proxy = 305,
    temporary_redirect = 307,
    permanent_redirect = 308,

    // 4xx Client Error
    bad_request = 400,
    unauthorized = 401,
    payment_required = 402,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    not_acceptable = 406,
    proxy_authentication_required = 407,
    request_timeout = 408,
    conflict = 409,
    gone = 410,
    length_required = 411,
    precondition_failed = 412,
    payload_too_large = 413,
    uri_too_long = 414,
    unsupported_media_type = 415,
    range_not_satisfiable = 416,
    expectation_failed = 417,
    im_a_teapot = 418, // RFC 2324
    misdirected_request = 421,
    unprocessable_content = 422,
    too_many_requests = 429,

    // 5xx Server Error
    internal_server_error = 500,
    not_implemented = 501,
    bad_gateway = 502,
    service_unavailable = 503,
    gateway_timeout = 504,
    http_version_not_supported = 505,

    /// Returns the standard reason phrase associated with the status code.
    pub fn phrase(self: HttpStatus) []const u8 {
        return switch (self) {
            .continue_request => "Continue",
            .switching_protocols => "Switching Protocols",
            .processing => "Processing",
            .early_hints => "Early Hints",

            .ok => "OK",
            .created => "Created",
            .accepted => "Accepted",
            .non_authoritative_information => "Non-Authoritative Information",
            .no_content => "No Content",
            .reset_content => "Reset Content",
            .partial_content => "Partial Content",
            .multi_status => "Multi Status",
            .im_used => "IM Used",

            .multiple_choices => "Multiple Choices",
            .moved_permanently => "Moved Permanently",
            .found => "Found",
            .see_other => "See Other",
            .not_modified => "Not Modified",
            .use_proxy => "Use Proxy",
            .temporary_redirect => "Temporary Redirect",
            .permanent_redirect => "Permanent Redirect",

            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .payment_required => "Payment Required",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .not_acceptable => "Not Acceptable",
            .proxy_authentication_required => "Proxy Authentication Required",
            .request_timeout => "Request Timeout",
            .conflict => "Conflict",
            .gone => "Gone",
            .length_required => "Length Required",
            .precondition_failed => "Precondition Failed",
            .payload_too_large => "Payload Too Large",
            .uri_too_long => "URI Too Long",
            .unsupported_media_type => "Unsupported Media Type",
            .range_not_satisfiable => "Range Not Satisfiable",
            .expectation_failed => "Expectation Failed",
            .im_a_teapot => "I'm a teapot",
            .misdirected_request => "Misdirected Request",
            .unprocessable_content => "Unprocessable Content",
            .too_many_requests => "Too Many Requests",

            .internal_server_error => "Internal Server Error",
            .not_implemented => "Not Implemented",
            .bad_gateway => "Bad Gateway",
            .service_unavailable => "Service Unavailable",
            .gateway_timeout => "Gateway Timeout",
            .http_version_not_supported => "HTTP Version Not Supported",
        };
    }

    /// Convenience helper to check if a code is a success (200-299)
    pub fn isSuccess(self: HttpStatus) bool {
        const code = @intFromEnum(self);
        return code >= 200 and code <= 299;
    }

    /// Convenience helper to check if a code is a client error (400-499)
    pub fn isClientError(self: HttpStatus) bool {
        const code = @intFromEnum(self);
        return code >= 400 and code <= 499;
    }

    /// Convenience helper to check if a code is a server error (500-599)
    pub fn isServerError(self: HttpStatus) bool {
        const code = @intFromEnum(self);
        return code >= 500 and code <= 599;
    }
};

test "HttpStatus basic usage" {
    const status = HttpStatus.not_found;

    // Check integer value
    try std.testing.expectEqual(@as(u16, 404), @intFromEnum(status));

    // Check string phrase
    try std.testing.expectEqualStrings("Not Found", status.phrase());

    // Check helpers
    try std.testing.expect(status.isClientError());
    try std.testing.expect(!status.isSuccess());
}
