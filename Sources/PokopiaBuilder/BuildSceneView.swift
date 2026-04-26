import AppKit
import SceneKit
import SwiftUI
import UniformTypeIdentifiers

struct BuildSceneView: View {
    @EnvironmentObject private var store: PlannerStore

    var body: some View {
        GeometryReader { proxy in
            SceneKitCanvas(blocks: store.buildBlocks)
                .onDrop(of: [.text], delegate: BuildSceneDropDelegate(store: store, size: proxy.size))
        }
        .frame(minHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}

private struct BuildSceneDropDelegate: DropDelegate {
    @ObservedObject var store: PlannerStore
    var size: CGSize

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        let location = info.location
        let world = worldPosition(for: location, size: size)
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            let string: String?
            if let data = item as? Data {
                string = String(data: data, encoding: .utf8)
            } else {
                string = item as? String
            }

            guard let id = string else { return }
            Task { @MainActor in
                store.addItem(with: id, at: world)
            }
        }
        return true
    }

    private func worldPosition(for location: CGPoint, size: CGSize) -> SIMD3<Float> {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let x = round(Float((location.x / width) - 0.5) * 14)
        let z = round(Float((location.y / height) - 0.5) * 10)
        return SIMD3<Float>(max(-8, min(8, x)), 0, max(-8, min(8, z)))
    }
}

private struct SceneKitCanvas: NSViewRepresentable {
    var blocks: [PlacedBlock]

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = NSColor(calibratedRed: 0.55, green: 0.84, blue: 0.96, alpha: 1)
        view.antialiasingMode = .multisampling4X
        context.coordinator.configureBaseScene()
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.update(blocks: blocks)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        let scene = SCNScene()
        private let contentNode = SCNNode()

        func configureBaseScene() {
            guard contentNode.parent == nil else { return }

            scene.rootNode.addChildNode(contentNode)
            scene.rootNode.addChildNode(cameraNode())
            scene.rootNode.addChildNode(sunNode())
            scene.rootNode.addChildNode(lightNode(type: .ambient, position: SCNVector3Zero, intensity: 420))
            addReferenceGround()
        }

        func update(blocks: [PlacedBlock]) {
            contentNode.childNodes.forEach { $0.removeFromParentNode() }
            for placed in blocks {
                contentNode.addChildNode(nodes(for: placed))
            }
        }

        private func cameraNode() -> SCNNode {
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            camera.orthographicScale = 10.5
            camera.zNear = 0.1
            camera.zFar = 100
            let node = SCNNode()
            node.camera = camera
            node.position = SCNVector3(7.2, 7.4, 8.2)
            node.look(at: SCNVector3(0, 0, 0))
            return node
        }

        private func sunNode() -> SCNNode {
            let light = SCNLight()
            light.type = .directional
            light.intensity = 950
            light.castsShadow = true
            light.shadowMode = .deferred
            light.shadowRadius = 5
            light.shadowSampleCount = 16
            let node = SCNNode()
            node.light = light
            node.eulerAngles = SCNVector3(-0.85, 0.45, -0.35)
            return node
        }

        private func lightNode(type: SCNLight.LightType, position: SCNVector3, intensity: CGFloat) -> SCNNode {
            let light = SCNLight()
            light.type = type
            light.intensity = intensity
            let node = SCNNode()
            node.light = light
            node.position = position
            return node
        }

        private func nodes(for placed: PlacedBlock) -> SCNNode {
            let group = SCNNode()
            group.name = placed.block.name

            let visualCount = visualCopies(for: placed)
            let offsets = copyOffsets(count: visualCount, block: placed.block)
            for offset in offsets {
                let copy = PlacedBlock(
                    block: placed.block,
                    count: placed.count,
                    position: SIMD3<Float>(placed.position.x + offset.x, 0, placed.position.z + offset.y),
                    rotation: placed.rotation,
                    footprint: placed.footprint
                )
                group.addChildNode(node(for: copy, showLabel: offset == offsets.first))
            }

            return group
        }

