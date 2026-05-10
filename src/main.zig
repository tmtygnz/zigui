const std = @import("std");
const Io = std.Io;

const zigui = @import("zigui");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    var window = zigui.windowing.WindowInstance.init(1280, 800, "Hello World", allocator);

    var button = zigui.widget_collection.buttonWidget.ButtonWidget.init(.{ .content = .{ .text = "hello world" } });
    const buttonWidget = button.getWidget();

    try window.addComponent(buttonWidget);

    window.run();
}
