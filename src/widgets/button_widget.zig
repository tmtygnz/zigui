const std = @import("std");
const sokol = @import("sokol");
const sgl = sokol.gl;
const sapp = sokol.app;
const widget = @import("./widget.zig");
const label_widget = @import("./label_widget.zig");

pub const ButtonWidgetOptions = struct {
    dimensions: @Vector(2, f32) = .{ 100.0, 100.0 },
    padding: @Vector(2, f32) = .{ 4.0, 2.0 },
    content: ButtonWidgetContent,
    position: @Vector(2, f32) = .{ 0.0, 0.0 },
    font_provider: *label_widget.FontProvider,
};

pub const ButtonWidgetContent = union(enum) {
    text: []const u8,
};

pub const ButtonWidget = struct {
    dimensions: @Vector(2, f32),
    padding: @Vector(2, f32),
    content: ButtonWidgetContent,
    position: @Vector(2, f32),
    font_provider: *label_widget.FontProvider,

    const Self = @This();

    pub fn init(options: ButtonWidgetOptions) Self {
        return .{
            .dimensions = options.dimensions,
            .padding = options.padding,
            .content = options.content,
            .position = options.position,
            .font_provider = options.font_provider,
        };
    }

    pub fn event_callback(selfPtr: *anyopaque, widg: *widget.Widget, event: [*c]const sapp.Event) void {
        const self: *Self = @ptrCast(@alignCast(selfPtr));
        _ = self;
        _ = widg;
        _ = event;
    }

    pub fn getWidget(self: *Self) widget.Widget {
        const widg = widget.Widget.init(.{
            .bbox_dimensions = self.dimensions,
            .position = self.position,
            .render_callback = Self.render,
            .component_context = self,
            .event_callback = Self.event_callback,
        });
        return widg;
    }

    pub fn render(ctx: *anyopaque, parent_widget: *widget.Widget) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const x = parent_widget.position[0];
        const y = parent_widget.position[1];

        // Use either explicit dimensions or calculate based on content + padding
        var w = self.dimensions[0];
        var h = self.dimensions[1];

        const text_str = switch (self.content) {
            .text => |t| t,
        };

        const text_size = self.font_provider.measureText(text_str);

        // If dimensions are 0, auto-size
        if (w == 0) w = text_size[0] + self.padding[0] * 2.0;
        if (h == 0) h = text_size[1] + self.padding[1] * 2.0;

        // Update parent widget bbox if it was auto-sized
        parent_widget.set_bbox_size(.{ w, h });

        if (parent_widget.hovering) {
            sgl.c4f(0.25, 0.25, 0.25, 1.0);
        } else {
            sgl.c4f(0.15, 0.15, 0.15, 1.0);
        }

        if (parent_widget.pressed) {
            sgl.c4f(0.05, 0.05, 0.05, 1.0);
        }

        sgl.beginQuads();
        sgl.v2f(x, y);
        sgl.v2f(x, y + h);
        sgl.v2f(x + w, y + h);
        sgl.v2f(x + w, y);
        sgl.end();

        // Render centered text
        const text_x = x + (w / 2.0) - (text_size[0] / 2.0);
        // Position baseline so the text is centered
        const asc = self.font_provider.ascender;
        const desc = self.font_provider.descender;
        const font_middle_offset = (asc + desc) / 2.0;
        const text_y = y + (h / 2.0) + font_middle_offset;

        // std.debug.print("Button Render: h={d:.2} asc={d:.2} desc={d:.2} mid_off={d:.2} final_y={d:.2}\n", .{h, asc, desc, font_middle_offset, text_y});

        self.font_provider.renderText(text_str, text_x, text_y);
    }
};
