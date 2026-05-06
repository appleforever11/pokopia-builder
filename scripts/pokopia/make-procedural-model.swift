#!/usr/bin/env swift
import AppKit
import SceneKit

enum Shape: String {
    case cube
    case floor
    case wall
    case crystal
    case cylinder
    case lamp
    case sign
    case fence
    case stairs
}

func color(_ hex: String) -> NSColor {
    let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var value: UInt64 = 0
    Scanner(string: clean).scanHexInt64(&value)
    return NSColor(
        calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
        green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255,
        alpha: 1
    )
}

func material(_ color: NSColor, roughness: CGFloat = 0.8, alpha: CGFloat = 1) -> SCNMaterial {
    let material = SCNMaterial()
    material.diffuse.contents = color.withAlphaComponent(alpha)
    material.roughness.contents = roughness
    material.transparency = alpha
    material.blendMode = alpha < 1 ? .alpha : .replace
    material.isDoubleSided = true
    return material
}

func box(width: CGFloat, height: CGFloat, length: CGFloat, chamfer: CGFloat, color: NSColor) -> SCNNode {
    let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: chamfer)
    let top = material(color.blended(withFraction: 0.18, of: .white) ?? color)
    let side = material(color.blended(withFraction: 0.18, of: .black) ?? color)
    geometry.materials = [side, side, top, side, side, side]
    let node = SCNNode(geometry: geometry)
    node.position.y = height / 2
    return node
}

func makeScene(shape: Shape, baseColor: NSColor) -> SCNScene {
    let scene = SCNScene()
    let root = scene.rootNode

    switch shape {
    case .cube:
        root.addChildNode(box(width: 1, height: 1, length: 1, chamfer: 0.08, color: baseColor))
    case .floor:
        root.addChildNode(box(width: 1, height: 0.12, length: 1, chamfer: 0.02, color: baseColor))
    case .wall:
        root.addChildNode(box(width: 1, height: 1, length: 0.22, chamfer: 0.025, color: baseColor))
    case .crystal:
        let geometry = SCNPyramid(width: 0.75, height: 1.15, length: 0.75)
        geometry.firstMaterial = material(baseColor, roughness: 0.25, alpha: 0.72)
        let node = SCNNode(geometry: geometry)
        node.position.y = 0.575
        root.addChildNode(node)
    case .cylinder:
        let geometry = SCNCylinder(radius: 0.42, height: 0.9)
        geometry.firstMaterial = material(baseColor)
        let node = SCNNode(geometry: geometry)
        node.position.y = 0.45
        root.addChildNode(node)
    case .lamp:
        let pole = SCNCylinder(radius: 0.06, height: 1.0)
        pole.firstMaterial = material(.darkGray)
        let poleNode = SCNNode(geometry: pole)
        poleNode.position.y = 0.5
        root.addChildNode(poleNode)

        let lightBox = SCNBox(width: 0.38, height: 0.38, length: 0.38, chamferRadius: 0.04)
        let glow = material(baseColor, roughness: 0.2, alpha: 0.82)
        glow.emission.contents = baseColor
        lightBox.firstMaterial = glow
        let lightNode = SCNNode(geometry: lightBox)
        lightNode.position.y = 1.16
        root.addChildNode(lightNode)
    case .sign:
        let post = SCNCylinder(radius: 0.045, height: 0.72)
        post.firstMaterial = material(baseColor.blended(withFraction: 0.35, of: .black) ?? baseColor)
        let postNode = SCNNode(geometry: post)
        postNode.position.y = 0.36
        root.addChildNode(postNode)

        let face = SCNBox(width: 0.72, height: 0.44, length: 0.08, chamferRadius: 0.025)
        let top = material(baseColor.blended(withFraction: 0.22, of: .white) ?? baseColor)
        face.materials = [top, top, top, top, top, top]
        let faceNode = SCNNode(geometry: face)
        faceNode.position.y = 0.88
        root.addChildNode(faceNode)
    case .fence:
        for x in [-0.36, 0.36] {
            let post = box(width: 0.12, height: 0.72, length: 0.12, chamfer: 0.025, color: baseColor)
            post.position.x = CGFloat(x)
            root.addChildNode(post)
        }
        for y in [0.28, 0.52] {
            let rail = box(width: 0.9, height: 0.12, length: 0.10, chamfer: 0.018, color: baseColor)
            rail.position.y = CGFloat(y)
            root.addChildNode(rail)
        }
    case .stairs:
        for index in 0..<3 {
            let step = box(width: 1, height: 0.16, length: 0.34, chamfer: 0.02, color: baseColor)
            step.position = SCNVector3(0, CGFloat(index + 1) * 0.08, CGFloat(index) * 0.23 - 0.23)
            root.addChildNode(step)
        }
    }

    return scene
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    fputs("Usage: make-procedural-model.swift <name-slug> <shape:cube|floor|wall|crystal|cylinder|lamp|sign|fence|stairs> <hex-color> [output-dir]\n", stderr)
    exit(2)
}

let name = args[1]
let shape = Shape(rawValue: args[2]) ?? .cube
let baseColor = color(args[3])
let defaultOutputDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Documents")
    .appendingPathComponent("Pokopia Models", isDirectory: true)
    .path
let outputDir = args.count > 4 ? args[4] : defaultOutputDir
let outputURL = URL(fileURLWithPath: outputDir, isDirectory: true).appendingPathComponent(name).appendingPathExtension("scn")

try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let scene = makeScene(shape: shape, baseColor: baseColor)
let ok = scene.write(to: outputURL, options: nil, delegate: nil, progressHandler: nil)
if !ok {
    fputs("Failed to write \(outputURL.path)\n", stderr)
    exit(1)
}
print(outputURL.path)
