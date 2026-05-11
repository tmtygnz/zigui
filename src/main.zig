const std = @import("std");
const Io = std.Io;
const zigui = @import("zigui");

pub fn main(init: std.process.Init) !void {
    // var gpa: std.heap.DebugAllocator(.{}) = .init;
    // const allocator = gpa.allocator();
    var ff = try zigui.widget_collection.labelWidget.FontProvider.init(init.gpa, 15);
    try ff.generate_atlas();
    try ff.consolidateGlyphsToAtlas();

    var window = zigui.windowing.WindowInstance.init(1280, 800, "Hello World", init.gpa, init.io);

    var button = zigui.widget_collection.buttonWidget.ButtonWidget.init(.{
        .content = .{ .text = "hello world" },
        .position = .{ 50.0, 50.0 },
    });
    const buttonWidget = button.getWidget();

    try window.addComponent(buttonWidget);

    window.run();
}
