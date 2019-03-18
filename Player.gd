#some idea stuff:
#raycast should only be enabled when on the ground, when no longer on the ground disable it
#use the raycast to look for a slope to snap down to, and make sure the player's rotation is set based on the floor angle
#the collision shape should only be used for enemies, walls/ceilings, and touching the ground again once in the air, not for the floor movement stuff

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

var circlePos = Vector2(0,0)

#the difference from the players position to cast this ray to use for finding downward slopes
const raycastGroundForSlopes : Vector2 = Vector2(0, 1)

#player move speed, temporary, should be replaced with acceleration system later
const MOVE_SPEED : float = 240.0

func _ready():
	input_move_vector = Vector2(0, 0)
	velocity = Vector2(0, 0)
	relative_up = Vector2(0, -1)
	
	state_current = states.IN_AIR
	
func _process(delta):
	get_movement_input()
	
func _physics_process(delta):
	#access the current state of the world to use for raycasting and such
	var space_state = get_world_2d().direct_space_state
	
	#velocity and movement stuff starts here
	velocity = MOVE_SPEED * input_move_vector
	
	if state_current == states.IN_AIR:
		velocity.y += 50
		
	if state_current == states.ON_GROUND:
		pass
		
	if state_current == states.ON_GROUND:
		velocity = velocity.rotated(rotation)
	
	#collision stuff starts here
	
	var raycast_result = space_state.intersect_ray(position, position + (velocity * delta), [self])
	update()
	
	if raycast_result:
		var raycast_collision_normal = raycast_result.normal
		var raycast_collision_position = raycast_result.position
		
		#print(raycast_collision_normal)
		
		if state_current == states.IN_AIR:
			if raycast_collision_normal.y < -0.5:
				#on floor, transition from air state to ground state
				state_current = states.ON_GROUND
	
				position = raycast_collision_position
				position += raycast_collision_normal * 0.1
				rotation = absolute_up.angle_to(raycast_collision_normal)
				relative_up = raycast_collision_normal
				#rotation = atan2(raycast_collision_normal.x, -raycast_collision_normal.y)
				
				velocity = Vector2(0,0)
				
				circlePos = raycast_collision_position
			else:
				velocity = Vector2(0,0)
		elif state_current == states.ON_GROUND:
			#ground to new slope
			var dotOfSlopes = relative_up.dot(raycast_collision_normal)
			if dotOfSlopes > 0.6:
				#slope isn't super steep, so we can move onto it
				#print(dotOfSlopes)
				position = raycast_collision_position
				position += raycast_collision_normal * 0.1
				rotation = absolute_up.angle_to(raycast_collision_normal)
				relative_up = raycast_collision_normal
				#atan2(raycast_collision_normal.x, -raycast_collision_normal.y)
				
				velocity = Vector2(0,0)
			else:
				#slope is super steep and therefore is a wall
				velocity = Vector2(0, 0)
	elif state_current == states.ON_GROUND:
		#no initial collision, maybe there's a slope going down?
		#position += velocity * delta
		
		raycast_result = space_state.intersect_ray(position, position - relative_up * 5, [self])
		if raycast_result:
			var raycast_collision_normal = raycast_result.normal
			var raycast_collision_position = raycast_result.position
			
			var dotOfSlopes = relative_up.dot(raycast_collision_normal)
			if dotOfSlopes > 0.6:
				position = raycast_collision_position
				position += raycast_collision_normal * 0.1
				rotation = absolute_up.angle_to(raycast_collision_normal)
				relative_up = raycast_collision_normal
			elif relative_up.angle_to(raycast_collision_normal) > 90:
				state_current = states.IN_AIR
				rotation = 0
				relative_up = absolute_up
		else:
			state_current = states.IN_AIR
			rotation = 0
			relative_up = absolute_up
			
			
#			#rotation = atan2(raycast_collision_normal.x, -raycast_collision_normal.y)
#		
#			velocity = Vector2(0,0)
	
	#apply the players movement
	position += velocity * delta	

func _draw():
	var inverse_transform = get_transform().inverse()
	
	draw_set_transform(inverse_transform.get_origin(), inverse_transform.get_rotation(), inverse_transform.get_scale())
	#draw_line(Vector2(0,0) + Vector2(0, -1), (velocity * 0.0167) + Vector2(0, -1), Color(1,0,0,1))
	#draw_line(Vector2(0,0), Vector2(0,0) - relative_up * 6, Color(1,0,0))
	
#	draw_circle(circlePos - position, 5, Color(1,0,0))
	pass
	
func get_movement_input():
	input_move_vector.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	input_move_vector.y = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))