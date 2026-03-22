import Foundation
import Metal

enum HeightFieldRendererError: Error, LocalizedError {
    case noDevice
    case noCommandQueue
    case noLibrary
    case noFunction
    case noPipelineState(Error)
    case noTexture
    case noBuffer

    var errorDescription: String? {
        switch self {
        case .noDevice:          return "No Metal device available"
        case .noCommandQueue:    return "Failed to create Metal command queue"
        case .noLibrary:         return "Failed to load Metal default library"
        case .noFunction:        return "tidalHeightField kernel not found in library"
        case .noPipelineState(let e): return "Failed to create compute pipeline: \(e.localizedDescription)"
        case .noTexture:         return "Failed to create output texture"
        case .noBuffer:          return "Failed to create height field buffer"
        }
    }
}

final class HeightFieldRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    let outputTexture: MTLTexture          // 512×256, reused across frames
    private let heightFieldBuffer: MTLBuffer  // 2048 floats, reused
    private var flatBuffer: [Float]        // pre-allocated for flattening [[Float]]

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw HeightFieldRendererError.noDevice
        }
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            throw HeightFieldRendererError.noCommandQueue
        }
        self.commandQueue = queue

        guard let library = device.makeDefaultLibrary() else {
            throw HeightFieldRendererError.noLibrary
        }

        guard let function = library.makeFunction(name: "tidalHeightField") else {
            throw HeightFieldRendererError.noFunction
        }

        do {
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            throw HeightFieldRendererError.noPipelineState(error)
        }

        // Create 512×256 output texture (reused every frame)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 512,
            height: 256,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw HeightFieldRendererError.noTexture
        }
        self.outputTexture = texture

        // Create buffer for 64×32 = 2048 floats
        guard let buffer = device.makeBuffer(
            length: 2048 * MemoryLayout<Float>.size,
            options: .storageModeShared
        ) else {
            throw HeightFieldRendererError.noBuffer
        }
        self.heightFieldBuffer = buffer
        self.flatBuffer = [Float](repeating: 0, count: TidalForceField.rows * TidalForceField.columns)
    }

    func render(field: TidalForceField) {
        // Flatten [[Float]] (32 rows × 64 cols) into pre-allocated buffer
        var offset = 0
        for row in field.heightField {
            let count = min(row.count, TidalForceField.columns)
            for i in 0..<count {
                flatBuffer[offset + i] = row[i]
            }
            offset += TidalForceField.columns
        }

        // Copy to shared Metal buffer
        heightFieldBuffer.contents().copyMemory(
            from: flatBuffer,
            byteCount: flatBuffer.count * MemoryLayout<Float>.size
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(heightFieldBuffer, offset: 0, index: 0)
        encoder.setTexture(outputTexture, index: 0)

        let threadsPerGrid = MTLSize(width: 512, height: 256, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
