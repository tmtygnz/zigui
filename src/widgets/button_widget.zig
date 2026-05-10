const std = @import("std");
const sokol = @import("sokol");
const sgl = sokol.gl;
const saap = sokol.app;
const widget = @import("./widget.zig");

pub const ButtonWidgetOptions = struct {
    dimensions: @Vector(2, f32) = .{ 100.0, 100.0 },
    padding: @Vector(2, f32) = .{ 4.0, 2.0 },
    content: ButtonWidgetContent,
};

pub const ButtonWidgetContent = union(enum) {
    text: []const u8,
};

pub const ButtonWidget = struct {
    dimensions: @Vector(2, f32),
    padding: @Vector(2, f32),
    content: ButtonWidgetContent,

    const Self = @This();

    pub fn init(options: ButtonWidgetOptions) Self {
        return .{
            .dimensions = options.dimensions,
            .padding = options.padding,
            .content = options.content,
        };
    }

    pub fn event_callback(selfPtr: *anyopaque, widg: *widget.Widget, event: [*c]const saap.Event) void {
        const self: *Self = @ptrCast(@alignCast(selfPtr));
        _ = self;
        _ = widg;
        _ = event;
        std.debug.print("Event called \n", .{});
    }

    pub fn getWidget(self: *Self) widget.Widget {
        var widg = widget.Widget.init(.{
            .bbox_dimensions = .{ 0.0, 0.0 },
            .position = .{ 0.0, 0.0 },
            .render_callback = Self.render,
            .component_context = self,
            .event_callback = Self.event_callback,
        });
        widg.set_bbox_size(self.dimensions);
        return widg;
    }

    pub fn render(ctx: *anyopaque, parent_widget: *widget.Widget) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const x = parent_widget.position[0];
        const y = parent_widget.position[1];
        const w = self.dimensions[0];
        const h = self.dimensions[1];

        if (parent_widget.hovering) {
            sgl.c4f(0.2, 0.6, 1.0, 1.0);
        } else {
            sgl.c4f(0.6, 0.6, 1.0, 1.0);
        }

        sgl.v2f(x, y);
        sgl.v2f(x, y + h);
        sgl.v2f(x + w, y + h);
        sgl.v2f(x + w, y);
    }
};
