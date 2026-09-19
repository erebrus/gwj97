extends Node

signal level_ended()

signal thrust_requested()
signal thrust_stopped()
signal out_of_fuel()
signal player_position_updated(pos:Vector2)
signal fuel_consumed(fuel:int)


signal laser_position_updated(start:Vector2, end:Vector2)
signal laser_cancelled()


signal control_state_changed(control_type:Game.MouseControl)

signal successful_production(room:StationRoom)
signal unsuccessful_production(room:StationRoom)

signal request_hud_update()

signal on_camera_mode_changed(val:bool)
