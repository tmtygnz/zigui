const std = @import("std");
const widget_collection = @import("widget_collection.zig");

pub const WidgetOptions = struct {
    position: @Vector(2, f32),
    bbox_dimensions: @Vector(2, f32),
    render_callback: *const fn (ctx: *anyopaque, widget: *Widget) void,
    render_context: *anyopaque,
};

pub const Widget = struct {
    position: @Vector(2, f32),
    bbox_dimensions: @Vector(2, f32),

    hovering: bool = false,
    pressed: bool = false,

    render_callback: *const fn (ctx: *anyopaque, widget: *Widget) void,
    render_context: *anyopaque,

    const Self = @This();

    pub fn init(widgetOptions: WidgetOptions) Widget {
        return .{
            .position = widgetOptions.position,
            .bbox_dimensions = widgetOptions.bbox_dimensions,
            .render_callback = widgetOptions.render_callback,
            .render_context = widgetOptions.render_context,
        };
    }

    pub fn set_bbox_size(self: *Self, size: @Vector(2, f32)) void {
        self.bbox_dimensions = size;
    }

    pub fn render_step(self: *Self, mouse_position: @Vector(2, f32)) void {
        self.check_mouse_collisions(mouse_position);
        self.render_callback(self.render_context, self);
    }

    // Checks wether mouse cursor is within the minimum and maximum
    // boundaries of both axis.
    fn check_mouse_collisions(self: *Self, mouse_position: @Vector(2, f32)) void {
        const min_x = self.position[0];
        const min_y = self.position[1];
        const max_x = min_x + self.bbox_dimensions[0];
        const max_y = min_y + self.bbox_dimensions[1];

        if (min_x <= mouse_position[0] and mouse_position[0] <= max_x and min_y <= mouse_position[1] and mouse_position[1] <= max_y) {
            self.hovering = true;
        } else {
            self.hovering = false;
        }
    }
};
