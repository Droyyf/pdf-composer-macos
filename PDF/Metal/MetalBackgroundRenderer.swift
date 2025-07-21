import Foundation
import MetalKit

enum MetalBackgroundRendererError: Error {
    case deviceNotAvailable
    case commandQueueCreationFailed
    case libraryNotAvailable
    case vertexFunctionNotFound
    case fragmentFunctionNotFound
    case pipelineStateCreationFailed
    case bufferCreationFailed
    case samplerCreationFailed
    case commandBufferCreationFailed
    case renderEncoderCreationFailed
}

class MetalBackgroundRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var uniforms = Uniforms(time: 0, resolution: .zero, blurRadius: 0.0, noiseIntensity: 0.2, grainIntensity: 0.2, textureMix: 0.5, colorTint: SIMD4<Float>(1, 1, 1, 1), vignette: 0.0)
    private var texture: MTLTexture?
    private var sampler: MTLSamplerState?
    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private var isInitialized = false

    struct Uniforms {
        var time: Float
        var resolution: SIMD2<Float>
        var blurRadius: Float
        var noiseIntensity: Float
        var grainIntensity: Float
        var textureMix: Float
        var colorTint: SIMD4<Float>
        var vignette: Float
    }

    init(mtkView: MTKView, texture: MTLTexture? = nil) throws {
        guard let device = mtkView.device else {
            throw MetalBackgroundRendererError.deviceNotAvailable
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalBackgroundRendererError.commandQueueCreationFailed
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.texture = texture
        super.init()
        
        mtkView.delegate = self
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        
        try buildPipeline(mtkView: mtkView)
        try buildVertexBuffer()
        try buildSampler()
        
        isInitialized = true
    }

    private func buildPipeline(mtkView: MTKView) throws {
        guard let library = device.makeDefaultLibrary() else {
            throw MetalBackgroundRendererError.libraryNotAvailable
        }
        
        let vertexFunc = library.makeFunction(name: "vertex_passthrough") ?? library.makeFunction(name: "vertex_main")
        guard let vertexFunction = vertexFunc else {
            throw MetalBackgroundRendererError.vertexFunctionNotFound
        }
        
        guard let fragmentFunc = library.makeFunction(name: "backgroundShader") else {
            throw MetalBackgroundRendererError.fragmentFunctionNotFound
        }
        
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunction
        pipelineDesc.fragmentFunction = fragmentFunc
        pipelineDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch {
            throw MetalBackgroundRendererError.pipelineStateCreationFailed
        }
    }

    private func buildVertexBuffer() throws {
        // Fullscreen quad
        let vertices: [Float] = [
            -1, -1, 0, 1, 0, 1,
            1, -1, 0, 1, 1, 1,
            -1, 1, 0, 1, 0, 0,
            1, 1, 0, 1, 1, 0
        ]
        
        guard let buffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: []) else {
            throw MetalBackgroundRendererError.bufferCreationFailed
        }
        
        vertexBuffer = buffer
    }

    private func buildSampler() throws {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw MetalBackgroundRendererError.samplerCreationFailed
        }
        
        sampler = samplerState
    }

    func updateUniforms(time: Float, resolution: CGSize, blur: Float, noise: Float, grain: Float, textureMix: Float, colorTint: SIMD4<Float>, vignette: Float) {
        uniforms.time = time
        uniforms.resolution = SIMD2<Float>(Float(resolution.width), Float(resolution.height))
        uniforms.blurRadius = blur
        uniforms.noiseIntensity = noise
        uniforms.grainIntensity = grain
        uniforms.textureMix = textureMix
        uniforms.colorTint = colorTint
        uniforms.vignette = vignette
    }

    func draw(in view: MTKView) {
        // Early return if not properly initialized
        guard isInitialized,
              let pipelineState = pipelineState,
              let vertexBuffer = vertexBuffer,
              let sampler = sampler else {
            return
        }
        
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        
        if let tex = texture {
            encoder.setFragmentTexture(tex, index: 0)
        }
        
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op
    }
    
    deinit {
        // Explicit cleanup of Metal resources
        // Note: Most Metal resources are reference-counted and will be cleaned up automatically,
        // but we explicitly nil them to ensure proper cleanup order and make our intent clear
        
        pipelineState = nil
        vertexBuffer = nil
        sampler = nil
        texture = nil
        
        // Mark as not initialized to prevent any further operations
        isInitialized = false
        
        // Device and commandQueue are let properties and will be cleaned up automatically
        // when this object is deallocated
    }
}