        private func node(for placed: PlacedBlock, showLabel: Bool) -> SCNNode {
            if let modelURL = placed.block.modelURL, let model = modelNode(for: placed, url: modelURL, showLabel: showLabel) {
                return model
            }
            if placed.block.isConstructionBlock {
                return constructionNode(for: placed, showLabel: showLabel)
            }
            if placed.block.prefersCutoutModel, let image = placed.block.cutoutImage {
                return cutoutNode(for: placed, image: image, showLabel: showLabel)
            }
            return blockNode(for: placed, showLabel: showLabel)
        }

        private func modelNode(for placed: PlacedBlock, url: URL, showLabel: Bool) -> SCNNode? {
            guard let sourceScene = try? SCNScene(url: url, options: nil) else { return nil }

            let parent = SCNNode()
            parent.name = placed.block.name
            parent.position = SCNVector3(placed.position.x, 0, placed.position.z)
            parent.eulerAngles.y = CGFloat(placed.rotation)

            let modelRoot = SCNNode()
            for child in sourceScene.rootNode.childNodes {
                modelRoot.addChildNode(child.clone())
            }
            normalize(modelRoot, targetSize: placed.block.modelTargetSize)
            parent.addChildNode(modelRoot)

            if showLabel && placed.count > 1 {
                let label = textNode(for: placed)
                label.position = SCNVector3(-0.18, placed.block.modelTargetSize.y + 0.18, 0)
                parent.addChildNode(label)
            }

            return parent
        }

        private func normalize(_ node: SCNNode, targetSize: SIMD3<Float>) {
            let bounds = node.boundingBox
            let min = bounds.min
            let maxBounds = bounds.max
            let size = SIMD3<Float>(
                Swift.max(Float(maxBounds.x - min.x), 0.001),
                Swift.max(Float(maxBounds.y - min.y), 0.001),
                Swift.max(Float(maxBounds.z - min.z), 0.001)
            )
            let target = Swift.max(targetSize.x, Swift.max(targetSize.y, targetSize.z))
            let current = Swift.max(size.x, Swift.max(size.y, size.z))
            let scale = target / current

            node.scale = SCNVector3(scale, scale, scale)

            let center = SCNVector3(
                (min.x + maxBounds.x) / 2,
                min.y,
                (min.z + maxBounds.z) / 2
            )
            node.position = SCNVector3(-center.x * CGFloat(scale), -center.y * CGFloat(scale), -center.z * CGFloat(scale))
        }

        private func blockNode(for placed: PlacedBlock, showLabel: Bool) -> SCNNode {
            let width = CGFloat(max(0.92, placed.footprint.x))
            let length = CGFloat(max(0.92, placed.footprint.y))
            let height = CGFloat(height(for: placed.block.kind))
            let box = SCNBox(width: width, height: height, length: length, chamferRadius: blockChamfer(for: placed.block.kind))
            box.materials = materials(for: placed.block)

            let node = SCNNode(geometry: box)
            node.name = placed.block.name
            node.position = SCNVector3(placed.position.x, Float(height / 2), placed.position.z)
            node.eulerAngles.y = CGFloat(placed.rotation)

            if showLabel && placed.count > 1 {
                let label = textNode(for: placed)
                label.position = SCNVector3(0, Float(height) + 0.08, 0)
                node.addChildNode(label)
            }

            return node
        }

