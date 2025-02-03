const std = @import("std");
const rl = @import("raylib");

const t = std.testing;
const Allocator = std.mem.Allocator;

pub const Voxel = struct {
    id: Id,

    pub const Id = u8;

    /// Coordinates within a a single Chunk's VoxelGrid.
    /// Always positive, always less than Chunk.Size (0 to Chunk.Size - 1).
    pub const Position = struct {
        x: u32,
        y: u32,
        z: u32,

        pub fn index(v: Voxel.Position, grid_size: VoxelGrid.Size) ?usize {
            if (v.x >= grid_size or v.y >= grid_size or v.z >= grid_size) {
                return null;
            }

            return v.x + (v.y * grid_size) + (v.z * grid_size * grid_size);
        }

        pub fn fromWorldPosition(world_position: World.Position, chunk_size: Chunk.Size) Voxel.Position {
            return .{
                .x = coordinateFromWorldCoordinate(world_position.x, chunk_size),
                .y = coordinateFromWorldCoordinate(world_position.y, chunk_size),
                .z = coordinateFromWorldCoordinate(world_position.z, chunk_size),
            };
        }

        pub fn coordinateFromWorldCoordinate(world_coordinate: i32, chunk_size: u32) u32 {
            const chunk_offset = @divFloor(world_coordinate, chunk_size) * chunk_size;
            return @intCast(world_coordinate - chunk_offset);
        }
    };
};

pub const VoxelGrid = struct {
    voxels: []Voxel.Id,
    size: Size,

    pub const Size = u16;

    pub fn init(grid_size: usize, voxels: []Voxel) VoxelGrid {
        return .{
            .grid_size = grid_size,
            .voxels = voxels,
        };
    }

    pub fn get(v: *VoxelGrid, voxel_position: Voxel.Position) ?Voxel {
        if (voxel_position.index(v.size)) |i| {
            return v.voxels[i];
        }

        return null;
    }

    pub fn set(v: *VoxelGrid, voxel_position: Voxel.Position, voxel: Voxel) void {
        if (voxel_position.index(v.size)) |i| {
            v.voxels[i] = voxel;
        }
    }
};

test VoxelGrid {
    const grid_size: usize = 4;
    const voxels = try t.allocator.alloc(Voxel, grid_size * grid_size * grid_size);
    defer t.allocator.free(voxels);

    @memset(voxels, 0);

    var grid = VoxelGrid.init(grid_size, voxels);

    const x: u32 = 1;
    const y: u32 = 2;
    const z: u32 = 1;
    grid.set(x, y, z, 1);

    const value: Voxel = 1;
    grid.set(x, y, z, value);
    const result = grid.get(x, y, z);
    try t.expectEqual(result, value);
}

pub const Chunk = struct {
    position: Position,
    grid: VoxelGrid,

    /// Position of a Chunk in a World
    /// Can be negative or positive
    pub const Position = struct {
        x: i32,
        y: i32,
        z: i32,
    };

    pub fn getVoxel(c: *Chunk, voxel_position: Voxel.Position) ?Voxel {
        return c.grid.get(voxel_position);
    }

    pub fn setVoxel(c: *Chunk, voxel_position: Voxel.Position, voxel: Voxel) void {
        c.grid.set(voxel_position, voxel);
    }

    pub fn getVoxelFromWorldPosition(c: *Chunk, world_position: World.Position) ?Voxel {
        const voxel_position = Voxel.Position.fromWorldPosition(world_position, c.grid.size);
        return c.grid.get(voxel_position);
    }

    pub fn setVoxelFromWorldPosition(c: *Chunk, world_position: World.Position, voxel: Voxel) void {
        const voxel_position = Voxel.Position.fromWorldPosition(world_position, c.grid.size);
        return c.grid.set(voxel_position, voxel);
    }

    pub fn coordinateFromWorldCoordinate(world_coordinate: i32, grid_size: VoxelGrid.Size) u32 {
        const chunk_offset = @divFloor(world_coordinate, grid_size) * grid_size;
        return @intCast(world_coordinate - chunk_offset);
    }

    pub fn positionFromWorldPosition(world_position: World.Position, grid_size: VoxelGrid.Size) Chunk.Position {
        return .{
            .x = @divFloor(world_position.x, grid_size),
            .y = @divFloor(world_position.y, grid_size),
            .z = @divFloor(world_position.z, grid_size),
        };
    }
};

pub const World = struct {
    allocator: Allocator,
    chunks: std.AutoHashMap(Chunk.Position, Chunk),
    chunk_size: Chunk.Size,

    pub fn init(allocator: Allocator, grid_size: VoxelGrid.Size) World {
        return .{
            .allocator = allocator,
            .chunks = std.AutoHashMap(Chunk.Position, Chunk).init(allocator),
            .chunk_size = grid_size,
        };
    }

    pub fn deinit(world: *World) void {
        world.chunks.deinit();
    }

    pub fn getChunk(world: *World, position: Chunk.Position) ?*Chunk {
        return world.chunks.getPtr(position);
    }

    pub fn setChunk(world: *World, chunk: Chunk) !void {
        try world.chunks.put(chunk.position, chunk);
    }

    // pub fn getVoxel(w: *World, x: i32, y: i32, z: i32) ?Voxel {
    //     if (w.getChunk(chunk_position)) |chunk| {
    //         return chunk.voxelFromWorldPosition(x, y, z, w.chunk_size);
    //     }

    //     return null;
    // }

    // pub fn setVoxel(w: *World, x: i32, y: i32, z: i32, voxel: Voxel) void {
    //     const chunk_position = Chunk.positionFromWorldPosition(.{
    //         .x = x,
    //         .y = y,
    //         .z = z,
    //     });

    //     if (w.getChunk(chunk_position)) |chunk| {
    //         chunk.setVoxel(voxel);
    //     }

    //     return null;
    // }

    /// Absolute position in the entire world
    /// Can be negative or positive
    pub const Position = struct {
        x: i32,
        y: i32,
        z: i32,
    };
};

test World {
    var world = World.init(t.allocator, 10);
    defer world.deinit();

    const chunk_position = Chunk.Position{ .x = 0, .y = 0, .z = 0 };

    const grid_size: usize = 4;
    const voxels = try t.allocator.alloc(Voxel, grid_size * grid_size * grid_size);
    defer t.allocator.free(voxels);
    @memset(voxels, 0);
    const grid = VoxelGrid.init(grid_size, voxels);

    const chunk = Chunk{ .position = chunk_position, .grid = grid };
    try world.setChunk(chunk);

    const result = world.getChunk(chunk_position);
    try t.expect(result != null);

    if (result) |c| {
        try t.expectEqual(c.position.x, 0);
        try t.expectEqual(c.position.y, 0);
        try t.expectEqual(c.position.z, 0);
    }
}
