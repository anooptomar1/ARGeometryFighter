//
//  ViewController.swift
//  ARGeometryFighter
//
//  Created by 吴迪玮 on 2017/9/8.
//  Copyright © 2017年 吴迪玮. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    var scnScene: SCNScene!
    var game = GameHelper.sharedInstance
    var splashNodes: [String: SCNNode] = [:]
    
    var spawnTime: TimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScene()
        setupHUD()
        setupSplash()
        setupSounds()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(getSessionConfiguration())
    }
    
    func setupScene() {
        sceneView.delegate = self
        //        sceneView.showsStatistics = true
        
        sceneView.automaticallyUpdatesLighting = true
        
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        
        scnScene = SCNScene()
        
        sceneView.scene = scnScene
        
    }
    
    private func getSessionConfiguration() -> ARConfiguration {
        if ARWorldTrackingConfiguration.isSupported {
            // 创建 session configuration
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            return configuration;
        } else {
            // 适配低配置设备
            return AROrientationTrackingConfiguration()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: setup
    
    func setupHUD() {
        game.hudNode.position = SCNVector3(x: 0.0, y: 10.0, z: 0.0)
        scnScene.rootNode.addChildNode(game.hudNode)
    }
    
    func setupSplash() {
        splashNodes["TapToPlay"] = createSplash(name: "TAPTOPLAY",
                                                imageFileName: "GeometryFighter.scnassets/Textures/TapToPlay_Diffuse.png")
        splashNodes["GameOver"] = createSplash(name: "GAMEOVER",
                                               imageFileName: "GeometryFighter.scnassets/Textures/GameOver_Diffuse.png")
        showSplash(splashName: "TapToPlay")
    }
    
    func createSplash(name: String, imageFileName: String) -> SCNNode {
        let plane = SCNPlane(width: 5, height: 5)
        let splashNode = SCNNode(geometry: plane)
        splashNode.position = SCNVector3(x: 0, y: 5, z: 0)
        splashNode.name = name
        splashNode.geometry?.materials.first?.diffuse.contents = imageFileName
        scnScene.rootNode.addChildNode(splashNode)
        return splashNode
    }
    
    func setupSounds() {
        game.loadSound("ExplodeGood",
                       fileNamed: "GeometryFighter.scnassets/Sounds/ExplodeGood.wav")
        game.loadSound("SpawnGood",
                       fileNamed: "GeometryFighter.scnassets/Sounds/SpawnGood.wav")
        game.loadSound("ExplodeBad",
                       fileNamed: "GeometryFighter.scnassets/Sounds/ExplodeBad.wav")
        game.loadSound("SpawnBad",
                       fileNamed: "GeometryFighter.scnassets/Sounds/SpawnBad.wav")
        game.loadSound("GameOver",
                       fileNamed: "GeometryFighter.scnassets/Sounds/GameOver.wav")
    }
    
    //MARK: action
    
    @IBAction func actionTap(_ sender: UITapGestureRecognizer) {
        if game.state == .GameOver {
            return
        }
        
        if game.state == .TapToPlay {
            game.reset()
            game.state = .Playing
            showSplash(splashName: "")
            return
        }
        // 获取屏幕空间坐标并传递给 ARSCNView 实例的 hitTest 方法
        let tapPoint = sender.location(in: sceneView)
        let hitResults = sceneView.hitTest(tapPoint, options: nil)
        
        // 如果射线与某个平面几何体相交，就会返回该平面，以离摄像头的距离升序排序
        // 如果命中多次，用距离最近的平面
        if let result = hitResults.first {
            if result.node.name == "HUD" ||
                result.node.name == "GAMEOVER" ||
                result.node.name == "TAPTOPLAY" {
                return
            } else if result.node.name == "GOOD" {
                handleGoodCollision()
            } else if result.node.name == "BAD" {
                handleBadCollision()
            }
            
            createExplosion(geometry: result.node.geometry!,
                            position: result.node.presentation.position,
                            rotation: result.node.presentation.rotation)
            
            result.node.removeFromParentNode()
        }
    }
    
    func showSplash(splashName: String) {
        for (name,node) in splashNodes {
            if name == splashName {
                node.isHidden = false
            } else {
                node.isHidden = true
            }
        }
    }
    
    func handleGoodCollision() {
        game.score += 1
        game.playSound(scnScene.rootNode, name: "ExplodeGood")
    }
    
    func handleBadCollision() {
        game.lives -= 1
        game.playSound(scnScene.rootNode, name: "ExplodeBad")
        
        //TODO 考虑如何震动
//        game.shakeNode(cameraNode)
        
        if game.lives <= 0 {
            game.saveState()
            showSplash(splashName: "GameOver")
            game.playSound(scnScene.rootNode, name: "GameOver")
            game.state = .GameOver
            scnScene.rootNode.runAction(SCNAction.waitForDurationThenRunBlock(5) { (node:SCNNode!) -> Void in
                self.showSplash(splashName: "TapToPlay")
                self.game.state = .TapToPlay
            })
        }
    }

    // MARK: Logic
    
    func spawnShape() {
        // 创建几何体
        var geometry:SCNGeometry
        //SCNGeometry 相关文档 https://developer.apple.com/documentation/scenekit/scngeometry#//apple_ref/occ/cl/SCNGeometry
        
        // 根据随机值来
        switch ShapeType.random() {
        case .box:
            // 正方体形状
            geometry = SCNBox(width: 1.0, height: 1.0, length: 1.0,
                              chamferRadius: 0.05)
            print("正方体形状")
        case .sphere:
            // 球形状
            geometry = SCNSphere(radius: 0.5)
            print("球形状")
        case .pyramid:
            // 金字塔形状
            geometry = SCNPyramid(width: 1.0, height: 1.0, length: 1.0)
            print("金字塔形状")
        case .torus:
            // 环形状
            geometry = SCNTorus(ringRadius: 0.5, pipeRadius: 0.4)
            print("环形状")
        case .capsule:
            // 胶囊形状
            geometry = SCNCapsule(capRadius: 0.2, height: 1.0)
            print("胶囊形状")
        case .cylinder:
            // 圆柱形状
            geometry = SCNCylinder(radius: 0.5, height: 1.0)
            print("圆柱形状")
        case .cone:
            // 圆锥形状
            geometry = SCNCone(topRadius: 0.1, bottomRadius: 0.5, height: 1.0)
            print("圆锥形状")
        case .tube:
            // 管形状
            geometry = SCNTube(innerRadius: 0.4, outerRadius: 0.5, height: 1.0)
            print("管形状")
        }
        let color = UIColor.random()
        geometry.materials.first?.diffuse.contents = color
        // 通过几何体来创建node
        let geometryNode = SCNNode(geometry: geometry)
        geometryNode.physicsBody =
            SCNPhysicsBody(type: .dynamic, shape: nil)
        
        //设置粒子效果
        let trailEmitter = createTrail(color: color, geometry: geometry)
        geometryNode.addParticleSystem(trailEmitter)
        
        //定义好的和坏的几何体
        if color == UIColor.black {
            geometryNode.name = "BAD"
        } else {
            geometryNode.name = "GOOD"
        }
        
        // 把正方体node添加到场景中
        scnScene.rootNode.addChildNode(geometryNode)
        
        // 1
        let randomX = Float.random(min: -2, max: 2)
        let randomY = Float.random(min: 10, max: 18)
        // 2
        let force = SCNVector3(x: randomX, y: randomY , z: 0)
        // 3
        let position = SCNVector3(x: 0.05, y: 0.05, z: 0.05)
        // 4
        geometryNode.physicsBody?.applyForce(force,
                                             at: position, asImpulse: true)
    }
    
    // 创建尾巴的粒子效果
    func createTrail(color: UIColor, geometry: SCNGeometry) -> SCNParticleSystem {
        // 2
        let trail = SCNParticleSystem(named: "Trail.scnp", inDirectory: nil)!
        // 3
        trail.particleColor = color
        // 4
        trail.emitterShape = geometry
        // 5
        return trail
    }
    
    // 点击后产生💥效果的粒子动画
    func createExplosion(geometry: SCNGeometry, position: SCNVector3,
                         rotation: SCNVector4) {
        // 加载
        let explosion =
            SCNParticleSystem(named: "Explode.scnp", inDirectory:
                nil)!
        explosion.emitterShape = geometry
        explosion.birthLocation = .surface
        // 旋转、组合位置等
        let rotationMatrix =
            SCNMatrix4MakeRotation(rotation.w, rotation.x,
                                   rotation.y, rotation.z)
        let translationMatrix =
            SCNMatrix4MakeTranslation(position.x, position.y,
                                      position.z)
        let transformMatrix =
            SCNMatrix4Mult(rotationMatrix, translationMatrix)
        // 4
        scnScene.addParticleSystem(explosion, transform: transformMatrix)
    }
    
    func cleanScene() {
        // 1
        for node in scnScene.rootNode.childNodes {
            // 2 presentation为该node在当前动作后的一个copy
            if node.presentation.position.y < -3 {
                // 3
                node.removeFromParentNode()
            }
        }
        
    }
    
}

extension ViewController: ARSCNViewDelegate {
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    //TODO 找到平面后在该平面上添加
    //    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    //        DispatchQueue.main.async {
    //            if let planeAnchor = anchor as? ARPlaneAnchor {
    //                // 第一个发现的平面
    //                // TODO
    //            }
    //        }
    //    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer,
                  updateAtTime time: TimeInterval) {
        
        if game.state == .Playing {
            if time > spawnTime {
                spawnShape()
                spawnTime = time + TimeInterval(Float.random(min: 0.2, max: 1.5))
            }
            cleanScene()
        }
        game.updateHUD()
    }
}
