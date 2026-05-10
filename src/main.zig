const std = @import("std");
const Io = std.Io;

const zigui = @import("zigui");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    var window = zigui.windowing.WindowInstance.init(1280, 800, "Hello World", allocator);

    var button = zigui.widget_collection.buttonWidget.ButtonWidget.init(.{
        .content = .{ .text = "hello world" },
        .position = .{ 50.0, 50.0 },
    });
    const buttonWidget = button.getWidget();

    var button2 = zigui.widget_collection.buttonWidget.ButtonWidget.init(.{
        .content = .{ .text = "hello world" },
        .position = .{ 300.0, 50.0 },
    });
    const buttonWidget2 = button2.getWidget();

    try window.addComponent(buttonWidget);
    try window.addComponent(buttonWidget2);

    window.run();
}