        private func constructionNode(for placed: PlacedBlock, showLabel: Bool) -> SCNNode {
            let block = placed.block
            let name = block.name.lowercased()
            let palette = constructionPalette(for: block)
            let parent = SCNNode()
            parent.name = block.name
            parent.position = SCNVector3(placed.position.x, 0, placed.position.z)
            parent.eulerAngles.y = CGFloat(placed.rotation)

            if name.contains("cube light") || name.contains("light") && block.kind == .utility {
                let cube = makeBox(width: 0.78, height: 0.78, length: 0.78, chamfer: 0.08, materials: glowingMaterials(color: palette.top))
                cube.position.y = 0.39
                parent.addChildNode(cube)
                let glow = SCNLight()
                glow.type = .omni
                glow.intensity = 140
                glow.color = palette.top
                let glowNode = SCNNode()
                glowNode.light = glow
                glowNode.position.y = 0.72
                parent.addChildNode(glowNode)
            } else if name.contains("crystal") || name.contains("glowing stone") || name.contains("mysterious stone") {
                let crystal = SCNPyramid(width: 0.82, height: 0.95, length: 0.82)
                crystal.firstMaterial = translucentMaterial(color: palette.top)
                let crystalNode = SCNNode(geometry: crystal)
                crystalNode.position.y = 0.48
                parent.addChildNode(crystalNode)
                addBaseShadow(to: parent, radius: 0.38)
            } else if block.kind == .floor || block.kind == .terrain || block.kind == .pattern || name.contains("road") || name.contains("tiling") || name.contains("carpeting") || name.contains("mat") {
                let tile = makeBox(width: 0.96, height: 0.12, length: 0.96, chamfer: 0.018, materials: tileMaterials(for: block, palette: palette))
                tile.position.y = 0.06
                parent.addChildNode(tile)
                addTileDetails(to: parent, block: block, palette: palette)
            } else if block.kind == .wall || name.contains("wall") || name.contains("pillar") {
                let slab = makeBox(width: wallWidth(for: name), height: wallHeight(for: name), length: 0.22, chamfer: 0.018, materials: wallMaterials(for: block, palette: palette))
                slab.position.y = wallHeight(for: name) / 2
                parent.addChildNode(slab)
                addWallDetails(to: parent, block: block, palette: palette)
            } else {
                let size = cubeSize(for: block)
                let cube = makeBox(width: size.x, height: size.y, length: size.z, chamfer: cubeChamfer(for: block), materials: constructionMaterials(for: block, palette: palette))
                cube.position.y = size.y / 2
                parent.addChildNode(cube)
                addBlockDetails(to: parent, block: block, palette: palette, size: size)
            }

            if showLabel && placed.count > 1 {
                let label = textNode(for: placed)
                label.position = SCNVector3(-0.18, 1.15, 0)
                parent.addChildNode(label)
            }

            return parent
        }

        private func makeBox(width: CGFloat, height: CGFloat, length: CGFloat, chamfer: CGFloat, materials: [SCNMaterial]) -> SCNNode {
            let box = SCNBox(width: width, height: height, length: length, chamferRadius: chamfer)
            box.materials = materials
            return SCNNode(geometry: box)
        }

        private func constructionMaterials(for block: PokopiaBlock, palette: (top: NSColor, side: NSColor, bottom: NSColor)) -> [SCNMaterial] {
            [
                solidMaterial(color: palette.side),
                solidMaterial(color: palette.side.blended(withFraction: 0.08, of: .black) ?? palette.side),
                solidMaterial(color: palette.top),
                solidMaterial(color: palette.bottom),
                solidMaterial(color: palette.side.blended(withFraction: 0.06, of: .white) ?? palette.side),
                solidMaterial(color: palette.side.blended(withFraction: 0.12, of: .black) ?? palette.side)
            ]
        }

        private func tileMaterials(for block: PokopiaBlock, palette: (top: NSColor, side: NSColor, bottom: NSColor)) -> [SCNMaterial] {
            [
                solidMaterial(color: palette.side),
                solidMaterial(color: palette.side),
                solidMaterial(color: palette.top, roughness: 0.9),
                solidMaterial(color: palette.bottom),
                solidMaterial(color: palette.side),
                solidMaterial(color: palette.side)
            ]
        }

        private func wallMaterials(for block: PokopiaBlock, palette: (top: NSColor, side: NSColor, bottom: NSColor)) -> [SCNMaterial] {
            [
                solidMaterial(color: palette.side.blended(withFraction: 0.05, of: .white) ?? palette.side),
                solidMaterial(color: palette.side.blended(withFraction: 0.10, of: .black) ?? palette.side),
                solidMaterial(color: palette.top),
                solidMaterial(color: palette.bottom),
                solidMaterial(color: palette.top),
                solidMaterial(color: palette.side)
            ]
        }

