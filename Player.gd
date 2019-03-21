extends Node2D

enum states {
		ON_GROUND = 0,
		IN_AIR = 1
	}

#contains the direction and magnitude of the input for movement
var input_move_vector : Vector2 = Vector2()
#the velocity of the player
var velocity : Vector2 = Vector2()
#what direction up is based on the ground the player currently is on
var relative_up : Vector2 = Vector2()
#what direction up actually is, could maybe add support for changing gravity later using this
var absolute_up : Vector2 = Vector2(0, -1)
#the current state of the player, states defined in player_states
var state_current : int


#the difference from the players position to cast this ray to use for finding downward slopes
const raycastGroundForSlopes : Vector2 = Vector2(0, 1)

#how far away to stay from walls and floors after a collision
const COLLISION_OFFSET : float = 0.1

#how powerful the force of gravity is
const GRAVITY = 1

#player move speed, temporary, should be replaced with acceleration system later
const MOVE_SPEED : float = 240.0

func _ready() -> void:
	input_move_vector = Vector2(0, 0)
	velocity = Vector2(0, 0)
	relative_up = Vector2(0, -1)
	
	state_current = states.IN_AIR
	
#warning-ignore:unused_argument
func _process(delta) -> void:
	get_movement_input()
	
func _physics_process(delta) -> void:
	#access the current state of the world to use for raycasting and such
	var space_state = get_world_2d().direct_space_state
	
	if state_current == states.ON_GROUND:
		calculate_next_velocity_ground(delta)
	#velocity += (input_move_vector * 100).rotated(rotation)
	
	#move sonic based on the slope he is on.
	if state_current == states.ON_GROUND:
		if relative_up.y > -1:
			var slope_power = 150 #/ (velocity.length() + 1)
			var slope_velocity = Vector2(0, slope_power * delta)
			slope_velocity = project_vector2_onto_face(slope_velocity, relative_up)
			velocity += slope_velocity
	
	#movement and collision starts here
	var raycast_result = space_state.intersect_ray(position, position + (velocity * delta), [self])
	update()
	
	if raycast_result:
		var raycast_collision_normal = raycast_result.normal
		var raycast_collision_position = raycast_result.position
		
		if state_current == states.IN_AIR:
			if raycast_collision_normal.y < -0.5:
				#touching a floor at a usable angle, transition from air state to ground state
				state_current = states.ON_GROUND
				
				get_onto_floor(raycast_collision_position, raycast_collision_normal)
				
				velocity = velocity.project(relative_up)
				
			else:
				#in the air, but not touching a floor that can be moved onto, do wall stuff
				
				#calculate how much distance is left to be moved, so you can slide down a slope for example
				var distanceMoved = (raycast_collision_position - position).length()
				var distanceLeftToMove = (velocity * delta).length() - distanceMoved
				
				#calculate the new direction for the velocity based on the wall
				velocity = calculate_velocity_new_floor(velocity, raycast_collision_normal)
				#place the player at the collision point and move them away from the wall a little
				position = raycast_collision_position
				position += raycast_collision_normal * COLLISION_OFFSET
				
				var positionToMove = position + scale_vector2_to_length(velocity, distanceLeftToMove)
				
				if distanceLeftToMove > 0:
					if not space_state.intersect_ray(position, positionToMove, [self]):
						#no collision occured
						position = positionToMove
						
				velocity.y += GRAVITY
				
		elif state_current == states.ON_GROUND:
			#ground to new slope
			#to account for moving onto multiple different slopes in one frame, use a while loop (ref Car.cpp line ~140)
			var dotOfSlopes = relative_up.dot(raycast_collision_normal)
			if dotOfSlopes > 0.5:
				#touching a slope at a usable angle, transition to being on that slope
				var distanceTraveled = (raycast_collision_position - position).length()
				var distanceLeftToMove = (velocity.length() * delta) - distanceTraveled
				
				velocity = calculate_velocity_new_floor(velocity, raycast_collision_normal)
				
				get_onto_floor(raycast_collision_position, raycast_collision_normal)
				
				var positionToMove = position + (velocity.normalized() * distanceLeftToMove)
				
				while (distanceLeftToMove > 0):
					raycast_result = null
					raycast_result = space_state.intersect_ray(position, positionToMove)
					
					if raycast_result:
						#there was a collision, handle it
						dotOfSlopes = relative_up.dot(raycast_collision_normal)
						if dotOfSlopes > 0.5:
							#touching a slope at a usable angle, transition to being on that slope
							distanceTraveled = (raycast_collision_position - position).length()
							distanceLeftToMove -= distanceTraveled
						
							velocity = calculate_velocity_new_floor(velocity, raycast_collision_normal)
						
							get_onto_floor(raycast_collision_position, raycast_collision_normal)
						
							positionToMove = position + (velocity.normalized() * distanceLeftToMove)
						else:
							#slope is super steep and therefore is a wall
							velocity = Vector2(0, 0)
							distanceLeftToMove = 0
					else:
						#no collision, move remaining distance
						position = positionToMove
						distanceLeftToMove = 0
			else:
				#slope is super steep and therefore is a wall
				velocity = Vector2(0, 0)
	else:
		#no initial collision, maybe there's a slope going down?
		position += velocity * delta
		
		#null out the raycast_result, if you collide later 
		raycast_result = null
		
		if state_current == states.ON_GROUND:
			raycast_result = space_state.intersect_ray(position, position - relative_up * 10, [self])
			if raycast_result:
				var raycast_collision_normal = raycast_result.normal
				var raycast_collision_position = raycast_result.position
				
				var dotOfSlopes = relative_up.dot(raycast_collision_normal)
				if dotOfSlopes > 0.6:
					get_onto_floor(raycast_collision_position, raycast_collision_normal)
					
					#align the velocity with the new floor
					velocity = calculate_velocity_new_floor(velocity, raycast_collision_normal)
					
				elif relative_up.angle_to(raycast_collision_normal) > 90:
					#ignore cliffs, but not walls
					raycast_result = null
				
		if raycast_result:
			#colliding with a wall
			#velocity = Vector2(0, 0)
			pass
		else:
			#not colliding with anything, go into air state
			state_current = states.IN_AIR
			rotation = 0
			relative_up = absolute_up
			
			velocity.y += GRAVITY

