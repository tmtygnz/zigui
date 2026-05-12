const std = @import("std");
const widget = @import("./widget.zig");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sgl = sokol.gl;
const c = @cImport({
    @cInclude("schrift.h");
});

const char_set = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890~!@#$%^&*()_+{}|[]";

pub const LabelWidgetOptions = struct {
    font_size: f32 = 16,
    text: []const u8,
    position: @Vector(2, f32) = .{ 0.0, 0.0 },
};

const FontProviderErrors = error{
    GlyphNotInFontError,
    GlyphRenderFail,
    FailedToLoadFontFile,
};

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

const GlyphInfo = struct {
    char: u8,
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
    width: f32,
    height: f32,
    advance: f32,
    offset_x: f32,
    offset_y: f32,
};

pub const FontProvider = struct {
    font_SFT: c.SFT,
    atlas: ?sg.Image,
    image_atlas_items: std.ArrayListUnmanaged(FontImageAtlasItem) = .empty,
    glyphs: std.AutoHashMapUnmanaged(u8, GlyphInfo) = .empty,
    allocator: std.mem.Allocator,
    font_size_at_raster: f64,
    tracked_max_row_height: i32,
    image: sg.Image,
    view: sg.View,
    sampler: sg.Sampler,
    pipeline: sgl.Pipeline,

    // Line metrics
    ascender: f32 = 0,
    descender: f32 = 0,
    line_gap: f32 = 0,

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, font_size_to_raster_at: f64) FontProviderErrors!Self {
        const font: *c.struct_SFT_Font = c.sft_loadfile("src/assets/InterVariable.ttf") orelse return FontProviderErrors.FailedToLoadFontFile;

        var self = Self{
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
            .view = .{ .id = 0 },
            .sampler = .{ .id = 0 },
            .pipeline = .{ .id = 0 },
            .tracked_max_row_height = 0, // Start at zero
            .image_atlas_items = .empty, // Explicitly set the ArrayList
            .glyphs = .empty,
        };

        var lmetrics: c.SFT_LMetrics = undefined;
        if (c.sft_lmetrics(&self.font_SFT, &lmetrics) == 0) {
            self.ascender = @floatCast(lmetrics.ascender);
            self.descender = @floatCast(lmetrics.descender);
            self.line_gap = @floatCast(lmetrics.lineGap);
            std.debug.print("Font Metrics: asc={d:.2} desc={d:.2} gap={d:.2}\n", .{ self.ascender, self.descender, self.line_gap });
        }

        return self;
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

    pub fn rasterizeGlyphs(self: *Self) !void {
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

            std.debug.print("Rasterizing pixels for {c}\n", .{ch});
        }
    }

    pub fn consolidateGlyphsToAtlas(self: *Self) !void {
        const atlas_size: usize = 1024;
        const master_atlas_buffer = try self.allocator.alloc(u32, atlas_size * atlas_size);
        defer self.allocator.free(master_atlas_buffer);
        @memset(master_atlas_buffer, 0);

        var glyph_count: usize = 0;
        for (self.image_atlas_items.items) |item| {
            std.debug.print("Merging to main atlas for char {c} at {d},{d} size {d}x{d}\n", .{ item.char, item.pos_x, item.pos_y, item.width, item.height });
            const glyph_pixels = item.pixels;
            const h = item.height;
            const w = item.width;

            var has_alpha = false;
            var glyph_row: usize = 0;
            while (glyph_row < h) : (glyph_row += 1) {
                const target_atlas_row = @as(usize, @intCast(item.pos_y)) + glyph_row;
                const dest_x = @as(usize, @intCast(item.pos_x));
                const dest_index = (target_atlas_row * atlas_size) + dest_x;
                const src_index = glyph_row * w;

                var i: usize = 0;
                while (i < w) : (i += 1) {
                    const alpha = glyph_pixels[src_index + i];
                    if (alpha > 0) has_alpha = true;
                    master_atlas_buffer[dest_index + i] = (@as(u32, alpha) << 24) | 0x00FFFFFF;
                }
            }
            if (!has_alpha) {
                std.debug.print("Warning: Glyph {c} has no non-zero alpha pixels!\n", .{item.char});
            } else {
                glyph_count += 1;
            }

            item.deinitPixels(self.allocator);
        }
        std.debug.print("Merged {d} glyphs with content.\n", .{glyph_count});

        // Make Sokol Image here
        std.debug.print("Creating Sokol Image...\n", .{});
        self.image = sg.makeImage(.{
            .width = @intCast(atlas_size),
            .height = @intCast(atlas_size),
            .pixel_format = .RGBA8,
            .data = .{
                .mip_levels = blk: {
                    var mip_levels: [16]sg.Range = @splat(.{});
                    mip_levels[0] = .{
                        .ptr = master_atlas_buffer.ptr,
                        .size = master_atlas_buffer.len * @sizeOf(u32),
                    };
                    break :blk mip_levels;
                },
            },
        });
        std.debug.print("Sokol Image created: {d}\n", .{self.image.id});

        std.debug.print("Creating Sokol View...\n", .{});
        self.view = sg.makeView(.{
            .texture = .{ .image = self.image },
        });
        std.debug.print("Sokol View created: {d}\n", .{self.view.id});

        std.debug.print("Creating Sokol Sampler...\n", .{});
        self.sampler = sg.makeSampler(.{
            .min_filter = .NEAREST,
            .mag_filter = .NEAREST,
        });
        std.debug.print("Sokol Sampler created: {d}\n", .{self.sampler.id});

        std.debug.print("Creating Sokol GL Pipeline...\n", .{});
        self.pipeline = sgl.makePipeline(.{
            .colors = blk: {
                var colors: [8]sg.ColorTargetState = @splat(.{});
                colors[0].blend = .{
                    .enabled = true,
                    .src_factor_rgb = .SRC_ALPHA,
                    .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                };
                break :blk colors;
            },
        });
        std.debug.print("Sokol GL Pipeline created: {d}\n", .{self.pipeline.id});

        // Store Glyph Info for lookup
        for (self.image_atlas_items.items) |item| {
            const glyph = self.lookup(item.char) catch continue;
            const metrics = self.getGlyphMetrics(glyph);

            const inv_size: f32 = 1.0 / @as(f32, @floatFromInt(atlas_size));

            self.glyphs.put(self.allocator, item.char, .{
                .char = item.char,
                .u0 = @as(f32, @floatFromInt(item.pos_x)) * inv_size,
                .v0 = @as(f32, @floatFromInt(item.pos_y)) * inv_size,
                .u1 = @as(f32, @floatFromInt(item.pos_x + @as(i32, @intCast(item.width)))) * inv_size,
                .v1 = @as(f32, @floatFromInt(item.pos_y + @as(i32, @intCast(item.height)))) * inv_size,
                .width = @floatFromInt(item.width),
                .height = @floatFromInt(item.height),
                .advance = @floatCast(metrics.advanceWidth),
                .offset_x = @floatCast(metrics.leftSideBearing),
                .offset_y = @floatFromInt(metrics.yOffset),
            }) catch continue;
        }
    }

    pub fn renderText(self: *Self, text: []const u8, x: f32, y: f32) void {
        var cursor_x = x;

        sgl.enableTexture();
        sgl.texture(self.view, self.sampler);
        sgl.pushPipeline();
        sgl.loadPipeline(self.pipeline);
        sgl.beginQuads();
        sgl.c4f(1.0, 1.0, 1.0, 1.0);

        for (text) |char| {
            if (self.glyphs.get(char)) |info| {
                const x0 = cursor_x + info.offset_x;
                const y0 = y + info.offset_y;
                const x1 = x0 + info.width;
                const y1 = y0 + info.height;

                sgl.v2fT2f(x0, y0, info.u0, info.v0);
                sgl.v2fT2f(x1, y0, info.u1, info.v0);
                sgl.v2fT2f(x1, y1, info.u1, info.v1);
                sgl.v2fT2f(x0, y1, info.u0, info.v1);

                cursor_x += info.advance;
            } else if (char == ' ') {
                cursor_x += @floatCast(self.font_size_at_raster / 3.0);
            }
        }

        sgl.end();
        sgl.popPipeline();
        sgl.disableTexture();
    }

    pub fn measureText(self: *Self, text: []const u8) @Vector(2, f32) {
        var width: f32 = 0;
        const height: f32 = @abs(self.ascender - self.descender);

        for (text) |char| {
            if (self.glyphs.get(char)) |info| {
                width += info.advance;
            } else if (char == ' ') {
                width += @floatCast(self.font_size_at_raster / 3.0);
            }
        }
        return .{ width, height };
    }
};

pub const LabelWidget = struct {
    font_size: f32,
    text: []const u8,
    position: @Vector(2, f32),
    font_provider: *FontProvider,

    const Self = @This();

    pub fn init(options: LabelWidgetOptions, fontp: *FontProvider) Self {
        return .{
            .font_size = options.font_size,
            .text = options.text,
            .position = options.position,
            .font_provider = fontp,
        };
    }

    pub fn event_callback(selfPtr: *anyopaque, widg: *widget.Widget, event: [*c]const sapp.Event) void {
        const self: *Self = @ptrCast(@alignCast(selfPtr));
        _ = self;
        _ = widg;
        _ = event;
    }

    pub fn getWidget(self: *Self) widget.Widget {
        return widget.Widget.init(.{
            .bbox_dimensions = .{ 0.0, 0.0 }, // Should be calculated
            .position = self.position,
            .render_callback = Self.render,
            .component_context = self,
            .event_callback = Self.event_callback,
        });
    }

    pub fn render(ctx: *anyopaque, parent_widget: *widget.Widget) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const size = self.font_provider.measureText(self.text);
        parent_widget.set_bbox_size(size);
        self.font_provider.renderText(self.text, parent_widget.position[0], parent_widget.position[1]);
    }
};