        private func glowingMaterials(color: NSColor) -> [SCNMaterial] {
            let base = solidMaterial(color: color, roughness: 0.25)
            base.emission.contents = color.withAlphaComponent(0.65)
            let side = solidMaterial(color: color.blended(withFraction: 0.24, of: .black) ?? color, roughness: 0.35)
            side.emission.contents = color.withAlphaComponent(0.28)
            return [side, side, base, side, side, base]
        }

        private func translucentMaterial(color: NSColor) -> SCNMaterial {
            let material = solidMaterial(color: color, roughness: 0.18)
            material.transparency = 0.72
            material.blendMode = .alpha
            material.emission.contents = color.withAlphaComponent(0.18)
            return material
        }

        private func addTileDetails(to parent: SCNNode, block: PokopiaBlock, palette: (top: NSColor, side: NSColor, bottom: NSColor)) {
            let name = block.name.lowercased()
            if name.contains("marked road") {
                let stripe = makeBox(width: name.contains("vertical") ? 0.12 : 0.72, height: 0.012, length: name.contains("vertical") ? 0.72 : 0.12, chamfer: 0.002, materials: [solidMaterial(color: .white)])
                stripe.position.y = 0.128
                parent.addChildNode(stripe)
            } else if name.contains("stripe") || name.contains("lined") {
                for offset in [-0.22, 0.22] {
                    let stripe = makeBox(width: 0.78, height: 0.01, length: 0.045, chamfer: 0.002, materials: [solidMaterial(color: palette.side.blended(withFraction: 0.18, of: .white) ?? palette.side)])
                    stripe.position = SCNVector3(0, 0.128, CGFloat(offset))
                    parent.addChildNode(stripe)
                }
            } else if name.contains("print") || name.contains("mosaic") || name.contains("carpeting") {
                let accent = palette.top.blended(withFraction: 0.35, of: .systemPink) ?? palette.top
                for x in [-0.25, 0.25] {
                    for z in [-0.25, 0.25] {
                        let dot = SCNCylinder(radius: 0.055, height: 0.012)
                        dot.firstMaterial = solidMaterial(color: accent)
                        let node = SCNNode(geometry: dot)
                        node.position = SCNVector3(CGFloat(x), 0.13, CGFloat(z))
                        parent.addChildNode(node)
                    }
                }
            }
        }

        private func addWallDetails(to parent: SCNNode, block: PokopiaBlock, palette: (top: NSColor, side: NSColor, bottom: NSColor)) {
            let name = block.name.lowercased()
            let accent = wallAccentColor(for: block, palette: palette)
            let yValues: [CGFloat] = name.contains("trim") ? [0.82] : name.contains("middle") ? [0.46] : name.contains("lower") ? [0.18] : [0.22, 0.72]
            for y in yValues {
                let band = makeBox(width: 0.92, height: 0.055, length: 0.235, chamfer: 0.004, materials: [solidMaterial(color: accent)])
                band.position.y = y
                band.position.z = -0.003
                parent.addChildNode(band)
            }
        }

        private func addBlockDetails(to parent: SCNNode, block: PokopiaBlock, palette: (top: NSColor, side: NSColor, bottom: NSColor), size: (x: CGFloat, y: CGFloat, z: CGFloat)) {
            let name = block.name.lowercased()
            if name.contains("ore") || name.contains("deposit") {
                let accent = name.contains("gold") ? NSColor.systemYellow : name.contains("copper") ? NSColor.systemGreen : NSColor.systemGray
                for x in [-0.18, 0.12] {
                    let fleck = SCNSphere(radius: 0.055)
                    fleck.firstMaterial = solidMaterial(color: accent, roughness: 0.35)
                    let node = SCNNode(geometry: fleck)
                    node.position = SCNVector3(CGFloat(x), size.y * 0.72, -size.z / 2 - 0.015)
                    parent.addChildNode(node)
                }
            } else if name.contains("rock") || name.contains("stone") {
                for x in [-0.22, 0.2] {
                    let chip = makeBox(width: 0.18, height: 0.02, length: 0.035, chamfer: 0.004, materials: [solidMaterial(color: palette.top.blended(withFraction: 0.14, of: .white) ?? palette.top)])
                    chip.position = SCNVector3(CGFloat(x), size.y + 0.012, 0.18)
                    chip.eulerAngles.y = CGFloat.random(in: -0.45...0.45)
                    parent.addChildNode(chip)
                }
            }
        }