func _draw() -> void:
	var inverse_transform = get_transform().inverse()
	
	draw_set_transform(inverse_transform.get_origin(), inverse_transform.get_rotation(), inverse_transform.get_scale())
	#draw_line(position, position + velocity * 0.0167, Color(1,0,0,1))
	#draw_line(Vector2(0,0), Vector2(0,0) - relative_up * 6, Color(1,0,0))
	
	pass
	
func get_movement_input() -> void:
	input_move_vector.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	#input_move_vector.y = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	
#This function is used to aligh with floors and walls and such, since you only have a normal to work with for those faces
func project_vector2_onto_face(toProject : Vector2, projectOntoNormal : Vector2) -> Vector2:
	return toProject.project(projectOntoNormal.tangent())
	
func scale_vector2_to_length(vector2ToSet : Vector2, newLength : float) -> Vector2:
	var newVector : Vector2 = Vector2()
	if vector2ToSet.length() > 0:
		var ratio = newLength / vector2ToSet.length()
		newVector = vector2ToSet * ratio
	return newVector
	
func get_onto_floor(raycast_collision_position : Vector2, raycast_collision_normal : Vector2) -> void:
	position = raycast_collision_position
	position += raycast_collision_normal * COLLISION_OFFSET
	rotation = absolute_up.angle_to(raycast_collision_normal)
	relative_up = raycast_collision_normal

func calculate_velocity_new_floor(velocityOld : Vector2, raycast_collision_normal : Vector2) -> Vector2:
	var newDirection = project_vector2_onto_face(velocityOld, raycast_collision_normal)
	return scale_vector2_to_length(newDirection, velocityOld.length())
	
#port of a function from SAB2, applys drag using Eulers number
func apply_drag(velocityCurrent : Vector2, drag : float, delta : float) -> Vector2:
	if velocityCurrent.length() > 0:
		var newLength : float = velocityCurrent.length() * pow(2.718281828459, drag * delta)
		return velocity * (newLength / velocityCurrent.length())
	return velocityCurrent
	
func calculate_next_velocity_ground(delta : float) -> void:
	if input_move_vector.length() > 0:
		velocity += (input_move_vector * 100 * delta).rotated(rotation)
		
		velocity = apply_drag(velocity, -0.5, delta)
		
		if input_move_vector.angle_to(velocity) >= 90:
			velocity = apply_drag(velocity, -5, delta)
			
	else:
		velocity = apply_drag(velocity, -5.5, delta)
		
func calculate_next_velocity_air(delta : float) -> void:
	pass