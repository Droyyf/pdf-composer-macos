import Foundation
import MetalKit

class MetalBackgroundRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    private var uniforms = Uniforms(time: 0, resolution: .zero, blurRadius: 0.0, noiseIntensity: 0.2, grainIntensity: 0.2, textureMix: 0.5, colorTint: SIMD4<Float>(1, 1, 1, 1), vignette: 0.0)
    private var texture: MTLTexture?
    private var sampler: MTLSamplerState!
    private var startTime: CFTimeInterval = CACurrentMediaTime()

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

    init(mtkView: MTKView, texture: MTLTexture? = nil) {
        self.device = mtkView.device!
        self.commandQueue = device.makeCommandQueue()!
        self.texture = texture
        super.init()
        mtkView.delegate = self
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        buildPipeline(mtkView: mtkView)
        buildVertexBuffer()
        buildSampler()
    }

    private func buildPipeline(mtkView: MTKView) {
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertex_passthrough") ?? library.makeFunction(name: "vertex_main")
        let fragmentFunc = library.makeFunction(name: "backgroundShader")
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunc
        pipelineDesc.fragmentFunction = fragmentFunc
        pipelineDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
    }

    private func buildVertexBuffer() {
        // Fullscreen quad
        let vertices: [Float] = [
            -1, -1, 0, 1, 0, 1,
            1, -1, 0, 1, 1, 1,
            -1, 1, 0, 1, 0, 0,
            1, 1, 0, 1, 1, 0
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
    }

    private func buildSampler() {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)
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
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
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
}