        private func addBaseShadow(to parent: SCNNode, radius: CGFloat) {
            let base = SCNCylinder(radius: radius, height: 0.015)
            base.firstMaterial = solidMaterial(color: NSColor.black.withAlphaComponent(0.18))
            let node = SCNNode(geometry: base)
            node.position.y = 0.008
            parent.addChildNode(node)
        }

        private func cubeSize(for block: PokopiaBlock) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
            let name = block.name.lowercased()
            if name.contains("foundation") || name.contains("levee") {
                return (1.0, 0.35, 1.0)
            }
            if name.contains("hay pile") || name.contains("plating") {
                return (1.0, 0.28, 1.0)
            }
            return (0.92, 0.72, 0.92)
        }

        private func cubeChamfer(for block: PokopiaBlock) -> CGFloat {
            let name = block.name.lowercased()
            if name.contains("rock") || name.contains("stone") || name.contains("ore") {
                return 0.09
            }
            return 0.045
        }

        private func wallWidth(for name: String) -> CGFloat {
            name.contains("pillar") ? 0.36 : 0.96
        }

        private func wallHeight(for name: String) -> CGFloat {
            if name.contains("trim") { return 0.28 }
            if name.contains("upper") || name.contains("middle") || name.contains("lower") { return 0.72 }
            return 0.96
        }

        private func wallAccentColor(for block: PokopiaBlock, palette: (top: NSColor, side: NSColor, bottom: NSColor)) -> NSColor {
            let name = block.name.lowercased()
            if name.contains("pokemon center") || name.contains("poke ball") { return .systemRed }
            if name.contains("gold") || name.contains("antique") { return .systemYellow }
            if name.contains("warning") { return .systemYellow }
            if name.contains("cyber") || name.contains("neon") || name.contains("crystal") { return .systemCyan }
            return palette.top.blended(withFraction: 0.18, of: .white) ?? palette.top
        }

        private func addReferenceGround() {
            let root = SCNNode()
            root.name = "pokopia-reference-ground"

            for x in -9...9 {
                for z in -7...7 {
                    let tile = SCNBox(width: 0.98, height: 0.08, length: 0.98, chamferRadius: 0.018)
                    let material = SCNMaterial()
                    let isPath = abs(x) <= 1 || z == 0
                    let checker = (x + z).isMultiple(of: 2)
                    material.diffuse.contents = isPath
                        ? NSColor(calibratedRed: checker ? 0.86 : 0.80, green: checker ? 0.76 : 0.69, blue: checker ? 0.55 : 0.48, alpha: 1)
                        : NSColor(calibratedRed: checker ? 0.46 : 0.39, green: checker ? 0.72 : 0.65, blue: checker ? 0.33 : 0.29, alpha: 1)
                    material.roughness.contents = 0.88
                    tile.firstMaterial = material

                    let node = SCNNode(geometry: tile)
                    node.position = SCNVector3(Float(x), -0.04, Float(z))
                    root.addChildNode(node)
                }
            }

            scene.rootNode.addChildNode(root)
        }

        private func cutoutNode(for placed: PlacedBlock, image: NSImage, showLabel: Bool) -> SCNNode {
            let parent = SCNNode()
            parent.name = placed.block.name
            parent.position = SCNVector3(placed.position.x, 0, placed.position.z)
            parent.eulerAngles.y = CGFloat(placed.rotation)

            let scale = cutoutScale(for: placed.block, image: image)
            let plane = SCNPlane(width: CGFloat(scale.x), height: CGFloat(scale.y))
            plane.cornerRadius = 0
            plane.firstMaterial = cutoutMaterial(for: image)

            let front = SCNNode(geometry: plane)
            front.position = SCNVector3(0, Float(scale.y / 2) + 0.04, 0)
            parent.addChildNode(front)

            let base = SCNCylinder(radius: CGFloat(max(scale.x * 0.36, 0.18)), height: 0.035)
            let baseMaterial = SCNMaterial()
            baseMaterial.diffuse.contents = NSColor.black.withAlphaComponent(0.28)
            baseMaterial.blendMode = .alpha
            baseMaterial.roughness.contents = 0.95
            base.firstMaterial = baseMaterial
            let baseNode = SCNNode(geometry: base)
            baseNode.position = SCNVector3(0, 0.018, 0)
            parent.addChildNode(baseNode)

            if showLabel && placed.count > 1 {
                let label = textNode(for: placed)
                label.position = SCNVector3(-0.18, Float(scale.y) + 0.18, 0)
                parent.addChildNode(label)
            }

            return parent
        }

        private func visualCopies(for placed: PlacedBlock) -> Int {
            let category = placed.block.category.lowercased()
            if category.contains("material") || placed.block.kind == .ore || placed.block.kind == .rock {
                return min(3, max(1, placed.count / 8))
            }
            if placed.block.kind == .floor || placed.block.kind == .terrain || placed.block.kind == .pattern {
                return min(8, max(1, placed.count / 8))
            }
            if placed.block.kind == .wall {
                return min(6, max(1, placed.count / 6))
            }
            return min(4, max(1, placed.count / 4))
        }

        private func copyOffsets(count: Int, block: PokopiaBlock) -> [SIMD2<Float>] {
            guard count > 1 else { return [SIMD2<Float>(0, 0)] }

            if block.kind == .wall {
                return (0..<count).map { SIMD2<Float>(Float($0) - Float(count - 1) / 2, 0) }
            }

            if block.kind == .floor || block.kind == .terrain || block.kind == .pattern {
                let slots: [SIMD2<Float>] = [
                    SIMD2<Float>(-1, -1), SIMD2<Float>(0, -1), SIMD2<Float>(1, -1),
                    SIMD2<Float>(-1, 0), SIMD2<Float>(0, 0), SIMD2<Float>(1, 0),
                    SIMD2<Float>(-1, 1), SIMD2<Float>(0, 1)
                ]
                return Array(slots.prefix(count))
            }

            let ring: [SIMD2<Float>] = [
                SIMD2<Float>(0, 0), SIMD2<Float>(0.65, 0), SIMD2<Float>(-0.65, 0), SIMD2<Float>(0, 0.65)
            ]
            return Array(ring.prefix(count))
        }

        private func height(for kind: BlockKind) -> Float {
            switch kind {
            case .floor, .terrain, .pattern:
                0.1
            case .wall:
                1.0
            case .rock, .ore:
                0.62
            case .utility:
                0.85
            case .structure:
                1.0
            case .all:
                0.45
            }
        }

        private func blockChamfer(for kind: BlockKind) -> CGFloat {
            switch kind {
            case .floor, .terrain, .pattern, .wall:
                0.012
            default:
                0.045
            }
        }

        private func materials(for block: PokopiaBlock) -> [SCNMaterial] {
            if block.isConstructionBlock {
                let palette = constructionPalette(for: block)
                return [
                    solidMaterial(color: palette.side),
                    solidMaterial(color: palette.side),
                    solidMaterial(color: palette.top),
                    solidMaterial(color: palette.side),
                    solidMaterial(color: palette.side),
                    solidMaterial(color: palette.bottom)
                ]
            }

            let side = SCNMaterial()
            side.diffuse.contents = block.kind.nsColor.withSystemEffect(.pressed)
            side.roughness.contents = 0.82

            let face = SCNMaterial()
            face.diffuse.contents = block.kind.nsColor
            face.roughness.contents = 0.66
            face.locksAmbientWithDiffuse = true

            return [side, side, face, side, side, face]
        }

        private func solidMaterial(color: NSColor, roughness: CGFloat = 0.82) -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.roughness.contents = roughness
            material.locksAmbientWithDiffuse = true
            return material
        }

        private func constructionPalette(for block: PokopiaBlock) -> (top: NSColor, side: NSColor, bottom: NSColor) {
            let name = block.name.lowercased()
            let base: NSColor

            if name.contains("grass") || name.contains("leaf") || name.contains("moss") {
                base = NSColor(calibratedRed: 0.42, green: 0.68, blue: 0.31, alpha: 1)
            } else if name.contains("sand") || name.contains("seashell") || name.contains("beach") {
                base = NSColor(calibratedRed: 0.78, green: 0.66, blue: 0.46, alpha: 1)
            } else if name.contains("snow") || name.contains("ice") || name.contains("white") || name.contains("marble") {
                base = NSColor(calibratedRed: 0.74, green: 0.80, blue: 0.80, alpha: 1)
            } else if name.contains("red") || name.contains("brick") || name.contains("clay") {
                base = NSColor(calibratedRed: 0.60, green: 0.30, blue: 0.22, alpha: 1)
            } else if name.contains("yellow") || name.contains("gold") {
                base = NSColor(calibratedRed: 0.78, green: 0.58, blue: 0.22, alpha: 1)
            } else if name.contains("black") || name.contains("iron") || name.contains("asphalt") {
                base = NSColor(calibratedRed: 0.25, green: 0.27, blue: 0.28, alpha: 1)
            } else if name.contains("water") || name.contains("crystal") || name.contains("glowing") || name.contains("cyber") || name.contains("neon") {
                base = NSColor(calibratedRed: 0.34, green: 0.72, blue: 0.82, alpha: 1)
            } else if name.contains("wood") || name.contains("log") || name.contains("brown") {
                base = NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.20, alpha: 1)
            } else if name.contains("road") || name.contains("concrete") || name.contains("stone") || name.contains("rock") || name.contains("wall") || name.contains("floor") {
                base = NSColor(calibratedRed: 0.55, green: 0.56, blue: 0.53, alpha: 1)
            } else {
                base = block.kind.nsColor
            }

            let top = base.blended(withFraction: 0.18, of: .white) ?? base
            let side = base.blended(withFraction: 0.20, of: .black) ?? base
            let bottom = base.blended(withFraction: 0.30, of: .black) ?? base
            return (top, side, bottom)
        }

        private func dominantColor(from image: NSImage) -> NSColor {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return .systemGray
            }

            let width = 1
            let height = 1
            var pixel = [UInt8](repeating: 0, count: 4)
            guard let context = CGContext(
                data: &pixel,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return .systemGray
            }

            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            guard pixel[3] > 0 else { return .systemGray }
            return NSColor(
                calibratedRed: CGFloat(pixel[0]) / 255,
                green: CGFloat(pixel[1]) / 255,
                blue: CGFloat(pixel[2]) / 255,
                alpha: 1
            )
        }

        private func cutoutMaterial(for image: NSImage) -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = image
            material.transparent.contents = image
            material.transparencyMode = .aOne
            material.blendMode = .alpha
            material.isDoubleSided = true
            material.lightingModel = .constant
            material.locksAmbientWithDiffuse = true
            material.writesToDepthBuffer = true
            material.readsFromDepthBuffer = true
            material.cullMode = .back
            return material
        }

        private func cutoutScale(for block: PokopiaBlock, image: NSImage) -> SIMD2<Float> {
            let pixelWidth = max(Float(image.size.width), 1)
            let pixelHeight = max(Float(image.size.height), 1)
            let aspect = pixelWidth / pixelHeight
            let height: Float

            switch block.category.lowercased() {
            case "food", "materials":
                height = 0.65
            case "furniture":
                height = 0.95
            case "utilities", "outdoor":
                height = 1.15
            default:
                height = 0.9
            }

            return SIMD2<Float>(height * aspect, height)
        }

        private func textNode(for placed: PlacedBlock) -> SCNNode {
            let text = SCNText(string: "\(placed.count)", extrusionDepth: 0.01)
            text.font = NSFont.monospacedDigitSystemFont(ofSize: 0.22, weight: .bold)
            text.firstMaterial?.diffuse.contents = NSColor.white
            let node = SCNNode(geometry: text)
            node.scale = SCNVector3(0.8, 0.8, 0.8)
            node.eulerAngles.x = -.pi / 2
            node.position.x = -0.18
            return node
        }

    }
}

