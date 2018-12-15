package arm;

import kha.math.Matrix4;
import kha.math.Random;
import haxe.rtti.XmlParser;
import iron.math.Math;
import kha.graphics4.hxsl.Types.Matrix;
import haxe.io.Float32Array;
import iron.math.Mat3;
import kha.math.Matrix3;
import iron.math.Mat4;
import iron.math.Vec4;
import iron.math.Quat;
import iron.Trait;
import iron.object.Object;
import iron.object.Transform;
import iron.system.Time;
import armory.trait.physics.PhysicsWorld;

#if arm_bullet
import haxebullet.Bullet;
#end

class PoliceAI extends Trait {
	#if (!arm_bullet)
	public function new() {
		super();
	}
	#else
	// AI
	var target:Object;
	var physics:PhysicsWorld;
	var transform:Transform;
	// Wheels
	var wheels:Array<Object> = [];
	var wheelNames:Array<String>;
	var vehicle:BtRaycastVehiclePointer = null;
	var carChassis:BtRigidBodyPointer;
	var chassis_mass = 600.0;
	var wheelFriction = 1000;
	var suspensionStiffness = 80.0;
	var suspensionDamping = 4.0;
	var suspensionCompression = 2.0;
	var suspensionRestLength = 0.3;
	var rollInfluence = 0.1;
	var maxEngineForce = 2000;
	var maxBreakingForce = 200;
	var engineForce = 0.0;
	var breakingForce = 0.0;
	var vehicleSteering = 0.0;

	public function new(wheelName1:String, wheelName2:String, wheelName3:String, wheelName4:String) {
		super();

		wheelNames = [wheelName1, wheelName2, wheelName3, wheelName4];

		iron.Scene.active.notifyOnInit(init);
	}

	function init() {
		target = iron.Scene.active.getChild('player');
		physics = armory.trait.physics.PhysicsWorld.active;
		transform = object.transform;

		for (n in wheelNames) {
			wheels.push(iron.Scene.active.root.getChild(n));
		}

		var wheelDirectionCS0 = BtVector3.create(0, 0, -1);
		var wheelAxleCS = BtVector3.create(1, 0, 0);

		var chassisShape = BtBoxShape.create(BtVector3.create(transform.dim.x / 2, transform.dim.y / 2, transform.dim.z / 2));

		var compound = BtCompoundShape.create();

		var localTrans = BtTransform.create();
		localTrans.setIdentity();
		localTrans.setOrigin(BtVector3.create(0, 0, 1));

		compound.addChildShape(localTrans, chassisShape);

		carChassis = createRigidBody(chassis_mass, compound);

		// Create vehicle
		var tuning = BtVehicleTuning.create();
		var vehicleRayCaster = BtDefaultVehicleRaycaster.create(physics.world);
		vehicle = BtRaycastVehicle.create(tuning, carChassis, vehicleRayCaster);

		// Never deactivate the vehicle
		carChassis.setActivationState(BtCollisionObject.DISABLE_DEACTIVATION);

		// Choose coordinate system
		var rightIndex = 0;
		var upIndex = 2;
		var forwardIndex = 1;
		vehicle.setCoordinateSystem(rightIndex, upIndex, forwardIndex);

		// Add wheels
		for (i in 0...wheels.length) {
			var vehicleWheel = new VehicleWheelPolice(i, wheels[i].transform, object.transform);
			vehicle.addWheel(vehicleWheel.getConnectionPoint(), wheelDirectionCS0, wheelAxleCS, suspensionRestLength, vehicleWheel.wheelRadius, tuning,
				vehicleWheel.isFrontWheel);

			var wheel = vehicle.getWheelInfo(i);
			wheel.m_suspensionStiffness = suspensionStiffness;
			wheel.m_wheelsDampingRelaxation = suspensionDamping;
			wheel.m_wheelsDampingCompression = suspensionCompression;
			wheel.m_rollInfluence = rollInfluence;

			if (!vehicleWheel.isFrontWheel) {
				wheel.m_frictionSlip = 0.0;
			} else {
				wheel.m_frictionSlip = wheelFriction;
			}
		}

		physics.world.addAction(vehicle);

		notifyOnUpdate(update);
	}

