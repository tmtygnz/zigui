const std = @import("std");
const Io = std.Io;

const zigui = @import("zigui");

pub fn main() void {
    var window = zigui.windowing.WindowInstance.init(1280, 800, "Hello World");
    window.run();
}