private extension BlockKind {
    var nsColor: NSColor {
        switch self {
        case .all: NSColor.systemGray
        case .wall: NSColor.systemTeal
        case .floor: NSColor.systemGreen
        case .terrain: NSColor.systemMint
        case .rock: NSColor.systemGray
        case .ore: NSColor.systemYellow
        case .pattern: NSColor.systemPink
        case .structure: NSColor.systemOrange
        case .utility: NSColor.systemCyan
        }
    }
}

private extension PokopiaBlock {
    var cutoutImage: NSImage? {
        imagePath.flatMap(NSImage.init(contentsOfFile:))
    }

    var modelURL: URL? {
        let names = modelLookupNames
        let extensions = ["usdz", "scn", "dae", "obj"]
        var searchRoots: [URL] = []
        var scopedAccessURL: URL?

        if let selectedFolder = ModelFolderAccess.selectedFolderURL() {
            scopedAccessURL = selectedFolder.startAccessingSecurityScopedResource() ? selectedFolder : nil
            searchRoots.append(selectedFolder)
        }

        if let bundledModels = AppResources.bundle.resourceURL?.appendingPathComponent("Models", isDirectory: true) {
            searchRoots.append(bundledModels)
        }

        defer {
            scopedAccessURL?.stopAccessingSecurityScopedResource()
        }

        for root in searchRoots {
            for name in names {
                for ext in extensions {
                    let url = root.appendingPathComponent(name).appendingPathExtension(ext)
                    if FileManager.default.fileExists(atPath: url.path) {
                        return url
                    }
                }
            }
        }

        return nil
    }

