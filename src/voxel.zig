const std = @import("std");
const rl = @import("raylib");

const t = std.testing;
const Allocator = std.mem.Allocator;

pub const Voxel = struct {
    id: Id,

    pub const Id = u8;

    pub const Volume = union(enum) {
        full: Voxel.Id,
        divided: [8]Voxel.Id,
    };

    /// Coordinates within a a single Chunk's VoxelGrid.
    /// Always positive, always less than Chunk.Size (0 to Chunk.Size - 1).
    pub const Position = struct {
        pub const coordinateType = u32;

        x: coordinateType,
        y: coordinateType,
        z: coordinateType,

        pub fn index(v: Voxel.Position, chunk_size: Chunk.Size) ?usize {
            if (v.x >= chunk_size or v.y >= chunk_size or v.z >= chunk_size) {
                return null;
            }

            return v.x + (v.y * chunk_size) + (v.z * chunk_size * chunk_size);
        }

        pub fn fromWorldPosition(chunk_size: Chunk.Size, world_position: World.Position) Voxel.Position {
            return .{
                .x = coordinateFromWorldCoordinate(world_position.x, chunk_size),
                .y = coordinateFromWorldCoordinate(world_position.y, chunk_size),
                .z = coordinateFromWorldCoordinate(world_position.z, chunk_size),
            };
        }

        pub fn coordinateFromWorldCoordinate(world_coordinate: i32, chunk_size: u32) u32 {
            const chunk_size_i32: i32 = @intCast(chunk_size);
            const chunk_offset = @divFloor(world_coordinate, chunk_size_i32) * chunk_size_i32;
            return @intCast(world_coordinate - chunk_offset);
        }
    };
};

pub const Chunk = struct {
    position: Position,
    voxels: []Voxel.Id,
    divided_voxels: std.AutoHashMap(Voxel.Position, [8]Voxel.Id),

    pub const Size = u16;

    /// Position of a Chunk in a World
    /// Can be negative or positive
    pub const Position = struct {
        pub const coordinateType = i32;

        x: coordinateType,
        y: coordinateType,
        z: coordinateType,

        pub fn fromWorldPosition(
            chunk_size: Chunk.Size,
            world_position: World.Position,
        ) Chunk.Position {
            return .{
                .x = @divFloor(world_position.x, chunk_size),
                .y = @divFloor(world_position.y, chunk_size),
                .z = @divFloor(world_position.z, chunk_size),
            };
        }
    };

    pub fn init(
        allocator: Allocator,
        voxels: []Voxel.Id,
        position: Chunk.Position,
    ) Chunk {
        return .{
            .position = position,
            .voxels = voxels,
            .divided_voxels = std.AutoHashMap(Voxel.Position, [8]Voxel.Id).init(allocator),
        };
    }

    pub fn deinit(c: *Chunk) void {
        c.divided_voxels.deinit();
    }

    pub fn generateChunk(allocator: Allocator, chunk_size: Size, position: Chunk.Position) !Chunk {
        const voxels = try allocator.alloc(
            Voxel.Id,
            chunk_size * chunk_size * chunk_size,
        );

        @memset(voxels, 0);

        var iterate = iteratePositions(chunk_size);
        while (iterate.next()) |voxel_position| {
            if ((position.y * @as(i32, chunk_size) + @as(i32, @intCast(voxel_position.y))) < 10) {
                voxels[voxel_position.index(chunk_size).?] = 1;
            }
        }

        return Chunk.init(allocator, voxels, position);
    }

    pub fn hasVoxelVolume(c: *Chunk, voxel_position: Voxel.Position) bool {
        if (voxel_position.index(c.size)) |i| {
            if (c.voxels[i]) |v| {
                return v != 0;
            }
        }

        return false;
    }

    pub fn getVoxelVolume(
        c: *Chunk,
        chunk_size: Size,
        voxel_position: Voxel.Position,
    ) ?Voxel.Volume {
        if (voxel_position.index(chunk_size)) |i| {
            if (c.divided_voxels.get(voxel_position)) |sub_voxels| {
                return .{ .divided = sub_voxels };
            } else {
                return .{ .full = c.voxels[i] };
            }
        }

        return null;
    }

    pub fn setVoxelVolume(
        c: *Chunk,
        chunk_size: Size,
        voxel_volume: Voxel.Volume,
        voxel_position: Voxel.Position,
    ) !void {
        if (voxel_position.index(chunk_size)) |i| {
            switch (voxel_volume) {
                .full => |id| {
                    _ = c.divided_voxels.remove(voxel_position);
                    c.voxels[i] = id;
                },
                .divided => |sub_voxels| {
                    try c.divided_voxels.put(voxel_position, sub_voxels);
                    c.voxels[i] = 0;
                },
            }
        }
    }

    pub fn coordinateFromWorldCoordinate(world_coordinate: i32, chunk_size: Chunk.Size) u32 {
        const chunk_offset = @divFloor(world_coordinate, chunk_size) * chunk_size;
        return @intCast(world_coordinate - chunk_offset);
    }

    pub fn iteratePositions(size: Size) Iterator {
        return Iterator{
            .size = size,
            .current = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
        };
    }

    pub const Iterator = struct {
        size: Size,
        current: Voxel.Position,

        pub fn next(i: *Iterator) ?Voxel.Position {
            if (i.current.x >= i.size) {
                return null;
            }

            const position = i.current;

            i.current.z += 1;
            if (i.current.z >= i.size) {
                i.current.z = 0;
                i.current.y += 1;

                if (i.current.y >= i.size) {
                    i.current.y = 0;
                    i.current.x += 1;
                }
            }

            return position;
        }
    };
};