	function update() {
		if (vehicle == null)
			return;
		var forward = false;
		var backward = false;
		var left = false;
		var right = false;
		var brake = false;

		// AI
		var p = transform.world.getLoc();
		var tp = target.transform.world.getLoc();

		var unitPos = transform.world.getLoc();
		var unitDir = transform.look();
		var needDir = new Vec4(tp.x - p.x, tp.y - p.y, tp.z - p.z);
		var unitAngle = Math.atan2(unitDir.y, unitDir.x);
		var needAngle = Math.atan2(needDir.y, needDir.x);

		var diffAngle = needAngle - unitAngle;
		while (diffAngle < -Math.PI)
			diffAngle += Math.PI * 2;
		while (diffAngle > Math.PI)
			diffAngle -= Math.PI * 2;

		if( Math.abs( diffAngle ) > Math.toRadians(10.0))
			{
				if( diffAngle > 0 )
					left = true;
				else
					right = true;
		}

		forward = true;

		/*if( diffAngle > -Math.PI / 2 && diffAngle < Math.PI / 2 )
				forward = true;
			forward = true; */

		if (forward) {
			engineForce = maxEngineForce;
		} else if (backward) {
			engineForce = -maxEngineForce;
		} else if (brake) {
			breakingForce = maxBreakingForce;
		} else {
			engineForce = 0;
			breakingForce = 20;
		}

		if (left) {
			if (vehicleSteering < 0.3)
				vehicleSteering += Time.step;
		} else if (right) {
			if (vehicleSteering > -0.3)
				vehicleSteering -= Time.step;
		} else if (vehicleSteering != 0) {
			var step = Math.abs(vehicleSteering) < Time.step ? Math.abs(vehicleSteering) : Time.step;
			if (vehicleSteering > 0)
				vehicleSteering -= step;
			else
				vehicleSteering += step;
		}

		vehicle.applyEngineForce(engineForce, 2);
		vehicle.setBrake(breakingForce, 2);
		vehicle.applyEngineForce(engineForce, 3);
		vehicle.setBrake(breakingForce, 3);
		vehicle.setSteeringValue(vehicleSteering, 0);
		vehicle.setSteeringValue(vehicleSteering, 1);

		for (i in 0...vehicle.getNumWheels()) {
			// Synchronize the wheels with the chassis worldtransform
			vehicle.updateWheelTransform(i, false);

			// Update wheels transforms
			var trans = vehicle.getWheelTransformWS(i);
			var p = trans.getOrigin();
			var q = trans.getRotation();
			wheels[i].transform.localOnly = true;
			wheels[i].transform.loc.set(p.x(), p.y(), p.z());
			wheels[i].transform.rot.set(q.x(), q.y(), q.z(), q.w());
			wheels[i].transform.dirty = true;
		}

		var trans = carChassis.getWorldTransform();
		var p = trans.getOrigin();
		var q = trans.getRotation();
		transform.loc.set(p.x(), p.y(), p.z());
		transform.rot.set(q.x(), q.y(), q.z(), q.w());
		var up = transform.world.up();
		transform.loc.add(up);
		transform.dirty = true;
		transform.buildMatrix();
	}

	function createRigidBody(mass:Float, shape:BtCompoundShapePointer):BtRigidBodyPointer {
		var localInertia = BtVector3.create(0, 0, 0);
		shape.calculateLocalInertia(mass, localInertia);

		var centerOfMassOffset = BtTransform.create();
		centerOfMassOffset.setIdentity();

		var startTransform = BtTransform.create();
		startTransform.setIdentity();
		startTransform.setOrigin(BtVector3.create(transform.loc.x, transform.loc.y, transform.loc.z));
		startTransform.setRotation(BtQuaternion.create(transform.rot.x, transform.rot.y, transform.rot.z, transform.rot.w));

		var myMotionState = BtDefaultMotionState.create(startTransform, centerOfMassOffset);
		var cInfo = BtRigidBodyConstructionInfo.create(mass, myMotionState, shape, localInertia);

		var body = BtRigidBody.create(cInfo);
		body.setLinearVelocity(BtVector3.create(0, 0, 0));
		body.setAngularVelocity(BtVector3.create(0, 0, 0));
		physics.world.addRigidBody(body);

		return body;
	}
	#end
}

class VehicleWheelPolice {
	#if (!arm_bullet)
	public function new() {}
	#else
	public var isFrontWheel:Bool;
	public var wheelRadius:Float;
	public var wheelWidth:Float;

	var locX:Float;
	var locY:Float;
	var locZ:Float;

	public function new(id:Int, transform:Transform, vehicleTransform:Transform) {
		wheelRadius = transform.dim.z / 2;
		wheelWidth = transform.dim.x > transform.dim.y ? transform.dim.y : transform.dim.x;

		locX = transform.loc.x;
		locY = transform.loc.y;
		locZ = vehicleTransform.dim.z / 2 + transform.loc.z;
	}

	public function getConnectionPoint():BtVector3 {
		return BtVector3.create(locX, locY, locZ);
	}
	#end
}
