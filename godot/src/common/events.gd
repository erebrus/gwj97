extends Node

signal level_ended()

signal thrust_requested()
signal thrust_stopped()
signal out_of_fuel()
signal player_position_updated(pos:Vector2)
signal fuel_consumed(fuel:int)


signal laser_position_updated(start:Vector2, end:Vector2)
signal laser_cancelled()
