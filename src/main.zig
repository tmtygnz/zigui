const std = @import("std");
const Io = std.Io;
const zigui = @import("zigui");

pub fn main(init: std.process.Init) !void {
    const ff = try zigui.widget_collection.labelWidget.FontProvider.init(init.gpa, 16);
    // Initialize the window instance
    var window = zigui.windowing.WindowInstance.init(.{
        .initial_height = 900,
        .initial_width = 1400,
        .allocator = init.gpa,
        .app_font = @constCast(&ff),
        .io = init.io,
        .title = "Zigui Varied Stress Test",
    });

    // --- Header Section ---
    var title_label = zigui.widget_collection.labelWidget.LabelWidget.init(.{
        .text = "ZIGUI DEVELOPMENT DASHBOARD",
        .position = .{ 500.0, 20.0 },
    }, @constCast(&ff));
    try window.addComponent(title_label.getWidget());

    // --- Sidebar Section (Small Buttons) ---
    var sidebar_buttons: [15]zigui.widget_collection.buttonWidget.ButtonWidget = undefined;
    for (0..15) |i| {
        const text = try std.fmt.allocPrint(init.gpa, "Menu Item {d}", .{i + 1});
        sidebar_buttons[i] = zigui.widget_collection.buttonWidget.ButtonWidget.init(.{
            .content = .{ .text = text },
            .position = .{ 20.0, 60.0 + @as(f32, @floatFromInt(i * 45)) },
            .font_provider = @constCast(&ff),
            .dimensions = .{ 150, 35 },
            .padding = .{ 10.0, 5.0 },
        });
        try window.addComponent(sidebar_buttons[i].getWidget());
    }

    // --- Main Content Area (Labels & Diverse Buttons) ---
    var content_labels: [5]zigui.widget_collection.labelWidget.LabelWidget = undefined;
    const descriptions = [_][]const u8{
        "System Status: All systems nominal.",
        "Resource Usage: CPU 12%, RAM 450MB",
        "The quick brown fox jumps over the lazy dog.",
        "Zig is a general-purpose programming language and toolchain for maintaining robust, optimal and reusable software.",
        "This UI library uses Sokol for cross-platform rendering and Schrift for font rasterization.",
    };

    for (0..5) |i| {
        content_labels[i] = zigui.widget_collection.labelWidget.LabelWidget.init(.{
            .text = descriptions[i],
            .position = .{ 200.0, 100.0 + @as(f32, @floatFromInt(i * 120)) },
        }, @constCast(&ff));
        try window.addComponent(content_labels[i].getWidget());
    }

    var action_buttons: [10]zigui.widget_collection.buttonWidget.ButtonWidget = undefined;
    for (0..10) |i| {
        const x_pos = 200.0 + @as(f32, @floatFromInt((i % 2) * 400));
        const y_pos = 130.0 + @as(f32, @floatFromInt((i / 2) * 120));

        action_buttons[i] = zigui.widget_collection.buttonWidget.ButtonWidget.init(.{
            .content = .{ .text = if (i % 2 == 0) "PRIMARY ACTION" else "Secondary Alt" },
            .position = .{ x_pos, y_pos },
            .font_provider = @constCast(&ff),
            .dimensions = .{ 0, 0 }, // Auto-size
            .padding = .{ 30.0, 15.0 },
        });
        try window.addComponent(action_buttons[i].getWidget());
    }

    // --- Bottom Status Bar ---
    var footer_label = zigui.widget_collection.labelWidget.LabelWidget.init(.{
        .text = "Press ESC to exit | v0.1.0-alpha | Built with Zig 0.16.0",
        .position = .{ 20.0, 860.0 },
    }, @constCast(&ff));
    try window.addComponent(footer_label.getWidget());

    // Start the application loop
    window.run();
}