    var modelTargetSize: SIMD3<Float> {
        if isConstructionBlock {
            switch kind {
            case .floor, .terrain, .pattern:
                return SIMD3<Float>(1, 0.12, 1)
            case .wall:
                return SIMD3<Float>(1, 1, 0.25)
            default:
                return SIMD3<Float>(0.92, 0.92, 0.92)
            }
        }

        let category = category.lowercased()
        if category == "furniture" {
            return SIMD3<Float>(1.15, 1.0, 1.15)
        }
        if category == "utilities" || category == "outdoor" {
            return SIMD3<Float>(1, 1.35, 1)
        }
        if category.contains("material") || category == "food" {
            return SIMD3<Float>(0.65, 0.65, 0.65)
        }
        return SIMD3<Float>(1, 1, 1)
    }

    private var modelLookupNames: [String] {
        let primary = Self.slug(name)
        let idSlug = Self.slug(id.replacingOccurrences(of: "pokopedia-", with: ""))
        var values = [primary, idSlug]
        if primary.hasSuffix("-block") {
            values.append(String(primary.dropLast("-block".count)))
        }
        return Array(Set(values))
    }

    private static func slug(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "(block)", with: "")
            .replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    var prefersCutoutModel: Bool {
        if isConstructionBlock {
            return false
        }

        let category = category.lowercased()
        if category == "blocks" || category == "build parts" {
            return false
        }

        switch kind {
        case .floor, .terrain, .wall, .pattern:
            return false
        case .rock, .ore:
            return category != "blocks"
        case .structure, .utility, .all:
            return true
        }
    }

    var isConstructionBlock: Bool {
        let loweredName = name.lowercased()
        let loweredCategory = category.lowercased()

        if loweredCategory == "blocks" || loweredCategory == "build parts" {
            return true
        }

        if loweredName.contains("wall")
            || loweredName.contains("floor")
            || loweredName.contains("flooring")
            || loweredName.contains("tiling")
            || loweredName.contains("carpeting")
            || loweredName.contains("road")
            || loweredName.contains("soil")
            || loweredName.contains("grass")
            || loweredName.contains("sand")
            || loweredName.contains("rock")
            || loweredName.contains("stone")
            || loweredName.contains("clay")
            || loweredName.contains("ash")
            || loweredName.contains("ice")
            || loweredName.contains("marble")
            || loweredName.contains("brick")
            || loweredName.contains("plating")
            || loweredName.contains("print") {
            return true
        }

        return false
    }
}