test Chunk {
    const chunk_size: usize = 4;
    const voxels = try t.allocator.alloc(Voxel.Id, chunk_size * chunk_size * chunk_size);
    defer t.allocator.free(voxels);

    @memset(voxels, 0);

    var chunk = Chunk.init(
        t.allocator,
        voxels,
        .{ .x = 0, .y = 0, .z = 0 },
    );

    const voxel_position = Voxel.Position{ .x = 1, .y = 2, .z = 1 };
    const voxel_volume = Voxel.Volume{ .full = 1 };
    try chunk.setVoxelVolume(chunk_size, voxel_volume, voxel_position);
    const result_voxel_volume = chunk.getVoxelVolume(chunk_size, voxel_position);

    const id: Voxel.Id = result_voxel_volume.?.full;
    try t.expectEqual(1, id);
}

pub const World = struct {
    allocator: Allocator,
    chunks: std.AutoHashMap(Chunk.Position, Chunk),
    chunk_size: Chunk.Size,

    pub fn init(allocator: Allocator, chunk_size: Chunk.Size) World {
        return .{
            .allocator = allocator,
            .chunks = std.AutoHashMap(Chunk.Position, Chunk).init(allocator),
            .chunk_size = chunk_size,
        };
    }

    pub fn deinit(world: *World) void {
        world.chunks.deinit();
    }

    pub fn update(w: *World, position: World.Position) !void {
        _ = w;
        _ = position;
        // const current_chunk_position = Chunk.Position.fromWorldPosition(w.chunk_size, position);

        // if (w.hasChunk(current_chunk_position) == false) {
        //     const chunk = try Chunk.generateChunk(w.allocator, w.chunk_size, current_chunk_position);
        //     try w.setChunk(chunk);
        // }
    }

    pub fn hasChunk(w: *World, position: Chunk.Position) bool {
        if (w.chunks.getPtr(position)) |_| {
            return true;
        }

        return false;
    }

    pub fn getChunk(world: *World, position: Chunk.Position) ?*Chunk {
        return world.chunks.getPtr(position);
    }

    pub fn setChunk(world: *World, chunk: Chunk) !void {
        try world.chunks.put(chunk.position, chunk);
    }

    pub fn getVoxel(w: *World, world_position: World.Position) ?Voxel.Volume {
        const chunk_position = Chunk.Position.fromWorldPosition(
            w.chunk_size,
            world_position,
        );

        if (w.getChunk(chunk_position)) |chunk| {
            const voxel_position = Voxel.Position.fromWorldPosition(
                w.chunk_size,
                world_position,
            );

            return chunk.getVoxelVolume(w.chunk_size, voxel_position);
        }

        return null;
    }

    pub fn setVoxel(w: *World, voxel: Voxel.Volume, world_position: World.Position) !void {
        const chunk_position = Chunk.Position.fromWorldPosition(
            w.chunk_size,
            world_position,
        );

        if (w.getChunk(chunk_position)) |chunk| {
            const voxel_position = Voxel.Position.fromWorldPosition(
                w.chunk_size,
                world_position,
            );

            return chunk.setVoxelVolume(w.chunk_size, voxel, voxel_position);
        }
    }

    /// Absolute position in the entire world
    /// Can be negative or positive
    pub const Position = struct {
        pub const coordinateType = i32;
        x: coordinateType,
        y: coordinateType,
        z: coordinateType,
    };
};

test World {
    var world = World.init(t.allocator, 10);
    defer world.deinit();

    const chunk_size: usize = 10;
    const position = Chunk.Position{
        .x = 0,
        .y = 0,
        .z = 0,
    };

    const voxels = try t.allocator.alloc(
        Voxel.Id,
        chunk_size * chunk_size * chunk_size,
    );
    defer t.allocator.free(voxels);

    @memset(voxels, 0);

    const chunk = Chunk.init(t.allocator, voxels, position);

    try world.setChunk(chunk);
    const result = world.getChunk(position);
    try t.expect(result != null);

    if (result) |c| {
        try t.expectEqual(0, c.position.x);
        try t.expectEqual(0, c.position.y);
        try t.expectEqual(0, c.position.z);
    }

    const world_position = World.Position{
        .x = 1,
        .y = 2,
        .z = 1,
    };

    try world.setVoxel(.{ .full = 1 }, world_position);
    if (world.getVoxel(world_position)) |voxel_volume| {
        try t.expectEqual(Voxel.Volume{ .full = 1 }, voxel_volume);
    }
}

pub fn vector3FromPosition(position: anytype) rl.Vector3 {
    return .{
        .x = @as(f32, @floatFromInt(position.x)),
        .y = @as(f32, @floatFromInt(position.y)),
        .z = @as(f32, @floatFromInt(position.z)),
    };
}

pub fn positionFromVector3(comptime T: type, vector: rl.Vector3) T {
    return T{
        .x = @as(T.coordinateType, @intFromFloat(vector.x)),
        .y = @as(T.coordinateType, @intFromFloat(vector.y)),
        .z = @as(T.coordinateType, @intFromFloat(vector.z)),
    };
}
