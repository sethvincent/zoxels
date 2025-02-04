const std = @import("std");
const rl = @import("raylib");
const voxel = @import("voxel.zig");
const render = @import("render.zig");
const entity = @import("entity.zig");

const World = voxel.World;
const Chunk = voxel.Chunk;
const Voxel = voxel.Voxel;

const vector3FromPosition = voxel.vector3FromPosition;
const positionFromVector3 = voxel.positionFromVector3;

const VoxelRenderer = render.VoxelRenderer;
const Player = entity.Player;

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "zoxels");
    defer rl.closeWindow(); // Close window and OpenGL context

    //--------------------------------------------------------------------------------------
    const move_speed: f32 = 5;

    var player = Player{
        .height = 2,
        .width = 1,
        .speed = move_speed,
        .mouse_sensitivity = 0.005,
        .yaw = 0,
        .pitch = 0,
        .velocity_y = 0,
        .is_jumping = true,
        .jump_time = 0,
        .position = .{
            .x = 8,
            .y = 18,
            .z = 8,
        },
        .direction = .{
            .x = 0,
            .y = 0,
            .z = -1,
        },
    };

    var camera = rl.Camera3D{
        .position = player.position.add(rl.Vector3{ .x = 0, .y = player.height, .z = 0 }),
        .target = player.position.add(player.direction),
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = .perspective,
    };

    camera.update(.custom);
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    const allocator = std.heap.page_allocator;
    var world = World.init(allocator, 16);
    defer world.deinit();

    const chunk_position = Chunk.Position{
        .x = 0,
        .y = 0,
        .z = 0,
    };

    const voxels = try allocator.alloc(
        Voxel.Id,
        world.chunk_size * world.chunk_size * world.chunk_size,
    );

    @memset(voxels, 1);

    const chunk = Chunk.init(allocator, voxels, chunk_position);

    try world.setChunk(chunk);

    var renderer = try VoxelRenderer.init(
        allocator,
        @intCast(std.time.timestamp()),
        100,
    );

    var mouse_delta = rl.Vector2{ .x = 0, .y = 0 };

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //---------
        mouse_delta = rl.getMouseDelta();
        // rl.traceLog(.info, "Mouse Delta: x=%f y=%f", .{ mouse_delta.x, mouse_delta.y });

        if (rl.isCursorHidden()) {
            camera.update(.custom);
        }

        // Toggle camera controls
        if (rl.isMouseButtonPressed(.right)) {
            if (rl.isCursorHidden()) rl.enableCursor() else rl.disableCursor();
        }

        if (rl.isMouseButtonPressed(.left)) {}

        try player.update(&world, mouse_delta);
        camera.position = player.position;
        camera.target = player.position.add(player.direction);

        // rl.traceLog(.info, "Player pitch=%f yaw=%f", .{
        //     player.pitch,
        //     player.yaw,
        // });

        // rl.traceLog(.info, "Player direction x=%f y=%f z=%f", .{
        //     player.direction.x,
        //     player.direction.y,
        //     player.direction.z,
        // });

        // rl.traceLog(.info, "Player position x=%f y=%f z=%f", .{
        //     player.position.x,
        //     player.position.y,
        //     player.position.z,
        // });

        // rl.traceLog(.info, "Camera target: x=%f y=%f z=%f", .{
        //     camera.target.x,
        //     camera.target.y,
        //     camera.target.z,
        // });

        // rl.traceLog(.info, "Camera position: x=%f y=%f z=%f", .{
        //     camera.position.x,
        //     camera.position.y,
        //     camera.position.z,
        // });
        // try world.update(player.position);

        // Draw
        //---------

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);
        camera.begin();
        defer camera.end();

        {
            rl.drawGrid(10, 1);

            rl.drawCube(
                player.position,
                1,
                1,
                1,
                rl.Color.red,
            );

            if (world.getChunk(chunk_position)) |c| {
                var iterate = Chunk.iteratePositions(world.chunk_size);

                while (iterate.next()) |position| {
                    const voxel_volume = c.getVoxelVolume(
                        world.chunk_size,
                        position,
                    ).?;

                    switch (voxel_volume) {
                        .full => |id| {
                            const color = renderer.getColor(id);
                            rl.drawCube(
                                vector3FromPosition(position),
                                1.0,
                                1.0,
                                1.0,
                                color,
                            );
                        },
                        .divided => {
                            // ignore for now!
                        },
                    }
                }
            }
        }
    }
}
