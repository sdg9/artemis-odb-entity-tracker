package net.namekdev.entity_tracker

import com.artemis.*
import com.artemis.systems.EntityProcessingSystem
import net.namekdev.entity_tracker.connectors.IWorldControlListener
import net.namekdev.entity_tracker.network.ArtemisWorldSerializer
import net.namekdev.entity_tracker.network.base.WebSocketServer

/**
 *
 */
fun main(args: Array<String>) {
    val entityTracker = EntityTracker(
        ArtemisWorldSerializer(WebSocketServer().start()),
        worldControlListener = object : IWorldControlListener {
            override fun onComponentFieldValueChanged(entityId: Int, componentIndex: Int, treePath: IntArray, newValue: Any?) {
                println("E$entityId C$componentIndex [${treePath.joinToString(", ")}] = $newValue")
            }
        }
    )

    val world = World(
        WorldConfiguration()
            .setSystem(entityTracker)
            .setSystem(PositionSystem())
            .setSystem(RenderSystem())
            .setSystem(MotionBlurSystem())
            .setSystem(CollisionSystem())
            .setSystem(ConstantlyChangingValuesSystem())
    )

    for (i in 0..10) {
        val e = world.createEntity().edit()

        val pos = Pos(i * 6f, i * 2f)
        e.add(pos)

        val layer = if (i <= 5) RenderLayer.Back else RenderLayer.Front
        e.add(Renderable(layer))

        if (i == 0 || i == 5 || i == 6) {
            e.add(MotionBlur())
        }
        if (i % 3 == 0) {
            e.add(Speed(i * 10f))
        }

        e.add(Collider(ColliderType.AABB, Rect(pos.x, pos.y, 10f, 10f)))
        e.add(AllTypes())
    }

    world.process()

    world.getEntity(3).deleteFromWorld()
    world.process()

    var prevTime = System.nanoTime()
    val targetFps = 30
    val millisPerSecond = 1000f / 30
    val minDiffToProcess = 1000000000 / targetFps

    while (true) {
        val curTime = System.nanoTime()
        val diff = curTime - prevTime
        if (diff >= minDiffToProcess) {
            world.delta = diff.toFloat() / 1000000000
            world.process()
            prevTime = curTime
        }

        // don't hog cpu
        Thread.sleep(1)
    }
}

//
// Components
//

class Pos(
    var x: Float = 0f,
    var y: Float = 0f
) : Component()

class Speed(var speed: Float = 1f) : Component()

class Renderable(
    var layer: RenderLayer = RenderLayer.Front,
    var color: Long = Long.MAX_VALUE
) : Component()

class MotionBlur(
    var on: Boolean? = true,
    var power: Double = 0.0
) : Component()

class Collider(
    val type: ColliderType = ColliderType.AABB,
    val rect1: Rect = Rect(0f,0f,0f,0f),
    val rect2: Rect = Rect(0f,0f,0f,0f)
) : Component()

class AllTypes(
    var bool: Boolean = false,
    var boolRef: Boolean? = null,
    var int: Int = 124,
    var intRef: Int? = 124,
    var float: Float = 21.5f,
    var floatRef: Float? = null,
//    var str: String = "asdsad",
//    var strNullable: String? = null,
    var enum1: ColliderType = ColliderType.AABB,
    var enum2: RenderLayer = RenderLayer.Front
) : Component()


//
// Systems
//

class PositionSystem : EntityProcessingSystem(
    Aspect.all(Pos::class.java, Speed::class.java)
) {
    override fun process(e: Entity) {}
}

class RenderSystem : EntityProcessingSystem(
    Aspect.all(Pos::class.java, Renderable::class.java)
) {
    override fun process(e: Entity) {}
}

class MotionBlurSystem : EntityProcessingSystem(
    Aspect.all(Pos::class.java, Speed::class.java, MotionBlur::class.java)
) {
    override fun process(e: Entity) {}
}

class CollisionSystem : EntityProcessingSystem(
    Aspect.all(Collider::class.java, Pos::class.java)
) {
    override fun process(e: Entity) {}
}

class ConstantlyChangingValuesSystem : EntityProcessingSystem(
    Aspect.all(AllTypes::class.java)
) {
    lateinit var mPos: ComponentMapper<Pos>

    override fun process(e: Entity) {
        val pos = mPos[e]

        pos.x += world.delta * 3f
        if (pos.x > 1000f)
            pos.x = 0f
    }
}


//
// Utils, helpers, etc.
//

enum class RenderLayer {
    Front,
    Back
}

enum class ColliderType {
    AABB, Circle
}

data class Rect(var x: Float, var y: Float, var width: Float, var height: Float)