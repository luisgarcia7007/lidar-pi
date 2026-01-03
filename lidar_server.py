import asyncio
import websockets
import json
import numpy as np

PORT = 8765

def get_lidar_points():
    # DEMO DATA: replace later with real LiDAR
    pts = np.random.uniform(-5, 5, size=(3000, 3))
    return pts.tolist()

async def lidar_stream(websocket):
    print("Client connected")

    try:
        while True:
            points = get_lidar_points()

            msg = json.dumps({
                "points": points
            })

            await websocket.send(msg)
            await asyncio.sleep(0.05)  # ~20 FPS

    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    async with websockets.serve(lidar_stream, "0.0.0.0", PORT):
        print(f"LiDAR server running on port {PORT}")
        await asyncio.Future()

asyncio.run(main())
