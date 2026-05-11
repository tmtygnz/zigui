const std = @import("std");
const widget = @import("./widget.zig");
const sokol = @import("sokol");
const saap = sokol.app;
const sg = sokol.gfx;
const tt = @import("TrueType");
const c = @cImport({
    @cInclude("schrift.h");
});

const char_set = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890~!@#$%^&*()_+{}|[]";

pub const LabelWidgetOptions = struct {
    font_size: f32 = 16,
    text: []const u8,
};

const FontProviderErrors = error{ GlyphNotInFontError, GlyphRenderFail, FailedToLoadFontFile };

const FontImageAtlasItem = struct {
    pos_x: i32,
    pos_y: i32,
    width: usize,
    height: usize,
    pixels: []u8,
    char: u8,

    const Self = @This();

    /// This function deallocates the pixels generated to create char's glyphs.
    /// Only call this when the glyph is already stored or the font atlas is already created.
    pub fn deinitPixels(self: Self, alloc: std.mem.Allocator) void {
        alloc.free(self.pixels);
        std.debug.print("Freeing pixels for char {c}\n", .{self.char});
    }
};

pub const FontProvider = struct {
    font_SFT: c.SFT,
    atlas: ?sg.Image,
    image_atlas_items: std.ArrayListUnmanaged(FontImageAtlasItem) = .empty,
    allocator: std.mem.Allocator,
    font_size_at_raster: f64,
    tracked_max_row_height: i32,
    image: sg.Image,

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, font_size_to_raster_at: f64) !Self {
        const font: *c.struct_SFT_Font = c.sft_loadfile("src/assets/InterVariable.ttf") orelse return FontProviderErrors.FailedToLoadFontFile;

        return .{
            .font_SFT = .{
                .font = font,
                .xScale = font_size_to_raster_at,
                .yScale = font_size_to_raster_at,
                .flags = c.SFT_DOWNWARD_Y,
            },
            .allocator = alloc,
            .font_size_at_raster = font_size_to_raster_at,
            .atlas = null, // Initialize as null
            .image = .{ .id = 0 }, // Initialize with an empty Sokol handle
            .tracked_max_row_height = 0, // Start at zero
            .image_atlas_items = .empty, // Explicitly set the ArrayList
        };
    }

    pub fn lookup(self: *Self, codepoint: u32) FontProviderErrors!c.SFT_Glyph {
        var glyph: c.SFT_Glyph = undefined;

        if (c.sft_lookup(&self.font_SFT, codepoint, &glyph) != 0) {
            return FontProviderErrors.GlyphNotInFontError;
        }

        return glyph;
    }

    pub fn getGlyphMetrics(self: *Self, glyph: c.SFT_Glyph) c.SFT_GMetrics {
        var metrics: c.SFT_GMetrics = undefined;
        _ = c.sft_gmetrics(&self.font_SFT, glyph, &metrics);
        return metrics;
    }

    /// This function calculates the x and y position of the current glyph.
    /// This handles glyph wrapping and it tracks the max height of the current row.
    fn calculateXYPos(self: *Self, width: i32, height: i32) @Vector(2, i32) {
        const atlas_size = 1024;

        // If first item in atlas
        if (self.image_atlas_items.items.len == 0) {
            self.tracked_max_row_height = height;
            return .{ 0, 0 };
        }

        const last_item = self.image_atlas_items.items[self.image_atlas_items.items.len - 1];

        var next_x = last_item.pos_x + @as(i32, @intCast(last_item.width)) + 1;
        var next_y = last_item.pos_y;

        if (next_x + width > atlas_size) {
            // Wrap into new line.
            next_x = 0;
            next_y = last_item.pos_y + self.tracked_max_row_height + 1;
            self.tracked_max_row_height = height;
        } else {
            // Fits.
            if (height > self.tracked_max_row_height) {
                self.tracked_max_row_height = height;
            }
        }

        return .{ next_x, next_y };
    }

    pub fn generate_atlas(self: *Self) !void {
        for (char_set) |ch| {
            const glyph = self.lookup(ch) catch {
                continue;
            };
            const metrics = self.getGlyphMetrics(glyph);
            const g_width = metrics.minWidth;
            const g_height = metrics.minHeight;
            const buffer_size = @as(usize, @intCast(g_width * g_height));
            const pixels = try self.allocator.alloc(u8, buffer_size);
            // FREE Them in the consolidator
            @memset(pixels, 0);

            const image: c.SFT_Image = .{
                .width = g_width,
                .height = g_height,
                .pixels = pixels.ptr,
            };

            if (c.sft_render(&self.font_SFT, glyph, image) < 0) {
                return FontProviderErrors.GlyphRenderFail;
            }

            const glyph_origin = self.calculateXYPos(g_width, g_height);

            try self.image_atlas_items.append(self.allocator, .{
                .pos_x = glyph_origin[0],
                .pos_y = glyph_origin[1],
                .width = @intCast(g_width),
                .height = @intCast(g_height),
                .pixels = pixels,
                .char = ch,
            });
        }
    }

    pub fn consolidateGlyphsToAtlas(self: *Self) !void {
        const atlas_size: usize = 1024;
        const master_atlas_buffer = try self.allocator.alloc(u8, atlas_size * atlas_size);
        defer self.allocator.free(master_atlas_buffer);
        @memset(master_atlas_buffer, 0);

        for (self.image_atlas_items.items) |item| {
            const glyph_pixels = item.pixels;
            const h = item.height;
            const w = item.width;

            var glyph_row: usize = 0;
            while (glyph_row < h) : (glyph_row += 1) {
                const target_atlas_row = @as(usize, @intCast(item.pos_y)) + glyph_row;
                const dest_x = @as(usize, @intCast(item.pos_x));
                const dest_index = (target_atlas_row * atlas_size) + dest_x;
                const src_index = glyph_row * w;

                @memcpy(
                    master_atlas_buffer[dest_index .. dest_index + w],
                    glyph_pixels[src_index .. src_index + w],
                );
            }

            item.deinitPixels(self.allocator);
        }

        // 1. Fixed Image Description (Removed min_filter and mag_filter)
        var img_desc = sg.ImageDesc{
            .width = @intCast(atlas_size),
            .height = @intCast(atlas_size),
            .pixel_format = .R8,
            .label = "font-atlas",
        };

        img_desc.data.mip_levels[0][0] = .{
            .ptr = master_atlas_buffer.ptr,
            .size = master_atlas_buffer.len,
        };

        self.image = sg.makeImage(img_desc);
    }
};

pub const LabelWidget = struct {
    font_size: f32,
    text: []const u8,
    font_provider: FontProvider,

    const Self = @This();

    pub fn init(options: LabelWidgetOptions) Self {
        return .{
            .font_size = options.font_size,
            .text = options.text,
        };
    }

    pub fn event_callback(selfPtr: *anyopaque, widg: *widget.Widget, event: [*c]const saap.Event) void {
        const self: *Self = @ptrCast(@alignCast(selfPtr));
        _ = self;
        _ = widg;
        _ = event;
    }

    pub fn getWidget(self: *Self) widget.Widget {
        var widg = widget.Widget.init(.{
            .bbox_dimensions = .{ 0.0, 0.0 },
            .position = self.position,
            .render_callback = Self.render,
            .component_context = self,
            .event_callback = Self.event_callback,
        });
        widg.set_bbox_size(self.dimensions);
        return widg;
    }
};
